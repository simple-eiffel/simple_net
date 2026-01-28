# INTERFACE DESIGN: simple_net - Public API

**Date:** January 28, 2026
**Specification Phase:** Step 6 - API Design

---

## Overview

This document specifies the public API surface: creation patterns, configuration, core operations, status queries, and fluent design. Examples demonstrate typical usage patterns.

---

## Creation Patterns

### 1. Direct Socket Creation

**CLIENT_SOCKET:**
```eiffel
-- Pattern 1: Create with host and port
create client.make_for_host_port("example.com", 8080)

-- Pattern 2: Create with ADDRESS object
address := create {ADDRESS}.make_for_host_port("example.com", 8080)
create client.make_for_address(address)

-- Pattern 3: Convenience factory (via SIMPLE_NET)
client := simple_net.new_client_for_host_port("example.com", 8080)
```

**SERVER_SOCKET:**
```eiffel
-- Pattern 1: Create with port
create server.make_for_port(8080)

-- Pattern 2: Create with ADDRESS
address := create {ADDRESS}.make_for_host_port("0.0.0.0", 8080)
create server.make_for_address(address)

-- Pattern 3: Convenience factory
server := simple_net.new_server_for_port(8080)
```

**ADDRESS:**
```eiffel
-- Pattern 1: Direct creation
address := create {ADDRESS}.make_for_host_port("localhost", 8080)

-- Pattern 2: Localhost convenience
address := create {ADDRESS}.make_for_localhost_port(8080)

-- Pattern 3: Via SIMPLE_NET
address := simple_net.new_address_for_host_port("127.0.0.1", 8080)
```

---

## Configuration API

### Timeout Management

```eiffel
-- Set single timeout (applies to all operations)
client.set_timeout(5.0)  -- 5 seconds

-- Query current timeout
timeout := client.timeout
```

### Buffer Configuration (Phase 2)

```eiffel
-- Deferred to Phase 2
-- client.set_send_buffer_size(65536)
-- client.set_receive_buffer_size(65536)
```

---

## Core Operations

### CLIENT_SOCKET Operations

#### Connect

```eiffel
-- Connect to server
create client.make_for_host_port("example.com", 8080)
client.set_timeout(5.0)

if client.connect then
    -- Connected successfully
    log.info("Connected to " + client.remote_address.as_string)
else
    -- Connection failed
    log.error("Failed to connect: " + client.last_error_string)
    if client.error_classification = ERROR_TYPE.connection_timeout then
        -- Handle timeout (e.g., retry)
    elseif client.error_classification = ERROR_TYPE.connection_refused then
        -- Server refused; maybe retry later
    end
end
```

#### Send

```eiffel
-- Send string data
data := "Hello, server!"
if client.send_string(data) then
    log.info("Sent " + data.length.out + " bytes")
else
    log.error("Send failed: " + client.last_error_string)
    if client.error_classification = ERROR_TYPE.write_error then
        -- Broken pipe or connection reset
    end
end

-- Send binary data
binary_data: ARRAY [BYTE]
...
if client.send(binary_data) then
    log.info("Sent " + binary_data.count.out + " bytes")
else
    log.error("Send failed")
end
```

#### Receive

```eiffel
-- Receive data
data := client.receive(4096)  -- Up to 4096 bytes

if data.count > 0 then
    log.info("Received " + data.count.out + " bytes")
    -- Process data
elseif client.is_at_end_of_stream then
    log.info("Server closed connection")
else
    log.error("Receive error: " + client.last_error_string)
end
```

#### Close

```eiffel
-- Close connection
client.close
log.info("Connection closed")
```

---

### SERVER_SOCKET Operations

#### Listen

```eiffel
-- Create and listen
create server.make_for_port(8080)
server.set_timeout(5.0)

if server.listen(10) then  -- backlog = 10
    log.info("Listening on port 8080")
else
    log.error("Failed to listen: " + server.last_error_string)
    if server.error_classification = ERROR_TYPE.bind_error then
        -- Port already in use
    end
end
```

#### Accept

```eiffel
-- Accept one connection
connection := server.accept

if connection /= Void then
    log.info("Accepted connection from " + connection.remote_address.as_string)
    -- Handle connection
    connection.close
else
    log.error("Accept failed: " + server.last_error_string)
    if server.error_classification = ERROR_TYPE.operation_cancelled then
        -- Timeout waiting for connection
    end
end
```

#### Multi-Client Loop

```eiffel
-- Accept multiple clients in loop
create server.make_for_port(8080)
server.set_timeout(5.0)
server.listen(10)

from
    should_run := true
until
    not should_run
loop
    connection := server.accept
    if connection /= Void then
        handle_client(connection)
        connection.close
    else
        if server.is_error then
            log.error("Accept failed: " + server.last_error_string)
            should_run := false
        end
    end
end

server.close
```

#### Close

```eiffel
-- Stop listening and cleanup
server.close
log.info("Server closed")
```

---

## Status Queries

### CLIENT_SOCKET Queries

```eiffel
-- Connection state
if client.is_connected then
    log.info("Client connected")
else
    log.info("Client not connected")
end

-- Error state
if client.is_error then
    log.error("Client error: " + client.last_error_string)
    -- Check specific error
    err := client.error_classification
end

-- EOF state
if client.is_at_end_of_stream then
    log.info("Server closed; no more data")
end

-- Socket closed
if client.is_closed then
    log.info("Socket cleanup complete")
end

-- Address information
if client.is_connected then
    remote := client.remote_address
    local := client.local_address
    log.info("Remote: " + remote.as_string)
    log.info("Local: " + local.as_string)
end
```

### SERVER_SOCKET Queries

```eiffel
-- Server state
if server.is_listening then
    log.info("Server listening on " + server.local_address.as_string)
end

-- Error state
if server.is_error then
    log.error("Server error: " + server.last_error_string)
end

-- Statistics
log.info("Total connections accepted: " + server.connection_count.out)

-- Address information
addr := server.local_address
log.info("Listening on " + addr.as_string)
```

### CONNECTION Queries

```eiffel
-- Connection state
if connection.is_connected then
    log.info("Connection active")
end

-- EOF state
if connection.is_at_end_of_stream then
    log.info("Peer closed")
end

-- Statistics
log.info("Bytes sent: " + connection.bytes_sent.out)
log.info("Bytes received: " + connection.bytes_received.out)
```

---

## Error Handling Patterns

### Pattern 1: Check-Then-Act

```eiffel
-- Typical pattern: Check error after operation
client.connect()
if not client.is_error then
    -- Success
    client.send_string("data")
else
    -- Handle error
    log.error("Connect failed: " + client.last_error_string)
end
```

### Pattern 2: Error Classification

```eiffel
-- Smart retry based on error type
error_type := client.error_classification
if error_type = ERROR_TYPE.connection_timeout then
    -- Retriable: retry
    retry_count := retry_count + 1
elseif error_type = ERROR_TYPE.connection_refused then
    -- Retriable: retry
    retry_count := retry_count + 1
elseif error_type = ERROR_TYPE.address_not_available then
    -- Not retriable: give up
    log.error("Address resolution failed")
else
    -- Unknown: try once more
    log.warn("Unexpected error; retrying")
    retry_count := retry_count + 1
end
```

### Pattern 3: Error Classification Checks (Convenience)

```eiffel
-- Check if error is retriable
if ERROR_TYPE.is_retriable(client.error_classification) then
    -- Retry
    client.connect()
end

-- Check if error is fatal
if ERROR_TYPE.is_fatal(client.error_classification) then
    -- Give up, log and exit
    log.error("Fatal error: " + client.last_error_string)
    should_run := false
end
```

### Pattern 4: Timeout Handling

```eiffel
-- Set short timeout for fast-fail
client.set_timeout(1.0)
if client.connect then
    -- Connected quickly
else
    -- Either timeout or other error
    if client.error_classification = ERROR_TYPE.connection_timeout then
        log.warn("Connection timeout; server too slow")
    else
        log.error("Connection failed: " + client.last_error_string)
    end
end
```

### Pattern 5: Retry Loop

```eiffel
-- Retry with exponential backoff
max_retries := 3
retry_count := 0
backoff_ms := 100

from
    retry_count := 0
until
    retry_count >= max_retries or client.is_connected
loop
    if client.connect then
        log.info("Connected on attempt " + (retry_count + 1).out)
    else
        retry_count := retry_count + 1
        if retry_count < max_retries then
            log.warn("Connection failed; retrying in " + backoff_ms.out + "ms")
            sleep(backoff_ms)
            backoff_ms := backoff_ms * 2  -- Exponential backoff
        end
    end
end

if not client.is_connected then
    log.error("Failed to connect after " + max_retries.out + " attempts")
end
```

---

## Fluent API Considerations

### Current Design (Command-Query Separation)

```eiffel
-- Simple, straightforward API
client.set_timeout(5.0)
if client.connect then
    client.send_string("request")
else
    log.error("Failed")
end
```

### Future Fluent Variant (Phase 2 Optional)

```eiffel
-- Hypothetical fluent API (NOT in Phase 1)
-- Would require different design
client
    .set_timeout(5.0)
    .connect
    .send_string("request")
    .close
```

**Design Decision:** Phase 1 uses command-query separation (standard Eiffel). Fluent API deferred to Phase 2 if demanded.

---

## Command-Query Separation Analysis

### Commands (Actions That Change State)

| Command | Effect | Returns |
|---------|--------|---------|
| `connect()` | Changes is_connected state | BOOLEAN (success?) |
| `send()` | Changes bytes_sent | BOOLEAN (success?) |
| `listen()` | Changes is_listening state | BOOLEAN (success?) |
| `accept()` | Creates new CONNECTION | CONNECTION or Void |
| `close()` | Changes is_closed state | VOID |
| `set_timeout()` | Changes timeout value | VOID |

### Queries (State Inspection, No Side Effects)

| Query | Returns | Precondition |
|-------|---------|--------------|
| `is_connected` | BOOLEAN | none |
| `is_error` | BOOLEAN | none |
| `error_classification` | ERROR_TYPE | is_error |
| `last_error_string` | STRING | is_error |
| `bytes_sent` | INTEGER | connected (ideally) |
| `bytes_received` | INTEGER | connected (ideally) |
| `timeout` | REAL | none |
| `is_listening` | BOOLEAN | none |
| `is_at_end_of_stream` | BOOLEAN | is_connected |

**Principle:** Operations that change state return status (BOOLEAN); operations that only inspect state return values. This follows CQS (Command-Query Separation) principle.

---

## Feature Request Patterns

### How Does User Know What Methods Are Available?

**Answer:** Multiple routes:
1. IDE autocomplete (lists all public methods)
2. Documentation (API reference + examples)
3. Code examples (copy-paste starter patterns)
4. DBC contracts (preconditions document required state)

### Example: IDE Autocomplete Discovery

```eiffel
-- User types: client.
-- IDE suggests:
--   - connect()
--   - send()
--   - send_string()
--   - receive()
--   - receive_string()
--   - close()
--   - set_timeout()
--   - is_connected
--   - is_error
--   - error_classification
--   - ... etc
```

### Example: Contract-Driven Discovery

```eiffel
-- User calls send() without being connected
-- Compiler gives error:
-- "Precondition violated: send requires is_connected"
-- User realizes they must connect first
```

---

## Typical Workflows

### Workflow 1: Simple TCP Client

```eiffel
create client.make_for_host_port("server.example.com", 8080)
client.set_timeout(5.0)

if client.connect then
    if client.send_string("GET / HTTP/1.0") then
        response := client.receive_string(4096)
        log.info("Response: " + response)
    end
    client.close
else
    log.error("Connection failed: " + client.last_error_string)
end
```

### Workflow 2: Simple TCP Server

```eiffel
create server.make_for_port(8080)
server.set_timeout(10.0)

if server.listen(5) then
    from until not should_run loop
        connection := server.accept
        if connection /= Void then
            handle_client(connection)
            connection.close
        end
    end
    server.close
end
```

### Workflow 3: Echo Server with Timeout

```eiffel
-- Server that times out after 10 seconds of inactivity
create server.make_for_port(9000)
server.set_timeout(10.0)
server.listen(5)

from until not should_run loop
    connection := server.accept
    if connection /= Void then
        connection.set_timeout(10.0)

        from until connection.is_at_end_of_stream or connection.is_error loop
            data := connection.receive(1024)
            if data.count > 0 then
                connection.send(data)  -- Echo back
            end
        end
        connection.close
    else
        if server.error_classification = ERROR_TYPE.connection_timeout then
            -- Accept timed out; maybe this is OK
        else
            log.error("Accept error: " + server.last_error_string)
        end
    end
end
```

---

## API Consistency Checklist

| Aspect | Requirement | Example |
|--------|-------------|---------|
| **Naming** | Short, consistent verbs | connect, send, receive, listen, accept, close |
| **Return Types** | Command→BOOLEAN/VOID, Query→TYPE | send→BOOLEAN, is_connected→BOOLEAN, bytes_sent→INTEGER |
| **Preconditions** | Document required state | send requires is_connected |
| **Postconditions** | Document changed state | connect ensures is_connected or is_error |
| **Error Queries** | Consistent pattern | is_error, error_classification, last_error_string |
| **Immutability** | ADDRESS and ERROR_TYPE | address.host immutable, error_type enum |
| **Timeout** | Single set_timeout() method | Both client and server use same interface |
| **I/O Symmetry** | Both send and receive | send(data), receive(max_bytes) |
| **Lifecycle** | Clear state transitions | unconnected → connected → closed |

---

## API Stability & Versioning

### Phase 1 (v1.0)
- **Stable:** All public classes and methods
- **Immutable:** CLASS names (CLIENT_SOCKET, SERVER_SOCKET, CONNECTION, ADDRESS, ERROR_TYPE)
- **Immutable:** Public method signatures
- **Immutable:** Precondition/postcondition semantics

### Phase 2 (v1.1 or v2.0)
- **New Features:** Non-blocking variants, IPv6 support, connection pooling
- **Backward Compatible (v1.1):** Add new methods; don't remove old ones
- **Breaking Changes (v2.0):** Only if necessary (semantic versioning)

### Deprecation Path
- Method marked @deprecated in documentation
- Remains functional for 2-3 releases
- Clear migration path provided
- Example in documentation showing new way

---

## Type Safety

### Phase 1 Type Discipline

```eiffel
-- All operations type-safe
address: ADDRESS           -- Must be ADDRESS type
client: CLIENT_SOCKET      -- Must be CLIENT_SOCKET type
connection: CONNECTION     -- Must be CONNECTION type
error: ERROR_TYPE          -- Enum value, not string
timeout: REAL              -- Real seconds, not integer

-- No implicit conversions
-- No magic strings for errors
-- No void-unsafety issues
```

### Void Safety

All code compiled with `void_safety="all"`:
```eiffel
-- This doesn't compile (void-unsafe)
if address.host.is_equal("localhost") then ...  -- What if address is Void?

-- This is required (void-safe)
if address /= Void and then address.host.is_equal("localhost") then ...
```

---

