# Phase 2 Synopsis: Adversarial Contract Review

## Review Summary

**Reviewers:** Ollama (QwenCoder) + Claude (Model 4.5)
**Date:** 2026-01-28
**Total Issues Found:** 12 (3 CRITICAL, 3 HIGH, 4 MEDIUM, 1 LOW, 1 DESIGN)

## CRITICAL ISSUES (Must Fix Before Phase 3)

### 1. CLIENT_SOCKET.connect() Allows Contradictory States

**Current Problem:**
```eiffel
ensure
    connected_or_error: Result = is_connected or is_error
    on_success: Result implies is_connected and not is_error
    on_failure: not Result implies is_error and not is_connected
```

The postcondition "connected_or_error" is meaningless (always true). Worse, it permits Result=true while is_error=true simultaneously.

**Fix:**
```eiffel
ensure
    success_implies_connected: Result implies (is_connected and not is_error)
    failure_implies_error: (not Result) implies (is_error and not is_connected)
```

**Impact:** Phase 4 implementation must guarantee: either fully connected or fully in error state, never both.

---

### 2. SERVER_SOCKET.accept() Incomplete Failure Specification

**Current Problem:**
```eiffel
ensure
    result_on_error: (Result = Void) implies (is_error or operation_timed_out)
```

This allows Result=Void when neither is_error nor timed_out (violates "Returns Void on timeout or error").

**Fix:**
```eiffel
ensure
    success_guarantee: (Result /= Void) implies (connection_count = old connection_count + 1 and not is_error)
    failure_guarantee: (Result = Void) iff (is_error or operation_timed_out)
    counter_progress: (connection_count = old connection_count) or (connection_count = old connection_count + 1)
```

**Impact:** Phase 4 must treat Result=Void as error signal (never return Void for other reasons).

---

### 3. State Invariant Too Permissive

**Current Problem:**
```eiffel
invariant
    state_consistency: (is_connected and not is_error and not is_closed) or not is_connected
```

This allows multiple invalid combinations:
- (is_connected=false, is_error=true, is_closed=false) - should be impossible after error recovery
- Doesn't prevent simultaneous error and closed states

**Fix:**
```eiffel
invariant
    connected_excludes_error: is_connected implies not is_error
    connected_excludes_closed: is_connected implies not is_closed
    error_excludes_closed: is_closed implies not is_error
```

These three constraints together ensure proper mutual exclusion of states.

**Impact:** Phase 4 implementation must enforce these invariants in state transitions.

---

## HIGH PRIORITY ISSUES (Fix Before or During Phase 3)

### 4. CLIENT_SOCKET.send() Partial Send Not Specified

**Issue:** Comment promises "Full send guarantee (all or error)" but postcondition allows partial sends.

**Fix:**
```eiffel
ensure
    all_or_error: Result implies (bytes_sent = old bytes_sent + a_data.count)
    failure_means_error: (not Result) implies is_error
    no_data_loss: bytes_sent >= old bytes_sent
    partial_not_allowed: (bytes_sent > old bytes_sent and bytes_sent < old bytes_sent + a_data.count) implies Result = false
```

**Impact:** Phase 4 must implement retry logic or buffering to guarantee all-or-nothing semantics.

---

### 5. CLIENT_SOCKET.receive() Allows Empty Array Without Reason

**Issue:** Postcondition allows Result.count=0 with no EOF and no error, violating documented behavior.

**Fix:**
```eiffel
ensure
    bounded: Result.count <= a_max_bytes
    empty_requires_reason: (Result.count = 0) implies (is_at_end_of_stream or is_error)
    data_excludes_error: (Result.count > 0) implies (not is_error and not is_at_end_of_stream)
```

**Impact:** Phase 4 must guarantee: empty array only when EOF or error occurred.

---

### 6. SERVER_SOCKET.listen() Missing Success Postcondition

**Issue:** Postcondition doesn't specify that listen() success makes is_listening=true.

**Fix:**
```eiffel
ensure
    success_means_listening: Result implies (is_listening and not is_error and backlog = a_backlog)
    failure_means_error: (not Result) implies (is_error and not is_listening)
```

**Impact:** Phase 4 must set is_listening_impl=true on listen success.

---

## MEDIUM PRIORITY ISSUES (Fix During Implementation)

### 7. CLIENT_SOCKET.receive_string() Missing Error Specifications

**Issue:** Only postcondition is "result_not_void" - no spec for EOF or error behavior.

**Fix:**
```eiffel
ensure
    result_not_void: Result /= Void
    empty_on_error: is_error implies Result.count = 0
    empty_on_eof: is_at_end_of_stream implies Result.count = 0
    tracks_bytes: Result.count > 0 implies bytes_received > old bytes_received
```

---

### 8. ADDRESS.is_ipv4_address() Too Simplistic

**Issue:** Accepting anything with 3 dots (e.g., "....", "1.2.3", non-numeric).

**Fix:**
```eiffel
ensure
    dot_count: Result implies host.occurrences ('.') = 3
    numeric_octets: Result implies all_octets_are_numeric
    valid_range: Result implies all_octets_in_0_to_255
```

---

### 9. Timeout Scope Not Documented

**Issue:** set_timeout() postcondition doesn't specify which operations are affected.

**Fix:**
Add documentation postcondition:
```eiffel
set_timeout (a_seconds: REAL)
    -- Set timeout for ALL I/O operations: send, receive, connect, accept.
    ensure
        timeout_set: timeout = a_seconds
        applies_globally: "send, receive, connect, accept all use this timeout"
```

---

### 10. CLIENT_SOCKET.local_address Precondition Too Restrictive

**Issue:** Can't query until connected, blocking pre-connection testing.

**Fix:**
```eiffel
local_address: ADDRESS
    require
        available: is_connected or is_closed or is_listening
    do
        ...
    ensure
        result_not_void: Result /= Void
```

For CLIENT_SOCKET, allow querying after connect or close.

---

### 11. close() Doesn't Specify Error Handling

**Issue:** What happens to is_error when close() is called during error state?

**Fix:**
```eiffel
close
    ensure
        closed: is_closed
        not_connected: not is_connected
        -- Error state can persist or be cleared - document choice
```

**Design Decision Needed:** Should close() clear error state? Currently unspecified.

---

## MEDIUM PRIORITY NOTES

### 12. Monotonicity of bytes_sent / bytes_received (No Fix Needed)

Ollama flagged this, but Claude notes it's actually correct:
- Postconditions enforce non-decreasing within socket lifetime
- Creating new socket resets counters (correct behavior)
- Invariant can't reference old state
- **Decision: No change needed** - just document in postconditions

---

## Design Observations

### Strengths
1. ✓ ADDRESS as immutable value object - correct pattern
2. ✓ Separate CLIENT_SOCKET and SERVER_SOCKET - good UX
3. ✓ ERROR_TYPE classification system - excellent for retry logic
4. ✓ Cumulative counters - good for monitoring

### Gaps
1. ⚠️ CONNECTION is deferred but minimal interface - asymmetric (SERVER_SOCKET.accept returns CONNECTION, but CLIENT_SOCKET doesn't inherit from it)
2. ⚠️ No resource cleanup semantics - should specify behavior if socket not explicitly closed
3. ⚠️ No concurrency guarantees beyond SCOOP marking - what if two processors call send() simultaneously?

---

## Recommendation: Phase 2.1 Follow-Up

**Three sub-phases recommended:**

1. **Phase 2.1A (CRITICAL)**: Fix issues #1, #2, #3
   - Resolve state contradictions
   - Fix postcondition logic errors
   - Ensure invariants are satisfiable

2. **Phase 2.1B (HIGH)**: Fix issues #4, #5, #6
   - Strengthen send/receive guarantees
   - Complete listen() postconditions
   - Add biconditional constraints

3. **Phase 2.1C (MEDIUM)**: Fix issues #7-11
   - Add error specifications
   - Improve IPv4 validation
   - Document timeout scope
   - Relax preconditions where appropriate
   - Design close() error handling

**Timeline:** Can proceed to Phase 3 after 2.1A and 2.1B. Phase 2.1C can be done in parallel with Phase 3.

---

## Files to Update

1. ✏️ `src/client_socket.e` - connect, send, receive, receive_string, local_address
2. ✏️ `src/server_socket.e` - listen, accept, close
3. ✏️ `src/address.e` - is_ipv4_address
4. ✏️ `src/connection.e` - review deferred contracts consistency

---

## Next Step

**User Action Required:**

Option A: Approve fixes and proceed to Phase 2.1A (contract revision)
Option B: Request clarification on any issues before proceeding
Option C: Skip Phase 2.1 and proceed directly to Phase 3 (contracts as-is)

**Recommendation:** Proceed with Phase 2.1A+B before Phase 3, to ensure Phase 4 implementation is straightforward.
