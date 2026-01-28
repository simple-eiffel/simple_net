# SCOPE: simple_net - Simplified TCP Socket Abstraction

**Date:** January 28, 2026

---

## Problem Statement

**In one sentence:** Eiffel developers need a high-level, low-boilerplate TCP socket library that hides ISE's academic complexity behind a practical, US-friendly API.

### What's Wrong Today

- **ISE net.ecf is powerful but complex**: Deep knowledge required of socket theory, protocol details, event loops, polling strategies
- **Heavy boilerplate**: Developers write 50-100+ lines of code for simple client/server patterns
- **Academic naming conventions**: NETWORK_STREAM_SOCKET, INET_ADDRESS, SOCKET_POLLER use European academic terminology unfamiliar to typical US developers
- **Semantic confusion**: Classes named for implementation (SOCKET) rather than intent (CONNECTION, CHANNEL, STREAM)
- **No patterns for common scenarios**: Making a simple HTTP client or TCP echo server requires understanding ISE's full socket layer
- **Error handling complexity**: Socket errors, timeouts, connection states require manual state management
- **Async/event-driven unclear**: Polling, non-blocking mode, timeouts not intuitive for developers used to simpler APIs

### Who Experiences This

1. **Mainstream Eiffel developers** - Want to write network code but find ISE net too academic
2. **Python/Java/Go developers** - Switching to Eiffel, expect simpler socket APIs (like Python's socket.socket())
3. **Embedded/IoT developers** - Need reliable client connections without academic overhead
4. **Web framework builders** - Building on simple_web; want clean socket abstraction
5. **Scientific computing** - Need to network Eiffel code with Python/scientific tools

### Impact of Not Solving

- Network features remain "only for Eiffel experts"
- Developers avoid Eiffel for network-heavy applications
- simple_* ecosystem can't build higher-level protocols (gRPC, WebSocket properly) without clean socket base
- Repeated ad-hoc socket code across libraries (code duplication, inconsistency)

---

## Target Users

| User Type | Needs | Pain Level | Primary Semantic Frame |
|-----------|-------|------------|------------------------|
| **Embedded IoT Dev** | Reliable TCP client, connection pooling, retry logic | HIGH | "Connect to device", "Send message", "Wait for response" |
| **Data Scientist** | Bridge Eiffel validators with Python analysis | HIGH | "Open connection", "Stream data", "Close safely" |
| **Web Framework Dev** | WebSocket, gRPC, streaming HTTP foundations | HIGH | "Listen on port", "Accept connections", "Handle streams" |
| **Systems Integrator** | Multi-protocol server (HTTP, custom binary) | MEDIUM-HIGH | "Server socket", "Client socket", "Connection handler" |
| **Scientific Computing** | Network simulation, distributed validation | MEDIUM | "Create socket", "Connect", "Exchange messages" |
| **Legacy Eiffel Migrator** | Moving from ISE sockets to simpler abstraction | MEDIUM | "Simplify socket code", "Clearer semantics" |
| **Full-Stack Eiffel Developer** | Everything from web to embedded | MEDIUM | "Consistent, predictable API across protocols" |

---

## Success Criteria

| Level | Criterion | Measure |
|-------|-----------|---------|
| **MVP** | Simple TCP client connection | 5-10 line code example: connect, send, receive, disconnect |
| **MVP** | Simple TCP server acceptance | 10-15 line code example: listen, accept, handle client, loop |
| **MVP** | Timeouts and error handling | Clear error classification (connection failed, timeout, read error, write error) |
| **MVP** | IPv4 client and server working | Verified with Python/netcat test clients |
| **Full** | IPv6 support | Dual-stack capability |
| **Full** | Connection pooling | Reuse connections efficiently |
| **Full** | Async/event-driven mode | Non-blocking sockets for high concurrency |
| **Full** | Streaming data protocols | Proper frame handling, partial reads/writes |
| **Full** | Zero copy mode | Direct buffer operations for performance |

---

## Scope Boundaries

### In Scope (MUST HAVE)

**Core TCP Functionality:**
- `CLIENT_SOCKET` class - Connect to remote server, send/receive data
- `SERVER_SOCKET` class - Listen on port, accept incoming connections
- `CONNECTION` class - Represent active TCP connection (abstraction for both client and server)
- Blocking mode operation (simple, synchronous)
- IPv4 support (Windows primary)
- Timeouts with clear semantics
- Clean error classification (connection_failed, timeout, read_error, write_error, etc.)

**Data Movement:**
- Read/write operations with clear semantics (read_string, read_bytes, write_string, write_bytes)
- Partial read/write handling (know how many bytes actually moved)
- Clean EOF detection (end_of_stream queries)

**Connection Management:**
- Connection open/close lifecycle
- State queries (is_connected, is_listening)
- Graceful shutdown (close with optional timeout for pending writes)

**Error Handling:**
- Error classification without exception wrapping
- Timeout behavior (distinct from connection errors)
- Connection refused / timeout / broken pipe handled clearly
- No silent failures (all operations return status or query-able state)

**Semantic Reframing (US Developer Conventions):**
- Method names like `connect()`, `listen()`, `accept()`, `send()`, `receive()` (not academic European terminology)
- Class names like `CLIENT_SOCKET`, `SERVER_SOCKET`, `CONNECTION` (not NETWORK_STREAM_SOCKET, INET_ADDRESS)
- Feature queries like `is_connected`, `is_listening`, `is_at_end_of_stream` (not academic state predicates)
- Error semantics: `last_error` or query-based (not exception-heavy)
- Address representation: Simple (HOST, PORT) pairs not INET_ADDRESS objects

**Design by Contract:**
- 100% DBC: preconditions, postconditions, invariants on all public features
- Contract-based error handling (no exceptions, state verification via contracts)
- MML model queries for socket state

### In Scope (SHOULD HAVE)

- IPv6 support (future, but plan for it architecturally)
- Non-blocking mode (event-driven I/O for concurrency)
- Connection pooling (reuse/cache TCP connections)
- Keepalive options (TCP_KEEPALIVE)
- Socket options exposure (SO_REUSEADDR, SO_SNDBUF, SO_RCVBUF)
- Buffer size tuning (user-specifiable read/write buffer sizes)
- Statistics (bytes sent/received, connection count)
- Streaming protocol support (partial writes, chunked data)

### Out of Scope

- **UDP sockets** - Separate concern; simple_udp in future
- **Unix domain sockets** - Windows primary; deferred to Phase 2
- **SSL/TLS encryption** - Separate concern; simple_tls in future
- **HTTP protocol layer** - Already handled by simple_http (which wraps ISE)
- **WebSocket protocol** - separate concern; simple_websocket exists
- **gRPC protocol layer** - Will use simple_net for transport, not part of this library
- **Async/await syntax** - Use SCOOP for concurrency, not async keywords
- **Raw socket options** - Only expose common/safe options, not full SO_* universe
- **Packet-level control** - Focus on stream abstraction, not raw packets

### Deferred to Phase 2

- Unix domain sockets (when simple_unix_sockets needed)
- Non-blocking/event-driven API refinement
- Advanced buffer management (zero-copy)
- Connection pooling frameworks
- Performance profiling/optimization
- Advanced socket options exposure

---

## Constraints (Immutable)

| Type | Constraint | Rationale |
|------|-----------|-----------|
| **Technical** | Must be SCOOP-compatible (void-safe, concurrency-ready) | Simple_* ecosystem standard |
| **Technical** | Must wrap ISE net.ecf (don't rewrite sockets) | Leverage existing, maintained code |
| **Technical** | Windows primary in Phase 1 (ISE net is cross-platform but focus MVP) | Align with manufacturing/embedded focus |
| **Ecosystem** | Must be void-safe (void_safety="all") | Simple_* standard |
| **Ecosystem** | Must prefer simple_* patterns over ISE patterns | Consistency with ecosystem |
| **Design** | 100% Design by Contract (precondition, postcondition, invariant) | Simple_* standard |
| **Naming** | Must use US/mainstream developer semantics, not academic Eiffel | Target audience expectation |
| **API** | Must provide zero-boilerplate TCP client/server examples | Success metric |

---

## Assumptions to Validate

| ID | Assumption | Risk if False | Research Action |
|----|-----------|---------------|-----------------|
| **A-1** | ISE net.ecf works reliably on Windows with proper configuration | Medium | Verify with simple_http usage patterns |
| **A-2** | Developers expect Python/Go-like socket APIs (simple, imperative) | High | Research pain points in Eiffel community forums |
| **A-3** | US/mainstream naming (connect, send, receive) is more intuitive than NETWORK_STREAM_SOCKET | High | Validate with user personas (embedded dev, data scientist) |
| **A-4** | SCOOP is the right concurrency model for simple_net (not async/await) | Medium | Check simple_* ecosystem patterns |
| **A-5** | Blocking sockets are sufficient for MVP (non-blocking Phase 2) | Medium | Verify with gRPC/WebSocket requirements |
| **A-6** | Error handling via state queries beats exception wrapping | High | Research community preference |
| **A-7** | Connection class abstraction is better than raw socket typing | Medium | Verify with simple_http/simple_ipc patterns |

---

## Research Questions

1. **ISE net.ecf Analysis:**
   - What classes does ISE net.ecf actually export and require?
   - What's the boilerplate burden for a simple "connect and send" client?
   - How do ISE developers typically use SOCKET, INET_ADDRESS, SOCKET_POLLER?
   - What are common pitfalls/gotchas with ISE's socket API?

2. **Semantic Reframing:**
   - What naming conventions do Python, Go, Java developers expect for socket APIs?
   - What's wrong with NETWORK_STREAM_SOCKET from a user perspective?
   - How do we map Eiffel's academic terminology to mainstream conventions?
   - Which class/feature names cause confusion in the community?

3. **Pain Points & Innovations:**
   - What socket features do gRPC, WebSocket libraries need from simple_net?
   - How do embedded/IoT developers use sockets today (in Python, Rust)?
   - What error handling patterns are most useful (exceptions, result types, state queries)?
   - How do we make connection pooling, retries, timeouts intuitive?

4. **Architecture:**
   - Should simple_net expose internal ISE socket objects or hide them completely?
   - How deep should CONNECTION abstraction go (raw bytes vs. message framing)?
   - Should there be separate CLIENT_SOCKET and SERVER_SOCKET or unified SOCKET?
   - How do we make async/SCOOP concurrency natural for users?

5. **Ecosystem Integration:**
   - What does simple_http actually need from sockets?
   - What will gRPC (simple_grpc) need from simple_net?
   - How does simple_ipc differ and what can we learn from it?
   - Are there simple_* patterns we should follow?

---

## Next Steps

1. Research ISE net.ecf documentation and source (Step 2: LANDSCAPE)
2. Analyze boilerplate patterns in existing code (Step 2)
3. Define functional requirements (Step 3)
4. Make semantic reframing decisions (Step 4)
5. Identify innovations (Step 5)
6. Assess risks (Step 6)
7. Deliver recommendation (Step 7)

---
