# REQUIREMENTS: simple_net - TCP Socket Abstraction Library

**Date:** January 28, 2026

---

## Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria | Semantic Frame |
|----|-------------|----------|---------------------|-----------------|
| **FR-001** | TCP client socket creation and connection | MUST | Developer can write: `create {CLIENT_SOCKET}.make_for_host_port("server", 8080)` then `client.connect()` | Familiar to Python/Go devs |
| **FR-002** | TCP server socket creation and listening | MUST | Developer can write: `create {SERVER_SOCKET}.make_for_port(8080)` then `server.listen(5)` then `server.accept()` returns new CONNECTION | Matches Python ServerSocket pattern |
| **FR-003** | Data transmission (send/receive) | MUST | `connection.send(data)` and `data := connection.receive(1024)` work intuitively with STRING and ARRAY OF BYTES | Not `put_string` / `read_line` |
| **FR-004** | Connection lifecycle management | MUST | `is_connected`, `close()`, proper cleanup (SCOOP safe) | Clear state queries |
| **FR-005** | Timeout support with single, intuitive API | MUST | `client.set_timeout(seconds)` applies to all operations; no separate connect_timeout vs accept_timeout | Like Python settimeout() |
| **FR-006** | Error detection and reporting | MUST | Clear error states: connection_refused, timeout, read_error, write_error, connection_reset; queryable via `last_error` or `is_error` | Not opaque string errors |
| **FR-007** | IPv4 support (Windows primary) | MUST | Connect to "localhost", "127.0.0.1", "hostname.example.com" | Standard addressing |
| **FR-008** | Blocking mode (synchronous) | MUST | Calls block until completion; no async/callback complexity in MVP | Simplicity first |
| **FR-009** | Design by Contract on all public features | MUST | 100% preconditions, postconditions, invariants with MML | simple_* standard |
| **FR-010** | SCOOP compatibility | MUST | Safe for concurrent use across SCOOP processors | simple_* standard |
| **FR-011** | Connection object abstraction | SHOULD | Both CLIENT_SOCKET and SERVER_SOCKET produce CONNECTION objects (or similar interface) | Reusable across protocols |
| **FR-012** | Partial read/write handling | SHOULD | Track bytes_sent and bytes_received; handle short writes/reads transparently | Production robustness |
| **FR-013** | Buffer size configuration | SHOULD | Allow `set_send_buffer_size()`, `set_receive_buffer_size()` | Performance tuning |
| **FR-014** | Optional connection pooling (Phase 2) | SHOULD | Reuse TCP connections for same host:port | Efficiency |
| **FR-015** | Non-blocking/event-driven API (Phase 2) | SHOULD | Offer async alternative for high-concurrency servers | Future growth |

---

## Non-Functional Requirements

| ID | Requirement | Category | Measure | Target | Rationale |
|----|-------------|----------|---------|--------|-----------|
| **NFR-001** | Client connection latency | PERFORMANCE | Time to connect and first send | <100ms to localhost | Acceptable for embedded validation |
| **NFR-002** | Server accept latency | PERFORMANCE | Time from client connect to accept returns | <100ms | Acceptable for typical servers |
| **NFR-003** | Data throughput (localhost) | PERFORMANCE | MB/sec for continuous data transfer | ≥10 MB/sec | Sufficient for embedded/scientific |
| **NFR-004** | Memory overhead per connection | MEMORY | Bytes per active CONNECTION object | <1 KB | Embedded systems constraint |
| **NFR-005** | Code readability | QUALITY | Boilerplate LOC for simple client/server | 5-10 lines each | Better than ISE net.ecf's 50-100 |
| **NFR-006** | API consistency with simple_* ecosystem | DESIGN | All methods follow simple_* naming, DBC | 100% compliance | Ecosystem integrity |
| **NFR-007** | SCOOP thread safety | CONCURRENCY | No data races in concurrent use | Zero unsafe accesses | SCOOP verification |
| **NFR-008** | Void safety | SAFETY | All code compiles with void_safety="all" | 100% | simple_* standard |
| **NFR-009** | Zero compilation warnings | QUALITY | Compiler output | 0 warnings | simple_* standard |
| **NFR-010** | Test coverage | QUALITY | Code coverage by unit tests | ≥85% | Production readiness |
| **NFR-011** | Documentation completeness | DOCUMENTATION | API reference, examples, architecture | Sufficient for beginner Eiffel dev | Accessibility |
| **NFR-012** | Cross-platform readiness | PORTABILITY | Code structure supports Windows, Linux, macOS | Design allows it; implement Windows MVP | Future-proofing |

---

## Constraint Requirements

| ID | Constraint | Type | Immutable? | Rationale |
|----|-----------|------|-----------|-----------|
| **C-001** | Must wrap ISE net.ecf (don't reimplement sockets) | TECHNICAL | YES | Leverage proven, maintained code |
| **C-002** | Must be void-safe (void_safety="all") | TECHNICAL | YES | simple_* ecosystem standard |
| **C-003** | Must be SCOOP-compatible | TECHNICAL | YES | simple_* ecosystem standard |
| **C-004** | Must use 100% Design by Contract | TECHNICAL | YES | simple_* ecosystem standard |
| **C-005** | Must compile with zero warnings | TECHNICAL | YES | simple_* ecosystem standard |
| **C-006** | Must prefer US/mainstream naming over academic Eiffel | DESIGN | YES | Core differentiator from ISE net |
| **C-007** | Must use simple_* patterns, not custom conventions | ECOSYSTEM | YES | Consistency across ecosystem |
| **C-008** | Windows primary in Phase 1 (Linux/macOS Phase 2) | SCOPE | YES | MVP scope |
| **C-009** | MVP focuses on blocking synchronous I/O | SCOPE | YES | Simplicity first |
| **C-010** | Cannot introduce external dependencies (only simple_*, ISE base, testing) | ECOSYSTEM | YES | Keep footprint small |

---

## Semantic Reframing Requirements

### From ISE Academic to US Mainstream Conventions

| ISE Naming | Problem | Proposed simple_net Naming | Rationale |
|-----------|---------|---------------------------|-----------|
| **NETWORK_STREAM_SOCKET** | Abstract name; doesn't clarify intent (client vs server) | **CLIENT_SOCKET** / **SERVER_SOCKET** / **CONNECTION** | Intent-driven; Python/Go convention |
| **put_string()** | Old FILE API; unfamiliar to socket developers | **send(data: ARRAY OF BYTES or STRING)** | Matches Python socket.send(), Go Write() |
| **read_line()** | Assumes line-delimited data; not general | **receive(max_bytes: INTEGER): ARRAY OF BYTES** | Matches Python socket.recv(), Go Read() |
| **listen(queue: INTEGER)** | Kept as-is (universal) | **listen(backlog: INTEGER)** | Clarifies parameter meaning |
| **accept()** | Good name; kept but wraps result | **accept(): CONNECTION** | Returns connection object, not socket |
| **INET_ADDRESS** | Abstract factory pattern; too academic | **(host: STRING, port: INTEGER)** | Simple tuple (or helper class) |
| **SOCKET_POLLER** | Timer-based callbacks; confusing for async | **(defer to Phase 2)** | Use SCOOP threads instead |
| **was_error** | Past tense; unclear what error? | **is_error: BOOLEAN** or **last_error: STRING** | Clear, queryable state |
| **socket_error** | Opaque string from OS | **error_code: ENUM {CONNECTION_REFUSED, TIMEOUT, READ_ERROR, WRITE_ERROR, CONNECTION_RESET}** | Classified, actionable |
| **is_open_read** / **is_open_write** | Asymmetric; TCP is full-duplex | **is_connected: BOOLEAN** | Single, clear state |
| **set_connect_timeout()** + **set_accept_timeout()** | Two separate methods; confusing | **set_timeout(seconds: REAL)** | Single, universal timeout |

---

## Use Cases & Acceptance Scenarios

### UC-001: Simple HTTP Validator (from Python)

**Actor:** Python script calling Eiffel validator via HTTP

**Precondition:** Eiffel HTTP server listening on localhost:8080

**Flow:**
```eiffel
-- Eiffel side (what simple_net enables)
create {SERVER_SOCKET}.make_for_port(8080)
server.listen(5)
connection := server.accept()
request := connection.receive(4096)
response := validate_design(request)
connection.send(response)
connection.close()

-- Python side (for reference)
import socket
sock = socket.socket()
sock.connect(('localhost', 8080))
sock.send(b'GET /validate ...')
response = sock.recv(4096)
sock.close()
```

**Acceptance:**
- ✅ Python client connects successfully
- ✅ Eiffel server accepts without deadlock
- ✅ Data transmitted correctly both directions
- ✅ Timeout (5 sec) closes stale connections
- ✅ Code is readable (< 20 LOC per side)

---

### UC-002: Embedded Sensor Bridge

**Actor:** Embedded device (microcontroller or small SBC) connecting to Eiffel validator

**Precondition:** Eiffel client running, sensor device accessible on network

**Flow:**
```eiffel
-- Eiffel side (client connecting to embedded device)
create client: CLIENT_SOCKET.make_for_host_port("192.168.1.100", 5000)
client.set_timeout(10)  -- 10-second timeout
client.connect()
if client.is_connected then
    client.send("QUERY_STATUS")
    status := client.receive(256)
    client.close()
end
```

**Acceptance:**
- ✅ Connection succeeds or fails clearly (no mystery timeouts)
- ✅ Timeout doesn't cause hang (exactly 10 seconds)
- ✅ Handles connection_refused, timeout, read_error distinctly
- ✅ Retry logic can wrap this naturally

---

### UC-003: Data Stream Processing

**Actor:** Eiffel validator streaming validation results back to Python

**Precondition:** Python client connects and waits for stream

**Flow:**
```eiffel
-- Eiffel server accepting multiple clients and streaming
server := create {SERVER_SOCKET}.make_for_port(9000)
server.listen(10)
across (1 |..| 100) as design_batch loop
    connection := server.accept()  -- wait for client
    across design_batch as item loop
        result := validate(item.item)
        connection.send(result_to_bytes(result))
        -- Partial writes handled: if not all bytes sent, retry
    end
    connection.close()
end
```

**Acceptance:**
- ✅ Multiple clients can connect and receive streams
- ✅ Partial writes (if MTU limits transmission) handled gracefully
- ✅ No data loss or duplication
- ✅ Connection closes cleanly after stream ends

---

## Success Metrics (Phase 1 MVP)

1. **Boilerplate Reduction:** Simple TCP client/server examples ≤ 10 LOC (vs. ISE net's 50-100)
2. **Naming Clarity:** New Eiffel developers recognize `connect()`, `send()`, `receive()` without documentation
3. **Error Handling:** Developers can distinguish "connection refused" from "timeout" from "read error" automatically
4. **SCOOP Integration:** Multi-threaded server handling multiple connections safely
5. **No ISE Exposure:** Code using simple_net never directly references NETWORK_STREAM_SOCKET, INET_ADDRESS, or SOCKET_POLLER
6. **Production Grade:** Zero warnings, ≥85% test coverage, DBC coverage 100%
7. **Ecosystem Value:** simple_grpc, simple_websocket can layer on simple_net cleanly

---

## Verification Plan

| Requirement | How Verified | Acceptance |
|-------------|--------------|-----------|
| **FR-001 (TCP client)** | Python client connects to Eiffel server; exchange data | Successful 10-exchange test |
| **FR-002 (TCP server)** | Eiffel server accepts 5 simultaneous Python clients | All 5 exchanges complete |
| **FR-003 (send/receive)** | Test with STRING and ARRAY OF BYTES in both directions | Exact match on round-trip |
| **FR-004 (lifecycle)** | Stress test: 1000 connections open/close rapidly | No resource leaks, zero crashes |
| **FR-005 (timeout)** | Set 1-second timeout, attempt to connect to port that never accepts | Timeout fires at ~1 sec, not 2 or 0.5 |
| **FR-006 (errors)** | Test: connection refused, timeout, read error on closed socket | Each produces distinct, queryable error |
| **FR-007 (IPv4)** | Test: "localhost", "127.0.0.1", machine hostname, 192.168.x.x IP | All resolve and connect successfully |
| **FR-008 (blocking)** | Simple synchronous test: no callbacks, no event loops | Code is linear and comprehensible |
| **FR-009 (DBC)** | Compile with assertions enabled; run contract violations | All assertions hold under test |
| **FR-010 (SCOOP)** | Multi-threaded test: separate processors access same connection | No data races (verified by Eiffel's SCOOP analyzer) |

---

## Dependencies (Phase 1)

### Required Libraries

- **ISE base library** - Fundamental types
- **ISE net.ecf** - Socket layer (what we wrap)
- **ISE testing library** - Unit test framework
- **simple_mml** (if using MML postconditions for model queries)

### No External Dependencies
- ✅ Not bringing in simple_http, simple_ipc, etc.
- ✅ simple_net is standalone (although will be used BY those libraries)

---

## Out of Scope (Phase 1)

- ❌ Consumer library refactoring (Phase 2 after simple_net v1.0 ships: refactor simple_smtp and simple_cache to use simple_net)
- ❌ UDP sockets (separate library: simple_udp)
- ❌ Unix domain sockets (Phase 2)
- ❌ Non-blocking/async API (Phase 2)
- ❌ SSL/TLS encryption (separate library: simple_tls)
- ❌ Connection pooling (Phase 2)
- ❌ HTTP-specific features (handled by simple_http on top)
- ❌ IPv6 (Phase 2, design for it, implement Windows IPv4 MVP)

---

## Next Steps

1. **Step 4: DECISIONS** - Make design choices (class hierarchy, error handling style, API shape)
2. **Step 5: INNOVATIONS** - Identify how simple_net improves on ISE net.ecf
3. **Step 6: RISKS** - Assess what could go wrong
4. **Step 7: RECOMMENDATION** - Final BUILD recommendation with confidence level

---
