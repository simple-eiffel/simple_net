# SPECIFICATION: simple_net - Formal Eiffel Classes

**Date:** January 28, 2026
**Specification Phase:** Step 7 - Implementation Specification

---

## Overview

This document presents the complete Eiffel class specifications for simple_net. Each class includes:
- Full feature declarations
- Complete contracts (require/ensure/invariant)
- Comments documenting intent
- Inheritance structure
- Composition relationships

These specifications are ready for implementation via the /eiffel.implement workflow.

---

## File Organization

```
simple_net/
├── src/
│   ├── simple_net.e          -- Facade and constants
│   ├── address.e              -- Network endpoint value object
│   ├── error_type.e           -- Error classification enum
│   ├── connection.e           -- Active TCP stream
│   ├── client_socket.e        -- Outbound TCP socket
│   ├── server_socket.e        -- Inbound TCP socket
│   └── socket_base.e          -- Shared socket implementation
├── simple_net.ecf             -- Eiffel configuration file
└── tests/
    ├── test_simple_net.e      -- Facade tests
    ├── test_address.e         -- ADDRESS unit tests
    ├── test_connection.e      -- CONNECTION integration tests
    ├── test_client_socket.e   -- CLIENT_SOCKET tests
    ├── test_server_socket.e   -- SERVER_SOCKET tests
    └── test_error_handling.e  -- Error classification tests
```

---

## Class Specifications

### ADDRESS.e

```eiffel
indexing
    description: "Network endpoint (host:port) value object"
    author: "simple_net team"
    date: "2026-01-28"
    void_safety: "all"
    scoop: "thread_safe"

class ADDRESS

creation
    make_for_host_port,
    make_for_localhost_port

feature {NONE} -- Representation

    host_impl: STRING
        -- Hostname or IP address (immutable after creation)

    port_impl: INTEGER
        -- Port number 1-65535 (immutable after creation)

feature -- Creation

    make_for_host_port (a_host: STRING; a_port: INTEGER)
            -- Initialize address for host and port
            -- `a_host': hostname or IP address
            -- `a_port': port number (1-65535)
        require
            non_empty_host: a_host /= Void and then a_host.count > 0
            valid_port: a_port >= 1 and a_port <= 65535
        do
            host_impl := a_host
            port_impl := a_port
        ensure
            host_set: host = a_host
            port_set: port = a_port
        end

    make_for_localhost_port (a_port: INTEGER)
            -- Initialize address for localhost with port
        require
            valid_port: a_port >= 1 and a_port <= 65535
        do
            host_impl := "127.0.0.1"
            port_impl := a_port
        ensure
            host_is_loopback: is_loopback
            port_set: port = a_port
        end

feature -- Access

    host: STRING
            -- Hostname or IP address
        do
            Result := host_impl
        ensure
            result_not_void: Result /= Void
            result_not_empty: Result.count > 0
        end

    port: INTEGER
            -- Port number
        do
            Result := port_impl
        ensure
            in_range: Result >= 1 and Result <= 65535
        end

    as_string: STRING
            -- Human-readable form "host:port"
        do
            Result := host + ":" + port.out
        ensure
            result_not_void: Result /= Void
            result_contains_colon: Result.has(':')
        end

feature -- Queries

    is_loopback: BOOLEAN
            -- Is this localhost or 127.0.0.1?
        do
            Result := host.is_equal("localhost") or host.is_equal("127.0.0.1")
        end

    is_broadcast: BOOLEAN
            -- Is this broadcast address (255.255.255.255)?
        do
            Result := host.is_equal("255.255.255.255")
        end

    is_wildcard: BOOLEAN
            -- Is this wildcard address (0.0.0.0)?
        do
            Result := host.is_equal("0.0.0.0")
        end

    is_equal (other: like Current): BOOLEAN
            -- Are these addresses the same?
        do
            Result := host.is_equal(other.host) and port = other.port
        end

invariant
    host_valid: host.count > 0
    port_valid: port >= 1 and port <= 65535

end
```

---

### ERROR_TYPE.e

```eiffel
indexing
    description: "Error classification enum"
    author: "simple_net team"
    date: "2026-01-28"
    void_safety: "all"

class ERROR_TYPE

feature -- Error Categories

    no_error: INTEGER = 0
    connection_refused: INTEGER = 1
    connection_timeout: INTEGER = 2
    connection_reset: INTEGER = 3
    connection_closed: INTEGER = 4
    read_error: INTEGER = 5
    write_error: INTEGER = 6
    bind_error: INTEGER = 7
    listen_error: INTEGER = 8
    address_not_available: INTEGER = 9
    operation_cancelled: INTEGER = 10
    other: INTEGER = -1

feature -- Classification

    is_retriable (error_code: INTEGER): BOOLEAN
            -- Can operation be retried after this error?
        do
            Result :=
                error_code = connection_timeout or
                error_code = connection_reset or
                error_code = operation_cancelled
        ensure
            timeout_retriable: error_code = connection_timeout implies Result
            reset_retriable: error_code = connection_reset implies Result
            cancelled_retriable: error_code = operation_cancelled implies Result
            bind_not_retriable: error_code = bind_error implies not Result
        end

    is_fatal (error_code: INTEGER): BOOLEAN
            -- Is this error unrecoverable?
        do
            Result :=
                error_code = bind_error or
                error_code = address_not_available or
                error_code = listen_error
        ensure
            bind_fatal: error_code = bind_error implies Result
            address_fatal: error_code = address_not_available implies Result
        end

    description (error_code: INTEGER): STRING
            -- Human-readable error description
        do
            inspect error_code
            when no_error then
                Result := "No error"
            when connection_refused then
                Result := "Connection refused by server"
            when connection_timeout then
                Result := "Connection or operation timed out"
            when connection_reset then
                Result := "Connection reset by peer"
            when connection_closed then
                Result := "Connection closed by peer"
            when read_error then
                Result := "Error reading from socket"
            when write_error then
                Result := "Error writing to socket"
            when bind_error then
                Result := "Failed to bind to address"
            when listen_error then
                Result := "Failed to listen for connections"
            when address_not_available then
                Result := "Address not available or invalid"
            when operation_cancelled then
                Result := "Operation cancelled or timed out"
            else
                Result := "Unknown error"
            end
        ensure
            result_not_void: Result /= Void
            result_not_empty: Result.count > 0
        end

end
```

---

### CONNECTION.e

```eiffel
indexing
    description: "Active TCP connection (bidirectional stream)"
    author: "simple_net team"
    date: "2026-01-28"
    void_safety: "all"
    scoop: "separate"

class CONNECTION

creation
    make

feature {NONE} -- Representation

    underlying_socket: NETWORK_STREAM_SOCKET
        -- ISE net.ecf socket (hidden from users)

    error_code_impl: INTEGER
        -- Current error classification

    error_message_impl: STRING
        -- Error description for debugging

    timeout_impl: REAL
        -- Timeout in seconds

    bytes_sent_impl: INTEGER
        -- Cumulative bytes successfully sent

    bytes_received_impl: INTEGER
        -- Cumulative bytes successfully received

feature -- Creation

    make (socket: NETWORK_STREAM_SOCKET)
            -- Initialize connection from ISE socket
        require
            socket_not_void: socket /= Void
            socket_connected: socket.is_connected
        do
            underlying_socket := socket
            error_code_impl := 0
            create error_message_impl.make_from_string("")
            timeout_impl := 5.0  -- Default
            bytes_sent_impl := 0
            bytes_received_impl := 0
        ensure
            socket_set: underlying_socket = socket
            no_initial_error: not is_error
            connected: is_connected
        end

feature -- Status

    is_connected: BOOLEAN
            -- Is connection active?
        do
            Result := underlying_socket /= Void and then
                      underlying_socket.is_connected and then
                      error_code_impl = 0
        ensure
            connected_xor_error: Result xor is_error
        end

    is_at_end_of_stream: BOOLEAN
            -- Has peer closed connection (EOF)?
        require
            connected: is_connected
        do
            Result := error_code_impl = 4  -- connection_closed
        end

    is_error: BOOLEAN
            -- Did last operation fail?
        do
            Result := error_code_impl /= 0
        ensure
            iff_nonzero_code: Result = (error_code_impl /= 0)
        end

    error_classification: INTEGER
            -- Error type (ERROR_TYPE constant)
        require
            has_error: is_error
        do
            Result := error_code_impl
        end

    last_error_string: STRING
            -- Human-readable error description
        require
            has_error: is_error
        do
            Result := error_message_impl
        ensure
            result_not_void: Result /= Void
            result_not_empty: Result.count > 0
        end

feature -- I/O: Send

    send (data: ARRAY [BYTE]): BOOLEAN
            -- Send all bytes or error
        require
            connected: is_connected
            data_not_void: data /= Void
        local
            sent_so_far: INTEGER
            to_send: INTEGER
        do
            if data.count = 0 then
                Result := true
            else
                from
                    sent_so_far := 0
                    Result := true
                until
                    sent_so_far >= data.count or not Result
                loop
                    to_send := data.count - sent_so_far
                    -- ISE socket send operation here
                    -- If partial: continue loop
                    -- If error: set_error and Result := false
                    bytes_sent_impl := bytes_sent_impl + to_send
                    sent_so_far := sent_so_far + to_send
                end
            end
        ensure
            all_sent_or_error: Result = (bytes_sent >= old bytes_sent + data.count) or is_error
            bytes_monotonic: bytes_sent >= old bytes_sent
            frame_unchanged: bytes_received = old bytes_received
        end

    send_string (str: STRING): BOOLEAN
            -- Send string as bytes
        require
            connected: is_connected
            str_not_void: str /= Void
        do
            -- Convert string to bytes and call send()
            Result := true  -- Placeholder
        end

feature -- I/O: Receive

    receive (max_bytes: INTEGER): ARRAY [BYTE]
            -- Receive up to max_bytes
        require
            connected: is_connected
            valid_max: max_bytes > 0
        do
            create Result.make_filled (0, 1, 0)
            -- ISE socket receive operation here
            -- If data: update Result
            -- If EOF: set error_code = connection_closed, Result empty
            -- If error: set_error, Result empty
            bytes_received_impl := bytes_received_impl + Result.count
        ensure
            result_not_void: Result /= Void
            size_valid: Result.count <= max_bytes
            bytes_increased: bytes_received >= old bytes_received
        end

    receive_string (max_chars: INTEGER): STRING
            -- Receive string data
        require
            connected: is_connected
            valid_max: max_chars > 0
        do
            create Result.make_empty
            -- Convert receive() result to string
        end

feature -- Lifecycle

    close
            -- Close connection
        require
            not_already_closed: not is_closed
        do
            if underlying_socket /= Void then
                underlying_socket.close
            end
        ensure
            is_now_closed: is_closed
            not_connected: not is_connected
        end

    is_closed: BOOLEAN
            -- Is connection closed?
        do
            Result := underlying_socket = Void or else
                      not underlying_socket.is_open
        end

feature -- Configuration

    set_timeout (seconds: REAL)
            -- Set timeout for all operations
        require
            non_negative: seconds >= 0
        do
            timeout_impl := seconds
            if underlying_socket /= Void then
                underlying_socket.set_timeout (seconds.truncated_to_integer)
            end
        ensure
            timeout_set: timeout = seconds
        end

    timeout: REAL
            -- Current timeout setting
        do
            Result := timeout_impl
        ensure
            non_negative: Result >= 0
        end

feature -- Statistics

    bytes_sent: INTEGER
            -- Total bytes successfully sent
        do
            Result := bytes_sent_impl
        ensure
            non_negative: Result >= 0
        end

    bytes_received: INTEGER
            -- Total bytes successfully received
        do
            Result := bytes_received_impl
        ensure
            non_negative: Result >= 0
        end

feature {NONE} -- Implementation

    set_error (err_code: INTEGER; msg: STRING)
            -- Set error state (internal)
        require
            valid_code: (err_code >= 0 and err_code <= 10) or err_code = -1
            msg_not_void: msg /= Void
        do
            error_code_impl := err_code
            error_message_impl := msg
        ensure
            error_set: error_code_impl = err_code
        end

    clear_error
            -- Clear error state (internal)
        do
            error_code_impl := 0
            create error_message_impl.make_from_string("")
        ensure
            no_error: error_code_impl = 0
        end

invariant
    valid_error_code: (error_code_impl >= 0 and error_code_impl <= 10) or error_code_impl = -1
    connected_xor_error: not (is_connected and is_error)
    bytes_non_negative: bytes_sent >= 0 and bytes_received >= 0
    timeout_non_negative: timeout >= 0

end
```

---

### CLIENT_SOCKET.e

```eiffel
indexing
    description: "Outbound TCP socket (client)"
    author: "simple_net team"
    date: "2026-01-28"
    void_safety: "all"
    scoop: "thread_safe"

class CLIENT_SOCKET

creation
    make_for_host_port,
    make_for_address

feature {NONE} -- Representation

    remote_addr: ADDRESS
    local_addr: ADDRESS
    underlying_socket: NETWORK_STREAM_SOCKET
    error_code_impl: INTEGER
    error_message_impl: STRING
    timeout_impl: REAL

feature -- Creation

    make_for_host_port (host: STRING; port: INTEGER)
            -- Create client for remote server
        require
            valid_host: host /= Void and then host.count > 0
            valid_port: port >= 1 and port <= 65535
        do
            create remote_addr.make_for_host_port(host, port)
            error_code_impl := 0
            timeout_impl := 5.0
            create underlying_socket.make_for_address_port(host, port)
        ensure
            not_connected: not is_connected
            address_stored: remote_addr.host.is_equal(host) and remote_addr.port = port
            no_error: not is_error
        end

    make_for_address (addr: ADDRESS)
            -- Create client for address
        require
            address_not_void: addr /= Void
        do
            remote_addr := addr
            error_code_impl := 0
            timeout_impl := 5.0
            create underlying_socket.make_for_address_port(addr.host, addr.port)
        ensure
            not_connected: not is_connected
            address_set: remote_addr = addr
        end

feature -- Connection

    connect: BOOLEAN
            -- Establish connection to server
        require
            not_connected: not is_connected
            not_in_error: not is_error
        local
            was_successful: BOOLEAN
        do
            if underlying_socket /= Void then
                underlying_socket.connect
                was_successful := underlying_socket.is_connected
                if was_successful then
                    Result := true
                else
                    error_code_impl := 1  -- connection_refused (placeholder)
                    create error_message_impl.make_from_string("Connection failed")
                    Result := false
                end
            else
                Result := false
            end
        ensure
            connected_or_error: (is_connected and not is_error and Result) or
                               (not is_connected and is_error and not Result)
        end

    is_connected: BOOLEAN
            -- Is socket connected?
        do
            Result := underlying_socket /= Void and then
                      underlying_socket.is_connected and then
                      error_code_impl = 0
        ensure
            result_consistent: Result xor is_error
        end

    remote_address: ADDRESS
            -- Connected server address
        require
            is_connected: is_connected
        do
            Result := remote_addr
        ensure
            result_not_void: Result /= Void
        end

    local_address: ADDRESS
            -- Local endpoint address (if connected)
        require
            is_connected: is_connected
        do
            -- Extract from underlying_socket
            create Result.make_for_host_port("127.0.0.1", 0)
        ensure
            result_not_void: Result /= Void
        end

feature -- I/O

    send (data: ARRAY [BYTE]): BOOLEAN
            -- Send all bytes
        require
            is_connected: is_connected
            data_not_void: data /= Void
        do
            Result := true  -- Placeholder
        end

    send_string (str: STRING): BOOLEAN
            -- Send string
        require
            is_connected: is_connected
            str_not_void: str /= Void
        do
            Result := true  -- Placeholder
        end

    receive (max_bytes: INTEGER): ARRAY [BYTE]
            -- Receive up to max_bytes
        require
            is_connected: is_connected
            valid_max: max_bytes > 0
        do
            create Result.make_filled (0, 1, 0)  -- Placeholder
        end

    receive_string (max_chars: INTEGER): STRING
            -- Receive string
        require
            is_connected: is_connected
            valid_max: max_chars > 0
        do
            create Result.make_empty
        end

feature -- Lifecycle

    close
            -- Disconnect
        require
            not_already_closed: not is_closed
        do
            if underlying_socket /= Void then
                underlying_socket.close
            end
        ensure
            is_closed: is_closed
            not_connected: not is_connected
        end

    is_closed: BOOLEAN
        do
            Result := underlying_socket = Void or else
                      not underlying_socket.is_open
        end

feature -- Error State

    is_error: BOOLEAN
        do
            Result := error_code_impl /= 0
        end

    error_classification: INTEGER
        require
            is_error: is_error
        do
            Result := error_code_impl
        end

    last_error_string: STRING
        require
            is_error: is_error
        do
            Result := error_message_impl
        ensure
            result_not_void: Result /= Void
        end

feature -- Configuration

    set_timeout (seconds: REAL)
        require
            non_negative: seconds >= 0
        do
            timeout_impl := seconds
        ensure
            timeout_set: timeout = seconds
        end

    timeout: REAL
        do
            Result := timeout_impl
        ensure
            non_negative: Result >= 0
        end

invariant
    valid_error: error_code_impl /= 0 xor not is_error
    valid_address: remote_addr /= Void

end
```

---

### SERVER_SOCKET.e

```eiffel
indexing
    description: "Inbound TCP socket (server)"
    author: "simple_net team"
    date: "2026-01-28"
    void_safety: "all"
    scoop: "thread_safe"

class SERVER_SOCKET

creation
    make_for_port,
    make_for_address

feature {NONE} -- Representation

    local_addr: ADDRESS
    underlying_socket: NETWORK_STREAM_SOCKET
    listening_state: BOOLEAN
    backlog_size: INTEGER
    error_code_impl: INTEGER
    error_message_impl: STRING
    timeout_impl: REAL
    total_accepted: INTEGER

feature -- Creation

    make_for_port (port: INTEGER)
            -- Create server for port
        require
            valid_port: port >= 1 and port <= 65535
        do
            create local_addr.make_for_host_port("0.0.0.0", port)
            listening_state := false
            backlog_size := 0
            error_code_impl := 0
            timeout_impl := 5.0
            total_accepted := 0
            create underlying_socket.make
        ensure
            not_listening: not is_listening
            address_set: local_addr.port = port
        end

    make_for_address (addr: ADDRESS)
            -- Create server for address
        require
            address_not_void: addr /= Void
        do
            local_addr := addr
            listening_state := false
            backlog_size := 0
            error_code_impl := 0
            timeout_impl := 5.0
            total_accepted := 0
            create underlying_socket.make
        ensure
            not_listening: not is_listening
            address_set: local_addr = addr
        end

feature -- Listening

    listen (backlog: INTEGER)
            -- Start listening for connections
        require
            not_listening: not is_listening
            not_in_error: not is_error
            valid_backlog: backlog > 0
        do
            underlying_socket.bind(local_addr.host, local_addr.port)
            underlying_socket.listen(backlog)
            if underlying_socket.is_listening then
                listening_state := true
                backlog_size := backlog
            else
                error_code_impl := 7  -- bind_error
                create error_message_impl.make_from_string("Listen failed")
            end
        ensure
            listening_or_error: (is_listening and not is_error) or (not is_listening and is_error)
        end

    is_listening: BOOLEAN
        do
            Result := listening_state and underlying_socket /= Void and then
                      underlying_socket.is_listening
        ensure
            result_consistent: Result xor is_error
        end

    backlog: INTEGER
        require
            is_listening: is_listening
        do
            Result := backlog_size
        ensure
            positive: Result > 0
        end

feature -- Accepting

    accept: CONNECTION
            -- Accept new connection
        require
            is_listening: is_listening
            not_in_error: not is_error
        local
            new_socket: NETWORK_STREAM_SOCKET
        do
            if underlying_socket /= Void then
                new_socket := underlying_socket.accept
                if new_socket /= Void and then new_socket.is_connected then
                    create Result.make(new_socket)
                    total_accepted := total_accepted + 1
                else
                    error_code_impl := 2  -- connection_timeout (placeholder)
                    create error_message_impl.make_from_string("Accept failed")
                    Result := Void
                end
            else
                Result := Void
            end
        ensure
            success_implies_connected: Result /= Void implies Result.is_connected
            error_implies_void: is_error implies Result = Void
        end

    last_accepted_address: ADDRESS
        require
            has_accepted: total_accepted > 0
        do
            create Result.make_for_host_port("127.0.0.1", 0)  -- Placeholder
        ensure
            result_not_void: Result /= Void
        end

    local_address: ADDRESS
        require
            is_listening: is_listening
        do
            Result := local_addr
        ensure
            result_not_void: Result /= Void
        end

    connection_count: INTEGER
        do
            Result := total_accepted
        ensure
            non_negative: Result >= 0
        end

feature -- Lifecycle

    close
        require
            not_already_closed: not is_closed
        do
            if underlying_socket /= Void then
                underlying_socket.close
            end
            listening_state := false
        ensure
            is_closed: is_closed
            not_listening: not is_listening
        end

    is_closed: BOOLEAN
        do
            Result := underlying_socket = Void or else
                      not underlying_socket.is_open
        end

feature -- Error State

    is_error: BOOLEAN
        do
            Result := error_code_impl /= 0
        end

    error_classification: INTEGER
        require
            is_error: is_error
        do
            Result := error_code_impl
        end

    last_error_string: STRING
        require
            is_error: is_error
        do
            Result := error_message_impl
        ensure
            result_not_void: Result /= Void
        end

feature -- Configuration

    set_timeout (seconds: REAL)
        require
            non_negative: seconds >= 0
        do
            timeout_impl := seconds
        ensure
            timeout_set: timeout = seconds
        end

    timeout: REAL
        do
            Result := timeout_impl
        ensure
            non_negative: Result >= 0
        end

invariant
    listening_implies_backlog: is_listening implies backlog_size > 0
    connected_xor_error: not (is_listening and is_error)

end
```

---

### SIMPLE_NET.e

```eiffel
indexing
    description: "simple_net facade and factory"
    author: "simple_net team"
    date: "2026-01-28"
    void_safety: "all"

class SIMPLE_NET

feature -- Factory Methods

    new_client_for_host_port (host: STRING; port: INTEGER): CLIENT_SOCKET
            -- Create client socket
        require
            valid_host: host /= Void and then host.count > 0
            valid_port: port >= 1 and port <= 65535
        do
            create Result.make_for_host_port(host, port)
        ensure
            result_not_void: Result /= Void
            not_connected: not Result.is_connected
        end

    new_server_for_port (port: INTEGER): SERVER_SOCKET
            -- Create server socket
        require
            valid_port: port >= 1 and port <= 65535
        do
            create Result.make_for_port(port)
        ensure
            result_not_void: Result /= Void
            not_listening: not Result.is_listening
        end

    new_address_for_host_port (host: STRING; port: INTEGER): ADDRESS
            -- Create address
        require
            valid_host: host /= Void and then host.count > 0
            valid_port: port >= 1 and port <= 65535
        do
            create Result.make_for_host_port(host, port)
        ensure
            result_not_void: Result /= Void
            host_matches: Result.host.is_equal(host)
            port_matches: Result.port = port
        end

feature -- Constants

    default_timeout: REAL = 5.0
    max_backlog: INTEGER = 128
    min_port: INTEGER = 1
    max_port: INTEGER = 65535

feature -- Utilities

    is_valid_port (port: INTEGER): BOOLEAN
        do
            Result := port >= min_port and port <= max_port
        ensure
            iff_in_range: Result = (port >= min_port and port <= max_port)
        end

end
```

---

## Configuration File: simple_net.ecf

```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<system xmlns="http://www.eiffel.com/developers/xml/configuration-1-23-0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.eiffel.com/developers/xml/configuration-1-23-0 http://www.eiffel.com/developers/xml/configuration-1-23-0/configuration.xsd" name="simple_net" uuid="12345678-1234-5678-1234-567812345678">
	<target name="simple_net">
		<root class="SIMPLE_NET" feature="default_create"/>
		<file_rule>
			<exclude>/\.svn</exclude>
		</file_rule>
		<option warning="true" void_safety="all">
			<assertions precondition="true" postcondition="true" invariant="true"/>
		</option>
		<setting name="console_application" value="true"/>
		<setting name="name" value="simple_net"/>
		<setting name="version" value="1.0.0"/>
		<library name="base" location="$ISE_LIBRARY/library/base/base.ecf"/>
		<library name="net" location="$ISE_LIBRARY/library/net/net.ecf"/>
		<cluster name="simple_net" location="src\" recursive="true"/>
	</target>
	<target name="simple_net_tests" extends="simple_net">
		<root class="TEST_APP" feature="make"/>
		<option warning="true" void_safety="all">
			<assertions precondition="true" postcondition="true" invariant="true"/>
		</option>
		<library name="testing" location="$ISE_LIBRARY/library/testing/testing.ecf"/>
		<cluster name="tests" location="tests\" recursive="true"/>
	</target>
</system>
```

---

## Implementation Notes

1. **ISE Socket Integration:** Classes compose NETWORK_STREAM_SOCKET from ISE net.ecf; not all features fully specified here.

2. **Placeholder Comments:** Actual implementations of send/receive/connect logic will be filled in during /eiffel.implement phase.

3. **Error Mapping:** ISE socket errors must be mapped to ERROR_TYPE constants (0-10) during implementation.

4. **Timeout:** ISE socket timeout in milliseconds; convert from REAL seconds in preconditions.

5. **SCOOP:** Contracts documented; actual separate keyword usage in CLIENT_SOCKET/SERVER_SOCKET instantiation in client code (not library internals).

6. **Testing:** Test suite validates all contracts (assertion checking enabled).

---

