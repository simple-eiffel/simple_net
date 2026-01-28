# Phase 9: MML Integration Analysis

**Date:** 2026-01-28  
**Status:** Initial Analysis  
**Task:** Evaluate MML integration needs for simple_net

---

## Overview

Phase 9 involves:
1. **9.1:** MML Model Queries for Collection State (if needed)
2. **9.2:** Frame Conditions (Postcondition Enhancement - what didn't change)

---

## Current Contract Structure Analysis

### ADDRESS Class
**Attributes:**
- `host_impl: STRING` - Single immutable value
- `port_impl: INTEGER` - Single immutable value

**Assessment:**
- ❌ NO collections
- ✓ Simple value object
- ✓ Immutable after creation
- **MML Need:** NONE

**Existing Contracts:**
```eiffel
make_for_host_port (a_host: STRING; a_port: INTEGER)
    require
        non_empty_host: a_host /= Void and then a_host.count > 0
        valid_port: a_port >= 1 and a_port <= 65535
    ensure
        host_set: host.is_equal (a_host)
        port_set: port = a_port
    end
```

**Frame Condition Opportunity:**
- Nothing needs to change (creation), so no frame conditions needed

---

### ERROR_TYPE Class
**Attributes:**
- `code_impl: INTEGER` - Single scalar value

**Assessment:**
- ❌ NO collections
- ✓ Simple value object
- ✓ Immutable after creation
- **MML Need:** NONE

---

### CONNECTION Class (Interface)
**Purpose:** Represents active TCP connection

**Attributes (from spec):**
- `remote_address: ADDRESS` - Peer address (immutable)
- `is_connected: BOOLEAN` - Connection state
- `is_error: BOOLEAN` - Error state
- `is_closed: BOOLEAN` - Closed state
- `bytes_sent: INTEGER` - Cumulative counter
- `bytes_received: INTEGER` - Cumulative counter
- `last_error: ERROR_TYPE` - Most recent error

**Assessment:**
- ❌ NO collections
- ✓ State object (not immutable)
- ⚠️ Multiple state flags
- **MML Need:** Frame conditions for state queries

**Existing Contracts (from spec):**
```eiffel
send (data: ARRAY [NATURAL_8]): BOOLEAN
    require
        is_connected: is_connected
        data_not_void: data /= Void
        -- full send: either all bytes sent or error occurs
    ensure
        -- postconditions to be refined
    end
```

---

### CLIENT_SOCKET Class
**Attributes:**
- `remote_address: ADDRESS` - Peer address (immutable)
- `is_connected: BOOLEAN` - Connection state
- `is_error: BOOLEAN` - Error state
- `is_closed: BOOLEAN` - Closed state
- `bytes_sent: INTEGER` - Cumulative counter
- `bytes_received: INTEGER` - Cumulative counter
- `timeout: REAL` - Timeout in seconds

**Assessment:**
- ❌ NO collections
- ✓ State object
- ⚠️ Multiple state flags (mutually exclusive?)
- **MML Need:** Frame conditions for state/metric preservation

---

### SERVER_SOCKET Class
**Attributes:**
- `local_address: ADDRESS` - Listening address (immutable)
- `is_listening: BOOLEAN` - Listening state
- `is_error: BOOLEAN` - Error state
- `is_closed: BOOLEAN` - Closed state
- `connection_count: INTEGER` - Cumulative connections accepted
- `timeout: REAL` - Timeout in seconds
- `backlog: INTEGER` - Last listen() backlog

**Assessment:**
- ❌ NO publicly exposed collections
- ⚠️ Has internal queue (hidden)
- ✓ State object
- **MML Need:** Frame conditions for counter/state preservation

---

## Conclusion: MML Assessment

### Classes Needing MML Model Queries
**Result: NONE**

simple_net classes don't have:
- ❌ PUBLIC collection attributes
- ❌ Complex internal state needing formal specification
- ❌ Multi-element collections to verify with MML_SET, MML_SEQUENCE

### Classes Needing Frame Conditions (Phase 9.2)
**Result: YES - Connection classes (CLIENT_SOCKET, SERVER_SOCKET, CONNECTION)**

These classes have:
- ✓ Multiple properties (state flags, counters, addresses)
- ✓ Operations that shouldn't affect some properties
- ✓ Need documentation of "what doesn't change"

---

## Recommended Phase 9 Approach

### ✅ Phase 9.1 (MML Model Queries): SKIP
**Reason:** simple_net has no collections requiring MML formalization

**Future Consideration:** If SERVER_SOCKET were redesigned to expose `accepted_connections`, then add:
```eiffel
accepted_connections_model: MML_SEQUENCE [CONNECTION]
    -- Formal model of accepted connections for frame conditions
```

### ✅ Phase 9.2 (Frame Conditions): IMPLEMENT
**Approach:** Add frame conditions to key operations in:
- CLIENT_SOCKET: set_timeout, connect, send, receive, close
- SERVER_SOCKET: set_timeout, listen, accept, close
- CONNECTION (interface): Standard operations

**Example - CLIENT_SOCKET.set_timeout():**
```eiffel
set_timeout (a_seconds: REAL)
    require
        positive_timeout: a_seconds > 0.0
    ensure
        timeout_set: timeout = a_seconds
        -- Frame conditions: unchanged properties
        remote_address_unchanged: remote_address = old remote_address
        is_connected_unchanged: is_connected = old is_connected
        is_error_unchanged: is_error = old is_error
        is_closed_unchanged: is_closed = old is_closed
        bytes_sent_unchanged: bytes_sent = old bytes_sent
        bytes_received_unchanged: bytes_received = old bytes_received
    end
```

---

## Phase 9 Execution Plan

1. **Skip MML Model Queries** - Not needed for simple_net structure
2. **Add Frame Conditions** to all public operations in:
   - CLIENT_SOCKET (10+ operations)
   - SERVER_SOCKET (10+ operations)
3. **Document Frame Condition Pattern** for developers
4. **Verify All Contracts Compile** without errors

---

## Files to Modify

- `src/address.e` - No changes (immutable)
- `src/error_type.e` - No changes (immutable)
- `src/connection.e` - Add frame conditions to interface specs
- `src/client_socket.e` - Add frame conditions to operations
- `src/server_socket.e` - Add frame conditions to operations

---

## Expected Outcome

**Phase 9 Deliverable:**
- All public operations document what DOES and DOESN'T change
- Frame conditions make postconditions more precise
- Easier for clients to reason about library behavior
- MML remains optional (can be added if collections appear)

---

## Next: Implement Frame Conditions
Ready to add frame conditions to CLIENT_SOCKET, SERVER_SOCKET, and CONNECTION.
