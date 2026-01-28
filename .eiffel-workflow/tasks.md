# Implementation Tasks: simple_net

## Overview

simple_net is a TCP socket abstraction library with 6 core classes and 2 value objects. Implementation broken into 13 focused tasks organized by dependency chain.

---

## Phase 4 Task List

### Task Group 1: Value Objects (No Dependencies)

#### Task 1: ADDRESS Immutable Value Object
**Files:** `src/address.e`
**Features:** `make_for_host_port`, `make_for_localhost_port`, `host`, `port`, `as_string`, `is_loopback`, `is_ipv4_address`

**Acceptance Criteria:**
- [ ] Creation methods initialize host_impl and port_impl correctly
- [ ] `host` and `port` accessors return stored values
- [ ] `as_string` formats as "host:port"
- [ ] `is_loopback` detects 127.0.0.1 and "localhost"
- [ ] `is_ipv4_address` validates IPv4 format (3 dots, numeric octets)
- [ ] All postconditions verified (host_set, port_set, is_loopback)
- [ ] Invariants maintained: host_not_empty, port_in_range
- [ ] No modifications after creation (immutability via twin() copy)

**Implementation Notes:**
- Use STRING.twin() to copy host parameter (ensures immutability)
- IPv4 check: verify each octet is 0-255, not just dot count
- All features are queries - no state modification

**Dependencies:** None

---

#### Task 2: ERROR_TYPE Error Classification Enum
**Files:** `src/error_type.e`
**Features:** `make`, `code`, `is_connection_refused`, `is_connection_timeout`, `is_connection_reset`, `is_read_error`, `is_write_error`, `is_bind_error`, `is_address_not_available`, `is_timeout`, `is_retriable`, `is_fatal`, `to_string`

**Acceptance Criteria:**
- [ ] Constructor stores error code correctly
- [ ] All classification queries check both Linux and Windows error codes
- [ ] `is_timeout` covers connection timeout and generic -1
- [ ] `is_retriable` returns true for connection_refused, connection_timeout, connection_reset
- [ ] `is_fatal` returns true for address_not_available, bind_error
- [ ] `to_string` returns human-readable error for each classification
- [ ] Invariant maintained: code_impl >= -1
- [ ] `to_string` always returns non-empty string

**Implementation Notes:**
- Error codes: Linux vs Windows (111 vs 10061 for ECONNREFUSED, etc.)
- These are all queries (no state modification)
- Error code -1 is reserved for generic timeout

**Dependencies:** None

---

### Task Group 2: Socket Base Classes (Depend on Task 1-2)

#### Task 3: CONNECTION Deferred Base Class
**Files:** `src/connection.e`
**Features:** All deferred features (send, send_string, receive, receive_string, close, set_timeout, is_connected, is_closed, is_error, error_classification, last_error_string, is_at_end_of_stream, bytes_sent, bytes_received, timeout, local_address, remote_address)

**Acceptance Criteria:**
- [ ] No implementation needed (all deferred)
- [ ] Feature signatures match subclass implementations
- [ ] Preconditions/postconditions are consistent across deferred/implemented versions
- [ ] Invariants define state machine semantics (state exclusion)
- [ ] Compiles with no warnings

**Implementation Notes:**
- This is a specification interface for concrete sockets
- CLASS must be declared as `deferred class CONNECTION`
- All feature bodies must be empty `deferred` or minimal stub

**Dependencies:** Tasks 1-2

---

### Task Group 3: CLIENT_SOCKET TCP Client (Depend on Task 1-2)

#### Task 4: CLIENT_SOCKET Initialization and State Queries
**Files:** `src/client_socket.e`
**Features:** `make_for_host_port`, `make_for_address`, `is_connected`, `is_closed`, `is_error`, `error_classification`, `last_error_string`, `is_at_end_of_stream`, `bytes_sent`, `bytes_received`, `timeout`, `remote_address`, `local_address`

**Acceptance Criteria:**
- [ ] Creation methods initialize all impl fields correctly
  - timeout_impl = 30.0
  - All flags = False
  - error_impl = ERROR_TYPE.make(0)
  - bytes counters = 0
- [ ] `is_connected` returns true only when connected AND NOT error AND NOT closed
- [ ] `is_closed` returns is_closed_impl
- [ ] `is_error` returns is_error_impl
- [ ] Error queries work: error_classification, last_error_string
- [ ] Byte counters return non-negative values
- [ ] `timeout` returns positive timeout
- [ ] `remote_address` returns remote_address_impl
- [ ] All postconditions verified
- [ ] Invariants maintained (state exclusion, bounds checking)

**Implementation Notes:**
- These are mostly wrappers around impl fields
- State queries enforce invariants through logical AND/OR
- No I/O operations (pure state queries)

**Dependencies:** Tasks 1-2

---

#### Task 5: CLIENT_SOCKET connect() TCP Connection
**Files:** `src/client_socket.e`
**Features:** `connect`

**Acceptance Criteria:**
- [ ] Preconditions enforced: not_connected, not_already_closed
- [ ] On success: is_connected_impl=True, is_error_impl=False
- [ ] On failure: is_error_impl=True, error_impl set to OS error code
- [ ] Returns true iff connected, false iff error
- [ ] Timeout respected (30 seconds by default, or user-set)
- [ ] Postcondition verified: success_implies_connected, failure_implies_error
- [ ] Invariants maintained after state change
- [ ] Error classification available in error_classification

**Implementation Notes:**
- Use ISE's NETWORK_SOCKET for platform abstraction
- On Windows: use Winsock WSACONNREFUSED (10061), WSAETIMEDOUT (10060), etc.
- On Linux: use ECONNREFUSED (111), ETIMEDOUT (110), etc.
- Map OS error codes to ERROR_TYPE via code parameter
- Timeout can be implemented via select() call or non-blocking socket

**Dependencies:** Tasks 1-2, 4

---

#### Task 6: CLIENT_SOCKET send() Full Send Guarantee
**Files:** `src/client_socket.e`
**Features:** `send`

**Acceptance Criteria:**
- [ ] Preconditions enforced: is_connected, not_in_error, data_not_void, data_not_empty
- [ ] Sends ALL bytes successfully OR fails with error (no partial success)
- [ ] Returns true iff all bytes sent
- [ ] Returns false iff error occurred (and is_error becomes true)
- [ ] bytes_sent_impl incremented by a_data.count on success only
- [ ] bytes_sent_impl unchanged on failure
- [ ] Postcondition verified: all_or_error, failure_means_error, no_data_loss
- [ ] Invariants maintained

**Implementation Notes:**
- Loop until all bytes sent or error
- On each successful write: increment bytes_sent_impl by bytes written
- On any error: set is_error_impl=True, error_impl to OS error, return False
- Handle partial writes (some bytes sent, then error) by retrying/buffering
- Timeout from set_timeout() applies
- Guarantee in comment: "all bytes sent or error - never partial success"

**Dependencies:** Tasks 1-2, 4, 5

---

#### Task 7: CLIENT_SOCKET send_string() UTF-8 String Send
**Files:** `src/client_socket.e`
**Features:** `send_string`

**Acceptance Criteria:**
- [ ] Preconditions enforced: is_connected, not_in_error, string_not_void, string_not_empty
- [ ] Encodes string as UTF-8 bytes
- [ ] Calls send() with encoded array
- [ ] Returns true iff all bytes sent
- [ ] bytes_sent_impl reflects UTF-8 byte count, not character count
- [ ] Postcondition verified: success_or_error, bytes_non_decreasing
- [ ] Invariants maintained

**Implementation Notes:**
- Convert a_string to UTF-8 byte array
- Call send() with the byte array
- Return result from send()
- Note: bytes_sent is BYTES, not characters (important for multi-byte UTF-8)

**Dependencies:** Tasks 1-2, 4, 6

---

#### Task 8: CLIENT_SOCKET receive() Data Reception
**Files:** `src/client_socket.e`
**Features:** `receive`

**Acceptance Criteria:**
- [ ] Preconditions enforced: is_connected, valid_max_bytes
- [ ] Receives up to a_max_bytes bytes from socket
- [ ] Returns empty array on EOF or error (not on temporary no-data)
- [ ] Sets is_at_eof_impl=True when peer closes cleanly
- [ ] Sets is_error_impl=True on error, fills error_impl
- [ ] bytes_received_impl incremented by bytes received (0 on EOF/error)
- [ ] Postconditions verified: empty_requires_reason, data_excludes_error, bytes_non_decreasing
- [ ] Invariants maintained
- [ ] Timeout respected

**Implementation Notes:**
- Use select() or non-blocking read with timeout
- Distinguish between EOF (peer close) and error
- Empty array signals "stop receiving": either EOF or error occurred
- Partial receive is allowed (up to a_max_bytes, not required to fill)
- Timeout from set_timeout() applies

**Dependencies:** Tasks 1-2, 4, 5

---

#### Task 9: CLIENT_SOCKET receive_string() UTF-8 String Reception
**Files:** `src/client_socket.e`
**Features:** `receive_string`

**Acceptance Criteria:**
- [ ] Preconditions enforced: is_connected, valid_max_bytes
- [ ] Calls receive() to get bytes
- [ ] Decodes bytes as UTF-8 string
- [ ] Returns empty string on EOF or error
- [ ] Handles partial UTF-8 sequences gracefully (buffer incomplete chars)
- [ ] Postcondition verified: result_not_void (always returns string, never Void)
- [ ] Invariants maintained

**Implementation Notes:**
- Call receive(a_max_bytes)
- Decode result as UTF-8
- Handle multi-byte UTF-8 sequences at boundaries
- Return empty string when receive returns empty array
- Result is never Void (contract guarantees)

**Dependencies:** Tasks 1-2, 4, 8

---

#### Task 10: CLIENT_SOCKET close() Cleanup
**Files:** `src/client_socket.e`
**Features:** `close`

**Acceptance Criteria:**
- [ ] Precondition enforced: not_already_closed
- [ ] Closes underlying socket (graceful shutdown)
- [ ] Sets is_closed_impl=True
- [ ] Clears is_connected_impl=False
- [ ] Cleans up resources (socket descriptor, buffers)
- [ ] Postcondition verified: is_closed, not_connected
- [ ] Invariants maintained
- [ ] Idempotent: calling twice doesn't error

**Implementation Notes:**
- Use ISE's NETWORK_SOCKET.close() or equivalent
- Graceful shutdown: send FIN packet first if possible
- Set is_closed_impl=True, is_connected_impl=False
- Don't modify is_error_impl (leave error state standing)
- Safe to call multiple times (second call no-op)

**Dependencies:** Tasks 1-2, 4-9

---

#### Task 11: CLIENT_SOCKET set_timeout() Configuration
**Files:** `src/client_socket.e`
**Features:** `set_timeout`

**Acceptance Criteria:**
- [ ] Precondition enforced: positive timeout
- [ ] Sets timeout_impl to a_seconds
- [ ] Applies to all future I/O operations (send, receive, connect)
- [ ] Postcondition verified: timeout_set
- [ ] Existing connections use new timeout on next operation
- [ ] No retroactive effect on in-flight operations

**Implementation Notes:**
- Simple field assignment: timeout_impl = a_seconds
- Timeout applies to send(), receive(), and future connect() calls
- No socket-level timeout needed yet (Phase 4 stubs)
- Implementation will use this in connect, send, receive (Phase 4)

**Dependencies:** Tasks 1-2, 4

---

### Task Group 4: SERVER_SOCKET TCP Server (Depend on Task 1-2)

#### Task 12: SERVER_SOCKET Initialization and State Queries
**Files:** `src/server_socket.e`
**Features:** `make_for_port`, `make_for_address`, `is_listening`, `is_closed`, `is_error`, `error_classification`, `last_error_string`, `backlog`, `connection_count`, `timeout`, `local_address`, `operation_timed_out`

**Acceptance Criteria:**
- [ ] Creation methods initialize all impl fields correctly
  - local_address_impl set to ADDRESS
  - timeout_impl = 30.0
  - All flags = False
  - error_impl = ERROR_TYPE.make(0)
  - backlog_impl = 0
  - connection_count_impl = 0
- [ ] `is_listening` returns true only when listening AND NOT error AND NOT closed
- [ ] `is_closed` returns is_closed_impl
- [ ] `is_error` returns is_error_impl
- [ ] Error queries work: error_classification, last_error_string
- [ ] `backlog` returns backlog_impl (requires is_listening or is_closed)
- [ ] `connection_count` returns non-negative connection_count_impl
- [ ] `timeout` returns positive timeout
- [ ] `local_address` returns local_address_impl
- [ ] `operation_timed_out` returns is_error AND error_classification.is_timeout
- [ ] All postconditions verified
- [ ] Invariants maintained (state exclusion, bounds checking)

**Implementation Notes:**
- Similar structure to CLIENT_SOCKET but for server state
- `operation_timed_out` is a helper query combining error state + timeout check
- backlog only meaningful when listening (precondition enforces)

**Dependencies:** Tasks 1-2

---

#### Task 13: SERVER_SOCKET listen(), accept(), close(), set_timeout()
**Files:** `src/server_socket.e`
**Features:** `listen`, `accept`, `close`, `set_timeout`

**Acceptance Criteria:**
- [ ] **listen()**:
  - Preconditions enforced: not_listening, positive_backlog, not_already_closed
  - On success: is_listening_impl=True, backlog_impl=a_backlog, is_error_impl=False
  - On failure: is_error_impl=True, error_impl set to OS error (e.g., EADDRINUSE port in use)
  - Returns true iff listening, false iff error
  - Postconditions verified: success_means_listening, failure_means_error
  - Uses NETWORK_SOCKET.bind() and listen() with backlog parameter

- [ ] **accept()**:
  - Preconditions enforced: is_listening, not_in_error
  - On success: returns new CONNECTION object representing client socket
  - On success: connection_count_impl incremented
  - On timeout/error: returns Void, sets is_error_impl=True, error_impl set
  - Postconditions verified: success_guarantee (connection_count incremented), void_means_error_or_timeout
  - Timeout respected (from set_timeout)

- [ ] **close()**:
  - Precondition enforced: not_already_closed
  - Closes listening socket
  - Sets is_closed_impl=True, is_listening_impl=False
  - Cleans up resources
  - Postconditions verified: is_closed, not_listening
  - Idempotent (safe to call twice)

- [ ] **set_timeout()**:
  - Precondition enforced: positive timeout
  - Sets timeout_impl to a_seconds
  - Applies to accept() calls
  - Postcondition verified: timeout_set

**Implementation Notes:**
- **listen()**: Use NETWORK_SOCKET on local_address with backlog; map OS errors
- **accept()**: Use NETWORK_SOCKET.accept() with timeout; return new CLIENT_SOCKET or Void
- **close()**: Graceful server shutdown, clean up listen socket
- **set_timeout()**: Simple field assignment
- Error handling: map OS errors (EADDRINUSE for port in use, EACCES for permission denied, etc.)

**Dependencies:** Tasks 1-2, 12

---

### Task Group 5: Facade (Depend on Task 1-3, 11-13)

#### Task 14: SIMPLE_NET Factory Facade
**Files:** `src/simple_net.e`
**Features:** `make`, `new_client_for_host_port`, `new_client_for_address`, `new_server_for_port`, `new_server_for_address`, `new_address_for_host_port`, `new_address_for_localhost_port`, `version`, `description`

**Acceptance Criteria:**
- [ ] `make` initializes facade (no-op, just create object)
- [ ] All factory methods create appropriate objects and return Result
- [ ] `new_client_for_host_port` calls CLIENT_SOCKET.make_for_host_port
- [ ] `new_client_for_address` calls CLIENT_SOCKET.make_for_address
- [ ] `new_server_for_port` calls SERVER_SOCKET.make_for_port
- [ ] `new_server_for_address` calls SERVER_SOCKET.make_for_address
- [ ] `new_address_for_host_port` calls ADDRESS.make_for_host_port
- [ ] `new_address_for_localhost_port` calls ADDRESS.make_for_localhost_port
- [ ] `version` returns "1.0.0"
- [ ] `description` returns library description string
- [ ] All postconditions verified
- [ ] Factory methods just delegate (minimal logic)

**Implementation Notes:**
- Pure factory pattern: create objects and return them
- Single line implementations: `create Result.make_for_...(...)`
- Postconditions are on the delegated constructors

**Dependencies:** Tasks 1-2, 4-13

---

## Task Dependency Graph

```
Task 1 (ADDRESS) ─┐
Task 2 (ERROR_TYPE) ├─→ Task 3 (CONNECTION base)
                   │
Task 1, 2 ────────→ Task 4 (CLIENT_SOCKET init) ─┐
                     ├─→ Task 5 (connect)          │
                     ├─→ Task 6 (send)              │
                     ├─→ Task 7 (send_string) ←─────┤
                     ├─→ Task 8 (receive)            │
                     ├─→ Task 9 (receive_string) ←──┤
                     ├─→ Task 10 (close)             │
                     └─→ Task 11 (set_timeout)       │
                                                    ├─→ Task 14 (SIMPLE_NET facade)
Task 1, 2 ────────→ Task 12 (SERVER_SOCKET init) ┐│
                     ├─→ Task 13 (listen/accept/close/set_timeout) ┘
```

## Implementation Order (Recommended)

1. **Phase 4.1**: Tasks 1-2 (value objects, no dependencies)
2. **Phase 4.2**: Task 3 (CONNECTION base - already deferred)
3. **Phase 4.3**: Tasks 4-11 (CLIENT_SOCKET - enable testing)
4. **Phase 4.4**: Tasks 12-13 (SERVER_SOCKET - enable integration)
5. **Phase 4.5**: Task 14 (SIMPLE_NET facade - optional, minimal)

Each task takes 15-60 minutes depending on I/O complexity.

---

## Acceptance Criteria Summary

All tasks must:
- ✓ Have zero compilation warnings
- ✓ Satisfy all preconditions and postconditions
- ✓ Maintain class invariants
- ✓ Pass Phase 5 unit tests (to be created in Phase 5)
- ✓ Work correctly with ISE net.ecf API

---

## Total Task Count: 14

- Group 1 (Value Objects): 2 tasks
- Group 2 (Base Classes): 1 task
- Group 3 (CLIENT_SOCKET): 8 tasks
- Group 4 (SERVER_SOCKET): 2 tasks
- Group 5 (Facade): 1 task

**Estimated Total Implementation Time (Phase 4):** 3-4 days

---

## Next Step: Phase 4 Implementation

Run `/eiffel.implement d:\prod\simple_net` to begin writing feature bodies for each task in order.
