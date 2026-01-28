# Phase 10: Network Integration Tests - PLANNING DOCUMENT

**Date:** 2026-01-28
**Status:** Planning Phase
**Target Version:** v1.2.0
**Estimated Scope:** 15-25 integration tests

---

## Overview

Phase 10 transitions simple_net from **stubbed implementation** to **real TCP socket operations**. Currently, all CLIENT_SOCKET and SERVER_SOCKET methods are stubs that return success without actual network I/O. Phase 10 will implement real socket functionality and verify it with comprehensive integration tests.

---

## Current State Assessment

### Stubbed Implementations

#### CLIENT_SOCKET Stubs
```eiffel
connect: BOOLEAN
    do
        -- Phase 4 Stub: Return success (real implementation would use NETWORK_SOCKET)
        is_connected_impl := True
        is_error_impl := False
        error_impl.make (0)
        Result := True
    end

send (a_data: ARRAY [NATURAL_8]): BOOLEAN
    do
        -- Phase 4 Stub: Record bytes sent and return success
        bytes_sent_impl := bytes_sent_impl + a_data.count
        Result := True
    end

receive (a_max_bytes: INTEGER): ARRAY [NATURAL_8]
    local
        l_empty: ARRAY [NATURAL_8]
    do
        -- Phase 4 Stub: Return empty array (EOF simulation)
        create l_empty.make_empty
        is_at_eof_impl := True
        Result := l_empty
    end
```

#### SERVER_SOCKET Stubs
```eiffel
listen (a_backlog: INTEGER): BOOLEAN
    do
        -- Phase 4 Stub: Return success (real implementation would use NETWORK_SOCKET)
        is_listening_impl := True
        backlog_impl := a_backlog
        is_error_impl := False
        error_impl.make (0)
        Result := True
    end

accept: detachable CONNECTION
    do
        -- Phase 4 Stub: Return Void (timeout/error simulation)
        is_error_impl := True
        error_impl.make (-1)  -- -1 for generic timeout
        Result := Void
    end
```

### What Works (Tested)
- ✅ Object creation and state machine transitions
- ✅ Contract validation (preconditions, postconditions, invariants, frame conditions)
- ✅ Error classification
- ✅ Timeout configuration
- ✅ Address validation and formatting
- ✅ SCOOP type compatibility

### What Doesn't Work (Stubbed)
- ❌ Actual TCP connections
- ❌ Real data transfer
- ❌ Real error scenarios (connection refused, timeouts from network)
- ❌ Multiple concurrent clients
- ❌ Large data transfer
- ❌ Connection state management during I/O

---

## Phase 10 Scope

### What This Phase Will Do
1. **Implement Real Socket Operations**
   - Replace stubs with actual TCP socket code
   - Support loopback connections (127.0.0.1)
   - Handle real network errors

2. **Create Integration Tests**
   - Real client-server connections
   - Data send/receive verification
   - Error scenario testing
   - Timeout verification
   - Graceful shutdown

3. **Verify Contract Compliance**
   - Ensure all real operations satisfy postconditions
   - Verify error handling maintains invariants
   - Test frame conditions with real operations

### What This Phase Will NOT Do
- ❌ Cross-machine network tests (requires infrastructure)
- ❌ Performance optimization (Phase 11)
- ❌ Platform-specific features (Phase 13)
- ❌ Advanced features (encryption, compression, etc.)

---

## Implementation Strategy

### Option A: Use ISE's net.ecf Library (Recommended)

**Rationale:**
- simple_net already wraps ISE's net.ecf
- Proven, stable socket library
- Available in standard EiffelStudio
- No external dependencies

**Integration Points:**
```
NETWORK_SOCKET (ISE's net.ecf)
    ↓
CLIENT_SOCKET_IMPL (new - real implementation)
    ↓
CLIENT_SOCKET (public API - already exists)
```

**Required Implementation:**
1. Create `CLIENT_SOCKET_IMPL` with real socket operations using NETWORK_SOCKET
2. Create `SERVER_SOCKET_IMPL` with real socket operations using NETWORK_SOCKET
3. Modify CLIENT_SOCKET and SERVER_SOCKET to delegate to implementations
4. Handle platform-specific socket details (Windows vs Linux)

**Estimated Effort:** High (socket API complexity) but straightforward architecture

---

### Option B: Direct C Inline Externals (Alternative)

Following simple_* ecosystem pattern for inline C:

**Implementation:**
- Win32 API socket calls via inline C externals
- POSIX socket calls via inline C externals
- Platform detection at runtime

**Pros:**
- No ISE library dependency
- Direct control
- Follows simple_* inline C pattern

**Cons:**
- Platform-specific code (Windows/Linux)
- More error-prone
- Requires C knowledge

**Estimated Effort:** Very High (C socket API mastery required)

---

## Recommended Approach: Option A + Hybrid

**Phase 10.1: ISE net.ecf Integration**
- Use ISE's NETWORK_SOCKET for socket operations
- Create CLIENT_SOCKET_IMPL and SERVER_SOCKET_IMPL classes
- Implement loopback-only functionality first (fast iteration)

**Phase 10.2: Platform-Specific Handling**
- Handle Windows socket peculiarities
- Handle Linux socket peculiarities
- Add platform detection

**Phase 10.3: Advanced Testing**
- Multiple concurrent connections
- Large data transfer
- Stress testing

---

## Test Plan

### Phase 10.1: Basic Integration Tests (LOOPBACK ONLY)

#### Test 1: Simple Echo Test
```eiffel
test_client_server_echo_loopback
    -- Create server on 127.0.0.1:9999
    -- Create client connecting to 127.0.0.1:9999
    -- Send "Hello" from client
    -- Receive "Hello" on server
    -- Echo back "Hello from server"
    -- Receive on client
    -- Verify both directions work
```

**Acceptance Criteria:**
- Server listens successfully
- Client connects successfully
- Data transfer in both directions
- Correct bytes count

#### Test 2: Connection Refused
```eiffel
test_connection_refused
    -- Try to connect to unused port
    -- Verify error state is set
    -- Verify error_classification.is_connection_refused
```

**Acceptance Criteria:**
- Connection fails (Result = False)
- is_error becomes true
- error_classification matches connection refused

#### Test 3: Connection Timeout
```eiffel
test_connection_timeout
    -- Set short timeout (0.1 seconds)
    -- Try to connect to non-routable address (10.255.255.1)
    -- Verify timeout occurs
```

**Acceptance Criteria:**
- Connection fails after timeout
- error_classification.is_timeout
- Timing is reasonable (within 2x configured timeout)

#### Test 4: Server Accept with Single Client
```eiffel
test_server_accepts_single_client
    -- Server listening on 127.0.0.1:9998
    -- Client connects
    -- Server.accept returns connection
    -- Connection represents client
```

**Acceptance Criteria:**
- accept() returns non-void CONNECTION
- CONNECTION.remote_address matches client
- CONNECTION can be used for send/receive

#### Test 5: Multiple Sequential Connections
```eiffel
test_server_accepts_multiple_sequential_clients
    -- Server listening
    -- Client 1 connects, sends data, closes
    -- Client 2 connects, sends data, closes
    -- Server accepts both
    -- connection_count increments
```

**Acceptance Criteria:**
- Both connections accepted
- connection_count = 2
- Each client data received correctly

#### Test 6: Send and Receive Data
```eiffel
test_send_and_receive_100_bytes
test_send_and_receive_1000_bytes
test_send_and_receive_10000_bytes
    -- Send various amounts of data
    -- Receive and verify
    -- Check bytes_sent and bytes_received
```

**Acceptance Criteria:**
- All bytes transferred correctly
- Counters accurate
- No data loss or corruption

#### Test 7: Graceful Close
```eiffel
test_close_from_client
test_close_from_server
    -- Client closes
    -- Server detects EOF
    -- Server closes
    -- Both is_closed becomes true
```

**Acceptance Criteria:**
- EOF properly detected
- is_at_end_of_stream = true
- Clean shutdown without errors

#### Test 8: Timeout During Operations
```eiffel
test_timeout_during_receive
    -- Set short timeout (1 second)
    -- Server and client connect
    -- Client sends data
    -- Server doesn't receive (simulated hang)
    -- Receive times out
```

**Acceptance Criteria:**
- timeout occurs
- Operation terminates cleanly
- No resource leaks

### Phase 10.2: Concurrent Connection Tests (10+ tests)

#### Test: Multiple Concurrent Clients
```eiffel
test_server_handles_3_concurrent_clients
    -- Create server
    -- Create 3 client threads (separate processors in SCOOP)
    -- All connect simultaneously
    -- All send data
    -- Server accepts all 3
    -- All receive data correctly
```

**Acceptance Criteria:**
- All 3 connections succeed
- connection_count = 3
- No race conditions in state updates
- Data integrity maintained

#### Test: SCOOP Separate Connection
```eiffel
test_client_socket_concurrent_send_receive
    -- Use separate {CLIENT_SOCKET}
    -- Send from main processor
    -- Receive from separate processor
    -- Verify no data races
```

**Acceptance Criteria:**
- SCOOP type checking passes
- Concurrent operations work
- No data corruption

### Phase 10.3: Error Scenario Tests (5+ tests)

#### Test: Connection Reset by Peer
```eiffel
test_connection_reset_by_server
    -- Client connects
    -- Server closes connection abruptly
    -- Client tries to receive
    -- Gets error (not timeout)
```

**Acceptance Criteria:**
- is_error becomes true
- error_classification.is_connection_reset
- Clean error handling

#### Test: Bind Address Already in Use
```eiffel
test_listen_on_already_used_port
    -- Server 1 listens on port 9997
    -- Server 2 tries to listen on same port
    -- Server 2 fails
    -- error_classification.is_bind_error
```

**Acceptance Criteria:**
- listen() returns false
- is_error becomes true
- is_bind_error classification

#### Test: Invalid Port Range
```eiffel
test_listen_on_port_zero
test_listen_on_port_65536
    -- Try to listen on invalid ports
    -- Verify precondition prevents it
```

**Acceptance Criteria:**
- Preconditions enforce port range
- Errors during creation phase

---

## Test Class Structure

### New Test Class: TEST_NETWORK_INTEGRATION

```eiffel
class TEST_NETWORK_INTEGRATION
    inherit TEST_SET_BASE

feature -- Basic Integration Tests
    test_client_server_echo_loopback
    test_connection_refused
    test_connection_timeout
    test_server_accepts_single_client
    test_multiple_sequential_clients
    test_send_and_receive_100_bytes
    test_send_and_receive_1000_bytes
    test_send_and_receive_10000_bytes
    test_graceful_close_from_client
    test_graceful_close_from_server
    test_timeout_during_receive
    -- Total: 11 tests

feature -- Concurrent Tests
    test_server_handles_3_concurrent_clients
    test_client_socket_concurrent_send_receive
    -- Total: 2 tests

feature -- Error Scenario Tests
    test_connection_reset_by_server
    test_listen_on_already_used_port
    test_listen_on_port_zero
    test_listen_on_port_65536
    -- Total: 4 tests

feature {NONE} -- Helpers
    create_listening_server (a_port: INTEGER): SERVER_SOCKET
        -- Create and start server
    connect_client_to_localhost (a_port: INTEGER): CLIENT_SOCKET
        -- Create and connect client
    wait_for_accept (a_server: SERVER_SOCKET; a_timeout_ms: INTEGER): detachable CONNECTION
        -- Helper to accept with timeout

end
```

---

## Architecture Changes Required

### New Classes

#### CLIENT_SOCKET_IMPL
```eiffel
class CLIENT_SOCKET_IMPL
    -- Real TCP socket implementation

feature -- Network Operations
    do_connect (a_remote_address: ADDRESS): BOOLEAN
        -- Actually connect to remote server
    do_send (a_data: ARRAY [NATURAL_8]): BOOLEAN
        -- Actually send bytes
    do_receive (a_max_bytes: INTEGER): ARRAY [NATURAL_8]
        -- Actually receive bytes
    do_close
        -- Actually close connection
```

#### SERVER_SOCKET_IMPL
```eiffel
class SERVER_SOCKET_IMPL
    -- Real TCP server implementation

feature -- Network Operations
    do_listen (a_local_address: ADDRESS; a_backlog: INTEGER): BOOLEAN
        -- Actually bind and listen
    do_accept (a_timeout: REAL): detachable CONNECTION
        -- Actually accept connection
    do_close
        -- Actually close socket
```

### Modifications to Existing Classes

#### CLIENT_SOCKET
```eiffel
class CLIENT_SOCKET

feature {NONE}
    implementation: CLIENT_SOCKET_IMPL
        -- Delegate to real implementation

feature -- Commands (Delegate to implementation)
    connect: BOOLEAN
        do
            Result := implementation.do_connect (remote_address_impl)
            -- Update state based on result
        end
```

### ISE net.ecf Integration

Add to simple_net.ecf:
```xml
<library name="net" location="$ISE_LIBRARY/library/net/net.ecf"/>
```

---

## Blockers and Dependencies

### Critical Dependencies
1. **ISE net.ecf Access** ✅ Already available
2. **NETWORK_SOCKET API Knowledge** - Need to research ISE's net library
3. **Socket Error Code Mapping** - Map ISE errors to simple_net ERROR_TYPE

### Potential Blockers

#### Blocker 1: ISE net.ecf Not Available
**Risk:** MEDIUM
**Mitigation:** Use Option B (inline C) as fallback
**Current Status:** ✅ net.ecf is standard library, no blocker

#### Blocker 2: Socket Complexity
**Risk:** MEDIUM
**Mitigation:** Start with loopback only (no cross-machine networking)
**Current Status:** ✅ Can proceed with loopback approach

#### Blocker 3: SCOOP + Sockets Interaction
**Risk:** LOW
**Mitigation:** Test SCOOP separate objects with real sockets early
**Current Status:** ⚠️ Needs careful testing but not blocking

#### Blocker 4: Platform Differences
**Risk:** MEDIUM
**Mitigation:** Defer platform-specific tests to Phase 13
**Current Status:** ✅ Start on one platform (Windows), document differences

---

## Acceptance Criteria

### Phase 10 Complete When:
- [ ] Real TCP socket operations implemented in CLIENT_SOCKET
- [ ] Real TCP socket operations implemented in SERVER_SOCKET
- [ ] 15+ integration tests created and passing
- [ ] Loopback client-server connections work (127.0.0.1)
- [ ] Data transfer verified (send/receive) with various sizes
- [ ] Error scenarios tested (connection refused, timeout, reset)
- [ ] Graceful shutdown verified from both sides
- [ ] connection_count increments correctly for multiple clients
- [ ] Frame conditions verified with real operations
- [ ] All existing Phase 1-9 tests still passing (no regressions)
- [ ] Zero new compilation warnings
- [ ] New tests documented in CHANGELOG.md

### Success Metrics
- **Test Coverage:** 15+ new integration tests, all passing
- **Regression Safety:** Phase 1-9 tests still 132/132 passing
- **Contract Compliance:** All frame conditions satisfied by real implementation
- **Error Handling:** All error scenarios properly classified and handled

---

## Timeline Estimate

### If Proceeding Immediately:
- **Week 1:** Research ISE net.ecf API, design CLIENT_SOCKET_IMPL/SERVER_SOCKET_IMPL
- **Week 2:** Implement real socket operations (loopback basic)
- **Week 3:** Implement 15+ integration tests
- **Week 4:** Fix bugs, test edge cases, document

**Total:** 4 weeks estimated

### Critical Path:
1. Understand ISE's NETWORK_SOCKET API
2. Implement connect() for CLIENT_SOCKET
3. Implement listen() for SERVER_SOCKET
4. Implement send/receive
5. Create and iterate on tests

---

## Decision Point: Proceed?

### Go / No-Go Criteria

**GO if:**
- ✅ Simple_net feature-complete in terms of API (TRUE - Phase 7+9 complete)
- ✅ Contract discipline strong enough to guide implementation (TRUE - 49 frame conditions)
- ✅ Test framework ready to verify real operations (TRUE - TEST_SET_BASE, comprehensive)
- ✅ Resource available to do socket implementation (DEPENDS - User decision)

**NO-GO if:**
- ❌ ISE net.ecf unavailable or incompatible
- ❌ SCOOP + sockets causes blocking issues
- ❌ Resources not available for 4-week effort

### Current Status: READY TO GO ✅

All prerequisite phases complete. Phase 10 can begin immediately if resources available.

---

## Next Steps

1. **Review this plan** - User approval needed
2. **Research ISE net.ecf API** - Understand NETWORK_SOCKET capabilities
3. **Create CLIENT_SOCKET_IMPL** - Start with connect() operation
4. **Create basic integration test** - test_client_server_echo_loopback
5. **Iterate on implementation** - Incrementally add features and tests

---

## References

- PHASE_9_COMPLETION_STATUS.md - Phase 9 deliverables (frame conditions)
- FUTURE_PHASES_ROADMAP.md - Phases 10-14 overview
- PROJECT_STATUS_SUMMARY.md - Full project context
- simple_net.ecf - Current configuration (will add net.ecf)
- src/client_socket.e - Public API and contracts (will add implementation)
- src/server_socket.e - Public API and contracts (will add implementation)

---

**Status:** Phase 10 is PLANNED and READY FOR IMPLEMENTATION

Awaiting user decision to proceed.
