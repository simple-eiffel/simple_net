# REFERENCES: simple_net - Research Sources

**Date:** January 28, 2026

---

## Documentation Consulted

### ISE EiffelStudio Socket Library

- **Path:** `/c/Program Files/Eiffel Software/EiffelStudio 25.02 Standard/library/net/`
- **Key Files Examined:**
  - `SOCKET.e` (1,238 lines) - Abstract base class defining socket semantics
  - `STREAM_SOCKET.e` (66 lines) - Deferred connection-oriented socket interface
  - `NETWORK_STREAM_SOCKET.e` (510 lines) - Concrete TCP/IP implementation
  - `INET_ADDRESS.e` and variants - Address handling and factory pattern
  - `SOCKET_POLLER.e` (491 lines) - Timer-based async polling mechanism

- **What We Learned:**
  - TCP/UDP abstraction works well (inheritance, separate classes)
  - INET_ADDRESS factory pattern is powerful but academically dense
  - Blocking mode is straightforward; non-blocking via polling is complex
  - Error handling via `was_error` boolean and `socket_error` string (not exceptions)
  - Socket options (TCP_NODELAY, keepalive, buffering) well-exposed

---

## Ecosystem Libraries Examined

### simple_smtp

- **URL:** `/d/prod/simple_smtp/src/simple_smtp.e`
- **Lines of Code:** 900+
- **Key Learning:** Direct NETWORK_STREAM_SOCKET usage for SMTP protocol
  - Shows how protocol logic tangles with socket I/O
  - Demonstrates boilerplate pattern: connect → send → read → error check → retry
  - Manual state tracking for SMTP state machine

- **Insight:** Would benefit from simple_net abstraction (reduce NETWORK_STREAM_SOCKET visibility)

### simple_cache / simple_redis

- **URL:** `/d/prod/simple_cache/src/redis/simple_redis.e`
- **Key Learning:** Redis protocol over NETWORK_STREAM_SOCKET
  - Similar boilerplate patterns
  - Manual connection pooling concepts emerging

- **Insight:** simple_net could provide pooling layer (Phase 2)

### simple_http

- **URL:** `/d/prod/simple_http/simple_http.ecf`
- **Key Learning:** Uses ISE's NET_HTTP_CLIENT (higher-level wrapper), NOT raw net.ecf
  - Proof that abstraction layers work (HTTP client is simpler than raw socket)
  - simple_http never touches NETWORK_STREAM_SOCKET directly

- **Insight:** Could simplify further by layering on simple_net instead of NET_HTTP_CLIENT

### simple_websocket

- **URL:** `/d/prod/simple_websocket/`
- **Key Learning:** RFC 6455 WebSocket implementation
  - Protocol layer (WS_HANDSHAKE, WS_FRAME) is independent of socket I/O
  - Transport layer (actual socket usage) is separate concern

- **Insight:** simple_net would be ideal transport foundation

---

## External Standards & Conventions

### Python socket Library

- **Official Documentation:** https://docs.python.org/3/library/socket.html
- **Key Design Patterns:**
  - `socket.socket()` creation, `connect()`, `send()`, `recv()`, `close()`
  - Single `settimeout()` method (universal)
  - Exception-based error handling
  - Intuitive naming (no "stream socket", just "socket")

- **Relevance:** simple_net borrows naming conventions from Python (most recognizable to mainstream devs)

### Go net Package

- **Official Documentation:** https://golang.org/pkg/net/
- **Key Design Patterns:**
  - `net.Dial()` for client, `net.Listen()` for server (clear intent)
  - Error handling via `(result, error)` tuple pattern
  - Goroutines for concurrency (parallel to SCOOP processors)
  - No callbacks; goroutines are first-class

- **Relevance:** Confirms blocking I/O + threading is superior to event-driven callbacks

### Java NIO

- **Official Documentation:** https://docs.oracle.com/javase/tutorial/nio/channels/
- **Key Design Patterns:**
  - `SocketChannel.open()` and `ServerSocketChannel.open()`
  - ByteBuffer abstraction for I/O (not strings)
  - Dual-mode: blocking and non-blocking (good Phase 1/2 progression)
  - Selector pattern for multiplexing (advanced use case)

- **Relevance:** Confirms ByteBuffer pattern useful for Phase 2 optimization

---

## Eiffel Ecosystem Patterns

### simple_mml (Mathematical Model Library)

- **URL:** `/d/prod/simple_mml/`
- **Relevance:** If using MML postconditions for model queries
  - MML_SET, MML_MAP, MML_SEQUENCE for collections
  - Frame conditions via `|=|` operator
  - Example: `ensure active_connections_model |=| old active_connections_model` (unchanged)

- **Decision:** Phase 1 uses basic contracts; Phase 2 can add MML if needed

### simple_* Ecosystem Standards

- **Pattern:** simple_http, simple_json, simple_ipc all follow:
  - Facade class (SIMPLE_X for X in {HTTP, JSON, IPC})
  - Thin wrapper over ISE or system APIs
  - DBC (Design by Contract) throughout
  - Void-safe, SCOOP-compatible
  - Zero warnings policy

- **Relevance:** simple_net must follow same patterns for ecosystem consistency

---

## Research Methodology

### Sources Consulted

1. **Primary Source: ISE EiffelStudio 25.02 Library Code**
   - Direct examination of source files in standard library
   - Boilerplate pattern analysis from real socket code
   - Understanding of class hierarchy and feature signatures

2. **Secondary Source: Python/Go/Java Documentation**
   - Standard library APIs to understand mainstream conventions
   - Design pattern recognition (Dial/Listen ≈ client/server distinction)
   - Error handling approaches (exceptions vs results)

3. **Tertiary Source: Eiffel Ecosystem Code**
   - Real-world usage in simple_smtp, simple_cache, simple_http
   - Pattern identification (what works, what's duplicated)
   - Integration points (where simple_net will layer)

### Search Queries Executed

- "EiffelStudio socket examples" → Examined simple_smtp, simple_cache
- "ISE NETWORK_STREAM_SOCKET usage" → Found boilerplate patterns
- "Python socket.socket vs Go net.Dial" → Confirmed naming expectations
- "Design by Contract socket library" → Identified contract patterns
- "SCOOP concurrency separate keyword" → Understood SCOOP threading model

---

## Key Insights Captured

### Insight 1: Boilerplate is Real
ISE net.ecf requires 50-100 LOC for typical client/server patterns. Python/Go achieve same in 3-5 LOC. **Gap is 10-20x.**

### Insight 2: Naming Matters
NETWORK_STREAM_SOCKET, INET_ADDRESS, SOCKET_POLLER are academically precise but confuse mainstream developers. **Simple naming is a feature.**

### Insight 3: Errors Need Classification
Opaque `socket_error` strings prevent automated error handling. **Classified error types enable smart retry logic.**

### Insight 4: Contracts Enable Reasoning
Full DBC (pre+post+inv) can document socket state machines. **Contracts become the API spec.**

### Insight 5: SCOOP Replaces Callbacks
ISE's SOCKET_POLLER (callbacks) is awkward. SCOOP's processor-per-connection is cleaner. **Threading, not event loops.**

### Insight 6: Ecosystem Multiplier
simple_net becomes foundation for simple_grpc, simple_websocket. **One library enables 3+.**

---

## Data Collection Summary

| Category | Items Researched | Key Finding |
|----------|------------------|------------|
| **ISE net.ecf** | 5 core classes, 2,000+ LOC | Boilerplate heavy; naming academic |
| **Usage Examples** | 3 libraries (smtp, cache, http) | Repeated socket handling; no unified pattern |
| **Mainstream APIs** | 3 languages (Python, Go, Java) | Consistent patterns: connect/listen/accept/send |
| **simple_* Ecosystem** | 5 libraries | All follow DBC, SCOOP, void-safe; simple_net must match |
| **Design Patterns** | Error handling, concurrency, async | Queryable state > exceptions; SCOOP > callbacks |

---

## Confidence in Findings

| Finding | Confidence | Evidence |
|---------|-----------|----------|
| ISE net boilerplate is heavy | **HIGH** | 50-100 LOC patterns in real code |
| Naming confuses mainstream devs | **HIGH** | Python/Go APIs universally different |
| Error classification needed | **HIGH** | All examined libraries check `was_error` |
| DBC adds value | **HIGH** | simple_* ecosystem standard; enables reasoning |
| SCOOP is right concurrency model | **HIGH** | ISE designed it; Eiffel community validates |
| Phase 1 scope (blocking, IPv4, Windows) is achievable | **HIGH** | ISE net already does this; simple_net just wraps |
| simple_net will be used by downstream | **HIGH** | simple_grpc and simple_websocket need sockets |

---

## Limitations & Assumptions

### Limitations

1. **No Customer Interviews** - We analyzed code, not direct user feedback. Actual pain points may differ.
2. **No Performance Benchmarks** - ISE net performance unknown; wrapper overhead not measured.
3. **Cross-Platform Not Tested** - Research focused on Windows. Linux/macOS differences deferred to Phase 2.
4. **Async Not Deeply Analyzed** - Phase 2 non-blocking mode not fully specified (intentional).

### Assumptions

1. **ISE net.ecf is Stable** - 20+ years old, ISE uses internally. Assume proven.
2. **SCOOP is Sufficient** - Assume processor-per-connection scales to 100s; rare need for 10K+.
3. **Blocking APIs are Sufficient for MVP** - Assume gRPC and WebSocket don't need non-blocking Phase 1.
4. **Mainstream Naming Will Resonate** - Assume Python/Go developers recognize `connect`, `send`, `receive`.

---

## Next Steps in Research Workflow

This research document concludes the **7-step research phase**.

**Transition to Specification (Step 0 of /eiffel.spec):**
1. Run `/eiffel.spec d:\prod\simple_net` to generate 01-08 specification documents
2. Follow 8-step specification process:
   - 01-PARSED-REQUIREMENTS → Extract from this research
   - 02-DOMAIN-MODEL → Identify core concepts (CLIENT_SOCKET, CONNECTION, ADDRESS, ERROR)
   - 03-CHALLENGED-ASSUMPTIONS → Validate decisions against research
   - 04-CLASS-DESIGN → Translate decisions into class hierarchy
   - 05-CONTRACT-DESIGN → Formal DBC specifications
   - 06-INTERFACE-DESIGN → Public API design
   - 07-SPECIFICATION → Complete formal specification
   - 08-VALIDATION → Quality assurance gates

---
