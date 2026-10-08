note
	description: "[
		TCP client socket (initiates outbound connections), IPv4, Winsock 2.

		Lifecycle: create -> `connect' -> `send' / `receive' ... -> `close'.

		- `connect' resolves the host (IPv4 literal such as "127.0.0.1", or a
		  name such as "localhost") and connects within `timeout'.
		- `send' sends every byte or fails. `receive' returns up to N bytes
		  (whatever has arrived); `receive_exactly' returns exactly N bytes
		  unless the peer closes first.
		- Every wait (connect, send, receive) is bounded by `timeout'. A
		  timeout is an error: `is_error' and `operation_timed_out' hold.
		- An error ends the connection: the socket is released at once, and
		  only queries and `close' remain useful. `last_error_code' (the
		  Winsock code, e.g. 10061 refused, 10060 timed out) and
		  `last_error_string' stay readable after `close'.
		- `close' is graceful (FIN first) and may be called more than once.
	]"
	author: "simple_net team"
	date: "2026-10-08"
	void_safety: "all"
	scoop: "One CLIENT_SOCKET belongs to one processor; every wait is a blocking external."

class
	CLIENT_SOCKET

inherit
	NET_HANDLE_OWNER

create
	make_for_host_port,
	make_for_address

feature {NONE} -- Representation

	remote_address_impl: ADDRESS
			-- Remote server address

	timeout_impl: REAL
			-- Timeout in seconds for every wait (default `Default_timeout')

	is_connected_impl: BOOLEAN
			-- True if successfully connected

	is_error_impl: BOOLEAN
			-- True if connection or operation failed

	error_impl: ERROR_TYPE
			-- Last error that occurred

	error_context_impl: STRING
			-- What was being done when `error_impl' occurred

	bytes_sent_impl: INTEGER
			-- Cumulative bytes sent

	bytes_received_impl: INTEGER
			-- Cumulative bytes received

	is_closed_impl: BOOLEAN
			-- True if connection has been closed

	is_at_eof_impl: BOOLEAN
			-- True if peer closed connection cleanly

	local_host_impl: STRING
			-- Local IPv4 address of the connection ("" until connected)

	local_port_impl: INTEGER
			-- Local port of the connection (0 until connected)

	api: NET_SOCKET_API
			-- Winsock primitives

feature -- Creation

	make_for_host_port (a_host: STRING; a_port: INTEGER)
			-- Initialize client socket for remote server at `a_host:a_port'
		require
			host_not_empty: a_host /= Void and then a_host.count > 0
			port_valid: a_port >= 1 and a_port <= 65535
		do
			make_for_address (create {ADDRESS}.make_for_host_port (a_host, a_port))
		ensure
			remote_host_set: remote_address.host.is_equal (a_host)
			remote_port_set: remote_address.port = a_port
			not_connected: not is_connected
			not_in_error: not is_error
			timeout_set: timeout = Default_timeout
		end

	make_for_address (a_address: ADDRESS)
			-- Initialize client socket for remote `a_address'
		require
			address_not_void: a_address /= Void
		do
			remote_address_impl := a_address
			timeout_impl := Default_timeout
			create error_impl.make (0)
			create error_context_impl.make_empty
			create local_host_impl.make_empty
			create api.make
		ensure
			remote_address_set: remote_address = a_address
			not_connected: not is_connected
			not_in_error: not is_error
			not_closed: not is_closed
			timeout_set: timeout = Default_timeout
		end

feature -- Constants

	Default_timeout: REAL = 30.0
			-- Timeout in seconds until `set_timeout' changes it

feature -- Commands

	connect: BOOLEAN
			-- Attempt to connect to remote server. Returns true if successful.
			-- On failure, is_error becomes true and error_classification indicates why.
			-- A socket whose earlier `connect' failed may try again.
		require
			not_connected: not is_connected
			not_already_closed: not is_closed
		do
			release_handle (False)
			is_error_impl := False
			is_at_eof_impl := False
			api.connect_to (remote_address.host, remote_address.port, api.milliseconds (timeout))
			if api.is_ok then
				set_handle (api.last_handle)
				local_host_impl := api.last_endpoint_host
				local_port_impl := api.last_endpoint_port
				is_connected_impl := True
				create error_impl.make (0)
				error_context_impl.wipe_out
				Result := True
			else
				fail (api.last_error_code, "connect to " + remote_address.as_string)
			end
		ensure
			success_implies_connected: Result implies (is_connected and not is_error)
			failure_implies_error: (not Result) implies (is_error and not is_connected)
			-- Frame conditions: what does NOT change
			remote_address_unchanged: remote_address = old remote_address
			timeout_unchanged: timeout = old timeout
			bytes_sent_unchanged: bytes_sent = old bytes_sent
			bytes_received_unchanged: bytes_received = old bytes_received
			closed_state_unchanged: is_closed = old is_closed
		end

	send (a_data: ARRAY [NATURAL_8]): BOOLEAN
			-- Send all bytes in `a_data'. Full send guarantee (all or error).
			-- Returns true if all bytes sent, false on error. Empty `a_data' sends nothing.
		require
			is_connected: is_connected
			not_in_error: not is_error
			data_not_void: a_data /= Void
		do
			if a_data.is_empty then
				Result := True
			else
				api.send_all (handle, a_data, api.milliseconds (timeout))
				if api.is_ok then
					bytes_sent_impl := bytes_sent_impl + a_data.count
					Result := True
				else
					fail (api.last_error_code, "send " + a_data.count.out + " bytes")
				end
			end
		ensure
			all_or_error: Result implies (bytes_sent = old bytes_sent + a_data.count)
			failure_means_error: (not Result) implies is_error
			no_data_loss: bytes_sent >= old bytes_sent
			-- Frame conditions: what does NOT change
			remote_address_unchanged: remote_address = old remote_address
			timeout_unchanged: timeout = old timeout
			bytes_received_unchanged: bytes_received = old bytes_received
			closed_state_unchanged: is_closed = old is_closed
		end

	send_string (a_string: STRING): BOOLEAN
			-- Send the 8-bit characters of `a_string' as bytes, unchanged
			-- (pass UTF-8 text already encoded). Full send guarantee.
		require
			is_connected: is_connected
			not_in_error: not is_error
			string_not_void: a_string /= Void
		do
			Result := send (api.bytes_of (a_string))
		ensure
			success_or_error: Result or is_error
			all_or_error: Result implies (bytes_sent = old bytes_sent + a_string.count)
			bytes_non_decreasing: bytes_sent >= old bytes_sent
			-- Frame conditions: what does NOT change
			remote_address_unchanged: remote_address = old remote_address
			timeout_unchanged: timeout = old timeout
			bytes_received_unchanged: bytes_received = old bytes_received
			closed_state_unchanged: is_closed = old is_closed
		end

	receive (a_max_bytes: INTEGER): ARRAY [NATURAL_8]
			-- Receive up to `a_max_bytes' bytes (at most 65536 per call): whatever
			-- has arrived, waiting up to `timeout' for the first byte.
			-- Returns empty array on EOF or error.
		require
			is_connected: is_connected
			valid_max_bytes: a_max_bytes > 0
		do
			if is_at_eof_impl then
				create Result.make_empty
			else
				api.receive_some (handle, a_max_bytes, api.milliseconds (timeout))
				Result := api.last_data
				if not api.is_ok then
					fail (api.last_error_code, "receive")
				elseif Result.is_empty then
					is_at_eof_impl := True
				else
					bytes_received_impl := bytes_received_impl + Result.count
				end
			end
		ensure
			result_not_void: Result /= Void
			result_bounded: Result.count <= a_max_bytes
			empty_requires_reason: (Result.count = 0) implies (is_at_end_of_stream or is_error)
			data_excludes_error: (Result.count > 0) implies (not is_error and not is_at_end_of_stream)
			bytes_counted: bytes_received = old bytes_received + Result.count
			-- Frame conditions: what does NOT change
			remote_address_unchanged: remote_address = old remote_address
			timeout_unchanged: timeout = old timeout
			bytes_sent_unchanged: bytes_sent = old bytes_sent
			closed_state_unchanged: is_closed = old is_closed
		end

	receive_exactly (a_count: INTEGER): ARRAY [NATURAL_8]
			-- Receive exactly `a_count' bytes, waiting up to `timeout' for each chunk.
			-- Fewer come back only when the peer closes first (`is_at_end_of_stream')
			-- or an error occurs (`is_error'); they are the bytes that did arrive.
		require
			is_connected: is_connected
			count_non_negative: a_count >= 0
		local
			l_chunk: ARRAY [NATURAL_8]
			l_got: INTEGER
			l_done: BOOLEAN
		do
			create Result.make_filled (0, 1, a_count)
			from
			invariant
				got_bounded: 0 <= l_got and l_got <= a_count
			until
				l_got = a_count or l_done
			loop
				l_chunk := receive (a_count - l_got)
				if l_chunk.is_empty then
					l_done := True
				else
					Result.subcopy (l_chunk, l_chunk.lower, l_chunk.upper, Result.lower + l_got)
					l_got := l_got + l_chunk.count
				end
			variant
				a_count - l_got + (if l_done then 0 else 1 end)
			end
			if l_got < a_count then
				Result := Result.subarray (1, l_got)
			end
		ensure
			result_not_void: Result /= Void
			bounded: Result.count <= a_count
			exact_unless_cut_short: Result.count = a_count or is_at_end_of_stream or is_error
			bytes_counted: bytes_received = old bytes_received + Result.count
			remote_address_unchanged: remote_address = old remote_address
			bytes_sent_unchanged: bytes_sent = old bytes_sent
			closed_state_unchanged: is_closed = old is_closed
		end

	receive_string (a_max_bytes: INTEGER): STRING
			-- Receive up to `a_max_bytes' bytes, one 8-bit character per byte
			-- (UTF-8 text stays UTF-8). Empty on EOF or error.
		require
			is_connected: is_connected
			valid_max_bytes: a_max_bytes > 0
		do
			Result := api.string_of (receive (a_max_bytes))
		ensure
			result_not_void: Result /= Void
			result_bounded: Result.count <= a_max_bytes
			-- Frame conditions: what does NOT change
			remote_address_unchanged: remote_address = old remote_address
			timeout_unchanged: timeout = old timeout
			bytes_sent_unchanged: bytes_sent = old bytes_sent
			closed_state_unchanged: is_closed = old is_closed
		end

	close
			-- Close connection gracefully (FIN, then release). Safe to call again.
		do
			release_handle (True)
			is_closed_impl := True
			is_connected_impl := False
			is_error_impl := False
		ensure
			is_closed: is_closed
			not_connected: not is_connected
			-- Frame conditions: what does NOT change
			remote_address_unchanged: remote_address = old remote_address
			timeout_unchanged: timeout = old timeout
			bytes_sent_unchanged: bytes_sent = old bytes_sent
			bytes_received_unchanged: bytes_received = old bytes_received
			error_code_kept: last_error_code = old last_error_code
		end

	set_timeout (a_seconds: REAL)
			-- Set timeout for all operations (connect, send, receive)
		require
			positive: a_seconds > 0.0
		do
			timeout_impl := a_seconds
		ensure
			timeout_set: timeout = a_seconds
			-- Frame conditions: what does NOT change
			remote_address_unchanged: remote_address = old remote_address
			connection_state_unchanged: is_connected = old is_connected
			error_state_unchanged: is_error = old is_error
			closed_state_unchanged: is_closed = old is_closed
			bytes_sent_unchanged: bytes_sent = old bytes_sent
			bytes_received_unchanged: bytes_received = old bytes_received
		end

feature -- Queries

	is_connected: BOOLEAN
			-- Is socket connected to remote server?
		do
			Result := is_connected_impl and not is_error_impl and not is_closed_impl
		ensure
			connected_or_error: Result or not is_connected_impl or is_error_impl or is_closed_impl
		end

	is_closed: BOOLEAN
			-- Has socket been closed?
		do
			Result := is_closed_impl
		end

	is_error: BOOLEAN
			-- Is socket in error state?
		do
			Result := is_error_impl
		ensure
			error_excludes_connected: Result implies not is_connected
		end

	operation_timed_out: BOOLEAN
			-- Did the last failed operation run out of `timeout'?
		do
			Result := is_error and error_impl.is_timeout
		end

	error_classification: ERROR_TYPE
			-- Classification of current error (if is_error)
		require
			in_error: is_error
		do
			Result := error_impl
		ensure
			result_not_void: Result /= Void
		end

	last_error_code: INTEGER
			-- Winsock code of the most recent failure (0 if none); kept after `close'.
		do
			Result := error_impl.code
		end

	last_error_string: STRING
			-- Human-readable description of the most recent failure, with the
			-- Winsock code, e.g. "connect to 127.0.0.1:9: Connection refused (WSA 10061)".
		require
			has_failed: last_error_code /= 0
		do
			create Result.make_from_string (error_context_impl)
			Result.append (": ")
			Result.append (error_impl.to_string)
			Result.append (" (WSA ")
			Result.append (error_impl.code.out)
			Result.append (")")
		ensure
			result_not_void: Result /= Void
			result_not_empty: Result.count > 0
		end

	is_at_end_of_stream: BOOLEAN
			-- Has peer closed connection cleanly (EOF)?
		do
			Result := is_at_eof_impl
		end

	bytes_sent: INTEGER
			-- Total bytes successfully sent (cumulative)
		do
			Result := bytes_sent_impl
		ensure
			non_negative: Result >= 0
		end

	bytes_received: INTEGER
			-- Total bytes successfully received (cumulative)
		do
			Result := bytes_received_impl
		ensure
			non_negative: Result >= 0
		end

	timeout: REAL
			-- Current timeout in seconds
		do
			Result := timeout_impl
		ensure
			positive: Result > 0.0
		end

	remote_address: ADDRESS
			-- Remote server address
		do
			Result := remote_address_impl
		ensure
			result_not_void: Result /= Void
		end

	has_local_address: BOOLEAN
			-- Is the local endpoint known (after a successful `connect')?
		do
			Result := local_port_impl > 0 and not local_host_impl.is_empty
		end

	local_address: ADDRESS
			-- Local endpoint address (known after a successful connect)
		require
			has_local_address: has_local_address
		do
			create Result.make_for_host_port (local_host_impl, local_port_impl)
		ensure
			result_not_void: Result /= Void
		end

feature {NONE} -- Implementation

	fail (a_code: INTEGER; a_context: STRING)
			-- Enter the error state for Winsock code `a_code' while doing `a_context';
			-- the connection is released.
		require
			real_error: a_code /= 0
		do
			release_handle (False)
			create error_impl.make (a_code)
			error_context_impl := a_context
			is_error_impl := True
			is_connected_impl := False
		ensure
			in_error: is_error
			not_connected: not is_connected
			code_kept: last_error_code = a_code
		end

invariant
	connected_excludes_error: is_connected implies not is_error
	connected_excludes_closed: is_connected implies not is_closed
	error_excludes_closed: is_error implies not is_closed
	error_has_code: is_error implies error_impl.code /= 0
	handle_iff_connected: has_handle = is_connected
	bytes_non_negative: bytes_sent >= 0 and bytes_received >= 0
	timeout_positive: timeout > 0.0
	remote_address_not_void: remote_address_impl /= Void

end
