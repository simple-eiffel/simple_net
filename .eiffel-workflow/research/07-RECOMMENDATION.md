# RECOMMENDATION: simple_net - Final Direction

**Date:** January 28, 2026

---

## Executive Summary

**BUILD simple_net.** It is a high-confidence, high-value project that fills a critical gap in the Eiffel ecosystem.

**Rationale:** ISE's net.ecf is proven and robust, but its academic naming and heavy boilerplate keep it from mainstream adoption. simple_net wraps ISE net.ecf with an intuitive, US-developer-friendly API (matching Python/Go conventions) while adding DBC contracts, SCOOP concurrency, and serving as the foundation for simple_grpc and simple_websocket.

**Confidence Level:** **HIGH** (90%)

**Timeline:** 4-5 days Phase 1 (MVP: TCP client/server, IPv4, Windows, blocking)

**Value:** Foundation library enabling 3+ downstream libraries (simple_grpc, simple_websocket, future simple_http v2)

---

## Recommendation

**Action:** **BUILD**

Construct simple_net as a thin, intentional wrapper around ISE net.ecf that:

1. Provides intuitive naming (CLIENT_SOCKET, SERVER_SOCKET, CONNECTION) familiar to Python/Go developers
2. Simplifies API to 5-10 LOC for typical client/server patterns (vs 50-100 with ISE net)
3. Classifies errors into meaningful categories (CONNECTION_REFUSED, TIMEOUT, etc.)
4. Adds 100% Design by Contract (precondition, postcondition, invariant, MML)
5. Supports SCOOP concurrency as first-class (separate keyword, processor-per-connection)
6. Serves as the canonical socket layer for simple_* ecosystem

---

## Phase 1 (MVP) Scope

### In Phase 1 - MUST HAVE

**Core Classes:**
- `CLIENT_SOCKET` - TCP client with connect, send, receive, close
- `SERVER_SOCKET` - TCP server with listen, accept, close
- `CONNECTION` - Abstraction for active TCP connection
- `ADDRESS` - Simple (host: STRING, port: INTEGER) wrapper
- `ERROR_TYPE` - Classification enum (CONNECTION_REFUSED, TIMEOUT, READ_ERROR, etc.)

**Capabilities:**
- TCP client/server (IPv4)
- Blocking I/O (synchronous)
- Timeouts (single `set_timeout()` applies to all operations)
- Error classification (not opaque strings)
- Design by Contract (100% coverage)
- SCOOP concurrency (separate keyword support)
- Windows primary (ISE net cross-platform, but Windows focused MVP)

**Code Quality:**
- Zero compilation warnings
- ≥85% test coverage
- 100% DBC (pre+post+inv+MML)
- SCOOP verification (no race conditions)
- Void-safe (void_safety="all")

**Not in Phase 1 - Defer to Phase 2:**
- Refactor simple_smtp to use simple_net (v2.0 release after Phase 1)
- Refactor simple_cache to use simple_net (v2.0 release after Phase 1)
- UDP sockets (separate library: simple_udp)
- Non-blocking / event-driven mode
- IPv6 support
- Unix domain sockets
- Connection pooling framework
- Advanced socket options

---

## Key Architectural Decisions (Phase 1)

| Decision | Choice | Why |
|----------|--------|-----|
| **Class Structure** | Separate CLIENT_SOCKET, SERVER_SOCKET | Intent clarity, prevents misuse |
| **Address Representation** | Custom ADDRESS (host, port) | Simple, familiar, validates at creation |
| **Error Handling** | Queryable state (is_error, error_classification) | Eiffel convention, enables contracts |
| **Timeout Model** | Single universal timeout | Simplicity (can refine Phase 2) |
| **Concurrency** | SCOOP processors + separate keyword | Race-free by design |
| **I/O Mode** | Blocking only | MVP simplicity (async Phase 2) |
| **API Naming** | Short names (send, receive, connect) | Match Python/Go expectation |
| **Contracts** | Full DBC (pre+post+inv+MML) | Foundation library standard |

---

## Proposed Phase 1 Implementation Timeline

### Week 1: Design & Specification (2-3 days)
1. Run `/eiffel.contracts` to generate class skeletons with contracts
2. Refine CONTRACT_DESIGN.md with detailed DBC signatures
3. Implement ADDRESS, ERROR_TYPE classes
4. Write CLIENT_SOCKET and SERVER_SOCKET skeletons

### Week 1-2: Core Implementation (2-3 days)
1. Implement CLIENT_SOCKET: make, connect, send, receive, close, error handling
2. Implement SERVER_SOCKET: make, listen, accept, error handling
3. Implement CONNECTION: abstraction for active connections
4. Write 50+ unit tests (client, server, errors, timeouts)

### Week 2: Testing & Hardening (1-2 days)
1. Integration tests with Python clients (netcat, custom scripts)
2. Stress tests (100 connections, rapid connect/close)
3. Error path verification (refused, timeout, broken pipe)
4. Contract violation tests (intentional precondition breaks)
5. SCOOP concurrent access tests

### Week 2-3: Documentation & Shipping (1 day)
1. API documentation with examples
2. Architecture guide (how simple_net wraps ISE net)
3. SCOOP usage guide
4. Shipping: README.md, CHANGELOG.md, GitHub Pages docs

---

## Expected Deliverables (Phase 1)

### Code

```
simple_net/
├── simple_net.ecf
├── src/
│   ├── simple_net.e                 (Facade)
│   ├── client_socket.e              (TCP client)
│   ├── server_socket.e              (TCP server)
│   ├── connection.e                 (Active connection abstraction)
│   ├── address.e                    (Host:port wrapper)
│   ├── error_type.e                 (Error classification enum)
│   └── connection_base.e            (Shared base)
├── test/
│   ├── test_app.e                   (Test runner)
│   ├── test_client_socket.e         (Client tests)
│   ├── test_server_socket.e         (Server tests)
│   ├── test_error_handling.e        (Error path tests)
│   ├── test_timeout.e               (Timeout tests)
│   └── test_scoop_concurrent.e      (Concurrent access tests)
└── docs/
    ├── index.html                   (Landing page)
    ├── quick-api.html               (Quick reference)
    ├── user-guide.html              (Detailed guide with examples)
    ├── api-reference.html           (Class/feature documentation)
    └── architecture.html            (Design rationale)
```

### Metrics

- **Code:** ~2,000-2,500 LOC (client/server/connection/error handling)
- **Tests:** ~1,500-2,000 LOC (unit, integration, stress, SCOOP)
- **Documentation:** ~3,000 words (guide, examples, API docs)
- **Total:** ~5,000-6,000 LOC delivered

### Quality Gates

✅ Zero compilation warnings
✅ 100% Design by Contract
✅ ≥85% test coverage
✅ All tests pass
✅ SCOOP verification clean
✅ Cross-language testing (Python clients)

---

## Success Criteria

Phase 1 is successful if:

1. **Simplicity Achieved:** Eiffel developer can write 5-line TCP client/server without documentation
2. **Naming Clarity:** Python/Go developers immediately recognize API (connect, send, receive)
3. **Error Handling:** Errors are actionable (not opaque strings)
4. **Ecosystem Integration:** simple_grpc and simple_websocket can layer cleanly on simple_net
5. **Quality Sustained:** Zero warnings, ≥85% test coverage, 100% DBC
6. **Documentation Complete:** User can learn from guide without asking questions

---

## Dependencies & Prerequisites

### Required

- **EiffelStudio 25.02** - Latest ISE release
- **ISE base library** - Fundamental types (included)
- **ISE net.ecf** - Socket layer (included)
- **ISE testing library** - EQA framework (included)

### Optional (If Using MML Model Queries)

- **simple_mml v1.0.1+** - Mathematical model library for advanced contracts
  - Not required for Phase 1; can add later

### No External Dependencies

- ✅ Not bringing in 3rd party libraries
- ✅ Not depending on simple_http, simple_ipc, etc.
- ✅ simple_net is standalone (will be consumed by others)

---

## Risk Mitigation (Phase 1)

| Risk | Mitigation |
|------|-----------|
| **ISE net.ecf bugs** | Thin wrapper + comprehensive contracts + testing |
| **Blocking-only limitation** | Document Phase 1 scope; Phase 2 adds non-blocking |
| **Single timeout mismatch** | Document behavior; easy to refine in Phase 2 |
| **Windows-only focus** | ISE net is cross-platform; design for it; test Linux/macOS in Phase 2 |
| **SCOOP learning curve** | Extensive documentation with examples |
| **Integration with downstream** | Semantic versioning + early testing with simple_http |

---

## Phase 2 (Future) - Two Tracks

### Phase 2 Track A: Consumer Library Refactoring (2-3 days per library)

**Purpose:** Once simple_net v1.0 is shipped and proven, refactor existing ecosystem libraries to use it.

**Scope:**

1. **simple_smtp v2.0 Refactoring** (2-3 days)
   - Replace direct `NETWORK_STREAM_SOCKET` usage with `CLIENT_SOCKET` from simple_net
   - Simplify error handling (use simple_net's ERROR_TYPE classification)
   - Reduce boilerplate in connection management
   - Update tests to validate refactor
   - Release as simple_smtp v2.0

2. **simple_cache v2.0 Refactoring** (2-3 days)
   - Replace direct `NETWORK_STREAM_SOCKET` usage with `CLIENT_SOCKET` from simple_net
   - Simplify Redis connection pooling (use simple_net as base)
   - Streamline error handling
   - Update tests to validate refactor
   - Release as simple_cache v2.0

**Benefits:**
- Reduces code duplication (50+ LOC per library)
- Standardizes error handling across ecosystem
- Proves simple_net integration works before downstream adoption
- Separate release cycles (each library update is independent)

**Not In Phase 1:** Consumer refactoring deferred to after simple_net v1.0 ships. This keeps Phase 1 focused and minimizes coupling.

### Phase 2 Track B: Feature Extensions (months 2-3 after Phase 1)

**Infrastructure & Enhancement:**
- Non-blocking / event-driven API
- IPv6 support
- Unix domain sockets (Linux/macOS)
- Connection pooling framework (built-in, not external)
- Per-operation timeout granularity
- Performance profiling & optimization
- Advanced socket options exposure

**Design Principle:** Phase 1 ships clean and stable; Phase 2 enhances without breaking backward compatibility.

### Phase 2 Timeline

```
Phase 1 Complete (v1.0.0 shipped)
    ↓
    ├─ Phase 2A: Refactor simple_smtp v2.0 (2-3 days)
    ├─ Phase 2A: Refactor simple_cache v2.0 (2-3 days)
    └─ Phase 2B: Feature enhancements (async, IPv6, pooling, etc.)

Total Phase 2: 1-2 weeks for consumer updates + feature work in parallel
```

---

## Go/No-Go Decision Matrix

| Criterion | Status | Confidence |
|-----------|--------|------------|
| **Problem Valid** | ISE net.ecf boilerplate is real | HIGH |
| **Solution Sound** | simple_net approach is solid | HIGH |
| **Architecture Clear** | Design decisions are clear | HIGH |
| **Timeline Realistic** | 4-5 days Phase 1 achievable | HIGH |
| **Resource Adequate** | Claude Code can execute | HIGH |
| **Risk Manageable** | Risks identified and mitigated | HIGH |
| **Ecosystem Benefit** | Foundation for 3+ libraries | HIGH |

---

## Next Steps

**Immediate (Day 1):**
1. Run `/eiffel.spec d:\prod\simple_net` to generate specification documents
2. Run `/eiffel.intent d:\prod\simple_net` to capture refined intent
3. Run `/eiffel.contracts d:\prod\simple_net` to generate class skeletons

**Following (Week 1):**
1. Run `/eiffel.review d:\prod\simple_net` for adversarial contract review
2. Run `/eiffel.tasks d:\prod\simple_net` to break into implementation tasks
3. Run `/eiffel.implement d:\prod\simple_net` to write feature bodies

**Completion (Week 2-3):**
1. Run `/eiffel.verify d:\prod\simple_net` to generate test suite
2. Run `/eiffel.harden d:\prod\simple_net` for adversarial testing
3. Run `/eiffel.ship d:\prod\simple_net` for production release

---

## Summary

simple_net is a **HIGH-VALUE, LOW-RISK** project that:

✅ **Solves a real problem** - ISE net boilerplate keeps Eiffel socket programming out of reach for mainstream developers

✅ **Leverages existing strength** - ISE net.ecf is proven; we wrap it intentionally

✅ **Enables ecosystem growth** - Foundation for simple_grpc, simple_websocket, future libraries

✅ **Follows simple_* patterns** - DBC, SCOOP, void-safe, ecosystem-first

✅ **Achievable timeline** - 4-5 days Phase 1 delivery realistic

**Confidence: HIGH (90%)**

**Recommendation: BUILD** ✅

---
