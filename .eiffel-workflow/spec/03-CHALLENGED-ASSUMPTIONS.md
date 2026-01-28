# CHALLENGED ASSUMPTIONS: simple_net - Architecture Validation

**Date:** January 28, 2026
**Specification Phase:** Step 3 - Critical Review

---

## Executive Summary

This document challenges the 9 architectural decisions (D-001 through D-009) from the research phase. For each decision, we ask "What if we're wrong?" and outline verification steps to validate assumptions before committing to implementation.

---

## Challenge 1: Separate CLIENT_SOCKET and SERVER_SOCKET (D-001)

**Decision:** Use separate classes instead of unified SOCKET class.

**Assumptions Being Challenged:**
1. "Developers prefer intent-explicit code"
2. "Prevents accidental misuse (calling connect on server)"
3. "Code duplication is acceptable trade-off"

### Challenge A: Intent Clarity May Not Matter

**Concern:** Both Python and Go use same socket primitive for client and server; developers learn it easily. Separate classes might add complexity without benefit.

**Counter-argument example:**
```python
# Python (one socket type)
client = socket.socket()
server = socket.socket()
```

**Verification Steps:**
1. Survey 5-10 Eiffel developers: "Would separate CLIENT_SOCKET/SERVER_SOCKET help you?"
2. Measure API surface: How many methods differ between CLIENT_SOCKET and SERVER_SOCKET?
3. If overlap >80%, unification might be better

**Decision Impact if Wrong:**
- If unified SOCKET preferred: Redesign to single class with mode selector
- Mitigation: Implement as separate classes; can merge in Phase 2 if feedback demands

---

### Challenge B: Compile-Time vs Runtime Prevention

**Concern:** Calling `connect()` on SERVER_SOCKET is prevented at compile-time with separate classes. But runtime checks might be simpler and more consistent with query-based error model.

**Counter-evidence:**
- ISE net uses unified SOCKET class - developers manage calling wrong method anyway
- DBC preconditions catch this at contract-check time (nearly as early as compile-time)

**Verification Steps:**
1. Test: Does precondition `connect requires not is_listening` catch misuse effectively?
2. Compare error messages: "Compile error: no method connect on SERVER_SOCKET" vs "Contract violation: cannot connect while listening"
3. Poll users: Which error message more helpful?

**Decision Impact if Wrong:**
- If runtime checks insufficient: Stick with separate classes (current decision)
- If adequate: Could consolidate implementation (still keep separate facade classes)

---

### Challenge C: Code Duplication Burden

**Concern:** Maintaining two classes increases code maintenance. If >60% code duplication, unified might be better.

**Verification Steps:**
1. Analyze ISE net source: How much code duplicates between socket implementations?
2. Measure: Do inheritance + composition + delegation reduce duplication to <20%?
3. Test team capacity: Can team maintain separate code effectively?

**Decision Impact if Wrong:**
- If duplication >40%: Consider common base class + interface
- Mitigation: Use inheritance (CLIENT_SOCKET, SERVER_SOCKET extend CONNECTION_BASE)

---

**Recommended Action:** Proceed with separate classes (D-001 stands). Verification: Create sample code in both designs; show to 3 Eiffel developers for preference feedback.

---

## Challenge 2: Custom ADDRESS Class (D-002)

**Decision:** Create custom ADDRESS (host: STRING, port: INTEGER) instead of wrapping ISE INET_ADDRESS.

**Assumptions Being Challenged:**
1. "Simple tuple API better than INET_ADDRESS factory"
2. "Type safety (port validation) valuable"
3. "Creating another class worth the effort"

### Challenge A: Validation Overhead

**Concern:** Checking `port >= 1 and port <= 65535` every time ADDRESS is created adds latency. If ports rarely invalid, overhead unjustified.

**Real-world data:**
- How often do developers pass invalid ports? (probably <1% of cases)
- Is that 1% worth catching at creation time?

**Verification Steps:**
1. Study real PORT values in codebase: Are they hardcoded constants (validation once) or dynamic (validation multiple times)?
2. Benchmark: TIME(ADDRESS.make_for_host_port("localhost", 8080)) with and without validation
3. If <1 microsecond overhead: Validation justified even for occasional use

**Decision Impact if Wrong:**
- If overhead significant and invalid ports rare: Remove validation, let ISE net error handling catch it
- Mitigation: Keep ADDRESS class; make validation optional via separate method

---

### Challenge B: ISE INET_ADDRESS Might Suffice

**Concern:** ISE already has INET_ADDRESS with proper factory pattern. Creating ADDRESS duplicates work.

**Counter-evidence:**
- INET_ADDRESS requires factory pattern (verbose: `create_from_host_and_port(...)`)
- simple_net goal is reduce boilerplate
- But: Maybe we're over-engineering for a minor simplification

**Verification Steps:**
1. Compare LOC: Writing ADDRESS vs using INET_ADDRESS directly
2. Read ISE net source: How complex is INET_ADDRESS factory pattern?
3. Test: Can we hide INET_ADDRESS complexity without creating ADDRESS?

**Counter-argument:** ISE INET_ADDRESS is ACADEMIC NAMING. ADDRESS is semantic reframing. Worth it.

**Decision Impact if Wrong:**
- If INET_ADDRESS simpler than expected: Skip ADDRESS; use ISE directly
- Mitigation: ADDRESS provides clean API layer; switching later is easy (internal only)

---

### Challenge C: Immutability Assumption

**Concern:** Requiring ADDRESS to be immutable might block some use cases (e.g., dynamic port assignment, retry with fallback addresses).

**Real-world case:**
```eiffel
-- Scenario: Retry with fallback addresses
address := create ADDRESS.make_for_host_port("primary.example.com", 8080)
if not client.is_connected then
    -- Can't change address; must create new ADDRESS
    address := create ADDRESS.make_for_host_port("backup.example.com", 8080)
    client := create CLIENT_SOCKET.make_for_address(address)
    ...
end
```

**Verification Steps:**
1. Survey: How many use cases require mutable addresses?
2. If <5%: Immutability is good (prevents bugs)
3. If >20%: Provide `set_host` / `set_port` mutators

**Decision Impact if Wrong:**
- If mutability needed: Relax immutability (add setters)
- Mitigation: Immutable is simpler; adds getters if dynamic changes needed

---

**Recommended Action:** Proceed with ADDRESS class (D-002 stands). Verification: Implement ADDRESS, test with real use cases (simple_smtp client code, simple_http server).

---

## Challenge 3: Queryable Error State vs Exceptions (D-003)

**Decision:** Use queryable state (is_error, error_classification) instead of exceptions.

**Assumptions Being Challenged:**
1. "Eiffel developers prefer contract-based error handling"
2. "Exceptions require explicit handling (more verbose)"
3. "Query pattern matches ISE net.ecf already"

### Challenge A: Modern Developers Expect Exceptions

**Concern:** Python, Java, Go developers (increasingly learning Eiffel) expect exception-based error handling. Forcing query pattern might confuse them.

**Counter-evidence from requirements:**
- All simple_* libraries (simple_http, simple_cache) use query pattern
- ISE net.ecf itself uses query pattern (was_error, socket_error)
- Eiffel ecosystem standardized on this

**But:** Might we be preserving outdated Eiffel convention?

**Verification Steps:**
1. Survey target users (embedded IoT dev, data scientist): "Exceptions or queries?"
2. Show examples:
   - Query-based: `if not client.is_error then ...`
   - Exception-based: `try { client.connect() } catch (ConnectionRefused) { ... }`
3. Measure readability/preference

**Decision Impact if Wrong:**
- If exceptions strongly preferred: Add exception mode in Phase 2 (backward compatible)
- Mitigation: Query-based now; can add `connect_with_exception()` later if needed

---

### Challenge B: Silent Failures Risk

**Concern:** Query-based error handling makes it EASY to ignore errors:
```eiffel
client.connect()
client.send("data")  -- What if connect failed?
```

vs

```eiffel
try {
    client.connect()
    client.send("data")
}
catch (ConnectionRefused) { ... }
```

**Real risk:** Developers forget to check `is_error` and data never sends.

**Verification Steps:**
1. Code review: Can we add linter warnings for unchecked errors?
2. Test: How often does forgetting `is_error` check cause bugs in practice?
3. Documentation: Can we make best practices so clear that developers check?

**Mitigation:**
- DBC precondition on `send()` requires `is_connected` (prevents sending on disconnected socket)
- Contracts document: "Always check is_error after operations"
- Test suite demonstrates pattern

**Decision Impact if Wrong:**
- If silent failures become problem: Add exceptions for critical operations
- Mitigation: Preconditions help (connect required before send); query pattern still primary

---

### Challenge C: Error Classification Too Coarse

**Concern:** Mapping OS errors (ERRNO values, Windows WSAERROR) to 11 enum values loses information.

**Real scenario:**
```
EMFILE (too many open files) → OTHER + error_code
User doesn't understand "OTHER" without googling error code
```

**Verification Steps:**
1. Enumerate common socket errors: How many distinct OS errors?
2. Classify: Can we group into <15 categories covering 95% of cases?
3. Fallback plan: Does `OTHER` + `error_code` + `last_error_string` provide sufficient debugging?

**Counter-argument:** We can't classify all errors. `OTHER` is acceptable fallback. Better than opaque string everywhere.

**Decision Impact if Wrong:**
- If <90% errors classified: Add more categories
- Mitigation: Phase 2 refines classification based on real-world data

---

**Recommended Action:** Proceed with queryable state (D-003 stands). Verification: Implement error queries; test with 3-5 real use cases (client connection failures, server accept, read/write errors); ensure preconditions catch misuse.

---

## Challenge 4: Single Universal Timeout (D-004)

**Decision:** One `set_timeout(seconds)` applies to all operations (connect, accept, send, receive).

**Assumptions Being Challenged:**
1. "Users need same timeout for all phases"
2. "Separate timeouts overcomplicate MVP"
3. "Advanced users can call set_timeout() multiple times"

### Challenge A: Connect Timeout Often Differs

**Real use case:**
- Connect timeout: 3 seconds (can't reach server, fail fast)
- Read timeout: 30 seconds (waiting for slow server response)
- Write timeout: 1 second (local buffer, should be fast)

**Concern:** Single timeout doesn't fit.

**Counter-evidence:**
- Most simple_net users won't need fine-grained control
- Typical value: 5-10 seconds works for all operations
- Advanced users (rare) can call `set_timeout()` before each operation

**Verification Steps:**
1. Survey use cases: How many need different timeouts per operation?
2. If <10%: Single timeout sufficient for MVP
3. If >20%: Phase 2 must add granular timeouts

**Decision Impact if Wrong:**
- If advanced users frustrated: Phase 2 adds `set_connect_timeout()`, `set_read_timeout()` without breaking existing code
- Mitigation: Single timeout now; extensible for Phase 2

---

### Challenge B: Platform Differences

**Concern:** Windows, Linux, macOS sockets interpret timeout differently. Single timeout might not translate well across platforms.

**Verification Steps:**
1. Test on three platforms: Same timeout value, measure actual timeout duration
2. If variance >10%: Document platform differences in API
3. If variance <5%: No problem

**Decision Impact if Wrong:**
- If platform differences significant: Add platform-specific overrides in Phase 2
- Mitigation: Test on Windows first (Phase 1); Phase 2 hardens Linux/macOS

---

### Challenge C: Timeout = 0 or None Edge Cases

**Concern:** What does `set_timeout(0)` mean? Immediate failure? Non-blocking? Blocking indefinitely?

**Verification Steps:**
1. Define semantics: timeout = 0 → blocking indefinitely (standard interpretation)
2. Test: Does ISE net handle timeout = 0 as expected?
3. Document: Clarify in API that timeout = 0 means no timeout

**Decision Impact if Wrong:**
- If semantics unclear: Add explicit `TIMEOUT_INFINITE` constant
- Mitigation: Precondition: `set_timeout(seconds >= 0)`

---

**Recommended Action:** Proceed with single timeout (D-004 stands). Verification: Test on Windows with typical values (5, 10, 30 seconds); document behavior clearly; plan Phase 2 granular overrides.

---

## Challenge 5: Full Send Guarantee, Partial Receive (D-005)

**Decision:** `send()` guarantees all bytes sent (or error); `receive()` returns up to max_bytes.

**Assumptions Being Challenged:**
1. "Users expect 'send all or fail' semantics"
2. "Partial sends are implementation detail (user shouldn't see)"
3. "Receive partial is transparent enough"

### Challenge A: Partial Sends Might Be Necessary

**Concern:** Some applications (real-time streaming) need to know exactly how many bytes sent, and might send partially intentionally.

**Real scenario:**
```
Streaming video: Send up to 1MB chunks
If network congested: Send 900KB, resume later
User needs: bytes_sent_count
```

**Verification Steps:**
1. Survey: How many use cases need partial send info?
2. If <5%: Full guarantee sufficient for MVP
3. If >10%: Expose `bytes_sent` return value

**Decision Impact if Wrong:**
- If partial sends needed: Phase 2 adds `send_with_count()` returning bytes_sent
- Mitigation: Full guarantee simpler for MVP; extensible for Phase 2

---

### Challenge B: Partial Receive Semantics Unclear

**Concern:** Is `receive(1024)` guaranteed to return 1024 bytes? Or fewer? Documentation must be crystal clear.

**Risk:** User assumes 1024 bytes; gets 512; data corruption in frame-based protocols.

**Verification Steps:**
1. Document: "`receive(max_bytes)` returns up to max_bytes; may be fewer on EOF or incomplete frame"
2. Provide helper: `receive_until(n_bytes)` that loops until n_bytes available
3. Test: Frame-based protocol (e.g., WebSocket) works correctly with partial receives

**Decision Impact if Wrong:**
- If semantics still unclear: Add explicit `receive_exact(n_bytes)` method
- Mitigation: Clear documentation + examples solve most confusion

---

### Challenge C: Partial Writes Complexity

**Concern:** Implementing "full send guarantee" internally requires retry loop. What if retry loop has bugs?

**Internal logic:**
```eiffel
send(data: ARRAY OF BYTES) do
    offset := 0
    from until offset = data.count or is_error loop
        n := send_partial(data, offset)
        if n <= 0 then
            set_error(WRITE_ERROR)
        else
            offset := offset + n
        end
    end
end
```

**Risk:** Off-by-one errors, infinite loops, resource leaks.

**Verification Steps:**
1. Test: Send 10MB of data in 100-byte chunks; verify all arrives
2. Stress: Send while network drops packets; verify error handling
3. Code review: Retry loop correctness

**Decision Impact if Wrong:**
- If retry loop unreliable: Expose `bytes_sent` and let user manage loop
- Mitigation: Full guarantee simpler; test thoroughly before release

---

**Recommended Action:** Proceed with full send, partial receive (D-005 stands). Verification: Implement both directions; test with real data (JSON, binary); verify with frame-based protocol (simulate WebSocket framing).

---

## Challenge 6: Full DBC (Pre+Post+Inv+MML) (D-006)

**Decision:** 100% Design by Contract on all public features.

**Assumptions Being Challenged:**
1. "Contracts are executable specification"
2. "MML model queries don't add prohibitive overhead"
3. "Maintenance burden acceptable"

### Challenge A: Contracts Add Complexity Without Measurable Benefit

**Concern:** Contracts are harder to understand than simple code. Do they actually prevent bugs?

**Real question:**
- Without DBC: How many bugs get through?
- With DBC: Same number, fewer, or disabled contracts anyway?

**Verification Steps:**
1. Implement core features with minimal DBC (preconditions only)
2. Test: Can we catch same bugs with unit tests instead of invariants?
3. Measure: % bugs caught by contracts vs % caught by tests
4. If >70% bugs caught by tests: Contracts might be over-engineering

**Decision Impact if Wrong:**
- If tests sufficient: Reduce to preconditions only (Phase 2)
- Mitigation: Full DBC now; can simplify if overhead proven

---

### Challenge B: MML Model Queries Too Expensive

**Concern:** Postconditions like `ensure connections_model = old connections_model` require copying/comparing sets. That's O(n) per operation.

**Performance risk:**
- 1000 active connections, each postcondition queries model
- O(1000) operations per check × 1000 connections = O(n²) total
- Negligible? Or unacceptable?

**Verification Steps:**
1. Benchmark: TIME(active_connections_model query) with 100, 1000, 10000 connections
2. If <1ms per check: No problem
3. If >10ms: Optimize or remove

**Decision Impact if Wrong:**
- If expensive: Use simpler postconditions (without MML model queries)
- Mitigation: MML optional; can disable in performance-critical builds

---

### Challenge C: Contracts Drift from Implementation

**Concern:** Contracts written once; code changes; contracts become stale. Stale contracts are worse than no contracts (false confidence).

**Risk:**
- Developer changes `send()` behavior
- Forgets to update postcondition
- Contract always passes (because it was already wrong)
- User relies on outdated contract

**Verification Steps:**
1. Code review process: Must review contracts alongside implementation
2. Test: Can we auto-check contract/code consistency?
3. CI/CD: Contract validation runs on every commit

**Decision Impact if Wrong:**
- If contracts become stale: Simpler contracts (just preconditions)
- Mitigation: Strict review discipline + tooling

---

**Recommended Action:** Proceed with full DBC (D-006 stands). Verification: Write contracts first (TDD style); validate with unit tests; measure MML overhead; plan Phase 2 optimization if needed.

---

## Challenge 7: SCOOP Concurrency (D-007)

**Decision:** Separate processor per connection via `separate` keyword.

**Assumptions Being Challenged:**
1. "SCOOP is right concurrency model for simple_net"
2. "separate keyword natural for Eiffel developers"
3. "Compiler verification prevents race conditions"

### Challenge A: SCOOP Complexity Blocks Adoption

**Concern:** Most developers (especially switching from Python/Go) don't understand SCOOP. Forcing it might hurt adoption.

**Learning curve:**
- Python/Java: Just use thread pools (mature, understood)
- SCOOP: Learn separate keyword, processor model, mutual exclusion rules

**Verification Steps:**
1. Survey: "Do you understand SCOOP?" among target users
2. If <30% understand: Consider thread pool abstraction in Phase 2
3. Alternative: Make SCOOP optional; provide simple threading layer

**Decision Impact if Wrong:**
- If SCOOP adoption poor: Phase 2 adds thread pool wrapper
- Mitigation: Clear documentation + examples + tutorials solve most learning curve

---

### Challenge B: separate Keyword Isn't Always Available

**Concern:** Some contexts don't support `separate` (e.g., non-SCOOP code, testing).

**Real scenario:**
```eiffel
-- Single-threaded test can't use separate
connection := server.accept()
connection.send("data")  -- Compile error: connection is separate?
```

**Verification Steps:**
1. Test: Can CONNECTION work in both separate and non-separate contexts?
2. If needed: Provide wrapper for non-separate use

**Decision Impact if Wrong:**
- If separate blocks testing: Make separate optional in tests
- Mitigation: CONNECTION signature clear; documentation shows usage

---

### Challenge C: Compiler Verification Doesn't Guarantee Safety

**Concern:** Eiffel compiler can verify SCOOP safety, but:
1. Only if code is ACTUALLY SCOOP-safe
2. If developer doesn't use `separate`, compiler allows unsafeaccess
3. Developer might not enable SCOOP verification

**Risk:** "Use separate keyword" recommendation easily ignored.

**Verification Steps:**
1. Test: Enforce strict SCOOP checking in compiler flags
2. Document: "Must compile with -scoop flag for safety"
3. CI/CD: Fail builds if SCOOP checks not enabled

**Decision Impact if Wrong:**
- If SCOOP safety can't be enforced: Use coarse-grained locks instead
- Mitigation: Clear documentation + build enforcements

---

**Recommended Action:** Proceed with SCOOP (D-007 stands). Verification: Write example multi-client server using `separate`; test with SCOOP verification enabled; document best practices.

---

## Challenge 8: Blocking Mode Only (D-008)

**Decision:** MVP supports blocking I/O only; non-blocking Phase 2.

**Assumptions Being Challenged:**
1. "Blocking sufficient for gRPC/WebSocket"
2. "Phase 2 can add non-blocking without breaking blocking code"
3. "Non-blocking adds complexity not worth MVP"

### Challenge A: gRPC Actually Needs Non-Blocking

**Concern:** gRPC (multiplexed streaming) might require non-blocking I/O to avoid head-of-line blocking.

**Real scenario:**
```
Client sends 100 requests over single connection
Server processes in batches
If blocking: Response to request 1 blocks response to request 99
If non-blocking: Can interleave responses
```

**Verification Steps:**
1. Study gRPC design: Does HTTP/2 multiplexing need non-blocking?
2. If yes: Phase 1 might need non-blocking after all
3. If no: Blocking sufficient; threading handles multiplexing

**Counter-argument:** gRPC can use multiple threads (SCOOP processors) for multiplexing. Blocking mode + threading = effective multiplexing.

**Decision Impact if Wrong:**
- If non-blocking needed: Phase 1 adds `set_non_blocking()` mode
- Mitigation: Design so non-blocking can be added (Phase 2) without breaking blocking

---

### Challenge B: Blocking Causes Performance Hangs

**Concern:** Real-time systems can't afford thread blocking (no cores available). Blocking mode might be unsuitable for embedded systems (original target).

**Real scenario:**
- Embedded device: 2 cores
- Thread 1: User code (must not block)
- Thread 2: Network I/O (blocks on receive, consuming core)
- Result: Deadlock or hang

**Verification Steps:**
1. Target user survey: "Is blocking I/O acceptable for your embedded system?"
2. If <50%: Must support non-blocking in Phase 1
3. If >70%: Blocking sufficient

**Counter-argument:** Most embedded systems have 4+ cores; blocking one core is acceptable.

**Decision Impact if Wrong:**
- If blocking inadequate: Phase 1 adds async variant
- Mitigation: Phase 2 adds non-blocking; design allows it now

---

### Challenge C: Phase 2 Upgrade Path Breaks Code

**Concern:** Adding non-blocking in Phase 2 might require breaking API changes (e.g., new method `send_async()` alongside `send()`).

**Risk:**
- Existing code uses `send()` (blocking)
- Phase 2 `send_async()` (non-blocking)
- Library users must choose; mixing = confusing

**Verification Steps:**
1. Design: Can `send()` remain blocking while `send_async()` available?
2. If yes: Backward compatible
3. If no: Need breaking change (requires major version bump)

**Decision Impact if Wrong:**
- If Phase 2 requires breaking change: Accept it (semantic versioning 2.0)
- Mitigation: Plan Phase 2 API early; announce plan before Phase 1 release

---

**Recommended Action:** Proceed with blocking only (D-008 stands). Verification: Test simple_grpc layering with blocking I/O; verify embedded device use case; plan Phase 2 async API (document before release).

---

## Challenge 9: Short Names (D-009)

**Decision:** Use short method names (send, receive, connect, listen, accept) instead of descriptive (send_data, receive_data, etc.).

**Assumptions Being Challenged:**
1. "Short names match Python/Go conventions"
2. "Developers immediately understand short names"
3. "Explicitness via contracts compensates for short names"

### Challenge A: Ambiguity

**Concern:** `send` could mean:
- Send data
- Send signal
- Send command
- Send request

**Real code:**
```eiffel
connection.send(data)  -- What is being sent?
client.send(command)   -- What is being sent?
```

**Verification Steps:**
1. Code review: Can context always disambiguate?
2. If yes: Short names fine
3. If no: Use descriptive names (send_data, send_message)

**Counter-argument:** Postcondition clarifies: `send(data) ensures bytes_sent = old bytes_sent + data.count`. Context + documentation = clarity.

**Decision Impact if Wrong:**
- If ambiguity persists: Rename to descriptive (send_data, receive_data)
- Mitigation: Short names fine for simple_net (socket domain is clear)

---

### Challenge B: Agent Syntax Conflict

**Concern:** `agent socket.send` might conflict with Eiffel agent syntax expectations.

**Verification Steps:**
1. Test: `agent socket.send` compiles without warning
2. If conflicts: Rename to longer name
3. If no conflict: Short names work

**Counter-argument:** No actual conflict; `agent socket.send` is valid Eiffel.

**Decision Impact if Wrong:**
- If conflict: Rename
- Mitigation: Test thoroughly before release

---

### Challenge C: Discoverability

**Concern:** IDE autocomplete might have trouble with very short names. User types `socket.s*` - both `send` and `set_timeout` appear.

**Real workflow:**
```
User: types "connection.se" in IDE
IDE suggests: [send, set_error, set_timeout, ...]
Confusion: Which one do I want?
```

**Verification Steps:**
1. Test in EiffelStudio IDE: Type "connection.se", check suggestions
2. If many collisions: Rename for clarity
3. If few collisions: Short names fine

**Counter-argument:** IDE filtering works; typing one more character disambiguates.

**Decision Impact if Wrong:**
- If discoverability problem: Rename to longer names
- Mitigation: Test with real developers using IDE

---

**Recommended Action:** Proceed with short names (D-009 stands). Verification: Test agent syntax, IDE autocomplete, code clarity; sample code review with 3 Eiffel developers; document API clearly.

---

## Assumption Dependency Graph

```
D-001 (Separate Client/Server)
    ├─ Assumes: Intent clarity matters
    ├─ Assumes: Separate classes prevent misuse
    └─ Blocks: None

D-002 (Custom ADDRESS)
    ├─ Assumes: Validation valuable
    ├─ Assumes: Simple (host, port) better than INET_ADDRESS
    └─ Blocks: None

D-003 (Queryable Error State)
    ├─ Assumes: Eiffel developers prefer queries
    ├─ Assumes: Exceptions silent-fail risk
    └─ Blocks: D-006 (contracts can verify error states)

D-004 (Single Timeout)
    ├─ Assumes: Users need one timeout
    ├─ Assumes: Same value for connect/accept/send/receive
    └─ Blocks: None (Phase 2 adds granular)

D-005 (Full Send, Partial Receive)
    ├─ Assumes: Users expect "all or nothing" for send
    ├─ Assumes: Partial receive transparent enough
    └─ Blocks: Implementation complexity

D-006 (Full DBC)
    ├─ Assumes: Contracts valuable documentation
    ├─ Assumes: MML overhead acceptable
    ├─ Blocks: D-003 (error state verification)
    └─ Depends: D-003 (uses error classification in contracts)

D-007 (SCOOP Concurrency)
    ├─ Assumes: SCOOP is right model
    ├─ Assumes: Separate keyword natural
    └─ Blocks: Architecture (assume separate on CONNECTION)

D-008 (Blocking Only)
    ├─ Assumes: Blocking sufficient
    ├─ Assumes: Phase 2 can add non-blocking
    └─ Blocks: None (extensible)

D-009 (Short Names)
    ├─ Assumes: Short names clear in context
    ├─ Assumes: IDE autocomplete not confusing
    └─ Blocks: API naming (must be consistent)
```

---

## Verification Roadmap

| Challenge | Verification | Owner | Timeline |
|-----------|--------------|-------|----------|
| D-001 | Survey 5 devs: Separate vs unified? | Design | Week 1 |
| D-002 | Compare LOC: ADDRESS vs INET_ADDRESS | Dev | Week 1 |
| D-003 | Test preconditions catch misuse | QA | Week 2 |
| D-004 | Test on 3 platforms: timeout variance | QA | Week 2 |
| D-005 | Test partial send/receive correctness | Dev | Week 3 |
| D-006 | Benchmark MML query overhead | QA | Week 3 |
| D-007 | Test SCOOP multi-client server | Dev | Week 4 |
| D-008 | Test gRPC blocking sufficiency | Integration | Week 4 |
| D-009 | IDE autocomplete test + code review | QA | Week 1 |

---

## Recommendation

**All 9 decisions should proceed as planned (D-001 through D-009).** Verification activities are _not blockers_; they are _confidence builders_. If any challenge raises red flags during implementation, adjust Phase 2 planning accordingly.

**Key risks to monitor:**
1. RISK-006: SCOOP learning curve → Plan documentation early
2. RISK-010: Integration breaking downstream → Semantic versioning + early testing with simple_http
3. RISK-003: Timeout semantics insufficient → Phase 2 granular overrides

---

