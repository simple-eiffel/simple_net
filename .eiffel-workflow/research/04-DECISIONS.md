# DECISIONS: simple_net - Architectural Choices

**Date:** January 28, 2026

---

## Decision Log

### D-001: Client/Server Class Separation vs Unified Socket Class

**Question:** Should we have separate CLIENT_SOCKET and SERVER_SOCKET classes, or one unified SOCKET class that works for both?

**Options:**

1. **Separate Classes (CLIENT_SOCKET, SERVER_SOCKET):**
   - Pros: Intent-clear in code (`CLIENT_SOCKET` vs `SERVER_SOCKET`), prevents misuse, mirrors Python/Go conventions, simpler API surface per class
   - Cons: Code duplication, two classes to maintain, must find common interface

2. **Unified SOCKET Class:**
   - Pros: Less duplication, single class to master, matches ISE net.ecf philosophy, smaller API footprint
   - Cons: API confusion (`connect()` on server socket makes no sense), harder for users, mixes concerns

**Decision:** ✅ **SEPARATE CLASSES** (CLIENT_SOCKET and SERVER_SOCKET)

**Rationale:**
- Clarity for users (intent-driven, matches Python socket creation, Go Dial/Listen)
- Prevents accidental misuse (can't call `connect()` on SERVER_SOCKET)
- Simple_* ecosystem values clarity over minimal class count
- Both classes can inherit from common CONNECTION_BASE to share impl

**Implications:**
- Design: CLIENT_SOCKET and SERVER_SOCKET inherit from CONNECTION_BASE
- Feature set: CLIENT_SOCKET has `connect()`, SERVER_SOCKET has `listen()/accept()`
- Testing: Separate test classes for each, plus integration tests
- Documentation: Clear examples for client vs server code paths

**Reversible:** NO - Once code published, changing class names is breaking change

---

### D-002: Address Representation (Simple Tuple vs INET_ADDRESS Factory)

**Question:** How should users specify address? Simple (host, port) or wrap ISE's INET_ADDRESS_FACTORY?

**Options:**

1. **Simple (host: STRING, port: INTEGER):**
   - Pros: No factory pattern, intuitive, matches Python/Go, minimal boilerplate
   - Cons: Less type-safe (what if port is negative?), no IP validation upfront, must validate at connect time

2. **Wrap INET_ADDRESS_FACTORY:**
   - Pros: Type-safe, immutable, can validate addresses
   - Cons: Heavy API (factory pattern confusing), still academic, defeats purpose of simplification

3. **Custom ADDRESS class wrapping (host, port):**
   - Pros: Simple tuple-like semantics, type-safe, custom validation, Eiffel-idiomatic
   - Cons: One more class, minor boilerplate

**Decision:** ✅ **CUSTOM ADDRESS CLASS**

**Rationale:**
- Keep semantics simple (host: STRING, port: INTEGER)
- Add type safety (valid port range: 1-65535 checked at creation)
- Preconditions validate host is not empty
- Avoids heavy ISE INET_ADDRESS factory pattern
- Still provides better API than Python's raw tuple

**Implications:**
- New class: ADDRESS (immutable, represents host:port)
- Creation: `ADDRESS.make_for_host_port(hostname, port)` or variant
- Used in both CLIENT_SOCKET and SERVER_SOCKET
- Validation happens once at creation, not deferred to connect

**Reversible:** YES - Can always add INET_ADDRESS support later without breaking ADDRESS

---

### D-003: Error Handling (Exceptions vs Queryable State)

**Question:** When socket operations fail, should we raise exceptions or use queryable error state (Eiffel convention)?

**Options:**

1. **Exceptions:**
   - Pros: Modern convention, forces error handling, clean flow for success path
   - Cons: Not Eiffel convention, requires exception handling in feature signatures, silent failures if not caught

2. **Queryable State (is_error, last_error):**
   - Pros: Eiffel convention, explicit checks, no exception machinery, predicates, contracts can verify states
   - Cons: Easy to ignore errors, manual checking required, older-style API

3. **Result Type (RESULT_TYPE [OUTCOME, ERROR]):**
   - Pros: Modern, forces handling, type-safe, trendy
   - Cons: Not Eiffel idiom, complicates contracts (what's the invariant on a failed result?), adds abstraction

**Decision:** ✅ **QUERYABLE STATE** (is_error, error_classification, last_error_string)

**Rationale:**
- Eiffel convention (Design by Contract, not exceptions)
- Simple_* ecosystem uses this pattern (see simple_http, simple_cache)
- Contracts can verify error states: `ensure not is_error implies is_connected`
- Explicit queries (`if not client.is_error then ...`) are clearer than try-catch
- ISE net.ecf already uses this pattern; we're just wrapping it more clearly

**Implications:**
- Query features: `is_error: BOOLEAN`, `error_classification: ERROR_TYPE`, `last_error_string: STRING`
- No exception raising from public features
- Every operation returns status queryable via `is_error` or more specific predicates
- Example: `client.connect()` doesn't raise; check `is_connected` or `is_error` after
- Documentation emphasizes: "Check is_error after operations; handle specific error types"

**Reversible:** YES - Can add exception mode later if ecosystem demands it

---

### D-004: Timeout Semantics (Single vs Multiple Timeout Settings)

**Question:** How many timeout settings? One unified timeout, or separate connect/accept/read/write timeouts?

**Options:**

1. **Single Universal Timeout:**
   - Pros: Intuitive (Python socket.settimeout()), simple API, matches user expectation
   - Cons: May not fit all scenarios (connect phase might need different timing than data transfer)

2. **Separate Timeouts (connect_timeout, accept_timeout, read_timeout, write_timeout):**
   - Pros: Fine-grained control, ISE net.ecf pattern, advanced use cases
   - Cons: Confusing API, too many settings, defeats simplification goal

3. **Universal Timeout + Phase-Specific Overrides (Phase 2):**
   - Pros: Simple default, escape hatch for advanced users
   - Cons: Complexity creep, future maintenance

**Decision:** ✅ **SINGLE UNIVERSAL TIMEOUT** (MVP); defer overrides to Phase 2

**Rationale:**
- MVP simplicity: one method `set_timeout(seconds: REAL)` applies to all phases
- Matches Python/Go convention (settimeout(), SetDeadline())
- 99% of use cases need one timeout: "this operation should not hang"
- If separate timeouts needed later, can add `set_connect_timeout()` without breaking existing code

**Implications:**
- Public method: `set_timeout(seconds: REAL)`
- Applies to: connect, accept, read, write, receive - ALL operations
- Zero special cases
- Documentation: "Set a timeout to prevent indefinite hangs; applies to all network operations"

**Reversible:** YES - Can add fine-grained timeouts without removing single timeout

---

### D-005: Receive/Send Semantics (Partial vs Total Guarantees)

**Question:** What should `send()` and `receive()` guarantee? Full or partial data movement?

**Options:**

1. **Full Guarantee (Keep Calling Until Done):**
   - Pros: Simple API, automatic partial handling, user doesn't think about it
   - Cons: May block longer than user expects, hides latency

2. **Partial Guarantee (Returns Bytes Moved):**
   - Pros: More transparent, user can see progress, matches lower-level APIs (Python recv, Go Read)
   - Cons: User must loop to ensure all data sent/received, more boilerplate

3. **Hybrid (Full By Default, Return Bytes Moved):**
   - Pros: Simple common case (all), transparent for advanced users
   - Cons: Slightly more complex API

**Decision:** ✅ **FULL GUARANTEE** (send all; receive up to max requested)

**Rationale:**
- Simplification goal: hide complexity from users
- Common pattern: "send this message whole, or error out" (no partial sends in MVP)
- Receive is different: return up to max_bytes available (matches Python recv behavior)
- If partial sends become issue (future high-throughput work), can add `bytes_sent` return

**Implications:**
- `send(data: ARRAY OF BYTES): BOOLEAN` - Returns TRUE if all data sent, FALSE if error
- `receive(max_bytes: INTEGER): ARRAY OF BYTES` - Returns up to max_bytes available; may be less if EOF
- Partial write loop handled inside send() - user doesn't see it
- If network drops mid-send, `send()` fails and returns FALSE; user retries or errors
- Internal: use ISE's `put_string` in loop until all bytes sent

**Reversible:** YES - Can expose `bytes_sent` in Phase 2 if needed

---

### D-006: DBC Approach (Full Contracts vs Minimal Contracts)

**Question:** How much DBC do we write? Full contracts on every feature or minimal?

**Options:**

1. **Minimal Contracts (Just Preconditions):**
   - Pros: Faster to implement, less maintenance, sufficient for basic safety
   - Cons: Incomplete specs, can't prove postconditions via contracts, weak documentation

2. **Full Contracts (Pre + Post + Invariant + MML):**
   - Pros: Complete specification, machine-verifiable properties, excellent documentation, enables formal reasoning
   - Cons: More boilerplate, requires careful thinking about state (what changed? what didn't?), MML overhead

3. **Pragmatic Middle (Pre + Post, No MML):**
   - Pros: Clear specifications without mathematical model overhead
   - Cons: Can't express "what didn't change" (frame conditions), less formal

**Decision:** ✅ **FULL CONTRACTS** (Pre + Post + Invariant + MML model queries)

**Rationale:**
- Simple_* ecosystem standard (see simple_mml, simple_http design)
- simple_net will be foundation for gRPC/WebSocket - needs solid contracts
- MML enables frame conditions: e.g., `ensure other_connections_unchanged := connections_model |=| old connections_model`
- Documentation value: contracts ARE the API spec
- Future: SCOOP concurrency requires strong contracts for safety

**Implications:**
- Every public method has precondition, postcondition, invariant
- Class maintains: `connection_count: INTEGER`, `total_bytes_sent: INTEGER`, etc.
- Model queries: `active_connections_model: MML_SET [INTEGER]`, `sent_bytes_model: MML_MAP [INTEGER, INTEGER]`
- Postconditions use MML `|=|` for frame conditions
- Test suite must verify contracts (not just functionality)

**Reversible:** NO - Cannot retrofit contracts after public release (changes the contract)

---

### D-007: SCOOP Concurrency Model (Separate Processors vs Coarse-Grained Locks)

**Question:** How do we ensure SCOOP safety when multiple threads access connections?

**Options:**

1. **Separate Processor Per Connection:**
   - Pros: Race-free by design, natural SCOOP pattern, clean separation
   - Cons: Overhead of processor creation, synchronization overhead, complex programming model

2. **Coarse-Grained Lock (One Lock for All Connections):**
   - Pros: Simple, obviously safe, low overhead
   - Cons: Not scalable, defeats SCOOP concurrency benefits, not idiomatic

3. **No Explicit Locking (Trust Client):**
   - Pros: Minimal overhead, simple code
   - Cons: Unsafe - race conditions likely, hard to debug

**Decision:** ✅ **SEPARATE PROCESSOR PER CONNECTION** (via `separate` declaration)

**Rationale:**
- SCOOP semantics: make each CONNECTION a separate object, accessed via `separate`
- Eiffel compiler guarantees no race conditions
- ISE net.ecf's NETWORK_STREAM_SOCKET already supports this (class is suitable for `separate`)
- Pattern: `separate_connection := separate connection; separate_connection.send(data)`
- Scales naturally to many concurrent connections

**Implications:**
- CONNECTION features return `separate` references
- API example: `separate_conn: separate CONNECTION := server.accept()`
- Contracts must account for separate semantics (no direct attribute access from different processor)
- Documentation emphasizes: "Use separate keyword when passing connections between processors"
- Test suite includes SCOOP tests

**Reversible:** NO - Fundamental architectural choice

---

### D-008: Blocking Mode Only (MVP) vs Async Support (Phase 2)

**Question:** Should MVP support non-blocking sockets and event-driven async, or just blocking mode?

**Options:**

1. **Blocking Mode Only (MVP):**
   - Pros: Simple API, one code path, sufficient for gRPC/WebSocket (they manage threading), fewer edge cases
   - Cons: Not suitable for single-threaded high-concurrency servers (rare in Eiffel), limits some use cases

2. **Both Blocking and Non-Blocking:**
   - Pros: Flexible, supports more use cases, modern
   - Cons: Complex API, confusing for users, testing overhead, harder to maintain

3. **Non-Blocking From Start:**
   - Pros: Modern, suitable for high concurrency
   - Cons: Steeper learning curve, more complex API, callbacks confusing (SOCKET_POLLER), not needed for MVP

**Decision:** ✅ **BLOCKING MODE ONLY** (MVP); async Phase 2

**Rationale:**
- Simplicity first: gRPC and WebSocket only need blocking I/O (they handle threading separately)
- SCOOP replaces event-driven async (use separate threads instead of callbacks)
- Fewer edge cases: no non-blocking partial reads, no state machines
- If high-concurrency single-threaded server needed: use SCOOP processors instead
- Can add `set_non_blocking()` in Phase 2 without breaking existing code

**Implications:**
- All calls block (no partial reads, no EWOULDBLOCK)
- Timeout behavior: operation blocks for up to timeout duration
- SOCKET_POLLER NOT used (better to use threads)
- Architecture allows async later: can add non-blocking mode with same underlying ISE net

**Reversible:** YES - Can add non-blocking mode without breaking blocking API

---

### D-009: Naming Convention for Methods

**Question:** Should we use `send` / `receive` (short, US convention) or `send_data` / `receive_data` (explicit, Eiffel convention)?

**Options:**

1. **Short Names (send, receive, close, connect, listen):**
   - Pros: Matches Python, Go, Java, minimal boilerplate, intuitive
   - Cons: Less explicit (what is send?), may conflict with Eiffel agent syntax, shorter names can be ambiguous

2. **Explicit Names (send_data, receive_data, close_connection, connect_to_server, listen_for_connections):**
   - Pros: Crystal clear intent, Eiffel convention, no ambiguity
   - Cons: Verbose, boilerplate, defeats simplification goal, doesn't match Python/Go conventions

3. **Mixed (send_data, receive, close, connect):**
   - Pros: Compromise - data operations explicit, control operations short
   - Cons: Inconsistent, hard to remember, not principled

**Decision:** ✅ **SHORT NAMES** (send, receive, close, connect, listen, accept)

**Rationale:**
- Core goal: reduce boilerplate and match developer expectation
- Python/Go/Java developers immediately understand `send`, `receive`, `connect`
- Eiffel developers learning networking expect these names (they're in ISE net already)
- Agent syntax: `agent socket.send` is fine (agents work with short names)
- Explicitness: postcondition contracts document what each does

**Implications:**
- Methods: `send()`, `receive()`, `connect()`, `listen()`, `accept()`, `close()`
- Queries: `is_connected`, `is_listening`, `is_error`, `last_error_string`
- Preconditions document required state: e.g., `send` requires `is_connected`
- Postconditions document changes: e.g., `send` ensures `total_bytes_sent >= old total_bytes_sent`

**Reversible:** NO - API method names cannot change (breaking change)

---

## Summary of Architectural Decisions

| Decision | Choice | Rationale | Phase 1 Impact |
|----------|--------|-----------|---|
| **D-001** | Separate CLIENT_SOCKET / SERVER_SOCKET | Intent clarity, prevents misuse | 2 classes instead of 1 |
| **D-002** | Custom ADDRESS class | Simple (host, port) with validation | 1 new class, tight integration |
| **D-003** | Queryable state (no exceptions) | Eiffel convention, contracts | Every feature must have error query |
| **D-004** | Single universal timeout | API simplicity | One `set_timeout()` method |
| **D-005** | Full send guarantee, partial receive | User expectations, simplicity | More internal state tracking |
| **D-006** | Full DBC (pre+post+inv+MML) | Foundation library standard | Longer feature signatures, model queries |
| **D-007** | Separate processor per connection (SCOOP) | Race-free concurrency | Documentation of `separate` usage |
| **D-008** | Blocking mode only | Simplification, threading via SCOOP | No non-blocking API yet |
| **D-009** | Short names (send, receive, connect) | Match Python/Go expectation | Familiar to most developers |

---

## Next Steps

1. **Step 5: INNOVATIONS** - How does simple_net innovate beyond ISE net.ecf?
2. **Step 6: RISKS** - What could go wrong with these decisions?
3. **Step 7: RECOMMENDATION** - Final BUILD recommendation

---
