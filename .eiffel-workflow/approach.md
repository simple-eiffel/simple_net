# Implementation Approach: simple_net

## Overview

simple_net is a TCP socket abstraction library that wraps EiffelStudio's ISE net.ecf with an intuitive, contract-first API. The library provides mainstream-friendly semantics (CLIENT_SOCKET, SERVER_SOCKET) instead of academic naming (NETWORK_STREAM_SOCKET).

## Architecture

### Core Domain Model

```
ADDRESS (immutable value object)
    ├── host: STRING (hostname or IP)
    └── port: INTEGER (1-65535)

ERROR_TYPE (error classification enum)
    ├── code: INTEGER (OS error code)
    ├── is_connection_refused, is_timeout, is_connection_reset, etc.
    └── is_retriable, is_fatal (for retry logic)

CONNECTION (deferred interface)
    ├── send, receive (data transfer)
    ├── close (cleanup)
    ├── set_timeout (configuration)
    ├── bytes_sent, bytes_received (telemetry)
    └── error_classification, last_error_string (error reporting)

CLIENT_SOCKET (TCP client) implements CONNECTION
    ├── remote_address: ADDRESS
    ├── connect(): BOOLEAN (initiates connection)
    ├── send/receive (CONNECTED state only)
    └── is_connected, is_closed, is_error (state queries)

SERVER_SOCKET (TCP server) implements CONNECTION interface pattern
    ├── local_address: ADDRESS
    ├── listen(backlog): BOOLEAN (starts listening)
    ├── accept(): detachable CONNECTION (returns client connection)
    └── is_listening, is_closed, is_error (state queries)

SIMPLE_NET (facade)
    └── Factory methods: new_client_*, new_server_*, new_address_*
```

## Implementation Strategy (Phase 4)

### CLIENT_SOCKET.connect()
- Use ISE's NETWORK_SOCKET API to establish TCP connection
- On success: set is_connected_impl=True, clear error
- On failure: set is_error_impl=True, set error_impl with OS error code
- Timeout handling: wrap socket operations with select() or equivalent

### CLIENT_SOCKET.send()
- Guarantee full send (all bytes or error)
- Loop until all bytes sent or error occurs
- Increment bytes_sent_impl on each successful send
- Return false and set error on any failure

### CLIENT_SOCKET.receive()
- Allow partial receive (up to a_max_bytes)
- Return empty array on EOF or error
- Increment bytes_received_impl on successful receive
- Set is_at_eof_impl when peer closes cleanly

### SERVER_SOCKET.listen()
- Use NETWORK_SOCKET.bind() then listen()
- Set backlog_impl to a_backlog parameter
- On success: set is_listening_impl=True
- On failure: set is_error_impl=True with bind error (port in use, etc.)

### SERVER_SOCKET.accept()
- Wait for incoming connection with timeout
- Return new CONNECTION representing client socket
- Increment connection_count_impl on success
- Return Void and set error on failure/timeout

## State Machine

### CLIENT_SOCKET States
```
[Created] --connect()--> [Connected] --send/receive--> [Connected]
                            |                              |
                            |--error()---> [Error] <--------
                            |
                            +--close()--> [Closed]
```

**Invariant:** `(is_connected and not is_error and not is_closed) or not is_connected`

### SERVER_SOCKET States
```
[Created] --listen()--> [Listening] --accept()--> [Listening]
                           |                           |
                           |--error()---> [Error] <-----
                           |
                           +--close()--> [Closed]
```

## Error Handling Strategy

### Error Classification (ERROR_TYPE)
- Supports both Linux (POSIX) and Windows error codes
- Categories: connection_refused, timeout, reset, read_error, write_error, bind_error, address_not_available
- Provides is_retriable and is_fatal flags for client retry logic

### Recovery Options
1. **Retriable Errors** (is_retriable=true): Connection refused, timeout, reset
   - Client can retry with exponential backoff
2. **Fatal Errors** (is_fatal=true): Address not available, bind error
   - Client should not retry; requires user intervention
3. **Operation Timeout**: Special case - distinguish from other timeouts

## Performance Considerations

### Timeout Defaults
- All sockets default to 30 second timeout (configurable via set_timeout)
- Prevents indefinite blocking on network operations

### Cumulative Counters
- bytes_sent and bytes_received track total for telemetry/monitoring
- Never reset (monotonically increasing per socket lifetime)
- Used for debugging and performance analysis

### Connection Queuing
- SERVER_SOCKET backlog parameter determines listen queue depth
- Typical values: 5-128 depending on expected concurrent clients
- OS kernel handles queuing beyond backlog

## Testing Strategy (Phase 5)

### Unit Tests
- ADDRESS: creation, validation, immutability, string representation
- ERROR_TYPE: classification queries, string representation, Linux vs Windows codes
- CLIENT_SOCKET: creation, state transitions, precondition checks
- SERVER_SOCKET: creation, state transitions, backlog tracking

### Integration Tests
- Create server, have client connect to it
- Send/receive data through established connection
- Test timeout behavior
- Test multiple concurrent connections

### Adversarial Tests (Phase 6)
- Bind to already-used port (error recovery)
- Connect to unreachable address (error handling)
- Timeout behavior under slow network
- Send large amounts of data (buffering)
- Rapid connect/disconnect cycles
- Resource exhaustion (many connections)

## SCOOP Compatibility

- All classes marked as SCOOP-separate qualified
- No shared mutable state across processors
- Each socket lives on a processor and is never migrated
- Inter-processor communication via separate calls

## External Dependencies

- **ISE net.ecf**: EiffelStudio's socket library
  - Provides: NETWORK_SOCKET, HOST, SOCKET_ADDRESS
  - Implementation: Wraps platform sockets (Winsock on Windows, BSD on Unix)

- **simple_mml v1.0.1+**: Mathematical Model Library
  - Used in Phase 5+ for precise postconditions with frame conditions
  - Not yet needed in Phase 1 (Phase 4 implementation is concrete)

## Remaining Decisions for Phase 1 Review

1. **Error Reporting**: Should error_classification be available even when is_error=false?
   - Current: Precondition requires is_error=true
   - Alternative: Return NO_ERROR classification always (less restrictive)

2. **EOF Handling**: Should is_at_end_of_stream be separate from is_error?
   - Current: EOF sets is_at_end_of_stream but not is_error
   - Alternative: EOF could set is_error and classify as EOF_ERROR

3. **Timeout Configuration**: Should server accept() timeout be independent from send/receive?
   - Current: set_timeout applies to all operations
   - Alternative: separate set_accept_timeout

4. **Address Immutability**: Should we document that ADDRESS is truly immutable?
   - Current: Made by copying strings in creation (twin)
   - Concern: Users might assume they can mutate created ADDRESS

## Next Steps

1. **Phase 2** (Current): AI review of contracts (this document + src/*.e files)
2. **Phase 3**: Break contracts into implementation tasks
3. **Phase 4**: Write feature bodies satisfying contracts
4. **Phase 5**: Generate comprehensive test suite from contracts
5. **Phase 6**: Adversarial testing and hardening
6. **Phase 7**: Documentation and production release
