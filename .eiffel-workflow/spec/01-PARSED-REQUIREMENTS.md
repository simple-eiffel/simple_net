# PARSED REQUIREMENTS: simple_net - TCP Socket Abstraction Library

**Date:** January 28, 2026
**Specification Phase:** Step 1 - Analyze and Extract Research

---

## Problem Summary

**In one sentence:** Eiffel developers need a high-level, low-boilerplate TCP socket library that hides ISE's academic complexity behind a practical, US-friendly API.

### The Core Problem

ISE's net.ecf is powerful but requires 50-100+ lines of boilerplate code for simple client/server patterns. The academic naming (NETWORK_STREAM_SOCKET, INET_ADDRESS, SOCKET_POLLER) and implementation-focused semantics make it inaccessible to mainstream Eiffel developers and developers switching from Python/Go/Java.

**simple_net solves this** by wrapping ISE net.ecf with:
- Intuitive naming (CLIENT_SOCKET, SERVER_SOCKET, CONNECTION)
- 5-10 LOC for typical patterns (vs 50-100 in ISE net)
- Classified error types (CONNECTION_REFUSED, TIMEOUT, READ_ERROR - not opaque strings)
- 100% Design by Contract
- SCOOP-native concurrency

---

## Scope

### In Scope (MUST HAVE)

**Core Classes & Features:**
- TCP client socket (CLIENT_SOCKET) - connect, send, receive, close
- TCP server socket (SERVER_SOCKET) - listen, accept, close
- Active connection abstraction (CONNECTION)
- Simple address representation (ADDRESS: host + port)
- Classified error types (ERROR_TYPE enum)
- Blocking I/O mode (synchronous)
- IPv4 support (Windows primary)
- Single unified timeout mechanism
- 100% Design by Contract
- SCOOP concurrency support (separate keyword)
- Zero compilation warnings
- ≥85% test coverage

### In Scope (SHOULD HAVE)

- Connection object abstraction (unified interface)
- Partial read/write handling with byte tracking
- Configurable buffer sizes
- Connection state queries (is_connected, is_listening)
- Comprehensive error handling with queryable state

### Out of Scope (Deferred to Phase 2 or Later)

- **Consumer library refactoring** - Phase 2 after simple_net v1.0 ships (refactor simple_smtp, simple_cache to use simple_net)
- UDP sockets (separate library: simple_udp)
- Non-blocking/async API
- IPv6 support
- Unix domain sockets
- Connection pooling
- Advanced socket options
- SSL/TLS encryption

---

## Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria | Semantic Frame |
|----|-------------|----------|---------------------|-----------------|
| **FR-001** | TCP client creation and connection | MUST | `create {CLIENT_SOCKET}.make_for_host_port("host", 8080)` followed by `client.connect()` works with hostname resolution | Python socket.socket() pattern |
| **FR-002** | TCP server creation and listening | MUST | `create {SERVER_SOCKET}.make_for_port(8080)` followed by `server.listen(5)` accepts incoming connections | Python ServerSocket pattern |
| **FR-003** | Data transmission (send/receive) | MUST | `connection.send(data)` and `connection.receive(max_bytes)` work with STRING and ARRAY OF BYTES | Not `put_string` / `read_line` |
| **FR-004** | Connection lifecycle management | MUST | `is_connected`, `close()`, proper cleanup; SCOOP-safe for concurrent use | Clear state queries, no leaks |
| **FR-005** | Unified timeout mechanism | MUST | `set_timeout(seconds)` applies to ALL operations (connect, send, receive, accept) | Like Python `settimeout()` |
| **FR-006** | Classified error detection | MUST | Distinct error types: `CONNECTION_REFUSED`, `TIMEOUT`, `READ_ERROR`, `WRITE_ERROR`, `CONNECTION_RESET` queryable via `is_error`, `error_classification`, `last_error_string` | Actionable, not opaque |
| **FR-007** | IPv4 address support | MUST | Resolve hostnames ("localhost", "example.com"), IP addresses ("127.0.0.1", "192.168.x.x"), and ports (1-65535) | Standard addressing |
| **FR-008** | Blocking synchronous mode | MUST | All operations block until completion; no callbacks, no event loops, no async-await in MVP | Simplicity first |
| **FR-009** | Design by Contract everywhere | MUST | 100% of public classes/features have preconditions, postconditions, invariants, and MML model queries | simple_* standard |
| **FR-010** | SCOOP concurrency safety | MUST | Safe for concurrent use via `separate` keyword; SCOOP processor per connection; Eiffel verifier confirms no race conditions | Race-free by design |
| **FR-011** | Connection abstraction | SHOULD | Both CLIENT_SOCKET and SERVER_SOCKET produce CONNECTION objects (or compatible interface) for unified I/O | Reuse across protocols |
| **FR-012** | Partial I/O handling | SHOULD | Track `bytes_sent` and `bytes_received`; handle short reads/writes transparently | Production robustness |
| **FR-013** | Buffer size tuning | SHOULD | `set_send_buffer_size(bytes)` and `set_receive_buffer_size(bytes)` for performance optimization | Embedded systems |
| **FR-014** | Connection pooling (Phase 2) | SHOULD | Reuse TCP connections for same (host:port) pair in Phase 2 | Efficiency |
| **FR-015** | Non-blocking API (Phase 2) | SHOULD | Offer `set_non_blocking()` and async variants in Phase 2 | High concurrency scenarios |

---

## Non-Functional Requirements

| ID | Requirement | Category | Measure | Target | Rationale |
|----|-------------|----------|---------|--------|-----------|
| **NFR-001** | Client latency | PERFORMANCE | Connection + first send time | <100ms to localhost | Embedded/scientific validation |
| **NFR-002** | Server acceptance latency | PERFORMANCE | Client connect to accept returns | <100ms | Acceptable for most servers |
| **NFR-003** | Data throughput | PERFORMANCE | MB/sec continuous transfer | ≥10 MB/sec | Sufficient for embedded work |
| **NFR-004** | Memory per connection | MEMORY | Bytes per CONNECTION object | <1 KB | Embedded systems constraint |
| **NFR-005** | Boilerplate reduction | QUALITY | LOC for simple client/server | 5-10 each | 80-90% reduction vs ISE net |
| **NFR-006** | API consistency | DESIGN | Naming, patterns, conventions | 100% simple_* compliance | Ecosystem integrity |
| **NFR-007** | Thread safety | CONCURRENCY | Data races in concurrent use | Zero | SCOOP verification |
| **NFR-008** | Void safety | SAFETY | Code compiled with | `void_safety="all"` | simple_* standard |
| **NFR-009** | Compilation warnings | QUALITY | Compiler output | 0 warnings | simple_* standard |
| **NFR-010** | Test coverage | QUALITY | Code coverage by tests | ≥85% | Production readiness |
| **NFR-011** | Documentation | DOCUMENTATION | Coverage for beginner dev | API ref + guide + examples | Accessibility |
| **NFR-012** | Cross-platform ready | PORTABILITY | Design structure | Supports Win/Linux/macOS | Future-proof, Phase 1 Windows |

---

## Constraints (Immutable)

| ID | Constraint | Type | Rationale |
|----|-----------|------|-----------|
| **C-001** | Wrap ISE net.ecf (don't reimplement) | TECHNICAL | Leverage proven, maintained code |
| **C-002** | Void-safe (void_safety="all") | TECHNICAL | simple_* ecosystem standard |
| **C-003** | SCOOP-compatible | TECHNICAL | simple_* ecosystem standard |
| **C-004** | 100% Design by Contract | TECHNICAL | simple_* ecosystem standard |
| **C-005** | Zero compilation warnings | TECHNICAL | simple_* ecosystem standard |
| **C-006** | US/mainstream naming over academic | DESIGN | Core differentiator from ISE net |
| **C-007** | simple_* patterns, not custom | ECOSYSTEM | Consistency across ecosystem |
| **C-008** | Windows primary Phase 1 | SCOPE | MVP scope (Linux/macOS Phase 2) |
| **C-009** | Blocking mode MVP only | SCOPE | Simplicity first |
| **C-010** | No external dependencies | ECOSYSTEM | Keep footprint minimal |

---

## Decisions Already Made (from Research Phase 04-DECISIONS.md)

| ID | Decision | Rationale | Impact |
|----|----------|-----------|--------|
| **D-001** | Separate CLIENT_SOCKET and SERVER_SOCKET classes | Intent clarity, prevents misuse, Python/Go convention | 2 classes instead of unified SOCKET |
| **D-002** | Custom ADDRESS class (host: STRING, port: INTEGER) | Simple, familiar, validates at creation | Type-safe address handling |
| **D-003** | Queryable state errors (is_error, error_classification) | Eiffel convention, enables contracts | No exceptions; explicit checks |
| **D-004** | Single universal timeout (set_timeout()) | API simplicity, Python pattern | Applies to all operations |
| **D-005** | Full send guarantee, partial receive | User expectations, transparency | More internal state tracking |
| **D-006** | Full DBC (pre+post+inv+MML) | Foundation library standard | Longer signatures, complete specs |
| **D-007** | Separate processor per connection (SCOOP) | Race-free by design | Eiffel compiler guarantees safety |
| **D-008** | Blocking mode only (Phase 1) | Simplicity, threading via SCOOP | No non-blocking API yet |
| **D-009** | Short method names (send, receive, connect) | Match Python/Go expectation | Familiar to most developers |

---

## Innovations to Implement (from Research Phase 05-INNOVATIONS.md)

| ID | Innovation | Design Impact |
|----|------------|---------------|
| **I-001** | US/mainstream semantic reframing | CLIENT_SOCKET, SERVER_SOCKET, CONNECTION (not NETWORK_STREAM_SOCKET) |
| **I-002** | Classified error types (enum, not strings) | CONNECTION_REFUSED, TIMEOUT, READ_ERROR queryable and actionable |
| **I-003** | DBC-first design (contracts as executable spec) | Formal, verifiable behavior; contracts document API |
| **I-004** | SCOOP-centric concurrency | separate keyword for processor-per-connection safety |
| **I-005** | simple_* ecosystem foundation | Unifies socket handling across simple_smtp, simple_cache, simple_grpc, simple_websocket |
| **I-006** | Zero-boilerplate server patterns | 5-10 LOC vs 50-100; clear separation of concerns |
| **I-007** | Phase 2 async without redesign | Blocking API forward-compatible with async layer |

---

## Risks to Address in Design (from Research Phase 06-RISKS.md)

| ID | Risk | Mitigation Strategy |
|----|------|---------------------|
| **RISK-001** | ISE net.ecf has bugs we inherit | Thorough contract-based testing; DBC prevents many issues; thin wrapper delegation |
| **RISK-002** | Blocking-only design insufficient for high concurrency | Document Phase 1 scope; Phase 2 adds non-blocking; rare for Eiffel |
| **RISK-003** | Single timeout doesn't match all use cases | Well-documented behavior; Phase 2 can add per-operation granularity |
| **RISK-004** | Cross-platform testing limited (Windows MVP) | Leverage ISE net cross-platform; Linux/macOS testing Phase 2 |
| **RISK-005** | Wrapper performance overhead | Thin delegation; profiling in Phase 2 if needed |
| **RISK-006** | SCOOP learning curve for threading-experienced devs | Extensive documentation with examples; compare to goroutines |
| **RISK-007** | Error classification misses edge cases | Comprehensive testing; `OTHER` category for unknowns; Phase 2 refinement |
| **RISK-008** | DBC contracts become maintenance burden | Contract review phase; test suite validates contracts; tools support |
| **RISK-009** | Address handling doesn't support all formats | Phase 1: IPv4 + hostname; Phase 2 adds IPv6, Unix sockets |
| **RISK-010** | Integration with downstream breaks code | Semantic versioning; early testing with simple_http; migration guides |

---

## Use Cases & Acceptance Scenarios

### UC-001: Simple HTTP Validator (Cloud + Embedded)

**Actor:** Python script or embedded device calling Eiffel validator

**Precondition:** Eiffel HTTP server listening on localhost:8080

**Main Flow:**
1. Python/embedded client initiates TCP connection to server
2. Eiffel server accepts connection (< 100ms)
3. Client sends validation request (JSON or binary)
4. Server processes and sends response
5. Client receives and closes

**Acceptance:**
- ✅ Python client connects successfully
- ✅ Eiffel server accepts without deadlock
- ✅ Data transmitted correctly both directions
- ✅ Timeout (5 sec) closes stale connections
- ✅ Code readable (< 20 LOC per side)

---

### UC-002: Embedded Sensor Bridge

**Actor:** Embedded device (IoT, SBC) connecting to Eiffel validator

**Precondition:** Eiffel client running, sensor device accessible on network

**Main Flow:**
1. Eiffel connects to sensor device on port 5000
2. Sends "QUERY_STATUS" command
3. Receives sensor data
4. Closes connection
5. Retries on timeout (up to 3 attempts)

**Acceptance:**
- ✅ Connection succeeds or fails clearly (no mystery hangs)
- ✅ Timeout exactly 10 seconds (not 5, not infinite)
- ✅ Errors distinct (refused vs timeout vs read error)
- ✅ Retry logic works naturally

---

### UC-003: Data Stream Processing

**Actor:** Eiffel validator streaming results to Python client

**Precondition:** Python client connects and waits for stream

**Main Flow:**
1. Eiffel server accepts client connection
2. Server sends validation results one-by-one
3. Client receives and processes each result
4. Connection closes when stream ends

**Acceptance:**
- ✅ Multiple clients connect simultaneously
- ✅ Partial writes handled gracefully (frame boundaries)
- ✅ No data loss or duplication
- ✅ Connection closes cleanly

---

## Success Criteria for Phase 1

1. **Simplicity:** Eiffel developer writes 5-line TCP client/server without documentation
2. **Naming Clarity:** Python/Go developers immediately recognize API (connect, send, receive)
3. **Error Handling:** Errors actionable (not opaque strings)
4. **Ecosystem Integration:** simple_grpc and simple_websocket can layer cleanly
5. **Quality:** Zero warnings, ≥85% test coverage, 100% DBC
6. **Documentation:** User learns from guide without questions

---

## Phase 1 vs Phase 2

### Phase 1 Deliverable (4-5 days)

- TCP client/server (IPv4, Windows, blocking)
- Simple ADDRESS and ERROR_TYPE classes
- 100% DBC
- SCOOP concurrency
- Zero warnings, comprehensive tests
- **Deliver: simple_net v1.0.0**

### Phase 2A: Consumer Refactoring (2-3 days each, after Phase 1)

- simple_smtp v2.0 (use simple_net)
- simple_cache v2.0 (use simple_net)

### Phase 2B: Feature Extensions (parallel)

- Non-blocking/async API
- IPv6 support
- Unix domain sockets
- Connection pooling
- Performance optimization

---

## Next Steps

1. **Step 2: Domain Model** - Identify core concepts (CLIENT_SOCKET, SERVER_SOCKET, CONNECTION, ADDRESS, ERROR_TYPE)
2. **Step 3: Challenge Assumptions** - Validate decisions
3. **Step 4: Class Design** - Detailed class hierarchy
4. **Step 5: Contract Design** - Full DBC specifications
5. **Step 6: Interface Design** - Public API design
6. **Step 7: Specification** - Formal class specifications
7. **Step 8: Validation** - Quality assurance gates

---
