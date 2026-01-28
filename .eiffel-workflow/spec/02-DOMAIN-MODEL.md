# DOMAIN MODEL: simple_net - TCP Socket Abstraction

**Date:** January 28, 2026
**Specification Phase:** Step 2 - Domain Analysis

---

## Overview

The simple_net domain models TCP client-server communication as a set of concrete entities (sockets, connections, addresses) and their relationships. This specification identifies core concepts, their responsibilities, and the rules governing their interactions.

---

## Domain Entities

### 1. CLIENT_SOCKET
**Purpose:** Initiates outbound TCP connections to remote servers

**Characteristics:**
- Represents a client endpoint (not yet connected)
- Holds remote address and port
- State machine: `unconnected` → `connected` → `closed`
- Supports: connect(), send(), receive(), close()
- Queries: is_connected, is_error, last_error_string

**Responsibilities:**
- Resolve hostname to IP address
- Establish TCP connection with timeout
- Send data with full guarantee
- Receive data with partial guarantee
- Track connection state
- Report classified errors (CONNECTION_REFUSED, TIMEOUT, READ_ERROR, etc.)

**Relationships:**
- Uses: ADDRESS (host, port specification)
- Creates: CONNECTION (when connected successfully)
- Reports: ERROR_TYPE (on failure)

**Invariants:**
- `not is_connected or is_error` - Cannot be simultaneously connected and in error
- `is_closed implies not is_connected` - Closed sockets are disconnected
- `timeout >= 0` - Timeout is non-negative real seconds

---

### 2. SERVER_SOCKET
**Purpose:** Accepts inbound TCP connections from remote clients

**Characteristics:**
- Represents a server endpoint (listens on port)
- Binds to local address and port
- State machine: `unbound` → `listening` → `closed`
- Supports: listen(), accept(), close()
- Queries: is_listening, is_error, last_error_string, backlog

**Responsibilities:**
- Bind to local port
- Listen for incoming connections with backlog queue
- Accept new connections with timeout
- Track server state
- Report classified errors (BIND_FAILED, ADDRESS_IN_USE, etc.)

**Relationships:**
- Uses: ADDRESS (local address/port to bind)
- Creates: CONNECTION (when accepting client)
- Reports: ERROR_TYPE (on failure)

**Invariants:**
- `not is_listening or is_error` - Cannot be simultaneously listening and in error
- `is_listening implies backlog > 0` - Listening server has positive backlog
- `backlog <= max_backlog` - Backlog respects OS limits

---

### 3. CONNECTION
**Purpose:** Represents an active TCP connection (bidirectional channel)

**Characteristics:**
- Represents established TCP stream (fully connected)
- Supports: send(), receive(), close()
- Can originate from CLIENT_SOCKET.connect() or SERVER_SOCKET.accept()
- State machine: `connected` → `closed`
- Full-duplex communication (send and receive independent)
- SCOOP-safe via `separate` keyword

**Responsibilities:**
- Send complete data (with retry on partial writes)
- Receive available data (up to max_bytes)
- Detect EOF (end of stream)
- Track bytes sent/received
- Graceful close
- Report I/O errors (READ_ERROR, WRITE_ERROR, CONNECTION_RESET)

**Relationships:**
- Created by: CLIENT_SOCKET (after connect) or SERVER_SOCKET (after accept)
- Reports: ERROR_TYPE (on I/O failure)
- Part of: Potential SCOOP processor separation

**Invariants:**
- `is_connected implies (bytes_sent >= 0 and bytes_received >= 0)` - Byte counters non-negative
- `not is_connected or not is_error` - Cannot be simultaneously connected and in error state
- `is_at_end_of_stream implies not last_send_succeeded` - EOF blocks further sends

---

### 4. ADDRESS
**Purpose:** Encapsulates network endpoint specification (host + port)

**Characteristics:**
- Value object (immutable after creation)
- Holds: hostname (STRING) or IP address (STRING) + port (INTEGER)
- Validates port range (1-65535) at creation
- Supports hostname resolution (localhost → 127.0.0.1)

**Responsibilities:**
- Type-safe host/port representation
- Validation at creation (fail-fast)
- Encapsulation (hides ISE's INET_ADDRESS complexity)
- Support both symbolic names (localhost) and IPs (127.0.0.1, 192.168.x.x)

**Relationships:**
- Used by: CLIENT_SOCKET (remote address), SERVER_SOCKET (local address)
- Converts to: ISE's INET_ADDRESS internally (hidden)

**Invariants:**
- `port >= 1 and port <= 65535` - Valid port range
- `host.length > 0` - Non-empty hostname
- `is_immutable` - Cannot modify host/port after creation

---

### 5. ERROR_TYPE
**Purpose:** Classify socket errors into actionable categories

**Characteristics:**
- Enumeration (finite set of error codes)
- Provides classification without string parsing
- Includes OS error number for debugging

**Error Categories (Enum Values):**
- `NO_ERROR` - Operation succeeded
- `CONNECTION_REFUSED` - Server rejected connection (ECONNREFUSED)
- `CONNECTION_TIMEOUT` - Connect timeout (ETIMEDOUT)
- `CONNECTION_RESET` - Peer reset connection mid-stream (ECONNRESET)
- `CONNECTION_CLOSED` - Normal peer close (EOF)
- `READ_ERROR` - Error reading data (EBADF, etc.)
- `WRITE_ERROR` - Error writing data (EBROKEN, EPIPE, etc.)
- `BIND_ERROR` - Failed to bind to port (EADDRINUSE, EACCES)
- `LISTEN_ERROR` - Failed to listen (EOPNOTSUPP)
- `ADDRESS_NOT_AVAILABLE` - Invalid/unreachable address
- `OPERATION_CANCELLED` - Timeout or user cancellation
- `OTHER` - Unknown error (includes raw error code for debugging)

**Responsibilities:**
- Represent error classification (machine-readable)
- Enable smart retry logic (only retry retriable errors)
- Support error logging/monitoring (distinguish error types)
- Provide fallback for unknowns (OTHER + error_code)

**Relationships:**
- Returned by: CLIENT_SOCKET, SERVER_SOCKET, CONNECTION error queries
- Used in: Postconditions (contracts verify error classification)
- Queried by: Client code for retry/fallback decisions

**Invariants:**
- Each instance has exactly one error code
- `NO_ERROR` (0) means no error occurred
- Negative error codes are retriable (implement retry logic)
- `OTHER` only used when classification fails

---

## Domain Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                    simple_net Domain                        │
└─────────────────────────────────────────────────────────────┘

                        ┌──────────────┐
                        │  ADDRESS     │
                        ├──────────────┤
                        │ host: STRING │
                        │ port: INTEGER│
                        └──────────────┘
                             ▲
                    ┌────────┴────────┐
                    │                 │
            ┌───────────────┐  ┌──────────────┐
            │ CLIENT_SOCKET │  │SERVER_SOCKET │
            ├───────────────┤  ├──────────────┤
            │ connect()     │  │ listen()     │
            │ send()        │  │ accept()     │
            │ receive()     │  │ close()      │
            │ close()       │  └──────────────┘
            │               │         │
            └───────────────┘         │
                    │                 │
                    └─────────┬───────┘
                              │
                              ▼
                        ┌─────────────┐
                        │ CONNECTION  │
                        ├─────────────┤
                        │ send()      │
                        │ receive()   │
                        │ close()     │
                        │ is_at_eof   │
                        └─────────────┘
                              │
                              ▼
                        ┌─────────────┐
                        │ ERROR_TYPE  │
                        ├─────────────┤
                        │ NO_ERROR    │
                        │ CONN_REFUSED│
                        │ TIMEOUT     │
                        │ ... (9 more)│
                        └─────────────┘

Legend:
  ──► "uses"
  ◀── "creates"
  ▼   "reports"
```

---

## Domain Rules

### Connection Lifecycle Rules

1. **CLIENT_SOCKET Lifecycle:**
   ```
   CREATED
     │ ↓ connect()
   CONNECTED ──→ (error) ──→ is_error = true
     │ ↓ send/receive
   CONNECTED
     │ ↓ close()
   CLOSED
   ```

2. **SERVER_SOCKET Lifecycle:**
   ```
   CREATED
     │ ↓ listen(backlog)
   LISTENING
     │ ↓ accept() returns CONNECTION
   LISTENING (still accepting)
     │ ↓ close()
   CLOSED
   ```

3. **CONNECTION Lifecycle:**
   ```
   CREATED (from CLIENT_SOCKET or SERVER_SOCKET)
     │ ↓ send/receive
   ACTIVE (bytes flowing)
     │ ↓ peer close or close()
   CLOSED
   ```

### State Invariants

4. **Mutual Exclusion:**
   - `CLIENT_SOCKET: is_connected XOR is_error` (connected or error, not both)
   - `SERVER_SOCKET: is_listening XOR is_error` (listening or error, not both)
   - `CONNECTION: is_connected XOR is_error` (connected or error, not both)

5. **Timeout Universality:**
   - `set_timeout(seconds)` applies to ALL operations:
     - connect attempt (CLIENT_SOCKET)
     - accept wait (SERVER_SOCKET)
     - send operation (CONNECTION)
     - receive operation (CONNECTION)
   - Timeout applies uniformly; no per-operation override in Phase 1

6. **Byte Tracking:**
   - `bytes_sent >= 0` - Cumulative bytes successfully sent (never decreases)
   - `bytes_received >= 0` - Cumulative bytes successfully received (never decreases)
   - `send(data) ensures bytes_sent = old bytes_sent + data.count OR is_error`

### Error Handling Rules

7. **Error Classification:**
   - Socket operation fails → error_classification is one of ERROR_TYPE values
   - Client code checks `is_error` BEFORE interpreting error details
   - `last_error_string` provides human-readable explanation (debugging)
   - Raw OS error code preserved in error_code (advanced debugging)

8. **Error Durability:**
   - Once `is_error = true`, socket remains in error state
   - Error persists until next successful operation or explicit close
   - User must explicitly handle error (no automatic recovery)

9. **No Silent Failures:**
   - Every operation returns queryable state (no exceptions)
   - User responsibility to check `is_error` after calls
   - Contracts enforce preconditions (e.g., `send` requires `is_connected`)

### Address Resolution Rules

10. **Hostname Resolution:**
    - ADDRESS accepts both symbolic names (localhost, example.com) and IPs (127.0.0.1)
    - Resolution happens at connect/bind time (not at ADDRESS creation)
    - Failed resolution treated as ADDRESS_NOT_AVAILABLE error

11. **Port Validation:**
    - PORT must be in range 1-65535 (valid IANA port range)
    - Port 0 reserved (OS assigns; not used in MVP)
    - Validation happens at ADDRESS creation (fail-fast)

### SCOOP Concurrency Rules

12. **Separate Connection Access:**
    - CONNECTION objects intended for `separate` keyword (SCOOP safety)
    - Multiple SCOOP processors can each have independent CONNECTION
    - No synchronized access to shared CONNECTION (design avoids it)
    - All CONNECTION state is per-instance (no shared mutable state)

---

## Glossary

| Term | Definition |
|------|-----------|
| **Socket** | OS-level endpoint for network communication (TCP stream) |
| **Connection** | Simple_net abstraction for active TCP stream (both directions) |
| **Client** | Endpoint that initiates connection (connects to server) |
| **Server** | Endpoint that accepts connections (listens on port) |
| **Bind** | Associate server socket with local address:port |
| **Listen** | Enable server socket to accept incoming connections |
| **Accept** | Wait for and create new CONNECTION from client |
| **Connect** | Establish outbound connection to remote server |
| **Send** | Transmit data over connection (all-or-nothing guarantee) |
| **Receive** | Get available data from connection (up to max_bytes) |
| **EOF** | End-of-file marker (peer closed connection cleanly) |
| **Timeout** | Maximum wait duration for network operation |
| **Error Classification** | Machine-readable error type (enum, not string) |
| **Backlog** | OS queue of pending connection accepts (listen parameter) |
| **Hostname** | Symbolic name (localhost, example.com) resolvable to IP |
| **IP Address** | Numeric address (127.0.0.1, 192.168.1.1) |
| **Port** | Numeric endpoint (1-65535) on host |
| **ADDRESS** | Tuple of (host, port) identifying network endpoint |
| **SCOOP** | Eiffel concurrency model (separate processors per object) |
| **Separate** | Eiffel keyword for cross-processor object access |
| **Frame Condition** | Contract clause specifying what state did NOT change |
| **Precondition** | Contract requirement before operation (must-be-true before) |
| **Postcondition** | Contract guarantee after operation (must-be-true after) |
| **Invariant** | Contract always-true property (before and after operations) |
| **MML** | Mathematical Model Language for formal contract specifications |

---

## Domain Constraints

| ID | Constraint | Rationale |
|----|-----------|----|
| **DC-001** | Only wrap ISE net.ecf (don't reimplement TCP) | Leverage proven, maintained socket layer |
| **DC-002** | ADDRESS is value object (immutable) | Simplifies sharing, prevents race conditions |
| **DC-003** | Error classification is finite (enum, not string) | Machine-readable, enables automation |
| **DC-004** | Timeout is universal (one setting, not per-operation) | MVP simplicity; Phase 2 can refine |
| **DC-005** | No exception raising from public features | Eiffel convention (use queryable state) |
| **DC-006** | SCOOP processor model, not callback model | Aligns with Eiffel concurrency |
| **DC-007** | Blocking I/O only (Phase 1) | Simplification; threading via SCOOP |
| **DC-008** | Full send guarantee, partial receive | Matches user expectations, transparency |
| **DC-009** | Connection state is atomic (connected XOR error) | Simplifies contracts, prevents confusion |

---

## Domain Assumptions to Verify

| ID | Assumption | Verification |
|----|-----------|----|
| **DA-001** | ISE net.ecf reliably handles TCP on Windows | Test CLIENT_SOCKET + SERVER_SOCKET integration with real Python client |
| **DA-002** | Developers understand `connect()`, `send()`, `receive()` | User survey or quick study with target persona |
| **DA-003** | ADDRESS (host, port) simpler than INET_ADDRESS factory | Compare boilerplate lines in examples |
| **DA-004** | Queryable error state better than exceptions | Verify with contract coverage % (exceptions less testable) |
| **DA-005** | SCOOP scaling sufficient for typical servers | Stress test: 100 concurrent connections |
| **DA-006** | Error classification covers 90%+ of real failures | Test with real network errors (refused, timeout, reset, read error) |
| **DA-007** | MML model queries don't add prohibitive overhead | Measure contract checking CPU time |

---

