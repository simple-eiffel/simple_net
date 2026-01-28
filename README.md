# simple_net

[Documentation](https://simple-eiffel.github.io/simple_net/) •
[GitHub](https://github.com/simple-eiffel/simple_net) •
[Issues](https://github.com/simple-eiffel/simple_net/issues)

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Eiffel 25.02](https://img.shields.io/badge/Eiffel-25.02-purple.svg)
![DBC: Contracts](https://img.shields.io/badge/DBC-Contracts-green.svg)

Production-ready TCP socket abstraction for Eiffel.

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem.

## Status

✅ **Production Ready** — v1.1.0
- 132 tests passing, 100% pass rate (core functionality)
- Enhanced contract strength with frame conditions (49 new postconditions)
- Comprehensive IPv4 validation (15+ edge case tests)
- Real SCOOP concurrency tests (12 separate object tests)
- TCP client/server sockets with intuitive API
- Design by Contract throughout
- Void-safe and SCOOP-compatible

## Quick Start

```eiffel
-- Create and connect client
client := create {SIMPLE_NET}.new_client_for_host_port ("example.com", 8080)
if client.connect then
    client.send_string ("Hello, server!")
    client.close
end
```

For complete documentation, see [our docs site](https://simple-eiffel.github.io/simple_net/).

## Features

- **CLIENT_SOCKET**: Intuitive TCP client with connect, send, receive, close
- **SERVER_SOCKET**: TCP server with listen, accept, configurable backlog
- **ADDRESS**: Immutable network endpoint (host:port) with IPv4 validation
- **ERROR_TYPE**: Semantic error classification (connection refused, timeout, etc.)
- **SIMPLE_NET**: Facade providing convenient factory methods

For details, see the [User Guide](https://simple-eiffel.github.io/simple_net/user-guide.html).

## Installation

```bash
# Add to your ECF:
<library name="simple_net" location="$SIMPLE_EIFFEL/simple_net/simple_net.ecf"/>
```

## License

MIT License - See LICENSE file

## Support

- **Docs:** https://simple-eiffel.github.io/simple_net/
- **GitHub:** https://github.com/simple-eiffel/simple_net
- **Issues:** https://github.com/simple-eiffel/simple_net/issues
