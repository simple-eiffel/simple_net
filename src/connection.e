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
	connected_excludes_error: is_connected implies not is_error
	connected_excludes_closed: is_connected implies not is_closed
	error_excludes_closed: is_error implies not is_closed
	bytes_non_negative: bytes_sent >= 0 and bytes_received >= 0
	eof_implies_not_connected: is_at_end_of_stream implies not is_connected or is_closed

end
