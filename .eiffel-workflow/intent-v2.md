# Intent: simple_net - TCP Socket Abstraction Library

**Date:** January 28, 2026
**Status:** Approved for Implementation (from Specification Phase)

---

## What

**simple_net** is a thin wrapper around ISE's net.ecf that provides an intuitive, US-developer-friendly TCP socket API.

**Core Purpose:**
Transform ISE's academic socket terminology (NETWORK_STREAM_SOCKET, INET_ADDRESS, SOCKET_POLLER) into mainstream naming (CLIENT_SOCKET, SERVER_SOCKET, CONNECTION) that matches Python/Go conventions, reducing boilerplate from 50-100 LOC to 5-10 LOC for typical client/server patterns.

**Key Transformations:**
- `NETWORK_STREAM_SOCKET` → `CLIENT_SOCKET` / `SERVER_SOCKET` (intent-driven)
- `put_string()` → `send()` (Python convention)
- `read_line()` → `receive()` (Python convention)
- `was_error` (past tense) → `is_error` (present state)
- `socket_error` (opaque string) → `error_classification` (enum: CONNECTION_REFUSED, TIMEOUT, READ_ERROR, etc.)
- `INET_ADDRESS` (factory pattern) → `ADDRESS` (simple host:port tuple)
- Multiple timeouts → Single `set_timeout()` (applies to all operations)

---

## Why

**Problem:** ISE's net.ecf is proven and robust (20+ years, used internally by ISE), but:
1. **Academic naming** deters mainstream developers switching from Python/Go/Java
2. **Heavy boilerplate** (50-100 LOC per pattern) makes socket programming inaccessible
3. **Opaque error handling** (string errors, not classified) prevents automated retry logic
4. **Repeated code** across ecosystem (simple_smtp, simple_cache, simple_http all reimplement socket management)

**Solution:** simple_net fills the gap by providing:
- **Intuitive API** familiar to Python/Go developers
- **Minimal boilerplate** (5-10 LOC typical patterns, 80-90% reduction)
- **Classified errors** (enum: CONNECTION_REFUSED, TIMEOUT, READ_ERROR, etc.) enabling smart retry logic
- **100% Design by Contract** (executable specification via preconditions, postconditions, invariants, MML)
- **SCOOP concurrency** (safe for concurrent use via `separate` keyword)
- **Foundation for ecosystem** (used by simple_grpc, simple_websocket, simple_http v2, and future socket-based protocols)

---

## Users

| User Type | Context | Primary Need |
|-----------|---------|--------------|
| **Embedded IoT Developers** | Connecting validation scripts to sensor networks | Simple TCP client for device communication with clear error classification |
| **Data Scientists** | Eiffel-based analysis frameworks needing network I/O | Blocking socket API without async complexity; works with SCOOP threading |
| **Web Framework Builders** | Building HTTP, WebSocket, gRPC on top | Foundation for protocol layers (simple_http, simple_websocket, simple_grpc) |
| **Systems Integrators** | Connecting Eiffel validators to external systems | Reliable TCP with queryable state, proper timeout handling |
| **Maintenance (simple_* Ecosystem)** | Refactoring simple_smtp, simple_cache, simple_http | Unified socket layer reduces code duplication, enables version 2.0 releases |

---

## Acceptance Criteria

### Success Metrics (Phase 1)

- [ ] **Simplicity:** Eiffel developer writes 5-line TCP client without reading documentation
- [ ] **Naming Clarity:** Python/Go developers immediately recognize `connect()`, `send()`, `receive()`
- [ ] **Error Handling:** Errors are actionable (CONNECTION_REFUSED vs TIMEOUT vs READ_ERROR)
- [ ] **Boilerplate Reduction:** Typical client/server patterns ≤ 10 LOC (vs ISE net's 50-100)
- [ ] **Ecosystem Integration:** simple_grpc and simple_websocket can layer cleanly on simple_net
- [ ] **Quality Gates:**
  - ✅ Zero compilation warnings
  - ✅ ≥85% test coverage (measured by code coverage tool)
  - ✅ 100% Design by Contract (all public features have pre/post/invariant)
  - ✅ SCOOP verification (no race conditions via Eiffel analyzer)
  - ✅ Void-safe compilation (`void_safety="all"`)
- [ ] **Documentation:** User learns from guide without needing to ask questions

### Functional Requirements (Traced from Specification)

| ID | Requirement | Priority | MVP? |
|----|-------------|----------|------|
| FR-001 | TCP client socket (create, connect, send, receive, close) | MUST | YES |
| FR-002 | TCP server socket (create, listen, accept, close) | MUST | YES |
| FR-003 | Data transmission (send/receive for STRING and ARRAY OF BYTES) | MUST | YES |
| FR-004 | Connection lifecycle management (is_connected, close, cleanup) | MUST | YES |
| FR-005 | Unified timeout mechanism (set_timeout applies to all ops) | MUST | YES |
| FR-006 | Classified error detection (enum, not strings) | MUST | YES |
| FR-007 | IPv4 address support (hostname resolution) | MUST | YES |
| FR-008 | Blocking synchronous mode (no callbacks, no event loops) | MUST | YES |
| FR-009 | Design by Contract (100% coverage: pre/post/inv/MML) | MUST | YES |
| FR-010 | SCOOP concurrency safety (separate keyword, race-free) | MUST | YES |
| FR-011 | Connection abstraction (unified interface) | SHOULD | OPTIONAL |
| FR-012 | Partial I/O handling (byte tracking) | SHOULD | OPTIONAL |
| FR-013 | Buffer size tuning (Phase 2) | SHOULD | NO |
| FR-014 | Connection pooling (Phase 2) | SHOULD | NO |
| FR-015 | Non-blocking API (Phase 2) | SHOULD | NO |

### Non-Functional Requirements (Traced from Specification)

| ID | Requirement | Category | Target | Rationale |
|----|-------------|----------|--------|-----------|
| NFR-001 | Client latency (connect + first send) | PERFORMANCE | <100ms localhost | Embedded validation |
| NFR-002 | Server accept latency | PERFORMANCE | <100ms | Typical servers |
| NFR-003 | Data throughput | PERFORMANCE | ≥10 MB/sec | Embedded work |
| NFR-004 | Memory per connection | MEMORY | <1 KB | Embedded constraint |
| NFR-005 | Boilerplate reduction | QUALITY | 5-10 LOC per pattern | vs ISE net's 50-100 |
| NFR-006 | API consistency | DESIGN | 100% simple_* compliance | Ecosystem integrity |
| NFR-007 | Thread safety (SCOOP) | CONCURRENCY | Zero data races | Eiffel verifier confirms |
| NFR-008 | Void safety | SAFETY | void_safety="all" | simple_* standard |
| NFR-009 | Zero warnings | QUALITY | 0 compiler warnings | simple_* standard |
| NFR-010 | Test coverage | QUALITY | ≥85% by code coverage | Production readiness |
| NFR-011 | Documentation | DOCUMENTATION | API ref + guide + examples | Beginner accessible |
| NFR-012 | Cross-platform ready | PORTABILITY | Design for Win/Linux/macOS | Phase 1 Windows, Phase 2 others |

---

## Out of Scope (Phase 1 MVP)

The following are **explicitly deferred to Phase 2** or later releases:

### Library Refactoring (Phase 2A - After simple_net v1.0 Ships)
- ❌ Refactor simple_smtp to use simple_net (Phase 2A, delivers simple_smtp v2.0)
- ❌ Refactor simple_cache to use simple_net (Phase 2A, delivers simple_cache v2.0)

**Rationale:** Keep Phase 1 focused on shipping simple_net v1.0. Consumer refactoring deferred until v1.0 proven stable, minimizing coupling and delivery risk.

### Protocol Extensions (Phase 2B - Feature Extensions)
- ❌ UDP sockets (separate library: simple_udp)
- ❌ Non-blocking/async API (defer until blocking proven sufficient)
- ❌ IPv6 support (defer to Phase 2; Phase 1 Windows IPv4 MVP)
- ❌ Unix domain sockets (defer to Phase 2; Windows MVP)
- ❌ Connection pooling (defer to Phase 2 framework)
- ❌ Advanced socket options (e.g., TCP_NODELAY, SO_KEEPALIVE tuning)
- ❌ SSL/TLS encryption (separate library: simple_tls)
- ❌ Per-operation timeout granularity (Phase 1 has single universal timeout)

---

## Dependencies (REQUIRED - simple_* First Policy)

**Rule:** Always prefer simple_* libraries over ISE stdlib. Only ISE allowed if no simple_* equivalent exists.

### Required Dependencies

| Need | Library | Justification | simple_* Check |
|------|---------|---------------|-----------------|
| Network I/O (TCP sockets) | `$ISE_LIBRARY/library/net/net.ecf` | No simple_* equivalent; ISE net.ecf is proven (20+ years, used internally) | N/A - this IS the ISE library we wrap |
| Fundamental types | `$ISE_LIBRARY/library/base/base.ecf` | Standard Eiffel base library; required | N/A - only ISE provides |
| Unit testing | `$ISE_LIBRARY/library/testing/testing.ecf` | EQA_TEST_SET framework; required for test suite | No simple_test equivalent yet |
| Mathematical models | `$SIMPLE_EIFFEL/simple_mml/simple_mml.ecf` | MML for formal contract postconditions (model queries, frame conditions) | ✅ simple_mml v1.0.1+ preferred |

### Dependency Audit Results

**Violations Found:** 0
**simple_* First Policy:** ✅ COMPLIANT
**Gaps Identified:** 1

| Gap | Current Workaround | Proposed Future | Priority |
|-----|-------------------|-----------------|----------|
| Unit testing framework | ISE testing (EQA_TEST_SET) | simple_test (for 100% simple_* compliance) | Low (EQA sufficient) |

**Recommendation:** After simple_net v1.0 ships, consider creating **simple_test** as a thin wrapper around EQA_TEST_SET to maintain ecosystem consistency.

### ECF Configuration

```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<system name="simple_net" uuid="[GENERATE-NEW-UUID]">
    <target name="simple_net">
        <description>TCP socket abstraction library</description>
        <root class="SIMPLE_NET" feature="default_create"/>

        <capability>
            <concurrency support="scoop"/>
            <void_safety support="all"/>
        </capability>

        <!-- ISE allowed (core + wrapped protocol) -->
        <library name="base" location="$ISE_LIBRARY/library/base/base.ecf"/>
        <library name="net" location="$ISE_LIBRARY/library/net/net.ecf"/>

        <!-- simple_* preferred (mathematical models for contracts) -->
        <library name="simple_mml" location="$SIMPLE_EIFFEL/simple_mml/simple_mml.ecf"/>

        <cluster name="src" location=".\src"/>
    </target>

    <target name="simple_net_tests" extends="simple_net">
        <description>Test suite for simple_net</description>
        <root class="TEST_SUITE" feature="default_create"/>

        <!-- ISE testing (no simple_test yet) -->
        <library name="testing" location="$ISE_LIBRARY/library/testing/testing.ecf"/>

        <cluster name="test" location=".\test"/>
    </target>
</system>
```

**Status:** ECF will be created in Phase 1 (Contracts skeleton generation).

---

## MML Decision (REQUIRED)

**Question:** Does simple_net need MML model queries for precise postconditions?

**Answer:** ✅ **YES - REQUIRED**

### Justification

**Internal collections that need MML:**
1. **bytes_sent** (INTEGER) - Not a collection; no MML needed
2. **bytes_received** (INTEGER) - Not a collection; no MML needed
3. **connection_state** (internal STATE enum) - Not a collection; no MML needed
4. **error_history** (theoretical CONNECTION tracking) - Not Phase 1 scope

**Decision:** While simple_net itself has **no user-facing collections**, the library's contracts will use **MML principles** for frame conditions:

```eiffel
ensure
    connected_state_changed: is_connected -- What changed
    not_error: not is_error                -- What's guaranteed
    timeout_preserved: timeout = old timeout -- What didn't change (frame)
```

**MML Model Queries to Define:**
- `connection_state_model`: Represents the connection as a formal state
- `error_state_model`: Represents error classification formally
- `bytes_sent_model`: Formal tracking of cumulative bytes sent
- `bytes_received_model`: Formal tracking of cumulative bytes received

### MML Dependency Impact

- ✅ Adds simple_mml v1.0.1+ to ECF (already decided in dependencies)
- ✅ Enables mathematical precision in contracts
- ✅ Allows Eiffel verifier to prove properties formally
- ✅ Supports Phase 2 advanced features (pooling, async with formal guarantees)

**Cost:** Minimal - MML is lightweight; contracts become more formally verifiable but don't add runtime overhead.

---

## Phase Architecture

### Phase 1: simple_net v1.0 MVP (4-5 days)

**Deliverable:** Production-ready TCP socket abstraction library

**Scope (MUST HAVE):**
- ✅ CLIENT_SOCKET - TCP client (connect, send, receive, close)
- ✅ SERVER_SOCKET - TCP server (listen, accept, close)
- ✅ CONNECTION - Active connection abstraction
- ✅ ADDRESS - Host:port tuple (immutable, validates at creation)
- ✅ ERROR_TYPE - Enum classification (CONNECTION_REFUSED, TIMEOUT, READ_ERROR, etc.)
- ✅ SIMPLE_NET - Facade coordinating library
- ✅ 100% Design by Contract (pre/post/inv/MML model queries)
- ✅ SCOOP concurrency (`separate` keyword for CONNECTION)
- ✅ IPv4 address support (hostname resolution)
- ✅ Blocking I/O mode (synchronous, no callbacks)
- ✅ Single unified timeout mechanism
- ✅ Zero compilation warnings
- ✅ ≥85% test coverage
- ✅ Void-safe (`void_safety="all"`)

**Scope (SHOULD HAVE - Optional):**
- ⚪ Partial read/write handling with byte tracking
- ⚪ Configurable buffer sizes
- ⚪ Connection state queries (is_listening, etc.)

**Scope (OUT OF SCOPE - Phase 2 or Later):**
- ❌ Consumer library refactoring (Phase 2A)
- ❌ Non-blocking/async API (Phase 2B)
- ❌ IPv6 support (Phase 2B)
- ❌ Connection pooling (Phase 2B)

**Workflow (8-phase Eiffel Spec Kit):**
1. **Phase 0: Intent** (this document) - ✅ COMPLETE
2. **Phase 1: Contracts** (eiffel-contracts skill) - `make_for_host_port` and features with DBC
3. **Phase 2: Review** (eiffel-review skill) - Adversarial AI review of contracts
4. **Phase 3: Tasks** (eiffel-tasks skill) - Break contracts into implementation tasks
5. **Phase 4: Implement** (eiffel-implement skill) - Write feature bodies (contracts frozen)
6. **Phase 5: Verify** (eiffel-verify skill) - Generate comprehensive test suite
7. **Phase 6: Harden** (eiffel-harden skill) - Adversarial testing, stress tests, edge cases
8. **Phase 7: Ship** (eiffel-ship skill) - Production release (GitHub Pages docs, binaries)

**Estimated Effort:** 4-5 days

---

### Phase 2A: Consumer Library Refactoring (2-3 days each, AFTER simple_net v1.0 ships)

**Deliverable:** Refactored libraries using simple_net

**simple_smtp v2.0 Refactoring:**
- Replace direct NETWORK_STREAM_SOCKET with CLIENT_SOCKET from simple_net
- Simplify error handling (use simple_net's ERROR_TYPE classification)
- Reduce boilerplate in connection management
- Release as simple_smtp v2.0

**simple_cache v2.0 Refactoring:**
- Replace direct NETWORK_STREAM_SOCKET with CLIENT_SOCKET from simple_net
- Simplify Redis connection pooling (use simple_net as base)
- Streamline error handling
- Release as simple_cache v2.0

**Rationale:** Keep Phase 1 focused on simple_net delivery. Consumer refactoring deferred until v1.0 proven stable. Separate release cycles (each library update is independent).

**Estimated Effort:** 2-3 days per library

---

### Phase 2B: Feature Extensions (months 2-3 after Phase 1, in parallel with Phase 2A)

**Deliverable:** Extended capabilities without breaking v1.0 API

**Features:**
- Non-blocking / event-driven API
- IPv6 support
- Unix domain sockets (Linux/macOS)
- Connection pooling framework
- Per-operation timeout granularity
- Performance profiling & optimization
- Advanced socket options exposure

**Design Principle:** Phase 1 ships clean and stable. Phase 2 enhances without breaking backward compatibility (semantic versioning v1.1.x for additions, v2.0 for breaking changes if needed).

---

## Success Criteria (Phase 1 Complete)

Phase 1 is successful if:

1. ✅ **Simplicity Achieved:** Eiffel developer writes 5-line TCP client without documentation
2. ✅ **Naming Clarity:** Python/Go developers immediately recognize API (`connect`, `send`, `receive`)
3. ✅ **Error Handling:** Errors are actionable (not opaque strings)
4. ✅ **Ecosystem Integration:** simple_grpc and simple_websocket can layer cleanly
5. ✅ **Quality Sustained:**
   - Zero warnings
   - ≥85% test coverage
   - 100% DBC
   - SCOOP verification clean
6. ✅ **Documentation Complete:** User learns from guide without asking questions

---

## Key Architectural Decisions (Locked from Specification Phase)

| ID | Decision | Rationale | Implementation Impact |
|----|----------|-----------|----------------------|
| **D-001** | Separate CLIENT_SOCKET and SERVER_SOCKET classes | Intent clarity, prevents misuse, matches Python/Go convention | 2 classes + shared base |
| **D-002** | Custom ADDRESS class (host: STRING, port: INTEGER) | Simple, familiar, validates at creation | Type-safe addresses |
| **D-003** | Queryable state errors (is_error, error_classification) | Eiffel convention, enables contracts | No exceptions; explicit checks |
| **D-004** | Single universal timeout (set_timeout()) | API simplicity, Python pattern | Applies to all operations |
| **D-005** | Full send guarantee, partial receive | User expectations, transparency | Internal state tracking |
| **D-006** | Full DBC (pre+post+inv+MML) | Foundation library standard | Longer signatures, complete specs |
| **D-007** | Separate processor per connection (SCOOP) | Race-free by design | Eiffel compiler guarantees safety |
| **D-008** | Blocking mode only (Phase 1) | Simplicity, threading via SCOOP | No non-blocking API yet |
| **D-009** | Short method names (send, receive, connect) | Match Python/Go expectation | Familiar to most developers |

---

## Use Cases (Validated in Specification)

### UC-001: Simple HTTP Validator (Cloud + Embedded)
- **Actor:** Python script or embedded device calling Eiffel validator
- **Flow:** Client connects → sends request → receives response → closes
- **Success:** <20 LOC per side, <100ms latency, timeout prevents hangs

### UC-002: Embedded Sensor Bridge
- **Actor:** IoT device connecting to Eiffel validator
- **Flow:** Client connects → sends command → receives data → retries on timeout
- **Success:** Clear error classification (refused vs timeout vs read error)

### UC-003: Data Stream Processing
- **Actor:** Eiffel server streaming results to Python client
- **Flow:** Server accepts clients → sends results one-by-one → closes
- **Success:** Multiple clients simultaneously, no data loss, clean close

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| ISE net.ecf has bugs we inherit | MEDIUM | HIGH | Thin wrapper + comprehensive contracts + testing |
| Blocking-only insufficient for high concurrency | MEDIUM | MEDIUM | Document Phase 1 scope; Phase 2 adds non-blocking |
| Single timeout doesn't match all use cases | MEDIUM | MEDIUM | Well-documented; Phase 2 can add per-operation granularity |
| Cross-platform testing limited (Windows MVP) | LOW | MEDIUM | Leverage ISE net cross-platform; Linux/macOS Phase 2 |
| SCOOP learning curve for threading-experienced devs | MEDIUM | LOW | Extensive documentation with examples |
| Integration with downstream breaks code | LOW | HIGH | Semantic versioning; early testing with users |

---

## Success Measures (How We Know We're Done)

**When Phase 1 Complete (simple_net v1.0.0):**

- [ ] Compilation: `ec.sh -batch -config simple_net.ecf -target simple_net_tests -c_compile` produces zero warnings
- [ ] Tests: All unit, integration, stress, and SCOOP tests pass (100% pass rate)
- [ ] Coverage: Code coverage ≥85% by automated measurement
- [ ] DBC: 100% of public features have require/ensure/invariant
- [ ] Documentation: GitHub Pages site with quick start + API reference + architecture guide
- [ ] Examples: 5+ working examples (client, server, error handling, timeout, retry)
- [ ] Release: GitHub release v1.0.0 with binaries (if applicable) and source

**When Phase 2A Complete (simple_smtp v2.0, simple_cache v2.0):**
- [ ] simple_smtp v2.0 shipped using simple_net CLIENT_SOCKET
- [ ] simple_cache v2.0 shipped using simple_net CLIENT_SOCKET
- [ ] Tests green for both refactored libraries

---

## Next Steps (From Here)

**Immediate (Phase 1 Begins):**

1. ✅ Intent captured and approved (this document)
2. → Run `/eiffel.contracts d:\prod\simple_net` to generate class skeletons with full DBC
3. → Run `/eiffel.review d:\prod\simple_net` for adversarial contract review
4. → Run `/eiffel.tasks d:\prod\simple_net` to break contracts into implementation tasks
5. → Run `/eiffel.implement d:\prod\simple_net` to write feature bodies (contracts frozen)
6. → Run `/eiffel.verify d:\prod\simple_net` to generate comprehensive test suite
7. → Run `/eiffel.harden d:\prod\simple_net` for adversarial testing and edge cases
8. → Run `/eiffel.ship d:\prod\simple_net` for production release and GitHub Pages

**After Phase 1 (Phase 2A/2B Begin):**

1. Ship simple_net v1.0.0 and validate in production use
2. Refactor simple_smtp to use simple_net → v2.0 release
3. Refactor simple_cache to use simple_net → v2.0 release
4. Implement Phase 2B features (async, IPv6, pooling) in parallel

---

## Approval Status

**Intent Document:** ✅ **APPROVED FOR IMPLEMENTATION**

**Synthesized From:** 8-step Specification Phase (01-PARSED-REQUIREMENTS through 08-VALIDATION)

**Ready For:** Phase 1 Contracts Generation via `/eiffel.contracts d:\prod\simple_net`

---
