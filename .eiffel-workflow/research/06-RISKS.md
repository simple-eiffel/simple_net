# RISKS: simple_net - Threat Assessment

**Date:** January 28, 2026

---

## Risk Register

| ID | Risk | Likelihood | Impact | Mitigation | Contingency |
|----|------|------------|--------|------------|-------------|
| **RISK-001** | ISE net.ecf has bugs we inherit | MEDIUM | HIGH | Thorough contract-based testing; DBC prevents many issues | Submit bug reports to ISE; workaround in wrapper |
| **RISK-002** | Blocking-only design insufficient for high-concurrency servers | LOW | MEDIUM | Use SCOOP processors instead of single-threaded event loop | Phase 2 adds non-blocking API |
| **RISK-003** | Timeout semantics don't match all use cases (connect vs read) | MEDIUM | MEDIUM | Well-documented single timeout behavior; Phase 2 adds granular timeouts | Retrofit per-operation timeouts |
| **RISK-004** | Cross-platform (Linux, macOS) not fully tested in Phase 1 | MEDIUM | MEDIUM | Focus Windows MVP; design for portability | Phase 2 focuses on Linux/macOS |
| **RISK-005** | Performance overhead of wrapper adds latency | LOW | LOW | Wrapper is thin (delegation); profiling in Phase 2 | Remove layer if bottleneck proven |
| **RISK-006** | SCOOP concurrency model confuses developers from threading background | MEDIUM | MEDIUM | Clear documentation with examples; gradual learning path | Provide non-SCOOP threading guide |
| **RISK-007** | Error classification misses some edge cases | MEDIUM | LOW | Comprehensive error testing; `OTHER` category for unknowns | Refine classification in Phase 2 |
| **RISK-008** | DBC contracts become maintenance burden | MEDIUM | MEDIUM | Tools support contract maintenance; automation where possible | Simplify contracts in Phase 2 if needed |
| **RISK-009** | Address handling doesn't support all formats (hostnames, IPv6, special cases) | MEDIUM | MEDIUM | Phase 1: IPv4 only (common cases); Phase 2 adds IPv6 | Fall back to ISE INET_ADDRESS if needed |
| **RISK-010** | Integration with simple_http/simple_grpc/simple_websocket breaks existing code | HIGH | HIGH | Clear versioning; semantic versioning (1.0, 1.1, 2.0); extensive compatibility testing | Provide migration guide |

---

## Detailed Risk Analysis

### RISK-001: ISE net.ecf Has Bugs We Inherit

**Description:** ISE's net.ecf is 20+ years old and has accumulated quirks. If ISE net.ecf has a bug, simple_net inherits it.

**Likelihood:** MEDIUM (ISE net is stable, but edge cases exist)

**Impact:** HIGH - Socket bugs can cause production failures (hangs, crashes, silent data loss)

**Indicators:**
- Connections hang on non-responsive servers
- Timeouts don't work as advertised
- Memory leaks in long-running servers
- TCP state machine violations (FIN_WAIT issues)

**Mitigation:**
1. Thorough contract-based testing (contracts catch many edge cases)
2. Use `separate` keyword (SCOOP prevents data races)
3. Timeout all operations (prevent indefinite hangs)
4. Monitor ISE EiffelStudio release notes (bugs get patched)
5. Keep updated to latest EiffelStudio (25.02 is current)

**Contingency:**
- File bug reports with ISE with minimal reproduction case
- Implement workaround in simple_net wrapper (e.g., external socket call if ISE broken)
- Fall back to raw ISE net.ecf if wrapper fails (not ideal, but survivable)

---

### RISK-002: Blocking-Only Design Insufficient for High-Concurrency Servers

**Description:** Some servers need 10,000+ concurrent connections. Blocking I/O + one processor per connection might not scale.

**Likelihood:** LOW (Eiffel's SCOOP can handle 100s easily; 10K rare in Eiffel)

**Impact:** MEDIUM - Server has to choose between simple_net blocking and complex event-driven code elsewhere

**Indicators:**
- Server accepts 1000+ connections simultaneously
- Single-threaded performance critical
- Event loop optimization essential

**Mitigation:**
1. Document threading model clearly (SCOOP processors per connection)
2. Provide performance guidance: "For <100 connections, simple_net blocking is fine"
3. Design Phase 1 to layer non-blocking cleanly (Phase 2 feature)
4. Use ISE net's `set_non_blocking()` internally if optimization needed

**Contingency:**
- Phase 2 adds non-blocking API without breaking blocking code
- User can use raw ISE net if extreme performance needed (not recommended, but possible)

---

### RISK-003: Timeout Semantics Don't Match All Use Cases

**Description:** Single `set_timeout()` applies to ALL operations. Some cases need different timeouts for connect vs read.

**Likelihood:** MEDIUM (advanced use cases, but real)

**Impact:** MEDIUM - May need workarounds or Phase 2 refinement

**Examples:**
- Connect timeout: 3 seconds (can't reach server, fail fast)
- Read timeout: 30 seconds (waiting for slow server response)
- Write timeout: 1 second (local buffer, should be fast)

**Mitigation:**
1. Document: "Single timeout applies to all phases; tune for your use case"
2. MVP targets 5-10 second timeout (works for most scenarios)
3. Precondition documents behavior: `set_timeout` ensures `all subsequent operations use this timeout`
4. Phase 2 adds granular: `set_connect_timeout()`, `set_read_timeout()`, etc.

**Contingency:**
- User can `set_timeout()` before `connect()`, then `set_timeout()` before `send()` (verbose, but works)
- Phase 2 refinement is backward compatible

---

### RISK-004: Cross-Platform Testing Limited in Phase 1

**Description:** Phase 1 focuses on Windows. Linux and macOS sockets may have subtle differences.

**Likelihood:** MEDIUM (ISE net is cross-platform, but edge cases exist)

**Impact:** MEDIUM - Phase 2 needs Linux/macOS hardening

**Known Differences:**
- Named pipes (Windows) vs Unix sockets (Linux/macOS)
- TCP_NODELAY behavior varies
- EOF handling differs (SO_LINGER)
- Address family handling (IPv4 vs IPv6 defaults)

**Mitigation:**
1. Document: "Phase 1 Windows MVP; Linux/macOS tested in Phase 2"
2. Use `separate` keyword (SCOOP verification is platform-independent)
3. ISE net.ecf already handles cross-platform (leverage ISE's work)
4. Keep implementation close to ISE net (minimize custom code that differs)

**Contingency:**
- Phase 2 includes Linux/macOS CI testing
- Port to Linux/macOS if blockers discovered

---

### RISK-005: Wrapper Performance Overhead

**Description:** simple_net adds another layer. Each call goes through wrapper, then to ISE net.

**Likelihood:** LOW (wrapper is thin delegation)

**Impact:** LOW - Latency <1% in typical scenarios

**Potential Issues:**
- Extra function call overhead (negligible)
- Extra validation (contracts, preconditions) add CPU (acceptable)
- String handling for error messages (minimal)

**Mitigation:**
1. Thin wrapper design (no extra copying, direct delegation)
2. Profiling in Phase 2 (measure actual overhead)
3. Optimize hot paths (send/receive) if needed
4. Use C externals if Eiffel overhead significant (rare)

**Contingency:**
- Profile and optimize Phase 2
- If unbearable, user can call ISE net directly (not supported, but possible)

---

### RISK-006: SCOOP Concurrency Model Confuses Threading-Background Developers

**Description:** Developers from Java/Python/C++ expect thread pooling, mutexes, callbacks. SCOOP's `separate` keyword and processor model is different.

**Likelihood:** MEDIUM (learning curve for non-Eiffel devs)

**Impact:** MEDIUM - Slower adoption, more support questions

**Symptoms:**
- "How do I synchronize multiple threads?"
- "Where's the thread pool?"
- "How do I wait for completion?"
- "Why can't I call methods on separate objects?"

**Mitigation:**
1. Extensive documentation with SCOOP examples
2. Provide tutorial: "SCOOP for threading-experienced developers"
3. Compare to Go goroutines (similar mental model)
4. Example code for common patterns (accept loop, worker pool)
5. Simplicity helps adoption (simple_net is easy; SCOOP can be learned separately)

**Contingency:**
- Provide threading library (future) that wraps SCOOP for Java/Python developers
- Or provide non-SCOOP threading guide (sequential blocks possible)

---

### RISK-007: Error Classification Misses Edge Cases

**Description:** We classify errors into ~10 categories. Socket errors can have 50+ distinct causes. Some will map to `OTHER` or wrong category.

**Likelihood:** MEDIUM (networking is complex)

**Impact:** LOW - Misclassification causes wrong error handling, but fallback exists

**Examples:**
- EMFILE (too many open files) - isn't connection error, but might be grouped as CONNECTION_FAILED
- ECONNRESET vs EPIPE - both "connection closed" but slightly different timing
- ETIMEDOUT vs EHOSTUNREACH - both "unreachable" but different causes

**Mitigation:**
1. Define clear error categories: CONNECTION_*, I/O_*, NETWORK_*, OS_*
2. Include `error_code: INTEGER` (raw OS error number) for debugging
3. Comprehensive testing of error paths
4. `OTHER` category catches unknown errors (still queryable, not lost)

**Contingency:**
- Phase 2 refines error classification based on real-world experience
- User can inspect raw error code if classification wrong

---

### RISK-008: DBC Contracts Become Maintenance Burden

**Description:** Full DBC (pre+post+inv+MML) requires careful thought. If contracts are wrong, they're worse than no contracts (misleading).

**Likelihood:** MEDIUM (contracts are hard)

**Impact:** MEDIUM - Wrong contracts = false confidence, harder debugging

**Issues:**
- Invariants too strict (prevent valid state transitions)
- Postconditions incomplete (miss important state changes)
- MML model queries expensive (O(n) per operation)
- Contracts drift from implementation (not updated when code changes)

**Mitigation:**
1. Contract review phase (separate from implementation)
2. Test suite validates contracts (assertion checking on)
3. Use contracts to guide implementation (not afterthought)
4. MML optimizations: cache models, avoid redundant queries
5. Documentation of contract design

**Contingency:**
- Simplify contracts in Phase 2 if overhead too high
- Tools can help auto-verify contracts (Eiffel's EVE tool)

---

### RISK-009: Address Handling Doesn't Support All Cases

**Description:** We use simple ADDRESS (host: STRING, port: INTEGER). Doesn't support all cases:
- IPv6 addresses (::1, 2001:db8::1)
- IPv6 link-local scopes (%eth0)
- Special addresses (0.0.0.0, broadcast)
- DNS SRV records
- Unix domain sockets (/tmp/socket.sock)

**Likelihood:** MEDIUM (common use cases covered, advanced cases missing)

**Impact:** MEDIUM - Phase 2 must extend

**Mitigation:**
1. MVP: Support IPv4 + hostname resolution
2. Document limitations: "Phase 1 is IPv4. Phase 2 adds IPv6, Unix sockets."
3. Design ADDRESS class to extend cleanly (inheritance, variants)
4. Internal: Use ISE INET_ADDRESS when needed (not exposed)

**Contingency:**
- Phase 2 extends ADDRESS for IPv6
- User can use ISE net directly for advanced addressing (not supported)

---

### RISK-010: Integration with Other simple_* Libraries Breaks Existing Code

**Description:** This is the HIGHEST RISK. Once simple_http, simple_grpc depend on simple_net, changes to simple_net break downstream.

**Likelihood:** HIGH (versioning challenges, breaking changes)

**Impact:** HIGH - Cascade failures in dependent libraries

**Scenarios:**
- simple_net 1.0 released, simple_http depends on it
- Bug fix changes CONNECTION interface → simple_http breaks
- Phase 2 adds features → backward compatibility must hold
- Library users upgrade simple_http → expect simple_net update included

**Mitigation:**
1. **Semantic versioning:** simple_net 1.0.0, 1.1.0 (features), 2.0.0 (breaking)
2. **Stable API:** First release is stable; changes require major version
3. **Extensive testing:** Integration tests with simple_http, simple_grpc early
4. **Early adoption:** Get simple_http using simple_net in Phase 1 (flush out issues)
5. **Deprecation path:** Features removed only after deprecation period

**Contingency:**
- Maintain simple_net 1.0 branch if Phase 2 needs breaking change
- Provide migration guide for dependent libraries
- Coordinate releases (all simple_* update together for major versions)

---

## Risk Mitigation Summary

**Critical Risks (Must Address Phase 1):**
- RISK-010: Integration breaking - Mitigated via semantic versioning + early testing with simple_http

**Important Risks (Monitor Phase 1, Address Phase 2):**
- RISK-001: ISE net bugs - Mitigated via thorough testing
- RISK-003: Timeout semantics - Mitigated via documentation; Phase 2 refinement
- RISK-004: Cross-platform - Mitigated via ISE leverage; Phase 2 hardening
- RISK-006: SCOOP learning curve - Mitigated via documentation

**Lower-Priority Risks (Phase 2 or if manifests):**
- RISK-002: Concurrency scaling - Unlikely; Phase 2 adds non-blocking
- RISK-005: Performance overhead - Measured in Phase 2 if needed
- RISK-007: Error classification gaps - Refined in Phase 2
- RISK-008: Contract burden - Simplified in Phase 2 if heavy
- RISK-009: Address limitations - Extended in Phase 2

---
