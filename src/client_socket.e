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
			-- Remote server address

	timeout_impl: REAL
			-- Timeout in seconds for all operations
			-- Default: 30.0 seconds

	is_connected_impl: BOOLEAN
			-- True if successfully connected

	is_error_impl: BOOLEAN
			-- True if connection or operation failed

	error_impl: ERROR_TYPE
			-- Last error that occurred

	bytes_sent_impl: INTEGER
			-- Cumulative bytes sent

	bytes_received_impl: INTEGER
			-- Cumulative bytes received

	is_closed_impl: BOOLEAN
			-- True if connection has been closed

	is_at_eof_impl: BOOLEAN
			-- True if peer closed connection cleanly

feature -- Creation

	make_for_host_port (a_host: STRING; a_port: INTEGER)
			-- Initialize client socket for remote server at `a_host:a_port'
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
			-- Initialize client socket for remote `a_address'
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
			-- Attempt to connect to remote server. Returns true if successful.
			-- On failure, is_error becomes true and error_classification indicates why.
		require
			not_connected: not is_connected
			not_already_closed: not is_closed
		do
			-- Phase 4 Stub: Return success (real implementation would use NETWORK_SOCKET)
			is_connected_impl := True
			is_error_impl := False
			error_impl.make (0)
			Result := True
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
			-- Returns true if all bytes sent, false on error.
		require
			is_connected: is_connected
			not_in_error: not is_error
			data_not_void: a_data /= Void
			data_not_empty: a_data.count > 0
		do
			-- Phase 4 Stub: Record bytes sent and return success
			bytes_sent_impl := bytes_sent_impl + a_data.count
			Result := True
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
			-- Send string as UTF-8 bytes. Full send guarantee.
		require
			is_connected: is_connected
			not_in_error: not is_error
			string_not_void: a_string /= Void
			string_not_empty: a_string.count > 0
		do
			-- Phase 4 Stub: Record string bytes and return success
			bytes_sent_impl := bytes_sent_impl + a_string.count
			Result := True
		ensure
			success_or_error: Result or is_error
			bytes_non_decreasing: bytes_sent >= old bytes_sent
			-- Frame conditions: what does NOT change
			remote_address_unchanged: remote_address = old remote_address
			timeout_unchanged: timeout = old timeout
			bytes_received_unchanged: bytes_received = old bytes_received
			closed_state_unchanged: is_closed = old is_closed
		end

	receive (a_max_bytes: INTEGER): ARRAY [NATURAL_8]
			-- Receive up to `a_max_bytes' bytes. Partial receive allowed.
			-- Returns empty array on EOF or error.
		require
			is_connected: is_connected
			valid_max_bytes: a_max_bytes > 0
		local
			l_empty: ARRAY [NATURAL_8]
		do
			-- Phase 4 Stub: Return empty array (EOF simulation)
			create l_empty.make_empty
			is_at_eof_impl := True
			Result := l_empty
		ensure
			result_not_void: Result /= Void
			result_bounded: Result.count <= a_max_bytes
			empty_requires_reason: (Result.count = 0) implies (is_at_end_of_stream or is_error)
			data_excludes_error: (Result.count > 0) implies (not is_error and not is_at_end_of_stream)
			bytes_non_decreasing: bytes_received >= old bytes_received
			-- Frame conditions: what does NOT change
			remote_address_unchanged: remote_address = old remote_address
			timeout_unchanged: timeout = old timeout
			bytes_sent_unchanged: bytes_sent = old bytes_sent
			closed_state_unchanged: is_closed = old is_closed
		end

	receive_string (a_max_bytes: INTEGER): STRING
			-- Receive up to `a_max_bytes' bytes as UTF-8 string.
		require
			is_connected: is_connected
			valid_max_bytes: a_max_bytes > 0
		do
			-- Phase 4 Stub: Return empty string (EOF simulation)
			create Result.make_empty
		ensure
			result_not_void: Result /= Void
			-- Frame conditions: what does NOT change
			remote_address_unchanged: remote_address = old remote_address
			timeout_unchanged: timeout = old timeout
			bytes_sent_unchanged: bytes_sent = old bytes_sent
			closed_state_unchanged: is_closed = old is_closed
		end

	close
			-- Close connection gracefully.
		require
			not_already_closed: not is_closed
		do
			is_closed_impl := True
			is_connected_impl := False
		ensure
			is_closed: is_closed
			not_connected: not is_connected
			-- Frame conditions: what does NOT change
			remote_address_unchanged: remote_address = old remote_address
			timeout_unchanged: timeout = old timeout
			bytes_sent_unchanged: bytes_sent = old bytes_sent
			bytes_received_unchanged: bytes_received = old bytes_received
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
			error_xor_connected: Result or is_connected
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

	last_error_string: STRING
			-- Human-readable error description
		require
			in_error: is_error
		do
			Result := error_impl.to_string
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

	local_address: ADDRESS
			-- Local endpoint address (only after successful connect)
		require
			is_connected or is_closed
		do
			create Result.make_for_localhost_port (0)
		ensure
			result_not_void: Result /= Void
		end

invariant
	connected_excludes_error: is_connected implies not is_error
	connected_excludes_closed: is_connected implies not is_closed
	error_excludes_closed: is_error implies not is_closed
	bytes_non_negative: bytes_sent >= 0 and bytes_received >= 0
	timeout_positive: timeout > 0.0
	remote_address_not_void: remote_address_impl /= Void

end
