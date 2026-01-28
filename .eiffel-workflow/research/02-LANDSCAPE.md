# LANDSCAPE: simple_net - Socket Library Ecosystem

**Date:** January 28, 2026

---

## Executive Summary

**ISE net.ecf is production-ready but complex.** It requires deep socket knowledge and has confusing academic naming (NETWORK_STREAM_SOCKET, SOCKET_POLLER, INET_ADDRESS). Mainstream developers from Python, Go, Java expect simpler APIs with intuitive naming (connect, send, receive, listen).

**Gap:** No simple_* library wraps ISE's socket layer with practical, low-boilerplate semantics.

---

## Existing Solutions

### 1. ISE EiffelStudio net.ecf Library

| Aspect | Assessment |
|--------|------------|
| **Type** | FRAMEWORK (TCP/UDP socket library) |
| **Platform** | Eiffel (ISE EiffelStudio 25.02) |
| **URL** | Built-in: `/c/Program Files/Eiffel Software/EiffelStudio 25.02 Standard/library/net/` |
| **Maturity** | **MATURE** (20+ years, actively maintained) |
| **License** | ISE license (part of standard library) |
| **Language** | Eiffel (some C externals for system calls) |
| **Cost** | Free (included with EiffelStudio) |

**What It Does:**
- TCP client/server sockets (NETWORK_STREAM_SOCKET)
- UDP datagram sockets (DATAGRAM_SOCKET)
- IPv4 and IPv6 address handling (INET_ADDRESS with factory pattern)
- Blocking and non-blocking modes
- Timer-based async polling (SOCKET_POLLER with callback commands)
- Socket options (TCP_NODELAY, keepalive, buffer sizes, SO_REUSEADDR)
- Basic I/O operations (put_string, read_line, close)

**Strengths:**
- ✅ **Proven, maintained code** - Used in ISE's own NET_HTTP_CLIENT
- ✅ **Complete feature set** - All standard socket operations
- ✅ **Cross-platform** - Works Windows, Linux, macOS
- ✅ **SCOOP-compatible** - Thread-safe with proper synchronization
- ✅ **Void-safe available** - Modern Eiffel patterns
- ✅ **Integrated with Eiffel ecosystem** - Part of standard library
- ✅ **TCP/UDP support** - Both connection and datagram modes
- ✅ **Used in production** - simple_smtp, simple_cache (Redis), simple_http internally rely on it

**Weaknesses:**
- ❌ **Academic naming** - NETWORK_STREAM_SOCKET, INET_ADDRESS, SOCKET_POLLER unfamiliar to mainstream developers
- ❌ **Heavy boilerplate** - 50-100 LOC for simple client/server patterns
- ❌ **Manual state management** - Must check `is_connected`, `was_error` after operations
- ❌ **String-based errors** - No exception raising; must check `socket_error` string manually
- ❌ **Naming confusion** - `put_string` / `read_line` from old FILE API, not socket conventions
- ❌ **Timeout complexity** - Two separate timeout settings (connect_timeout vs accept_timeout)
- ❌ **SOCKET_POLLER is awkward** - Timer-based, callback-driven; not intuitive for event-driven async
- ❌ **Hidden state** - Results stored in `last_string`, `accepted` properties (easy to miss)
- ❌ **No connection pooling** - Must manage socket reuse yourself
- ❌ **No retry logic** - Transient failures handled manually

**Relevance to simple_net:** **100%** - This is the foundation we'll wrap

**Used By:**
- simple_http (via ISE's NET_HTTP_CLIENT wrapper)
- simple_smtp (direct NETWORK_STREAM_SOCKET usage)
- simple_cache / simple_redis (direct NETWORK_STREAM_SOCKET usage)
- simple_websocket (protocol layer; would use raw net for frame transport)

---

### 2. Python socket Library (Python 3.x)

| Aspect | Assessment |
|--------|------------|
| **Type** | STANDARD LIBRARY |
| **Platform** | Python 3.x |
| **URL** | https://docs.python.org/3/library/socket.html |
| **Maturity** | **MATURE** (30+ years, de facto standard) |
| **License** | PSF (Python Software Foundation) |
| **Popularity** | **UBIQUITOUS** - Every Python developer knows this API |

**What It Does:**
```python
# Client
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(('hostname', 8080))
sock.send(b'hello')
data = sock.recv(1024)
sock.close()

# Server
server = socket.socket()
server.bind(('0.0.0.0', 8080))
server.listen(5)
client, addr = server.accept()
client.recv(1024)
client.send(b'response')
client.close()
```

**Strengths:**
- ✅ **Intuitive API** - `connect()`, `send()`, `recv()`, `close()` are self-documenting
- ✅ **Minimal boilerplate** - 3-5 lines for client, 5-8 lines for server
- ✅ **Explicit naming** - `SOCK_STREAM` (TCP), `SOCK_DGRAM` (UDP) clear
- ✅ **Error handling** - Exceptions raised, not silent failures
- ✅ **Timeouts simple** - Single `settimeout(seconds)` method
- ✅ **Async support** - asyncio, trio, gevent layer on top
- ✅ **Context managers** - `with socket: ...` for cleanup
- ✅ **Well-documented** - 30 years of tutorials and SO answers

**Weaknesses:**
- ❌ **Too low-level for some** - Still require understanding socket theory
- ❌ **Manual connection pooling** - asyncio/aiohttp layer needed for production use
- ❌ **Error handling can be verbose** - Different exceptions for different failure modes

**Relevance to simple_net:** **95%** - This is the SEMANTIC TARGET for simple_net naming/API design

**Why Mainstream Developers Expect This Style:**
- Python socket is the de facto standard for socket APIs in modern languages
- Go's `net.Dial()` / `net.Listen()` follows same pattern
- Java's `Socket` / `ServerSocket` follow same pattern
- JavaScript's `net.Socket` follows same pattern
- Rust's `std::net::TcpStream` / `TcpListener` follow same pattern

---

### 3. Go net Package

| Aspect | Assessment |
|--------|------------|
| **Type** | STANDARD LIBRARY |
| **Platform** | Go 1.x |
| **URL** | https://golang.org/pkg/net/ |
| **Maturity** | **MODERN** (2009+, idiomatic for concurrent network code) |
| **License** | BSD 3-Clause |

**Key Patterns:**
```go
// Client
conn, err := net.Dial("tcp", "hostname:8080")
conn.Write([]byte("hello"))
buf := make([]byte, 1024)
conn.Read(buf)
conn.Close()

// Server
listener, _ := net.Listen("tcp", ":8080")
for {
    conn, _ := listener.Accept()
    go handleClient(conn)
}
```

**Strengths:**
- ✅ **Goroutine-native** - Each connection runs in lightweight thread
- ✅ **Error handling first** - `conn, err := Dial()` pattern ubiquitous
- ✅ **Clean interfaces** - `net.Conn` abstraction works for TCP, UDP, Unix
- ✅ **No boilerplate** - Same 5-line pattern for all connection types
- ✅ **Built-in timeouts** - `conn.SetDeadline()` , `conn.SetReadDeadline()`

**Weaknesses:**
- ❌ **Requires concurrency mindset** - Not suited to sequential code
- ❌ **Error handling verbose** - `err != nil` checks everywhere

**Relevance to simple_net:** **85%** - Confirms the pattern: imperative, minimal boilerplate, goroutines ≈ SCOOP threads

---

### 4. Java NIO (java.nio.channels)

| Aspect | Assessment |
|--------|------------|
| **Type** | STANDARD LIBRARY (modern alternative) |
| **Platform** | Java 7+ |
| **URL** | https://docs.oracle.com/javase/7/docs/api/java/nio/channels/SocketChannel.html |
| **Maturity** | **MATURE** (2001+, industry standard for high-concurrency servers) |

**Key Patterns (Blocking Mode - Similar to simple_net MVP):**
```java
// Client
SocketChannel sock = SocketChannel.open();
sock.connect(new InetSocketAddress("hostname", 8080));
sock.write(ByteBuffer.wrap("hello".getBytes()));
ByteBuffer buf = ByteBuffer.allocate(1024);
sock.read(buf);
sock.close();

// Server
ServerSocketChannel server = ServerSocketChannel.open();
server.bind(new InetSocketAddress("::", 8080));
server.configureBlocking(true);
while (true) {
    SocketChannel client = server.accept();
    // handle client
}
```

**Strengths:**
- ✅ **Abstract interfaces** - `SocketChannel` abstraction
- ✅ **Dual-mode** - Blocking and non-blocking modes
- ✅ **Buffer-based I/O** - More efficient than stream copying
- ✅ **Selectors for async** - `Selector` enables non-blocking polling

**Weaknesses:**
- ❌ **Verbose APIs** - 10+ lines for simple operations
- ❌ **ByteBuffer complexity** - Position/limit/capacity state management
- ❌ **Not as intuitive** - Less accessible to beginners

**Relevance to simple_net:** **70%** - NIO shows good abstraction patterns; ByteBuffer concept useful for Phase 2

---

## Eiffel Ecosystem Check

### ISE Libraries (Besides net.ecf)

- **ISE net.ecf** (net/) - Raw socket implementation ✅ EXIST, TARGET
- **ISE http_network** (contrib/library/network/http_network/) - HTTP over sockets
- **ISE websocket** (contrib/library/network/websocket/) - RFC 6455 WebSocket

### simple_* Libraries

| Library | Purpose | Uses Raw net.ecf? | Abstractoin Level |
|---------|---------|-------------------|-------------------|
| simple_http | HTTP client | NO - uses ISE's NET_HTTP_CLIENT | High (HTTP protocol) |
| simple_smtp | SMTP client | YES - direct NETWORK_STREAM_SOCKET | Medium (SMTP protocol) |
| simple_cache | Redis client | YES - direct NETWORK_STREAM_SOCKET | Medium (Redis protocol) |
| simple_ipc | IPC (Windows named pipes) | NO - uses Windows API directly | High (IPC protocol) |
| simple_websocket | WebSocket RFC 6455 | MAYBE - protocol layer exists, transport unclear | High (WS protocol) |

**Gap Analysis:**

❌ **No simple_net library exists** - All direct consumption of net.ecf has these problems:
1. Each library implements its own connection management (timeouts, retries, error handling)
2. Boilerplate repeated across libraries (connect, error check, send, receive loop, close)
3. No consistent error handling semantics (simple_smtp vs simple_cache handle errors differently)
4. Protocol logic tangled with socket I/O (hard to test independently)

✅ **What simple_net would provide:**
1. **Unified abstraction** - All libraries use same CONNECTION interface
2. **DRY principle** - Connection pooling, retries, timeouts in one place
3. **Consistent errors** - All socket errors handled uniformly
4. **Protocol/transport separation** - Let simple_websocket focus on RFC 6455, not sockets

---

### Gobo Libraries

- **Gobo net library** - Similar to ISE net.ecf, academic naming, not an alternative

**Verdict:** Gobo socket layer has same academic approach; simple_net would improve both Gobo and ISE

---

## Socket Library Comparison Matrix

| Feature | ISE net.ecf | Python socket | Go net | Java NIO | **simple_net (target)** |
|---------|------------|----------------|--------|----------|------------------------|
| **Naming Intuition** | ❌ POOR (NETWORK_STREAM_SOCKET) | ✅ EXCELLENT (socket()) | ✅ EXCELLENT (Dial, Listen) | ⚠️ MODERATE (SocketChannel) | ✅ EXCELLENT (ClientSocket, ServerSocket) |
| **Boilerplate LOC** | ⚠️ 50-100 | ✅ 3-5 | ✅ 3-5 | ❌ 10-20 | ✅ TARGET: 5-10 |
| **Error Handling** | ⚠️ Manual checks (was_error) | ✅ Exceptions | ✅ err != nil | ✅ Exceptions | ✅ TARGET: Clear, queryable |
| **Timeout API** | ⚠️ Two settings (connect vs accept) | ✅ Single settimeout() | ✅ SetDeadline() | ✅ Socket timeout | ✅ TARGET: Single, intuitive |
| **Async/Concurrency** | ❌ SOCKET_POLLER awkward | ✅ asyncio/trio | ✅ Goroutines | ✅ Selector pattern | ✅ TARGET: SCOOP threads natural |
| **Connection Pooling** | ❌ Manual | ⚠️ aiohttp/urllib3 layer | ✅ TCP_REUSE_ADDR | ⚠️ Manual | ✅ TARGET: Built-in support |
| **IPv4/IPv6** | ✅ Both (INET_ADDRESS abstraction) | ✅ Both | ✅ Both | ✅ Both | ✅ Both (simple_net first, IPv6 Phase 2) |
| **DBC/Contracts** | ⚠️ Some, not comprehensive | ❌ Not applicable (Python) | ❌ Not applicable (Go) | ❌ Not applicable (Java) | ✅ TARGET: 100% DBC |
| **SCOOP Compatible** | ✅ Yes (with care) | ❌ Not applicable | ❌ Not applicable | ⚠️ Synchronization needed | ✅ TARGET: SCOOP-first |

---

## Patterns Identified for Adoption

| Pattern | Seen In | Adopt for simple_net? | Notes |
|---------|---------|----------------------|-------|
| **Imperative connect/listen/accept** | Python, Go, Java | ✅ YES | Intuitive for developers, replaces NETWORK_STREAM_SOCKET |
| **Single timeout setting** | Python (`settimeout()`), Go (`SetDeadline()`) | ✅ YES | Replace ISE's two-timeout complexity |
| **Error via exceptions OR result queries** | Python (exceptions), ISE (queries) | ✅ QUERIES (Eiffel convention) | Use `is_connected`, `last_error` not exceptions |
| **Connection abstraction** | Go (net.Conn interface), Java (SocketChannel) | ✅ YES | Abstract CONNECTION over NETWORK_STREAM_SOCKET |
| **Separate client and server sockets** | Python (socket() used for both), Go (Dial vs Listen) | ✅ PARTIALLY | Offer CLIENT_SOCKET, SERVER_SOCKET for clarity; they may share implementation |
| **Blocking mode MVP, async Phase 2** | All | ✅ YES | Blocking is simpler and sufficient for gRPC/WebSocket Phase 1 |
| **Builder/factory pattern for address** | Go, Java | ✅ YES | Simple (HOST, PORT) tuple replaces INET_ADDRESS factory complexity |
| **Read partial data handling** | Java (ByteBuffer position), Go (n, err := Read()) | ✅ YES | Track bytes_read, handle partial writes |
| **Context managers for cleanup** | Python (with statement) | ✅ YES (Eiffel pattern) | Ensure connection is closed in all paths |

---

## Build vs Buy vs Adapt Decision

| Option | Effort | Risk | Fit | Assessment |
|--------|--------|------|-----|------------|
| **Build simple_net from scratch** (wrap ISE net.ecf) | MEDIUM (3-5 days) | LOW (ISE proven) | PERFECT | ✅ RECOMMENDED |
| **Use ISE net.ecf directly** (don't build simple_net) | NONE | HIGH (boilerplate, complexity) | POOR | ❌ REJECTED - defeats purpose |
| **Adopt external library** (e.g., EWF HTTP socket) | LOW (2 days integration) | MEDIUM (dependency on ISE) | MODERATE | ⚠️ PARTIAL - Only for HTTP; simple_net needed for gRPC |
| **Adapt ISE websocket to general-purpose** | MEDIUM (refactor for TCP/UDP) | MEDIUM (ISE internal patterns) | GOOD | ✅ COULD WORK - But simple_net is cleaner |
| **Port Python socket.socket to Eiffel** | HIGH (reimplement socket layer) | HIGH (system calls) | EXCELLENT | ❌ TOO MUCH WORK - Reinvents ISE net |

**RECOMMENDATION: BUILD** ✅

Wrap ISE net.ecf with simple_net that:
1. Provides intuitive, US-developer-friendly naming (connect, listen, accept, send, receive)
2. Hides boilerplate (automatic error checking, connection state tracking)
3. Follows simple_* patterns (DBC, SCOOP-compatible, void-safe)
4. Separates protocol logic from socket I/O (enables reuse across libraries)

---

## References

### ISE EiffelStudio Net Library
- `/c/Program Files/Eiffel Software/EiffelStudio 25.02 Standard/library/net/` - Source code
- File: NETWORK_STREAM_SOCKET.e (510 lines) - Concrete implementation
- File: SOCKET.e (1238 lines) - Abstract base class
- File: SOCKET_POLLER.e (491 lines) - Async polling mechanism

### Python Socket Documentation
- https://docs.python.org/3/library/socket.html - Official documentation
- https://docs.python.org/3/howto/sockets.html - Socket Programming HowTo

### Go Net Package
- https://golang.org/pkg/net/ - Official net package documentation
- https://golang.org/doc/effective_go - Design philosophy

### Java NIO
- https://docs.oracle.com/javase/tutorial/nio/channels/ - Java NIO Tutorial
- https://docs.oracle.com/javase/7/docs/api/java/nio/channels/SocketChannel.html - SocketChannel API

### Eiffel Ecosystem Usage Examples
- `/d/prod/simple_smtp/src/simple_smtp.e` - Direct NETWORK_STREAM_SOCKET usage (900+ LOC)
- `/d/prod/simple_cache/src/redis/simple_redis.e` - Redis protocol over NETWORK_STREAM_SOCKET
- `/d/prod/simple_http/simple_http.ecf` - Uses ISE's NET_HTTP_CLIENT (not raw net)
- `/d/prod/simple_websocket/` - WebSocket protocol layer (transport TBD)

---
