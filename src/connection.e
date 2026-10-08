note
	description: "[
		An accepted TCP connection, created by SERVER_SOCKET.accept.

		Same I/O model as CLIENT_SOCKET: `send' sends every byte or fails,
		`receive' returns what has arrived (up to N), `receive_exactly' returns
		N bytes unless the peer closes first, every wait is bounded by
		`timeout', and an error releases the socket. `close' is graceful and
		may be called more than once.
	]"
	author: "simple_net team"
	date: "2026-10-08"
	void_safety: "all"
	scoop: "One CONNECTION belongs to the processor that accepted it."

class CONNECTION

inherit
	NET_HANDLE_OWNER

create {SERVER_SOCKET}
	make_accepted

feature {NONE} -- Creation

	make_accepted (a_handle: POINTER; a_remote_address: ADDRESS; a_timeout: REAL)
			-- Connection owning accepted socket `a_handle' from `a_remote_address'.
		require
			address_not_void: a_remote_address /= Void
			timeout_positive: a_timeout > 0.0
		do
			remote_address_impl := a_remote_address
			timeout_impl := a_timeout
			create error_impl.make (0)
			create api.make
			set_handle (a_handle)
		ensure
			remote_address_set: remote_address = a_remote_address
			timeout_set: timeout = a_timeout
			open: not is_closed and not is_error
		end

feature {NONE} -- Representation

	remote_address_impl: ADDRESS
			-- Remote client address

	timeout_impl: REAL
			-- Timeout in seconds

	bytes_sent_impl: INTEGER
			-- Bytes sent on this connection

	bytes_received_impl: INTEGER
			-- Bytes received on this connection

	is_closed_impl: BOOLEAN
			-- Connection closed

	is_at_eof_impl: BOOLEAN
			-- Peer closed cleanly

	is_error_impl: BOOLEAN
			-- Error occurred

	error_impl: ERROR_TYPE
			-- Last error

	api: NET_SOCKET_API
			-- Winsock primitives

feature -- Access

	remote_address: ADDRESS
			-- Remote client address
		do
			Result := remote_address_impl
		end

	timeout: REAL
			-- Timeout in seconds
		do
			Result := timeout_impl
		end

	bytes_sent: INTEGER
			-- Total bytes sent
		do
			Result := bytes_sent_impl
		end

	bytes_received: INTEGER
			-- Total bytes received
		do
			Result := bytes_received_impl
		end

	is_closed: BOOLEAN
			-- True if closed
		do
			Result := is_closed_impl
		end

	is_at_eof: BOOLEAN
			-- True if peer closed
		do
			Result := is_at_eof_impl
		end

	is_error: BOOLEAN
			-- True if error
		do
			Result := is_error_impl
		end

	error: ERROR_TYPE
			-- Last error
		do
			Result := error_impl
		end

	last_error_code: INTEGER
			-- Winsock code of the most recent failure (0 if none)
		do
			Result := error_impl.code
		end

feature -- Commands

	set_timeout (a_seconds: REAL)
			-- Set timeout for operations
		require
			timeout_positive: a_seconds > 0.0
		do
			timeout_impl := a_seconds
		ensure
			timeout_set: timeout = a_seconds
		end

	send (a_data: ARRAY [NATURAL_8]): BOOLEAN
			-- Send every byte of `a_data'. Returns true if all were sent;
			-- false (with `is_error') on failure or if the connection already failed.
		require
			data_not_void: a_data /= Void
			not_closed: not is_closed
		do
			if is_error then
				Result := False
			elseif a_data.is_empty then
				Result := True
			else
				api.send_all (handle, a_data, api.milliseconds (timeout))
				if api.is_ok then
					bytes_sent_impl := bytes_sent_impl + a_data.count
					Result := True
				else
					fail (api.last_error_code)
				end
			end
		ensure
			all_or_error: Result implies bytes_sent = old bytes_sent + a_data.count
			failure_means_error: (not Result) implies is_error
			bytes_sent_updated: bytes_sent >= 0
		end

	send_string (a_string: STRING): BOOLEAN
			-- Send the 8-bit characters of `a_string' as bytes, unchanged.
		require
			string_not_void: a_string /= Void
			not_closed: not is_closed
		do
			Result := send (api.bytes_of (a_string))
		ensure
			failure_means_error: (not Result) implies is_error
			bytes_sent_updated: bytes_sent >= 0
		end

	receive (a_max_bytes: INTEGER): ARRAY [NATURAL_8]
			-- Receive up to `a_max_bytes' (at most 65536): whatever has arrived,
			-- waiting up to `timeout'. Empty array on EOF or error.
		require
			max_bytes_positive: a_max_bytes > 0
			not_closed: not is_closed
		do
			if is_error or is_at_eof_impl then
				create Result.make_empty
			else
				api.receive_some (handle, a_max_bytes, api.milliseconds (timeout))
				Result := api.last_data
				if not api.is_ok then
					fail (api.last_error_code)
				elseif Result.is_empty then
					is_at_eof_impl := True
				else
					bytes_received_impl := bytes_received_impl + Result.count
				end
			end
		ensure
			result_not_void: Result /= Void
			bounded: Result.count <= a_max_bytes
			empty_requires_reason: Result.is_empty implies (is_at_eof or is_error)
			bytes_counted: bytes_received = old bytes_received + Result.count
		end

	receive_exactly (a_count: INTEGER): ARRAY [NATURAL_8]
			-- Receive exactly `a_count' bytes; fewer only when the peer closes
			-- first (`is_at_eof') or an error occurs (`is_error').
		require
			count_non_negative: a_count >= 0
			not_closed: not is_closed
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
			bounded: Result.count <= a_count
			exact_unless_cut_short: Result.count = a_count or is_at_eof or is_error
			bytes_counted: bytes_received = old bytes_received + Result.count
		end

	receive_string: STRING
			-- Receive what has arrived (up to 65536 bytes), one 8-bit character
			-- per byte. Empty string on EOF or error.
		require
			not_closed: not is_closed
		do
			Result := api.string_of (receive (api.Max_chunk))
		ensure
			result_not_void: Result /= Void
			bytes_received_updated: bytes_received >= 0
		end

	close
			-- Close connection gracefully (FIN, then release). Safe to call again.
		do
			release_handle (True)
			is_closed_impl := True
		ensure
			is_closed: is_closed
		end

feature {NONE} -- Implementation

	fail (a_code: INTEGER)
			-- Enter the error state for Winsock code `a_code'; the socket is released.
		require
			real_error: a_code /= 0
		do
			release_handle (False)
			create error_impl.make (a_code)
			is_error_impl := True
		ensure
			in_error: is_error
			code_kept: last_error_code = a_code
		end

invariant
	address_not_void: remote_address_impl /= Void
	timeout_positive: timeout > 0.0
	bytes_non_negative: bytes_sent >= 0 and bytes_received >= 0
	handle_iff_open: has_handle = (not is_closed and not is_error)
	error_has_code: is_error implies error_impl.code /= 0

end
