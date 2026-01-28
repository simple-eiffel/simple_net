# Phase 2 Review: Ollama Analysis

## Contract Analysis - simple_net

### Critical Issues Found

**ISSUE 1: CLIENT_SOCKET.connect() has no postcondition guarantees**
- LOCATION: CLIENT_SOCKET.connect (line 91-103)
- SEVERITY: CRITICAL
- PROBLEM:
  - Feature returns BOOLEAN but postcondition only says "Result = is_connected or is_error"
  - This allows Result=true AND is_error=true simultaneously (contradictory state)
  - Postcondition should guarantee: (Result=true) → (is_connected AND NOT is_error)
- SUGGESTION:
  ```eiffel
  ensure
      result_true_means_connected: Result implies (is_connected and not is_error)
      result_false_means_error: (not Result) implies is_error
      state_valid: is_connected xor is_error xor (not is_connected and not is_error)
  ```

**ISSUE 2: CLIENT_SOCKET.send() postcondition incomplete**
- LOCATION: CLIENT_SOCKET.send (line 105-120)
- SEVERITY: HIGH
- PROBLEM:
  - "on_success: Result implies bytes_sent = old bytes_sent + a_data.count" is too specific
  - Send could fail after partial transmission; postcondition allows bytes_sent to increase even when Result=false
  - The "Full send guarantee (all or error)" promise in comment is NOT enforced by contracts
- SUGGESTION:
  ```eiffel
  ensure
      all_or_nothing: Result implies (bytes_sent = old bytes_sent + a_data.count)
      partial_failure: (not Result) implies (bytes_sent >= old bytes_sent and bytes_sent < old bytes_sent + a_data.count) or (is_error and bytes_sent = old bytes_sent)
      error_on_failure: (not Result) implies is_error
  ```

**ISSUE 3: CLIENT_SOCKET.receive() postcondition allows contradictory states**
- LOCATION: CLIENT_SOCKET.receive (line 136-149)
- SEVERITY: HIGH
- PROBLEM:
  - Postcondition allows: "Result.count = 0 AND is_at_end_of_stream=false AND is_error=false"
  - This violates the comment "Returns empty array on EOF or error"
  - Current postcondition "eof_or_data: is_at_end_of_stream or Result.count > 0 or is_error" allows empty with no EOF/error
- SUGGESTION:
  ```eiffel
  ensure
      empty_means_eof_or_error: (Result.count = 0) implies (is_at_end_of_stream or is_error)
      data_means_success: (Result.count > 0) implies (not is_error and not is_at_end_of_stream)
      bounded: Result.count > 0 implies Result.count <= a_max_bytes
  ```

**ISSUE 4: receive_string() has trivial postcondition**
- LOCATION: CLIENT_SOCKET.receive_string (line 151-160)
- SEVERITY: MEDIUM
- PROBLEM:
  - Only postcondition is "result_not_void: Result /= Void"
  - Doesn't specify relationship to bytes_received counter
  - Doesn't specify what happens on EOF/error (should return empty string?)
- SUGGESTION:
  ```eiffel
  ensure
      result_not_void: Result /= Void
      empty_string_on_error: is_error implies Result.count = 0
      empty_string_on_eof: is_at_end_of_stream implies Result.count = 0
      bytes_increased: Result.count > 0 implies bytes_received > old bytes_received
  ```

**ISSUE 5: SERVER_SOCKET.listen() postcondition missing success case side-effects**
- LOCATION: SERVER_SOCKET.listen (line 84-98)
- SEVERITY: HIGH
- PROBLEM:
  - "backlog_set: Result implies backlog = a_backlog" only guarantees if Result=true
  - Postcondition doesn't specify that is_listening becomes true on success
  - Should be explicit: Result=true ↔ is_listening=true
- SUGGESTION:
  ```eiffel
  ensure
      listen_iff_success: is_listening = Result
      backlog_iff_listening: is_listening implies backlog = a_backlog
      error_iff_failure: is_error = (not Result)
  ```

**ISSUE 6: SERVER_SOCKET.accept() postcondition allows impossible states**
- LOCATION: SERVER_SOCKET.accept (line 100-112)
- SEVERITY: CRITICAL
- PROBLEM:
  - Current postcondition: "result_on_error: (Result = Void) implies is_error"
  - This allows (Result=Void AND is_error=false) - violates "Returns Void on timeout or error"
  - Timeout is a form of error; should be: Result=Void ↔ (is_error OR operation_timed_out)
- SUGGESTION:
  ```eiffel
  ensure
      result_on_success: (Result /= Void) implies (connection_count = old connection_count + 1 and not is_error)
      result_on_failure: (Result = Void) implies (is_error or operation_timed_out)
      no_partial_accept: (Result /= Void) or (connection_count = old connection_count)
  ```

**ISSUE 7: Invariant violation possible - is_connected XOR is_error**
- LOCATION: All socket classes (invariant line ~277)
- SEVERITY: CRITICAL
- PROBLEM:
  - Invariants use OR logic: "(is_connected and not is_error and not is_closed) or not is_connected"
  - This allows: (is_connected=false AND is_error=true AND is_closed=false) - valid per invariant
  - But violates semantic intent: should be XOR to ensure only ONE state true
- SUGGESTION:
  ```eiffel
  invariant
      exactly_one_state: (is_connected and not is_error and not is_closed) xor (is_error and not is_connected and not is_closed) xor (is_closed and not is_connected and not is_error) xor (not is_connected and not is_error and not is_closed)
      -- or more readable:
      not (is_connected and is_error)
      not (is_closed and is_connected)
      not (is_closed and is_error)
  ```

### High Priority Issues

**ISSUE 8: ADDRESS.is_ipv4_address() too simplistic**
- LOCATION: ADDRESS.is_ipv4_address (line 81-88)
- SEVERITY: MEDIUM
- PROBLEM:
  - IPv4 check "Result := host.occurrences ('.') = 3" accepts "....", "1.2.3", "::1.2.3.4"
  - Should at least validate each octet is 0-255
  - Postcondition missing to specify correctness
- SUGGESTION:
  ```eiffel
  ensure
      three_dots: Result implies host.occurrences ('.') = 3
      valid_octets: Result implies each_octet_is_0_to_255
  ```

**ISSUE 9: Timeout behavior under-specified**
- LOCATION: All *Commands*, especially send/receive (line 175-182)
- SEVERITY: MEDIUM
- PROBLEM:
  - set_timeout() postcondition just sets timeout value
  - But doesn't specify when timeout applies: creation time? all operations?
  - Should specify: does timeout apply to connect, send, receive, accept independently?
- SUGGESTION:
  - Add postcondition: "timeout_applies_to: Result implies applies_to_all_io_operations"
  - Or add separate features: set_send_timeout, set_receive_timeout, set_accept_timeout

**ISSUE 10: bytes_sent and bytes_received never decrease - not enforced**
- LOCATION: CLIENT_SOCKET invariant (line 278)
- SEVERITY: MEDIUM
- PROBLEM:
  - Comment says "cumulative, never decreases" but no invariant enforces monotonicity
  - Postconditions say "bytes_non_decreasing: bytes_sent >= old bytes_sent" but invariant doesn't constrain relative to prior calls
  - Create socket → close → create new socket → bytes_sent starts at 0 (correct) but single socket could go backward in theory
- SUGGESTION:
  - Add invariant that validates internal tracking: "bytes_impl >= 0 at all times"
  - Add helper function: "ensure bytes_monotonic: bytes_sent >= old bytes_sent in all states"

### Medium Priority Issues

**ISSUE 11: local_address unavailable until connected (query postcondition mismatch)**
- LOCATION: CLIENT_SOCKET.local_address (line 266-274)
- SEVERITY: MEDIUM
- PROBLEM:
  - Precondition: "is_connected or is_closed" but postcondition says Result /= Void
  - What should local_address return when neither connected nor closed? (initial state)
  - Can't query without triggering precondition violation
- SUGGESTION:
  ```eiffel
  -- Either make it available always (return default) or remove it from queries
  -- Option A: Always available
  ensure
      result_not_void: Result /= Void

  -- Option B: Precondition more descriptive
  require
      address_available: is_connected or is_closed or (is_connected_impl and not is_closed_impl)
  ```

**ISSUE 12: close() behavior with respect to error state**
- LOCATION: CLIENT_SOCKET.close, SERVER_SOCKET.close (line 162-171, 114-123)
- SEVERITY: LOW
- PROBLEM:
  - close() postcondition: "is_closed: is_closed" but no guarantee about is_error or is_connected
  - If in error state, what does close() do? Leave error standing?
  - Precondition allows close in any state except already_closed - might want to allow closing error sockets explicitly
- SUGGESTION:
  ```eiffel
  ensure
      closed: is_closed
      not_connected: not is_connected
      error_cleared_if_recoverable: not is_error or (is_error and previous_error_fatal)
  ```

### Design Questions (Not defects, but for clarification)

1. **ERROR_TYPE.is_retriable vs is_fatal**: These are mutually exclusive but not explicitly constrained. Should add invariant?
2. **Empty array vs null**: receive() returns empty array on error. Should it return Void instead?
3. **CONNECTION is deferred but never instantiated**: Only CLIENT_SOCKET and SERVER_SOCKET used. Is CONNECTION needed or should it be abstract interface?

## Summary

**Total Issues Found: 12**
- CRITICAL: 3 (Issues 1, 6, 7)
- HIGH: 3 (Issues 2, 3, 5)
- MEDIUM: 4 (Issues 4, 8, 9, 10, 11)
- LOW: 1 (Issue 12)
- DESIGN: 3

**Recommendation**: Fix CRITICAL and HIGH issues before Phase 3. Medium issues can be addressed in Phase 4 implementation.

**Main Theme**: Postconditions need stronger guarantees about mutually exclusive states (connected vs error vs closed). Current use of OR in postconditions is too permissive.
