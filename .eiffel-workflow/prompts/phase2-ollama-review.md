# Eiffel Contract Review Request - simple_net

**You are reviewing Design by Contract specifications for a TCP socket library. Find obvious problems, missing constraints, weak preconditions, and incomplete postconditions.**

## Review Checklist

- [ ] Preconditions that are just `True` or missing (too weak)
- [ ] Postconditions that don't constrain anything (too weak)
- [ ] Missing invariants (class consistency not enforced)
- [ ] Obvious edge cases not handled (empty input, max values, zero)
- [ ] State transitions not properly guarded by preconditions
- [ ] Contradictory postconditions that can never both be true
- [ ] Features with result but postcondition doesn't mention result
- [ ] Error handling paths not specified in postconditions
- [ ] Resource cleanup (close) not properly enforced
- [ ] Timeout behavior not specified in postconditions

## Contracts to Review

### Class: ADDRESS (Network Endpoint Value Object)

```eiffel
note
	description: "Network endpoint (host:port) value object"
	author: "simple_net team"
	date: "2026-01-28"
	void_safety: "all"
	scoop: "thread_safe"

class ADDRESS

create
	make_for_host_port,
	make_for_localhost_port

feature {NONE} -- Representation

	host_impl: STRING
			-- Hostname or IP address (immutable after creation)

	port_impl: INTEGER
			-- Port number 1-65535 (immutable after creation)

feature -- Creation

	make_for_host_port (a_host: STRING; a_port: INTEGER)
			-- Initialize address for `a_host' and `a_port'.
			-- `a_host': hostname (e.g., "example.com", "localhost") or IP address (e.g., "127.0.0.1", "192.168.1.1")
			-- `a_port': port number in range 1-65535
		require
			non_empty_host: a_host /= Void and then a_host.count > 0
			valid_port: a_port >= 1 and a_port <= 65535
		do
			host_impl := a_host.twin
			port_impl := a_port
		ensure
			host_set: host.is_equal (a_host)
			port_set: port = a_port
		end

	make_for_localhost_port (a_port: INTEGER)
			-- Initialize address for localhost (127.0.0.1) on `a_port'.
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
		end

	port: INTEGER
			-- Port number
		do
			Result := port_impl
		end

	as_string: STRING
			-- String representation (e.g., "example.com:8080" or "127.0.0.1:8080")
		do
			create Result.make_from_string (host_impl)
			Result.append (":")
			Result.append (port_impl.out)
		end

feature -- Status

	is_loopback: BOOLEAN
			-- Is this a loopback address (127.0.0.1 or localhost)?
		do
			Result := host_impl.is_equal ("127.0.0.1") or host_impl.is_equal ("localhost")
		end

	is_ipv4_address: BOOLEAN
			-- Is host an IPv4 address (e.g., "192.168.1.1")?
		do
			-- Simple check: contains exactly 3 dots
			Result := host.occurrences ('.') = 3
		end

invariant
	host_not_empty: host_impl.count > 0
	port_in_range: port_impl >= 1 and port_impl <= 65535

end
```

### Class: ERROR_TYPE (Error Classification Enum)

```eiffel
note
	description: "Socket error classification (enum)"
	author: "simple_net team"
	date: "2026-01-28"
	void_safety: "all"

class ERROR_TYPE

create
	make

feature {NONE} -- Representation

	code_impl: INTEGER
			-- OS error code or classification constant

feature -- Creation

	make (a_code: INTEGER)
			-- Initialize with error code
		do
			code_impl := a_code
		ensure
			code_set: code = a_code
		end

feature -- Access

	code: INTEGER
			-- Raw OS error code or classification constant
		do
			Result := code_impl
		end

feature -- Error Classification

	is_no_error: BOOLEAN
			-- No error occurred?
		do
			Result := code_impl = 0
		end

	is_connection_refused: BOOLEAN
			-- Connection refused by peer (ECONNREFUSED)?
		do
			Result := code_impl = 111 or code_impl = 10061  -- Linux ECONNREFUSED=111, Windows WSAECONNREFUSED=10061
		end

	is_connection_timeout: BOOLEAN
			-- Connection attempt timed out (ETIMEDOUT)?
		do
			Result := code_impl = 110 or code_impl = 10060  -- Linux ETIMEDOUT=110, Windows WSAETIMEDOUT=10060
		end

	is_connection_reset: BOOLEAN
			-- Peer reset connection (ECONNRESET)?
		do
			Result := code_impl = 104 or code_impl = 10054  -- Linux ECONNRESET=104, Windows WSAECONNRESET=10054
		end

	is_read_error: BOOLEAN
			-- Error reading data (EBADF, EIO, etc.)?
		do
			Result := code_impl = 9 or code_impl = 5  -- EBADF=9, EIO=5
		end

	is_write_error: BOOLEAN
			-- Error writing data (EPIPE, EBROKEN)?
		do
			Result := code_impl = 32 or code_impl = 54  -- EPIPE=32, ECONNRESET=54
		end

	is_bind_error: BOOLEAN
			-- Failed to bind socket (EADDRINUSE, EACCES)?
		do
			Result := code_impl = 98 or code_impl = 13 or code_impl = 10048  -- EADDRINUSE=98, EACCES=13, Windows=10048
		end

	is_address_not_available: BOOLEAN
			-- Invalid or unreachable address (EADDRNOTAVAIL)?
		do
			Result := code_impl = 99 or code_impl = 10049  -- EADDRNOTAVAIL=99, Windows=10049
		end

	is_timeout: BOOLEAN
			-- Timeout during operation?
		do
			Result := is_connection_timeout or code_impl = -1  -- -1 is generic timeout marker
		end

	is_retriable: BOOLEAN
			-- Is this error retriable (worth retrying)?
		do
			Result := is_connection_refused or is_connection_timeout or is_connection_reset
		end

	is_fatal: BOOLEAN
			-- Is this error fatal (don't retry)?
		do
			Result := is_address_not_available or is_bind_error
		end

feature -- String Representation

	to_string: STRING
			-- Human-readable error description
		do
			if is_no_error then
				Result := "No error"
			elseif is_connection_refused then
				Result := "Connection refused"
			elseif is_connection_timeout then
				Result := "Connection timeout"
			elseif is_connection_reset then
				Result := "Connection reset"
			elseif is_read_error then
				Result := "Read error"
			elseif is_write_error then
				Result := "Write error"
			elseif is_bind_error then
				Result := "Bind error (port in use?)"
			elseif is_address_not_available then
				Result := "Address not available"
			else
				create Result.make_from_string ("Unknown error (code: ")
				Result.append (code_impl.out)
				Result.append (")")
			end
		ensure
			result_not_empty: Result.count > 0
		end

invariant
	code_non_negative: code_impl >= -1

end
```

### Class: CONNECTION (Deferred Base - Active TCP Connection)

```eiffel
note
	description: "Active TCP connection (bidirectional channel)"
	author: "simple_net team"
	date: "2026-01-28"
	void_safety: "all"
	scoop: "separate"

deferred class CONNECTION

feature -- Creation

	make
			-- Create unconnected connection (will be initialized by CLIENT_SOCKET or SERVER_SOCKET)
		do
		end

feature -- Commands

	send (a_data: ARRAY [NATURAL_8]): BOOLEAN
			-- Send all bytes in `a_data'. Full send guarantee (all or error).
			-- Returns true if all bytes sent successfully, false on error.
		require
			is_connected: is_connected
			data_not_void: a_data /= Void
			data_not_empty: a_data.count > 0
		deferred
		ensure
			success_or_error: (Result and then bytes_sent = old bytes_sent + a_data.count) or (not Result and then is_error)
			bytes_non_decreasing: bytes_sent >= old bytes_sent
		end

	send_string (a_string: STRING): BOOLEAN
			-- Send string as UTF-8 bytes. Full send guarantee.
		require
			is_connected: is_connected
			string_not_void: a_string /= Void
			string_not_empty: a_string.count > 0
		deferred
		ensure
			success_or_error: (Result and then bytes_sent >= old bytes_sent) or (not Result and then is_error)
		end

	receive (a_max_bytes: INTEGER): ARRAY [NATURAL_8]
			-- Receive up to `a_max_bytes' bytes. Partial receive (may be < max_bytes).
			-- Returns empty array on EOF or error.
		require
			is_connected: is_connected
			valid_max_bytes: a_max_bytes > 0
		deferred
		ensure
			result_not_void: Result /= Void
			result_bounded: Result.count <= a_max_bytes
			bytes_non_decreasing: bytes_received >= old bytes_received
			eof_or_data: is_at_end_of_stream or Result.count > 0 or is_error
		end

	receive_string (a_max_bytes: INTEGER): STRING
			-- Receive up to `a_max_bytes' bytes as UTF-8 string.
		require
			is_connected: is_connected
			valid_max_bytes: a_max_bytes > 0
		deferred
		ensure
			result_not_void: Result /= Void
		end

	close
			-- Close connection gracefully and cleanup resources.
		deferred
		ensure
			not_connected: not is_connected
			closed: is_closed
		end

	set_timeout (a_seconds: REAL)
			-- Set timeout for all operations (connect, send, receive, etc.)
			-- Apply timeout to both send() and receive() calls
		require
			positive_timeout: a_seconds > 0.0
		deferred
		ensure
			timeout_set: timeout = a_seconds
		end

feature -- Queries

	is_connected: BOOLEAN
			-- Is this connection active (not closed, not in error)?
		deferred
		ensure
			connected_or_error: Result or not is_error or not is_closed
		end

	is_closed: BOOLEAN
			-- Has connection been closed?
		deferred
		end

	is_error: BOOLEAN
			-- Is connection in error state?
		deferred
		ensure
			error_xor_connected: Result or is_connected or is_closed
		end

	error_classification: ERROR_TYPE
			-- Classification of current error (if is_error)
		require
			in_error: is_error
		deferred
		ensure
			result_not_void: Result /= Void
		end

	last_error_string: STRING
			-- Human-readable error description
		require
			in_error: is_error
		deferred
		ensure
			result_not_void: Result /= Void
			result_not_empty: Result.count > 0
		end

	is_at_end_of_stream: BOOLEAN
			-- Has peer closed connection cleanly (EOF)?
		deferred
		end

	bytes_sent: INTEGER
			-- Total bytes successfully sent (cumulative, never decreases)
		deferred
		ensure
			non_negative: Result >= 0
		end

	bytes_received: INTEGER
			-- Total bytes successfully received (cumulative, never decreases)
		deferred
		ensure
			non_negative: Result >= 0
		end

	timeout: REAL
			-- Current timeout in seconds
		deferred
		ensure
			positive: Result > 0.0
		end

	local_address: ADDRESS
			-- Local endpoint address (if available)
		require
			is_connected or is_closed
		deferred
		ensure
			result_not_void: Result /= Void
		end

	remote_address: ADDRESS
			-- Remote endpoint address (if available)
		require
			is_connected or is_closed
		deferred
		ensure
			result_not_void: Result /= Void
		end

invariant
	state_consistency: (is_connected and not is_error and not is_closed) or (not is_connected)
	bytes_non_negative: bytes_sent >= 0 and bytes_received >= 0
	eof_implies_not_connected: is_at_end_of_stream implies not is_connected or is_closed

end
```

### Class: CLIENT_SOCKET (TCP Client)

```eiffel
note
	description: "TCP client socket (initiates outbound connections)"
	author: "simple_net team"
	date: "2026-01-28"
	void_safety: "all"
	scoop: "thread_safe"

class CLIENT_SOCKET

create
	make_for_host_port,
	make_for_address

feature {NONE} -- Representation

	remote_address_impl: ADDRESS
	timeout_impl: REAL
	is_connected_impl: BOOLEAN
	is_error_impl: BOOLEAN
	error_impl: ERROR_TYPE
	bytes_sent_impl: INTEGER
	bytes_received_impl: INTEGER
	is_closed_impl: BOOLEAN
	is_at_eof_impl: BOOLEAN

feature -- Creation

	make_for_host_port (a_host: STRING; a_port: INTEGER)
		require
			host_not_empty: a_host /= Void and then a_host.count > 0
			port_valid: a_port >= 1 and a_port <= 65535
		do
			create remote_address_impl.make_for_host_port (a_host, a_port)
			timeout_impl := 30.0
			is_connected_impl := False
			is_error_impl := False
			is_closed_impl := False
			is_at_eof_impl := False
			bytes_sent_impl := 0
			bytes_received_impl := 0
			create error_impl.make (0)
		ensure
			remote_host_set: remote_address.host.is_equal (a_host)
			remote_port_set: remote_address.port = a_port
			not_connected: not is_connected
			not_in_error: not is_error
			timeout_set: timeout = 30.0
		end

	make_for_address (a_address: ADDRESS)
		require
			address_not_void: a_address /= Void
		do
			remote_address_impl := a_address
			timeout_impl := 30.0
			is_connected_impl := False
			is_error_impl := False
			is_closed_impl := False
			is_at_eof_impl := False
			bytes_sent_impl := 0
			bytes_received_impl := 0
			create error_impl.make (0)
		ensure
			remote_address_set: remote_address = a_address
			not_connected: not is_connected
			not_in_error: not is_error
		end

feature -- Commands

	connect: BOOLEAN
		require
			not_connected: not is_connected
			not_already_closed: not is_closed
		do
		ensure
			connected_or_error: Result = is_connected or is_error
			on_success: Result implies is_connected and not is_error
			on_failure: not Result implies is_error and not is_connected
		end

	send (a_data: ARRAY [NATURAL_8]): BOOLEAN
		require
			is_connected: is_connected
			not_in_error: not is_error
			data_not_void: a_data /= Void
			data_not_empty: a_data.count > 0
		do
		ensure
			success_or_error: Result or is_error
			on_success: Result implies bytes_sent = old bytes_sent + a_data.count
			on_failure: not Result implies is_error
			bytes_non_decreasing: bytes_sent >= old bytes_sent
		end

	send_string (a_string: STRING): BOOLEAN
		require
			is_connected: is_connected
			not_in_error: not is_error
			string_not_void: a_string /= Void
			string_not_empty: a_string.count > 0
		do
		ensure
			success_or_error: Result or is_error
			bytes_non_decreasing: bytes_sent >= old bytes_sent
		end

	receive (a_max_bytes: INTEGER): ARRAY [NATURAL_8]
		require
			is_connected: is_connected
			valid_max_bytes: a_max_bytes > 0
		local
			l_empty: ARRAY [NATURAL_8]
		do
			create l_empty.make_empty
			Result := l_empty
		ensure
			result_not_void: Result /= Void
			result_bounded: Result.count <= a_max_bytes
			bytes_non_decreasing: bytes_received >= old bytes_received
			eof_or_data: is_at_end_of_stream or Result.count > 0 or is_error
		end

	receive_string (a_max_bytes: INTEGER): STRING
		require
			is_connected: is_connected
			valid_max_bytes: a_max_bytes > 0
		do
			create Result.make_empty
		ensure
			result_not_void: Result /= Void
		end

	close
		require
			not_already_closed: not is_closed
		do
		ensure
			is_closed: is_closed
			not_connected: not is_connected
		end

	set_timeout (a_seconds: REAL)
		require
			positive: a_seconds > 0.0
		do
			timeout_impl := a_seconds
		ensure
			timeout_set: timeout = a_seconds
		end

feature -- Queries

	is_connected: BOOLEAN
		do
			Result := is_connected_impl and not is_error_impl and not is_closed_impl
		ensure
			connected_or_error: Result or not is_connected_impl or is_error_impl or is_closed_impl
		end

	is_closed: BOOLEAN
		do
			Result := is_closed_impl
		end

	is_error: BOOLEAN
		do
			Result := is_error_impl
		ensure
			error_xor_connected: Result or is_connected
		end

	error_classification: ERROR_TYPE
		require
			in_error: is_error
		do
			Result := error_impl
		ensure
			result_not_void: Result /= Void
		end

	last_error_string: STRING
		require
			in_error: is_error
		do
			Result := error_impl.to_string
		ensure
			result_not_void: Result /= Void
			result_not_empty: Result.count > 0
		end

	is_at_end_of_stream: BOOLEAN
		do
			Result := is_at_eof_impl
		end

	bytes_sent: INTEGER
		do
			Result := bytes_sent_impl
		ensure
			non_negative: Result >= 0
		end

	bytes_received: INTEGER
		do
			Result := bytes_received_impl
		ensure
			non_negative: Result >= 0
		end

	timeout: REAL
		do
			Result := timeout_impl
		ensure
			positive: Result > 0.0
		end

	remote_address: ADDRESS
		do
			Result := remote_address_impl
		ensure
			result_not_void: Result /= Void
		end

	local_address: ADDRESS
		require
			is_connected or is_closed
		do
			create Result.make_for_localhost_port (0)
		ensure
			result_not_void: Result /= Void
		end

invariant
	state_consistency: (is_connected and not is_error and not is_closed) or not is_connected
	bytes_non_negative: bytes_sent >= 0 and bytes_received >= 0
	timeout_positive: timeout > 0.0
	remote_address_not_void: remote_address_impl /= Void

end
```

### Class: SERVER_SOCKET (TCP Server)

```eiffel
note
	description: "TCP server socket (accepts inbound connections)"
	author: "simple_net team"
	date: "2026-01-28"
	void_safety: "all"
	scoop: "thread_safe"

class SERVER_SOCKET

create
	make_for_port,
	make_for_address

feature {NONE} -- Representation

	local_address_impl: ADDRESS
	timeout_impl: REAL
	is_listening_impl: BOOLEAN
	is_error_impl: BOOLEAN
	error_impl: ERROR_TYPE
	backlog_impl: INTEGER
	is_closed_impl: BOOLEAN
	connection_count_impl: INTEGER

feature -- Creation

	make_for_port (a_port: INTEGER)
		require
			port_valid: a_port >= 1 and a_port <= 65535
		do
			create local_address_impl.make_for_host_port ("0.0.0.0", a_port)
			timeout_impl := 30.0
			is_listening_impl := False
			is_error_impl := False
			is_closed_impl := False
			backlog_impl := 0
			connection_count_impl := 0
			create error_impl.make (0)
		ensure
			local_port_set: local_address.port = a_port
			not_listening: not is_listening
			not_in_error: not is_error
			timeout_set: timeout = 30.0
		end

	make_for_address (a_address: ADDRESS)
		require
			address_not_void: a_address /= Void
		do
			local_address_impl := a_address
			timeout_impl := 30.0
			is_listening_impl := False
			is_error_impl := False
			is_closed_impl := False
			backlog_impl := 0
			connection_count_impl := 0
			create error_impl.make (0)
		ensure
			local_address_set: local_address = a_address
			not_listening: not is_listening
			not_in_error: not is_error
		end

feature -- Commands

	listen (a_backlog: INTEGER): BOOLEAN
		require
			not_listening: not is_listening
			positive_backlog: a_backlog > 0
			not_already_closed: not is_closed
		do
		ensure
			listening_or_error: Result = is_listening or is_error
			on_success: Result implies is_listening and not is_error
			on_failure: not Result implies is_error and not is_listening
			backlog_set: Result implies backlog = a_backlog
		end

	accept: detachable CONNECTION
		require
			is_listening: is_listening
			not_in_error: not is_error
		do
		end

	close
		require
			not_already_closed: not is_closed
		do
		ensure
			is_closed: is_closed
			not_listening: not is_listening
		end

	set_timeout (a_seconds: REAL)
		require
			positive_timeout: a_seconds > 0.0
		do
			timeout_impl := a_seconds
		ensure
			timeout_set: timeout = a_seconds
		end

feature -- Queries

	is_listening: BOOLEAN
		do
			Result := is_listening_impl and not is_error_impl and not is_closed_impl
		ensure
			listening_or_error: Result or not is_listening_impl or is_error_impl or is_closed_impl
		end

	is_closed: BOOLEAN
		do
			Result := is_closed_impl
		end

	is_error: BOOLEAN
		do
			Result := is_error_impl
		ensure
			error_xor_listening: Result or is_listening
		end

	error_classification: ERROR_TYPE
		require
			in_error: is_error
		do
			Result := error_impl
		ensure
			result_not_void: Result /= Void
		end

	last_error_string: STRING
		require
			in_error: is_error
		do
			Result := error_impl.to_string
		ensure
			result_not_void: Result /= Void
			result_not_empty: Result.count > 0
		end

	backlog: INTEGER
		require
			is_listening or is_closed
		do
			Result := backlog_impl
		ensure
			non_negative: Result >= 0
		end

	connection_count: INTEGER
		do
			Result := connection_count_impl
		ensure
			non_negative: Result >= 0
		end

	timeout: REAL
		do
			Result := timeout_impl
		ensure
			positive: Result > 0.0
		end

	local_address: ADDRESS
		do
			Result := local_address_impl
		ensure
			result_not_void: Result /= Void
		end

	operation_timed_out: BOOLEAN
		do
			Result := is_error and error_classification.is_timeout
		end

invariant
	state_consistency: (is_listening and not is_error and not is_closed) or not is_listening
	backlog_non_negative: backlog >= 0
	connection_count_non_negative: connection_count >= 0
	timeout_positive: timeout > 0.0
	local_address_not_void: local_address_impl /= Void

end
```

## Implementation Approach Summary

[PASTED FROM approach.md]

See attached approach.md for:
- Architecture overview with class relationships
- Implementation strategy for each major feature
- State machine diagrams for CLIENT_SOCKET and SERVER_SOCKET
- Error handling and recovery strategy
- Performance considerations (timeouts, cumulative counters)
- Testing strategy (unit, integration, adversarial)
- SCOOP compatibility guarantees
- Remaining design decisions

## Questions for Review

**Contract Issues to Find:**

1. Are there any preconditions that are too weak (should be stronger)?
2. Are there any postconditions that don't actually constrain anything?
3. Are there any missing postconditions (features that could return anything)?
4. Do the state invariants properly enforce consistency?
5. Are there edge cases (empty input, zero/max values) not handled?
6. Is the timeout behavior properly specified everywhere?
7. Should ERROR_TYPE classification features always be available, or precondition is_error?
8. Should EOF be a separate state from ERROR, or unified?
9. Are preconditions on derived queries (is_connected vs is_connected_impl) too restrictive?
10. Are there any features that violate preconditions when called in their postconditions?

**Output Format**

For each issue found:
```
ISSUE: [description]
LOCATION: [class.feature line number]
SEVERITY: CRITICAL / HIGH / MEDIUM / LOW
SUGGESTION: [how to fix]
```
