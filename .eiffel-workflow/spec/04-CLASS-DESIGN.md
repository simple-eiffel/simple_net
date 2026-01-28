# CLASS DESIGN: simple_net - OOSC2 Architecture

**Date:** January 28, 2026
**Specification Phase:** Step 4 - Structural Design

---

## Overview

This document describes the class inventory, inheritance hierarchy, composition relationships, and design justification following OOSC2 principles (Object-Oriented Software Construction, 2nd Edition by Bertrand Meyer).

---

## Class Inventory

### Core Classes (7)

| Class | Purpose | Parent | Status |
|-------|---------|--------|--------|
| **ADDRESS** | Network endpoint (host:port) | none | NEW |
| **CONNECTION** | Active TCP stream (bidirectional) | none | NEW |
| **CLIENT_SOCKET** | Outbound TCP socket | none | NEW |
| **SERVER_SOCKET** | Inbound TCP socket | none | NEW |
| **ERROR_TYPE** | Error classification enum | none | NEW |
| **SIMPLE_NET** | Facade / constants | none | NEW |
| **SOCKET_BASE** | Shared implementation | none | NEW |

### Reference Classes (3, from ISE net.ecf)

| Class | Role | ISE Location |
|-------|------|--------------|
| NETWORK_STREAM_SOCKET | Underlying TCP implementation | ISE net.ecf |
| INET_ADDRESS | Address resolution (hidden) | ISE net.ecf |
| ADDRESS_FAMILY | Protocol family constants | ISE net.ecf |

---

## Inheritance Hierarchy

```
──────────────────────────────────────────────────────────────
                   INHERITANCE TREE
──────────────────────────────────────────────────────────────

                          ANY
                           △
                           │
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    CONNECTION       CLIENT_SOCKET     SERVER_SOCKET
                           │                 │
                           └─────────┬───────┘
                                     │
                              SOCKET_BASE
                                     △
                                     │
                         (Internal implementation)

                          ERROR_TYPE
                        (Enum structure)

                          ADDRESS
                     (Value object)

                       SIMPLE_NET
                    (Facade/constants)
```

---

## Detailed Class Specifications

### 1. CONNECTION
**Purpose:** Represent active TCP stream (bidirectional, full-duplex)

**IS-A Justification:**
- CONNECTION is a SOCKET in general terms, but we don't inherit from SOCKET_BASE
- Reason: CONNECTION is already fully connected; SOCKET_BASE handles both connect and listen states
- Instead: CONNECTION composes ISE's NETWORK_STREAM_SOCKET (HAS-A relation)

**Public Interface:**
```eiffel
class CONNECTION

feature -- Status Queries
    is_connected: BOOLEAN
        -- Is stream actively connected and healthy?

    is_at_end_of_stream: BOOLEAN
        -- Has peer closed connection (EOF)?

    is_error: BOOLEAN
        -- Did last operation fail?

    error_classification: ERROR_TYPE
        -- What type of error occurred (if is_error)?

    last_error_string: STRING
        -- Human-readable error description

feature -- I/O Operations
    send (data: ARRAY [BYTE]): BOOLEAN
        -- Send complete data block (all or nothing)
        -- Returns: TRUE if all sent, FALSE if error

    send_string (data: STRING): BOOLEAN
        -- Send string as bytes
        -- Returns: TRUE if all sent, FALSE if error

    receive (max_bytes: INTEGER): ARRAY [BYTE]
        -- Receive up to max_bytes (may be less on EOF)
        -- Returns: Bytes available (empty if EOF or error)

    receive_string (max_chars: INTEGER): STRING
        -- Receive up to max_chars as string
        -- Returns: String received (empty if EOF or error)

feature -- Lifecycle
    close
        -- Close connection gracefully
        -- Flushes any pending data before close

    is_closed: BOOLEAN
        -- Is connection closed?

feature -- State Management
    set_timeout (seconds: REAL)
        -- Set timeout for all operations
        -- Precondition: seconds >= 0
        -- Effect: Applies to all subsequent send/receive

    timeout: REAL
        -- Current timeout setting

feature -- Statistics (MML Model)
    bytes_sent: INTEGER
        -- Cumulative bytes successfully transmitted

    bytes_received: INTEGER
        -- Cumulative bytes successfully received

    active_duration: REAL
        -- Time connection has been active (seconds)

end
```

**Composition:**
```
CONNECTION
    │
    ├─ underlying_socket: NETWORK_STREAM_SOCKET (hidden ISE socket)
    ├─ timeout_value: REAL
    ├─ error_state: ERROR_TYPE
    ├─ bytes_sent_count: INTEGER
    ├─ bytes_received_count: INTEGER
    └─ creation_time: TIME
```

**Invariant:**
```eiffel
invariant
    valid_timeout: timeout >= 0
    not_error_and_connected: not (is_error and is_connected)
    byte_counters_non_negative: bytes_sent >= 0 and bytes_received >= 0
```

---

### 2. CLIENT_SOCKET
**Purpose:** Initiate outbound TCP connections

**IS-A Justification:**
- CLIENT_SOCKET IS-A type of socket (intent: client-side)
- CLIENT_SOCKET specializes socket operations (only connect, send, receive; not listen, accept)
- Inheritance from SOCKET_BASE: Shares connection lifecycle, timeout, error handling

**Public Interface:**
```eiffel
class CLIENT_SOCKET

inherit
    SOCKET_BASE
        undefine
            listen, accept  -- Server operations not available
        end

feature -- Creation
    make_for_host_port (host: STRING; port: INTEGER)
        -- Create client socket for remote server
        -- Precondition: host.length > 0, port in 1..65535
        -- Effect: Initialize but not yet connected

    make_for_address (address: ADDRESS)
        -- Create client socket for given address
        -- Precondition: address /= Void
        -- Effect: Initialize but not yet connected

feature -- Connection
    connect: BOOLEAN
        -- Establish connection to remote server
        -- Precondition: not is_connected and not is_error
        -- Postcondition: (is_connected and not is_error) or (not is_connected and is_error)
        -- Returns: TRUE if connected, FALSE if error

    is_connected: BOOLEAN
        -- Is socket connected to server?

feature -- I/O
    send (data: ARRAY [BYTE]): BOOLEAN
        -- Send data to server (inherited from SOCKET_BASE)
        -- Precondition: is_connected

    receive (max_bytes: INTEGER): ARRAY [BYTE]
        -- Receive data from server (inherited from SOCKET_BASE)
        -- Precondition: is_connected

feature -- Lifecycle
    close
        -- Disconnect from server and cleanup
        -- Effect: is_connected = FALSE, is_closed = TRUE

feature -- Address Info
    remote_address: ADDRESS
        -- Connected server address (if connected)

    local_address: ADDRESS
        -- Local address bound to socket (if connected)

end
```

**Invariant:**
```eiffel
invariant
    not_simultaneous: not (is_connected and is_error)
    connect_if_connected: is_connected implies remote_address /= Void
```

---

### 3. SERVER_SOCKET
**Purpose:** Accept inbound TCP connections

**IS-A Justification:**
- SERVER_SOCKET IS-A type of socket (intent: server-side)
- SERVER_SOCKET specializes socket operations (listen, accept; not connect, send, receive directly)
- Inheritance from SOCKET_BASE: Shares error handling, timeout, lifecycle

**Public Interface:**
```eiffel
class SERVER_SOCKET

inherit
    SOCKET_BASE
        undefine
            connect, send, receive  -- Client operations not available on server itself
        end

feature -- Creation
    make_for_port (port: INTEGER)
        -- Create server socket listening on port
        -- Precondition: port in 1..65535
        -- Effect: Initialize but not yet listening

    make_for_address (address: ADDRESS)
        -- Create server socket for given address
        -- Precondition: address /= Void

feature -- Listening
    listen (backlog: INTEGER)
        -- Start listening for connections
        -- Precondition: not is_listening and not is_error, backlog > 0
        -- Postcondition: (is_listening and not is_error) or (not is_listening and is_error)

    is_listening: BOOLEAN
        -- Is server socket actively listening?

    backlog: INTEGER
        -- Current backlog queue size
        -- Precondition: is_listening

feature -- Accepting Connections
    accept: CONNECTION
        -- Wait for and accept incoming connection
        -- Precondition: is_listening and not is_error
        -- Postcondition: Result /= Void implies (not Result.is_error and Result.is_connected)
        -- Returns: CONNECTION object (fresh, connected) or Void if error

    last_accepted_address: ADDRESS
        -- Address of last accepted client (for logging)

feature -- Lifecycle
    close
        -- Stop listening and cleanup
        -- Effect: is_listening = FALSE

feature -- Server Info
    local_address: ADDRESS
        -- Server socket address (if listening)

    connection_count: INTEGER
        -- Total connections accepted so far (cumulative)

end
```

**Invariant:**
```eiffel
invariant
    not_simultaneous: not (is_listening and is_error)
    backlog_if_listening: is_listening implies backlog > 0
    listen_if_listening: is_listening implies local_address /= Void
```

---

### 4. SOCKET_BASE
**Purpose:** Shared implementation for CLIENT_SOCKET and SERVER_SOCKET

**IS-A Justification:**
- SOCKET_BASE is an abstract base class (not instantiated)
- Defines common features: error handling, timeout, lifecycle
- Avoids code duplication between CLIENT_SOCKET and SERVER_SOCKET

**Protected Features (Internal):**
```eiffel
deferred class SOCKET_BASE

feature {SOCKET_BASE, CLIENT_SOCKET, SERVER_SOCKET} -- Protected

    underlying_socket: NETWORK_STREAM_SOCKET
        -- ISE net.ecf socket (hidden from users)

    error_state: ERROR_TYPE
        -- Current error classification

    last_error_message: STRING
        -- Error description (for debugging)

    timeout_value: REAL
        -- Current timeout in seconds

feature {SOCKET_BASE, CLIENT_SOCKET, SERVER_SOCKET} -- Implementation

    set_error (error_type: ERROR_TYPE; message: STRING)
        -- Internal: Set error state
        deferred
        end

    clear_error
        -- Internal: Clear error state
        deferred
        end

    initialize_socket
        -- Internal: Setup underlying ISE socket
        deferred
        end

    cleanup_socket
        -- Internal: Cleanup ISE socket
        deferred
        end

feature -- Common Interface

    is_error: BOOLEAN
        -- Is socket in error state?

    error_classification: ERROR_TYPE
        -- What error occurred?

    last_error_string: STRING
        -- Error message

    set_timeout (seconds: REAL)
        -- Set timeout for all operations
        -- Precondition: seconds >= 0

    timeout: REAL
        -- Get current timeout

    close
        -- Close socket
        deferred
        end

    is_closed: BOOLEAN
        -- Is socket closed?

invariant
    valid_timeout: timeout >= 0
    error_consistency: is_error = (error_state /= ERROR_TYPE.no_error)

end
```

**Design Rationale:**
- Uses Eiffel's deferred class mechanism
- CLIENT_SOCKET and SERVER_SOCKET implement specifics
- Reuses error handling, timeout management
- Encapsulates ISE socket complexity
- Satisfies DRY (Don't Repeat Yourself) principle

---

### 5. ADDRESS
**Purpose:** Encapsulate network endpoint (host:port)

**IS-A Justification:**
- ADDRESS is a VALUE OBJECT (not mutable, reusable)
- Not derived from anything (self-contained)

**Public Interface:**
```eiffel
class ADDRESS

feature -- Creation
    make_for_host_port (a_host: STRING; a_port: INTEGER)
        -- Create address for hostname and port
        -- Precondition: a_host.length > 0, a_port in 1..65535
        -- Postcondition: host = a_host, port = a_port

    make_for_localhost_port (a_port: INTEGER)
        -- Convenience: Create address for localhost:port
        -- Precondition: a_port in 1..65535
        -- Postcondition: host = "127.0.0.1" or "localhost"

feature -- Access
    host: STRING
        -- Hostname or IP address (immutable)

    port: INTEGER
        -- Port number (immutable)

    as_string: STRING
        -- Human-readable form: "host:port"

feature -- Queries
    is_loopback: BOOLEAN
        -- Is address localhost or 127.0.0.1?

    is_broadcast: BOOLEAN
        -- Is address 255.255.255.255 (IPv4 broadcast)?

    is_wildcard: BOOLEAN
        -- Is address 0.0.0.0 (all interfaces)?

feature -- Comparison
    is_equal (other: ADDRESS): BOOLEAN
        -- Two addresses equal if same host:port

    is_same_host (other: ADDRESS): BOOLEAN
        -- Same hostname but possibly different port?

invariant
    valid_host: host.length > 0
    valid_port: port >= 1 and port <= 65535
    immutable: -- host and port never change after creation

end
```

**Design Rationale:**
- Immutable (value object semantics)
- Validates port range at creation (fail-fast)
- Simple API: (host: STRING, port: INTEGER)
- No external factory complexity
- Clear distinction from ISE's INET_ADDRESS
- Composable in both CLIENT_SOCKET and SERVER_SOCKET

---

### 6. ERROR_TYPE
**Purpose:** Classify socket errors

**IS-A Justification:**
- ERROR_TYPE is an enumeration (finite set of values)
- Not a class; defined as constants

**Definition:**
```eiffel
class ERROR_TYPE

feature -- Error Classification

    -- Common socket errors

    no_error: INTEGER = 0
        -- No error (operation successful)

    connection_refused: INTEGER = 1
        -- Peer refused connection (ECONNREFUSED)

    connection_timeout: INTEGER = 2
        -- Connect or accept timed out (ETIMEDOUT)

    connection_reset: INTEGER = 3
        -- Peer reset connection mid-stream (ECONNRESET)

    connection_closed: INTEGER = 4
        -- Peer closed connection normally (EOF)

    read_error: INTEGER = 5
        -- Error reading from socket (EIO, EBADF)

    write_error: INTEGER = 6
        -- Error writing to socket (EPIPE, EBROKEN)

    bind_error: INTEGER = 7
        -- Failed to bind to port (EADDRINUSE, EACCES)

    listen_error: INTEGER = 8
        -- Failed to listen (EOPNOTSUPP)

    address_not_available: INTEGER = 9
        -- Invalid or unreachable address

    operation_cancelled: INTEGER = 10
        -- Operation cancelled (timeout or user request)

    other: INTEGER = -1
        -- Unknown error (includes raw OS error code)

feature -- Query

    is_retriable (error_code: INTEGER): BOOLEAN
        -- Can client retry after this error?
        -- (CONNECTION_TIMEOUT, CONNECTION_RESET, etc.)

    is_fatal (error_code: INTEGER): BOOLEAN
        -- Is this error unrecoverable?
        -- (BIND_ERROR, ADDRESS_NOT_AVAILABLE, etc.)

    description (error_code: INTEGER): STRING
        -- Human-readable description of error code

end
```

**Design Rationale:**
- Finite set of common errors (11 categories)
- NO_ERROR (0) as default state
- RETRIABLE errors encourage retry logic
- FATAL errors indicate give-up
- OTHER (-1) for unknowns (preserves raw error code)
- Enables smart error handling (not just string comparison)

---

### 7. SIMPLE_NET
**Purpose:** Facade and public API entry point

**Public Interface:**
```eiffel
class SIMPLE_NET

feature -- Factory Methods

    new_client_for_host_port (host: STRING; port: INTEGER): CLIENT_SOCKET
        -- Create client socket for host:port
        -- Convenience factory

    new_server_for_port (port: INTEGER): SERVER_SOCKET
        -- Create server socket for port
        -- Convenience factory

    new_address_for_host_port (host: STRING; port: INTEGER): ADDRESS
        -- Create address for host:port
        -- Convenience factory

feature -- Constants

    default_timeout: REAL = 5.0
        -- Default timeout (seconds) for new sockets

    max_backlog: INTEGER = 128
        -- Maximum reasonable backlog queue

    min_port: INTEGER = 1
    max_port: INTEGER = 65535
        -- Valid port range

feature -- Utility

    resolve_hostname (hostname: STRING): STRING
        -- Resolve hostname to IP address
        -- Returns: IP address string, or empty if resolution fails

    is_valid_port (port: INTEGER): BOOLEAN
        -- Check if port is in valid range

end
```

**Design Rationale:**
- Single entry point for library
- Provides convenience factories
- Holds shared constants (default timeout, max backlog)
- Optional utility methods (hostname resolution, validation)
- Simplifies documentation and examples

---

## Composition Relationships

```
┌──────────────────────────────────────────────────────────────┐
│                    COMPOSITION DIAGRAM                       │
└──────────────────────────────────────────────────────────────┘

CLIENT_SOCKET
    │
    ├─ "has-a" ──→ ADDRESS (remote_address)
    │
    ├─ "has-a" ──→ ADDRESS (local_address, if connected)
    │
    └─ "has-a" ──→ NETWORK_STREAM_SOCKET (underlying_socket, hidden)

SERVER_SOCKET
    │
    ├─ "has-a" ──→ ADDRESS (local_address, if listening)
    │
    └─ "has-a" ──→ NETWORK_STREAM_SOCKET (underlying_socket, hidden)

CONNECTION
    │
    ├─ "has-a" ──→ NETWORK_STREAM_SOCKET (underlying_socket)
    │
    └─ "reports-a" ──→ ERROR_TYPE (error_state)

SOCKET_BASE
    │
    ├─ "has-a" ──→ NETWORK_STREAM_SOCKET (underlying_socket, hidden)
    │
    └─ "has-a" ──→ ERROR_TYPE (error_state)

```

---

## Design Principles Applied (OOSC2)

### 1. Single Responsibility Principle (SRP)
- **ADDRESS**: Represents network endpoint only
- **CONNECTION**: Manages active data transfer only
- **CLIENT_SOCKET**: Manages client-side connection lifecycle only
- **SERVER_SOCKET**: Manages server-side connection lifecycle only
- **ERROR_TYPE**: Classifies errors only
- **SOCKET_BASE**: Shared socket implementation only

### 2. Open-Closed Principle (OCP)
- Classes open for extension (inheritance for CLIENT_SOCKET, SERVER_SOCKET from SOCKET_BASE)
- Closed for modification (ADDRESS, ERROR_TYPE immutable)
- Phase 2 can add variants (e.g., non-blocking mode) without changing existing classes

### 3. Liskov Substitution Principle (LSP)
- Both CLIENT_SOCKET and SERVER_SOCKET can be used where SOCKET_BASE expected
- Both honor SOCKET_BASE contracts
- No surprises when using either type

### 4. Interface Segregation Principle (ISP)
- Separate CLIENT_SOCKET and SERVER_SOCKET (not unified socket)
- Each has only operations relevant to its role (connect for client, listen for server)
- Users don't see irrelevant methods

### 5. Dependency Inversion Principle (DIP)
- High-level code depends on ADDRESS, CONNECTION, ERROR_TYPE abstractions
- Not on ISE NETWORK_STREAM_SOCKET directly
- SOCKET_BASE depends on abstractions (error handling, timeout)
- Not on concrete implementations

---

## Class Design Justifications

| Class | Why Separate? | Why Not Inherit? | Why Compose ISE Socket? |
|-------|---------------|------------------|------------------------|
| **ADDRESS** | Value object with validation | Nothing to inherit from | N/A (value object) |
| **CLIENT_SOCKET** | Client-only interface (not accept) | Inherits from SOCKET_BASE | ISE net.ecf is proven |
| **SERVER_SOCKET** | Server-only interface (not connect) | Inherits from SOCKET_BASE | ISE net.ecf is proven |
| **CONNECTION** | Already connected (no connect/listen) | No common parent needed | ISE socket handles TCP |
| **SOCKET_BASE** | Shared impl, reduces duplication | Abstract base (not instantiated) | Encapsulates ISE |
| **ERROR_TYPE** | Finite enum (not mutable class) | Inheritance not applicable | Not composable |
| **SIMPLE_NET** | Facade / entry point | Not applicable | Not applicable |

---

## Design Alternatives Considered (and Rejected)

### Alternative 1: Unified SOCKET Class
**Rejected because:** ISP violation (users see irrelevant methods), confusion risk (connect on server), not matching Python/Go convention

### Alternative 2: Direct ISE net.ecf Exposure
**Rejected because:** Doesn't reduce boilerplate, confusing academic naming, no error classification, tight coupling to ISE

### Alternative 3: Exception-Based Error Handling
**Rejected because:** Not Eiffel convention, conflicts with DBC approach, ISE net already uses queries

### Alternative 4: Async/Non-Blocking in Phase 1
**Rejected because:** Adds complexity, blocks MVP, Phase 2 can add cleanly

---

## Forward Compatibility

**Phase 2 Extensions (Non-Breaking):**
- `set_non_blocking()` on CLIENT_SOCKET, SERVER_SOCKET, CONNECTION
- `send_async()` and `receive_async()` on CONNECTION
- `set_connect_timeout()`, `set_read_timeout()` for granular timeouts
- IPv6 variants of ADDRESS
- Connection pooling (external utility class)

**These additions don't require changing Phase 1 API.**

---

