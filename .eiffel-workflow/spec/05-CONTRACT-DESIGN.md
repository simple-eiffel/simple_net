# CONTRACT DESIGN: simple_net - Full DBC Specification

**Date:** January 28, 2026
**Specification Phase:** Step 5 - Formal Contracts

---

## Overview

This document specifies complete Design by Contract (DBC) for all public classes. Each class includes:
- **Invariants** - Always-true properties
- **Preconditions** - What must be true BEFORE an operation
- **Postconditions** - What must be true AFTER an operation
- **Frame Conditions** - What state did NOT change
- **MML Model Queries** - Mathematical specifications

---

## Notation

```
┌─ Precondition (require)
│
├─ Postcondition (ensure)
│
├─ Invariant
│
└─ MML Model Queries (ensure ... |=| ...)
```

---

## Address Contract

```eiffel
class ADDRESS

feature {NONE} -- Representation
    host_string: STRING
    port_number: INTEGER

invariant
    valid_host: host_string.length > 0
    valid_port: port_number >= 1 and port_number <= 65535

feature -- Creation

    make_for_host_port (a_host: STRING; a_port: INTEGER)
        require
            non_empty_host: a_host /= Void and a_host.length > 0
            valid_port: a_port >= 1 and a_port <= 65535
        ensure
            host_set: host = a_host
            port_set: port = a_port
            immutable: host = old host and port = old port
        end

    make_for_localhost_port (a_port: INTEGER)
        require
            valid_port: a_port >= 1 and a_port <= 65535
        ensure
            port_set: port = a_port
            is_local: is_loopback
            immutable: host = old host and port = old port
        end

feature -- Access

    host: STRING
        ensure
            non_empty: Result.length > 0
        end

    port: INTEGER
        ensure
            in_range: Result >= 1 and Result <= 65535
        end

    as_string: STRING
        -- "host:port" format
        ensure
            format_correct: Result.contains(":") and Result.starts_with(host)
            not_empty: Result.length > 0
        end

feature -- Queries

    is_loopback: BOOLEAN
        ensure
            result_consistent: Result = (host.is_equal("localhost") or host.is_equal("127.0.0.1"))
        end

    is_broadcast: BOOLEAN
        ensure
            result_consistent: Result = host.is_equal("255.255.255.255")
        end

    is_equal (other: ADDRESS): BOOLEAN
        require
            other_not_void: other /= Void
        ensure
            symmetric: Result = other.is_equal(Current)
            host_and_port_match: Result = (host.is_equal(other.host) and port = other.port)
        end

end
```

---

## Error_Type Contract

```eiffel
class ERROR_TYPE

feature -- Error Classification

    is_retriable (error_code: INTEGER): BOOLEAN
        ensure
            connection_timeout_retriable: error_code = connection_timeout implies Result
            connection_reset_retriable: error_code = connection_reset implies Result
            operation_cancelled_retriable: error_code = operation_cancelled implies Result
            bind_error_not_retriable: error_code = bind_error implies not Result
            address_not_available_not_retriable: error_code = address_not_available implies not Result
        end

    is_fatal (error_code: INTEGER): BOOLEAN
        ensure
            bind_error_fatal: error_code = bind_error implies Result
            address_not_available_fatal: error_code = address_not_available implies Result
            timeout_not_fatal: error_code = connection_timeout implies not Result
        end

    description (error_code: INTEGER): STRING
        ensure
            non_empty: Result.length > 0
            deterministic: description(error_code).is_equal(old description(error_code))
        end

end
```

---

## Connection Contract

```eiffel
class CONNECTION

feature {NONE} -- Representation
    underlying: NETWORK_STREAM_SOCKET
    error_code: INTEGER
    error_message: STRING
    bytes_sent_count: INTEGER
    bytes_received_count: INTEGER
    timeout_seconds: REAL

invariant
    valid_error_code: (error_code >= 0 and error_code <= 10) or error_code = -1
    bytes_non_negative: bytes_sent >= 0 and bytes_received >= 0
    valid_timeout: timeout >= 0
    not_connected_and_error: not (is_connected and is_error)
        -- Connection cannot be simultaneously active and in error state
    bytes_increase_only: bytes_sent = old bytes_sent and bytes_received = old bytes_received
        -- Bytes only increase over operation lifespan

feature -- Status Queries

    is_connected: BOOLEAN
        ensure
            connected_xor_error: Result = not is_error
        end

    is_at_end_of_stream: BOOLEAN
        require
            connected: is_connected
        ensure
            eof_implies_peer_closed: Result implies (error_code = connection_closed or last_send_failed)
        end

    is_error: BOOLEAN
        ensure
            error_iff_nonzero_code: Result = (error_code /= 0)
        end

    error_classification: ERROR_TYPE
        require
            is_error: is_error
        ensure
            code_matches: Result = error_code
        end

    last_error_string: STRING
        require
            is_error: is_error
        ensure
            non_empty: Result.length > 0
            matches_message: Result = error_message
        end

feature -- I/O Operations: Send

    send (data: ARRAY [BYTE]): BOOLEAN
        require
            connected: is_connected
            not_at_eof: not is_at_end_of_stream
            data_not_void: data /= Void
        ensure
            all_sent_or_error: Result = (bytes_sent = old bytes_sent + data.count) or is_error
            bytes_monotonic: bytes_sent >= old bytes_sent
            error_implies_failure: is_error implies not Result
            success_implies_no_error: Result implies not is_error
            frame_received_unchanged: bytes_received = old bytes_received
        end

    send_string (str: STRING): BOOLEAN
        require
            connected: is_connected
            not_at_eof: not is_at_end_of_stream
            str_not_void: str /= Void
        ensure
            success_or_error: Result xor is_error
            bytes_sent_increased: bytes_sent >= old bytes_sent
        end

feature -- I/O Operations: Receive

    receive (max_bytes: INTEGER): ARRAY [BYTE]
        require
            connected: is_connected
            valid_max: max_bytes > 0
        ensure
            result_not_void: Result /= Void
            result_size_valid: Result.count <= max_bytes
            bytes_received_increased: bytes_received >= old bytes_received
            bytes_added_matches_result: bytes_received = old bytes_received + Result.count
            frame_sent_unchanged: bytes_sent = old bytes_sent
            eof_has_zero_bytes: is_at_end_of_stream implies Result.count = 0
        end

    receive_string (max_chars: INTEGER): STRING
        require
            connected: is_connected
            valid_max: max_chars > 0
        ensure
            result_not_void: Result /= Void
            result_size_valid: Result.count <= max_chars
            bytes_received_increased: bytes_received >= old bytes_received
        end

feature -- Lifecycle

    close
        require
            not_already_closed: not is_closed
        ensure
            is_now_closed: is_closed
            not_connected: not is_connected
            bytes_preserved: bytes_sent = old bytes_sent and bytes_received = old bytes_received
        end

    is_closed: BOOLEAN
        ensure
            closed_implies_disconnected: Result implies not is_connected
        end

feature -- Configuration

    set_timeout (seconds: REAL)
        require
            non_negative: seconds >= 0
        ensure
            timeout_set: timeout = seconds
        end

    timeout: REAL
        ensure
            non_negative: Result >= 0
        end

feature -- Statistics

    bytes_sent: INTEGER
        ensure
            non_negative: Result >= 0
        end

    bytes_received: INTEGER
        ensure
            non_negative: Result >= 0
        end

end
```

---

## Client_Socket Contract

```eiffel
class CLIENT_SOCKET

inherit SOCKET_BASE

feature {NONE} -- Representation
    remote_addr: ADDRESS
    local_addr: ADDRESS
    connection_state: INTEGER  -- 0=new, 1=connected, 2=closed, -1=error

invariant
    valid_state: connection_state >= -1 and connection_state <= 2
    address_if_connected: connection_state = 1 implies remote_addr /= Void
    not_error_and_connected: not (is_error and is_connected)

feature -- Creation

    make_for_host_port (host: STRING; port: INTEGER)
        require
            non_empty_host: host /= Void and host.length > 0
            valid_port: port >= 1 and port <= 65535
        ensure
            not_connected: not is_connected
            address_stored: remote_addr /= Void and remote_addr.host.is_equal(host) and remote_addr.port = port
            no_error: not is_error
        end

    make_for_address (addr: ADDRESS)
        require
            address_not_void: addr /= Void
        ensure
            not_connected: not is_connected
            address_stored: remote_addr = addr
            no_error: not is_error
        end

feature -- Connection

    connect: BOOLEAN
        require
            not_connected: not is_connected
            not_in_error: not is_error
        ensure
            connected_or_error: (is_connected and not is_error and Result) or (not is_connected and is_error and not Result)
            not_both: not (is_connected and is_error)
            state_mutated: Result implies (old is_connected = false and is_connected = true)
        end

    is_connected: BOOLEAN
        ensure
            connected_iff_state: Result = (connection_state = 1)
            exclusive_with_error: Result xor is_error
        end

    remote_address: ADDRESS
        require
            connected: is_connected
        ensure
            result_not_void: Result /= Void
            result_matches: Result = remote_addr
        end

    local_address: ADDRESS
        require
            connected: is_connected
        ensure
            result_not_void: Result /= Void
        end

feature -- I/O (inherited from SOCKET_BASE)

    send (data: ARRAY [BYTE]): BOOLEAN
        require
            connected: is_connected
        end

    receive (max_bytes: INTEGER): ARRAY [BYTE]
        require
            connected: is_connected
        end

feature -- Lifecycle

    close
        require
            not_already_closed: not is_closed
        ensure
            is_closed: is_closed
            not_connected: not is_connected
            connection_state_updated: connection_state = 2
        end

end
```

---

## Server_Socket Contract

```eiffel
class SERVER_SOCKET

inherit SOCKET_BASE

feature {NONE} -- Representation
    local_addr: ADDRESS
    listening_state: BOOLEAN
    backlog_size: INTEGER
    connection_counter: INTEGER  -- Total accepted connections

invariant
    valid_backlog: listening_state implies backlog_size > 0
    address_if_listening: listening_state implies local_addr /= Void
    not_error_and_listening: not (is_error and is_listening)
    connection_counter_non_negative: connection_counter >= 0

feature -- Creation

    make_for_port (port: INTEGER)
        require
            valid_port: port >= 1 and port <= 65535
        ensure
            not_listening: not is_listening
            local_addr_set: local_addr /= Void and local_addr.port = port
            no_error: not is_error
        end

    make_for_address (addr: ADDRESS)
        require
            address_not_void: addr /= Void
        ensure
            not_listening: not is_listening
            local_addr_set: local_addr = addr
            no_error: not is_error
        end

feature -- Listening

    listen (backlog_queue_size: INTEGER)
        require
            not_listening: not is_listening
            not_in_error: not is_error
            valid_backlog: backlog_queue_size > 0
        ensure
            listening_or_error: (is_listening and not is_error) or (not is_listening and is_error)
            backlog_set_if_success: is_listening implies backlog = backlog_queue_size
        end

    is_listening: BOOLEAN
        ensure
            listening_iff_state: Result = listening_state
            exclusive_with_error: Result xor is_error
        end

    backlog: INTEGER
        require
            listening: is_listening
        ensure
            positive: Result > 0
        end

feature -- Accepting Connections

    accept: CONNECTION
        require
            listening: is_listening
            not_in_error: not is_error
        ensure
            result_or_void: Result /= Void or is_error
            success_implies_connected: Result /= Void implies Result.is_connected
            error_implies_void: is_error implies Result = Void
            connection_counter_increased: connection_counter = old connection_counter + (Result /= Void).to_integer
            frame_unchanged: is_listening = old is_listening
        end

    last_accepted_address: ADDRESS
        require
            has_accepted: connection_counter > 0
        ensure
            result_not_void: Result /= Void
        end

feature -- Server Info

    local_address: ADDRESS
        require
            listening: is_listening
        ensure
            result_not_void: Result /= Void
            result_matches: Result = local_addr
        end

    connection_count: INTEGER
        ensure
            non_negative: Result >= 0
            cumulative: Result = connection_counter
        end

feature -- Lifecycle

    close
        require
            not_already_closed: not is_closed
        ensure
            is_closed: is_closed
            not_listening: not is_listening
            counter_preserved: connection_count = old connection_count
        end

end
```

---

## Socket_Base Contract (Deferred)

```eiffel
deferred class SOCKET_BASE

feature {SOCKET_BASE, CLIENT_SOCKET, SERVER_SOCKET} -- Protected

    underlying_socket: NETWORK_STREAM_SOCKET
        -- ISE socket (hidden)

    error_code: INTEGER
        -- ERROR_TYPE value

    error_message: STRING
        -- Error description

    timeout_value: REAL
        -- Current timeout

    set_error (err_code: INTEGER; msg: STRING)
        require
            valid_code: (err_code >= 0 and err_code <= 10) or err_code = -1
            msg_not_void: msg /= Void
        deferred
        ensure
            error_set: error_code = err_code
            message_set: error_message = msg
        end

    clear_error
        deferred
        ensure
            no_error: error_code = 0
        end

    initialize_socket
        deferred
        ensure
            underlying_created: underlying_socket /= Void
            no_initial_error: error_code = 0
        end

    cleanup_socket
        deferred
        ensure
            underlying_closed: underlying_socket = Void or not underlying_socket.is_open
        end

feature -- Common Interface

    is_error: BOOLEAN
        ensure
            iff_nonzero_code: Result = (error_code /= 0)
        end

    error_classification: ERROR_TYPE
        require
            has_error: is_error
        ensure
            result_matches: Result = error_code
        end

    last_error_string: STRING
        require
            has_error: is_error
        ensure
            non_empty: Result.length > 0
            deterministic: Result = old error_message
        end

    set_timeout (seconds: REAL)
        require
            non_negative: seconds >= 0
        ensure
            timeout_set: timeout = seconds
        end

    timeout: REAL
        ensure
            non_negative: Result >= 0
        end

    close
        require
            not_already_closed: not is_closed
        deferred
        ensure
            is_closed: is_closed
        end

    is_closed: BOOLEAN
        ensure
            closed_consistent: Result implies error_code /= connection_closed
        end

invariant
    valid_error_code: (error_code >= 0 and error_code <= 10) or error_code = -1
    error_message_if_error: error_code /= 0 implies error_message.length > 0
    valid_timeout: timeout_value >= 0
    exclusive_error: is_error xor not is_error  -- Tautology, but documents intention

end
```

---

## Simple_Net Contract (Facade)

```eiffel
class SIMPLE_NET

feature -- Factory Methods

    new_client_for_host_port (host: STRING; port: INTEGER): CLIENT_SOCKET
        require
            non_empty_host: host /= Void and host.length > 0
            valid_port: port >= 1 and port <= 65535
        ensure
            result_not_void: Result /= Void
            not_connected: not Result.is_connected
            socket_created: Result /= Void
        end

    new_server_for_port (port: INTEGER): SERVER_SOCKET
        require
            valid_port: port >= 1 and port <= 65535
        ensure
            result_not_void: Result /= Void
            not_listening: not Result.is_listening
            socket_created: Result /= Void
        end

    new_address_for_host_port (host: STRING; port: INTEGER): ADDRESS
        require
            non_empty_host: host /= Void and host.length > 0
            valid_port: port >= 1 and port <= 65535
        ensure
            result_not_void: Result /= Void
            host_matches: Result.host.is_equal(host)
            port_matches: Result.port = port
        end

feature -- Constants

    default_timeout: REAL
        ensure
            positive: Result > 0
            deterministic: Result = old default_timeout
        end

    max_backlog: INTEGER
        ensure
            positive: Result > 0
            deterministic: Result = old max_backlog
        end

    min_port: INTEGER
        ensure
            result: Result = 1
        end

    max_port: INTEGER
        ensure
            result: Result = 65535
        end

feature -- Utility

    is_valid_port (port: INTEGER): BOOLEAN
        ensure
            iff_in_range: Result = (port >= min_port and port <= max_port)
        end

end
```

---

## MML Model Queries (Advanced)

For complex state verification, postconditions can use MML (Mathematical Model Language):

```eiffel
-- SERVER_SOCKET model (example)

feature {NONE} -- MML Models

    accepted_connections_model: MML_SET [INTEGER]
        -- Set of accepted connection IDs

invariant
    accepted_connections_size: accepted_connections_model.count = connection_counter

feature -- Verification

    accept: CONNECTION
        ensure
            connection_tracked: Result /= Void implies accepted_connections_model |=|
                (old accepted_connections_model & create {MML_SET [INTEGER]}.singleton(connection_counter))
        end

```

---

## Contract Testing Strategy

| Feature | Contract Check | Unit Test | Integration Test |
|---------|---------------|---------|----|
| **send** | Precondition: is_connected | Send empty array | Send to unreachable server |
| **receive** | Postcondition: bytes_received increases | Receive exact bytes sent | Receive EOF on close |
| **connect** | Postcondition: is_connected or is_error | Connect to localhost | Connect to refused port |
| **accept** | Precondition: is_listening | Accept without listen (should fail) | Accept 100 concurrent clients |
| **listen** | Postcondition: is_listening | Listen twice (second should fail) | Listen on ephemeral port |
| **close** | Postcondition: is_closed | Close twice (second should fail) | Close mid-transfer |
| **set_timeout** | Precondition: seconds >= 0 | Set negative timeout | Timeout on 100ms operation |
| **error_classification** | Precondition: is_error | Get error when no error | Classify all error types |

---

## Frame Conditions Summary

**What NEVER changes:**
- Past bytes sent (can only increase)
- Past bytes received (can only increase)
- Immutable ADDRESS (host, port never change)
- Socket identity (underlying ISE socket remains same throughout lifetime)

**What CAN change:**
- is_connected state
- is_error state
- timeout value
- error_classification
- is_listening state

---

