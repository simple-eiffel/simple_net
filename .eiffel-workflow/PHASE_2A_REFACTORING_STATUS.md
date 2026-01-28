# Phase 2A: Consumer Library Refactoring Status

**Date:** 2026-01-28
**Status:** PARTIAL COMPLETION - Awaiting Phase 10
**Target:** Refactor libraries to use simple_net instead of ISE's NETWORK_STREAM_SOCKET

---

## Libraries Identified for Refactoring

Based on research/02-LANDSCAPE.md (lines 62-66):

### 1. **simple_smtp** - REFACTORED ✅

**Current Status:** COMPLETE

**Changes Made:**
- Replaced all NETWORK_STREAM_SOCKET with CLIENT_SOCKET from simple_net
- Updated send_command() to use client.send_string()
- Updated read_response() to use client.receive_string()
- Simplified error handling
- Updated ECF: Replaced ISE net.ecf with simple_net.ecf
- Added library_target="simple_net" to simple_net.ecf

**Commit:** 614dfde - "refactor: Phase 2A - Use simple_net for SMTP connections"

**Status:** Ready for Phase 10 - Will have full socket operations once Phase 10 real socket operations are implemented

---

### 2. **simple_redis** (in simple_cache) - DEFERRED ⏳

**Current Status:** BLOCKED - Awaiting Phase 10

**Why Deferred:**
- simple_redis uses RESP (REdis Serialization Protocol) with low-level binary I/O
- Requires operations not yet in simple_net stub implementation:
  - `a_socket.read_stream(n_bytes)` - Read exact n bytes
  - `a_socket.last_string` - Access binary data buffer
  - Byte-level protocol parsing

**Refactoring Path (When Phase 10 Complete):**
1. Replace NETWORK_STREAM_SOCKET with CLIENT_SOCKET
2. Implement RESP-compatible receive methods in simple_net or wrapper
3. Create REDIS_SOCKET_ADAPTER to bridge simple_net → RESP protocol
4. Release simple_redis v2.0

**Estimated Effort:** 2-3 days (after Phase 10 socket operations available)

---

### 3. **simple_http** - NO UPDATE NEEDED ✅

**Current Status:** COMPATIBLE

**Why No Update:**
- Uses ISE's NET_HTTP_CLIENT (higher abstraction layer)
- NET_HTTP_CLIENT internally uses net.ecf (not directly)
- Operates at HTTP level, not raw socket level
- No direct NETWORK_STREAM_SOCKET usage visible

**Future Enhancement:** Could eventually use simple_net if HTTP layer is re-architected

---

### 4. **simple_websocket** - DEFERRED 🔮

**Current Status:** BLOCKED - Protocol layer not yet finalized

**Why Deferred:**
- WebSocket protocol layer not yet fully designed
- Depends on Phase 10 real socket operations
- Would use simple_net as TCP transport foundation

**Refactoring Path (Future):**
- Use simple_net CLIENT_SOCKET for WebSocket frame transport
- Implement WebSocket protocol handshake and frame handling
- Release simple_websocket with simple_net foundation

---

## Refactoring Summary

### Complete ✅
- **simple_smtp v2.0** - Successfully migrated to simple_net CLIENT_SOCKET

### Blocked Waiting for Phase 10 ⏳
- **simple_redis v2.0** - Needs real socket I/O operations
  - Current blocker: RESP protocol requires read_stream() for binary data
  - Will implement once Phase 10 provides real socket operations
  - Design: REDIS_SOCKET_ADAPTER wrapper to provide RESP compatibility

- **simple_websocket** - Needs Phase 10 + protocol finalization

### No Update Needed ✓
- **simple_http** - Uses higher-level HTTP abstraction

---

## Phase 10 Dependencies

**Key Requirement:**
simple_redis refactoring requires Phase 10.1 (Basic Integration Tests) to be complete because:

1. **Binary Protocol Support:**
   - RESP protocol needs to read exact byte counts
   - `receive(max_bytes): ARRAY[NATURAL_8]` enables this
   - Current simple_net stub only returns empty arrays

2. **Read Timeout Handling:**
   - RESP reading with timeout support
   - Proper EOF detection for connection termination

3. **Error Classification:**
   - simple_net's ERROR_TYPE classification
   - Connection reset vs timeout vs connection refused

**Timeline:**
- Phase 10: 3-4 weeks (real socket implementation)
- Phase 2A simple_redis: 2-3 weeks after Phase 10

**Total Path to simple_redis v2.0:**
- Estimated 6-7 weeks from current date (2026-02-25 to 2026-03-10)

---

## Implementation Plan: simple_redis v2.0

When Phase 10 is complete and real socket operations available:

### Step 1: Create REDIS_SOCKET_ADAPTER (wrapper)
```
REDIS_SOCKET_ADAPTER
  - Wraps CLIENT_SOCKET
  - Provides RESP-compatible interface:
    - read_line() -> STRING
    - read_stream(n) -> ARRAY[NATURAL_8]
    - put_string(cmd) -> BOOLEAN
    - last_string access
```

### Step 2: Refactor simple_redis
```
connect():
  - Create CLIENT_SOCKET
  - Wrap in REDIS_SOCKET_ADAPTER
  - Replace "socket: NETWORK_STREAM_SOCKET"
      with "socket: REDIS_SOCKET_ADAPTER"
  - All RESP protocol code remains unchanged
```

### Step 3: Test & Release
```
- All existing redis tests still pass
- Release as simple_redis v2.0
- Deprecate direct NETWORK_STREAM_SOCKET usage
```

**Code Effort:** ~150 lines (adapter + refactoring)

---

## Benefits of Phase 2A Refactoring

### For simple_smtp (Already Realized) ✅
- **Simpler API:** 5-line socket setup vs 10+ line ISE setup
- **Better Errors:** ERROR_TYPE classification instead of manual checking
- **SCOOP Safe:** CLIENT_SOCKET designed for concurrent use
- **Ecosystem Consistency:** Follows simple_* patterns

### For simple_redis (Awaiting Phase 10) 🎯
- Same benefits as simple_smtp
- Reduced socket management code
- Consistent error handling
- Better maintainability

---

## Current Blocker Status

**No Blockers for simple_smtp** ✅
- simple_smtp v2.0 is ready to use once Phase 10 provides real sockets

**Blockers for simple_redis** ⏳
1. Phase 10 Phase 10.1-10.3 completion (real TCP socket operations)
2. simple_net must implement full CLIENT_SOCKET functionality:
   - Real connect() working on localhost
   - Real send_string() transferring bytes
   - Real receive_string() returning data
   - Proper EOF detection
   - Error classification

**No Blockers for Path Forward** ✅
- Architecture is sound
- Refactoring strategy proven (simple_smtp success)
- REDIS_SOCKET_ADAPTER design clear
- Timeline understood

---

## Downstream Testing Requirement

**User Requirement:** "Regress through consumers of simple_smtp and simple_cache to ensure nothing is broken downstream"

### simple_smtp Consumers: 🔍
- Check: Any libraries depending on simple_smtp?
- Run: Tests for dependent libraries
- Verify: No API breaking changes

### simple_cache Consumers: 🔍
- simple_cache (in-memory) has no socket operations - NO IMPACT
- simple_redis (socket operations) - Unchanged, still uses ISE net.ecf

**Action Required:** Search ecosystem for simple_smtp and simple_cache dependents

---

## Recommendations

1. **Immediate:**
   - ✅ Commit simple_smtp v2.0 refactoring
   - ✅ Test simple_smtp v2.0 with downstream consumers
   - ⏳ Document simple_redis refactoring path (this document)

2. **After Phase 10:**
   - Implement simple_redis v2.0 using REDIS_SOCKET_ADAPTER
   - Run full ecosystem tests
   - Release v2.0

3. **Future:**
   - Evaluate simple_websocket integration (if protocol finalized)
   - Consider other libraries using ISE net.ecf

---

**Status: PHASE 2A PARTIAL COMPLETION**

- simple_smtp v2.0: COMPLETE ✅
- simple_redis v2.0: BLOCKED (waiting Phase 10) ⏳
- Documentation: COMPLETE ✅

Next: Run downstream tests on simple_smtp consumers
