# INNOVATIONS: simple_net - Novel Approaches

**Date:** January 28, 2026

---

## What Makes simple_net Different

### I-001: US/Mainstream Semantic Reframing

**Problem Solved:** Eiffel's academic socket naming (NETWORK_STREAM_SOCKET, INET_ADDRESS, SOCKET_POLLER) confuses developers from Python, Go, Java backgrounds who expect intuitive names.

**Approach:** Replace academic terminology with mainstream conventions:
- NETWORK_STREAM_SOCKET → CLIENT_SOCKET / SERVER_SOCKET
- put_string / read_line → send / receive
- INET_ADDRESS factory → Simple ADDRESS (host, port) wrapper
- SOCKET_POLLER → Remove entirely; use SCOOP threads instead

**Novelty:** First socket library for Eiffel that prioritizes developer UX over academic purity. Bridges gap between ISE's rigorous design and mainstream expectations.

**Design Impact:**
- Lower barrier to entry for socket programming in Eiffel
- Faster learning curve (3-5 lines for client/server vs 50-100 in ISE net)
- Attracts Python/Go developers learning Eiffel
- Reduces boilerplate by 80-90%

---

### I-002: Unified Error Classification (Not Opaque Strings)

**Problem Solved:** ISE net.ecf reports errors via `was_error` (BOOLEAN) and `socket_error` (STRING from OS). Developers can't distinguish "connection refused" from "timeout" from "read error" programmatically.

**Approach:** Classify errors into machine-readable categories:
```eiffel
error_classification: ERROR_TYPE
-- Enum: CONNECTION_REFUSED, CONNECTION_TIMEOUT, READ_ERROR, WRITE_ERROR,
--       CONNECTION_RESET, OPERATION_CANCELLED, ADDRESS_NOT_AVAILABLE, etc.
```

**Novelty:** First Eiffel socket library with structured error classification. Enables automation (retry on timeout, fail fast on refused, etc.).

**Design Impact:**
- Retry logic can be smart: only retry on retriable errors
- Monitoring/logging can classify failures
- Contracts can verify error recovery: `ensure is_error implies error_code = CONNECTION_TIMEOUT`
- No string parsing needed to understand failures

---

### I-003: DBC-First Design (Formal Contracts on Sockets)

**Problem Solved:** ISE net.ecf has minimal contracts. Developers must read code to understand socket state machines.

**Approach:** Full Design by Contract on every public feature:
- Preconditions: `connect requires not_connected`
- Postconditions: `send ensures total_bytes_sent = old total_bytes_sent + data.count`
- Invariants: `connected xor error_occurred` (connection is either healthy or in error state)
- MML model queries: `active_connections_model: MML_SET [INTEGER]`

**Novelty:** First socket library where contracts serve as executable specification. You can verify socket behavior via contracts, not just tests.

**Design Impact:**
- Contracts are the API documentation
- Tools can verify program safety at compile time (SCOOP verification)
- Model queries enable formal reasoning about connection state
- Future: Could enable contract-driven protocol implementations (simple_grpc, simple_websocket)

---

### I-004: SCOOP-Centric Concurrency (Not Callbacks)

**Problem Solved:** ISE net.ecf's SOCKET_POLLER uses timer-based callbacks (awkward, error-prone) for async. Eiffel developers prefer SCOOP's clean separation.

**Approach:** Design from day one for SCOOP concurrency:
- Each CONNECTION is a separate object (accessed via `separate` keyword)
- Threading is explicit (`separate client := server.accept()`)
- No callback machinery; just normal function calls across processors
- Eiffel compiler verifies no race conditions

**Novelty:** First socket library designed for SCOOP as primary concurrency model (not callbacks, not event loops).

**Design Impact:**
- Scaling to 100s of concurrent connections is natural (just spawn processors)
- No callback hell, no state machines for events
- Compiler prevents race conditions automatically
- Straightforward code for multi-client servers

---

### I-005: Simple_* Ecosystem Integration (Not Standalone)

**Problem Solved:** ISE net.ecf is standalone; each library (simple_http, simple_smtp, simple_websocket) reimplements connection handling.

**Approach:** simple_net becomes the canonical socket layer for simple_* ecosystem:
- simple_http: Builds on simple_net (instead of direct ISE net)
- simple_grpc: Builds on simple_net (instead of inventing sockets)
- simple_websocket: Transport layer uses simple_net
- Future libraries: Inherit simple_net patterns

**Novelty:** First unified socket abstraction in Eiffel ecosystem. Eliminates duplicated socket code across libraries.

**Design Impact:**
- Code reuse: Connection pooling, timeout handling, error recovery defined once
- Consistency: All libraries speak same socket language
- Maintainability: Bug fixes in simple_net benefit all libraries
- Future Phase 2: Connection pooling implemented once, used everywhere

---

### I-006: Zero-Boilerplate Server Patterns

**Problem Solved:** Writing a simple TCP server in ISE net still requires 50+ lines of boilerplate.

**Approach:** Provide server factory patterns and common recipes:
```eiffel
-- Simple echo server (one-liner setup, handler does the work)
server := create {SERVER_SOCKET}.make_for_port(8080)
server.listen(10)

-- Accept loop (user writes handler logic; framework handles connections)
from until not should_run loop
    connection := server.accept()
    handle_client(connection)  -- User's logic here
    connection.close()
end
```

**Novelty:** Clear separation of concerns - framework handles socket lifecycle, user writes business logic.

**Design Impact:**
- Beginner-friendly: write 10-15 LOC, get working server
- Advanced users: Can still access low-level socket options
- Testable: handler logic is separate from socket mechanics

---

### I-007: Phase 2 Path: Async Without Redesign

**Problem Solved:** Many socket libraries require complete redesign when adding async (callbacks → promises → async-await).

**Approach:** Designed blocking API so non-blocking layer can wrap cleanly:
- Phase 1: `send()` blocks (simple, good for threaded servers)
- Phase 2: `send_async()` and `send_with_timeout()` add choices
- Both use same underlying CONNECTION state and contracts

**Novelty:** Upgrade path that doesn't break existing code.

**Design Impact:**
- Blocking code doesn't change when async added
- High-concurrency servers can migrate incrementally
- No forklift redesign needed

---

## Differentiation from Existing Solutions

| Aspect | ISE net.ecf | Python socket | Go net | **simple_net (Innovation)** |
|--------|------------|----------------|--------|---------------------------|
| **Naming** | Academic (NETWORK_STREAM_SOCKET) | Minimal (socket) | Clear (Dial, Listen) | Intentional (CLIENT_SOCKET, SERVER_SOCKET) |
| **Error Handling** | Opaque string (socket_error) | Exceptions | Named errors (ConnRefused) | **Classified enum (CONNECTION_REFUSED, TIMEOUT)** ✨ |
| **Boilerplate** | 50-100 LOC per pattern | 3-5 LOC | 3-5 LOC | **5-10 LOC with DBC** ✨ |
| **DBC/Contracts** | Minimal | N/A | N/A | **Full pre+post+inv+MML** ✨ |
| **SCOOP Support** | Possible (with care) | N/A | N/A | **First-class (separate keyword)** ✨ |
| **Async Path** | SOCKET_POLLER awkward | asyncio library | Goroutines | **Blocking Phase 1, async Phase 2 non-breaking** ✨ |
| **Ecosystem Value** | Reused but raw | Standalone | Standalone | **Foundation for simple_grpc, simple_websocket** ✨ |

---

## Innovation Summary

simple_net is NOT a revolutionary new socket API - socket APIs are solved. Instead, it's **solving the Eiffel-specific problem**: reducing friction between ISE's rigorous design and mainstream developer expectations, while enabling clean layering in the simple_* ecosystem.

**The innovation is in the bridge:** Making ISE net accessible, understandable, and composable for the typical Eiffel developer.

---
