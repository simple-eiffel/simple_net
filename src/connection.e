note
	description: "Represents an accepted TCP connection from a server"
	author: "simple_net team"
	date: "2026-01-28"
	void_safety: "all"

class CONNECTION

create
	make

feature {NONE} -- Creation

	make (a_remote_address: ADDRESS; a_timeout: REAL)
			-- Create connection for accepted socket
		require
			address_not_void: a_remote_address /= Void
			timeout_positive: a_timeout > 0.0
		do
			remote_address_impl := a_remote_address
			timeout_impl := a_timeout
			bytes_sent_impl := 0
			bytes_received_impl := 0
			is_closed_impl := False
			is_at_eof_impl := False
			is_error_impl := False
			create error_impl.make (0)
		ensure
			remote_address_set: remote_address = a_remote_address
			timeout_set: timeout = a_timeout
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
			-- Send bytes. Returns true if successful.
		require
			data_not_void: a_data /= Void
			not_closed: not is_closed
		do
			-- TODO: Phase 10 Implementation
			bytes_sent_impl := bytes_sent_impl + a_data.count
			Result := True
		ensure
			bytes_sent_updated: bytes_sent >= 0
		end

	send_string (a_string: STRING): BOOLEAN
			-- Send string. Returns true if successful.
		require
			string_not_void: a_string /= Void
			not_closed: not is_closed
		do
			-- TODO: Phase 10 Implementation
			Result := True
		ensure
			bytes_sent_updated: bytes_sent >= 0
		end

	receive (a_max_bytes: INTEGER): ARRAY [NATURAL_8]
			-- Receive up to a_max_bytes. Empty array on EOF.
		require
			max_bytes_positive: a_max_bytes > 0
			not_closed: not is_closed
		do
			-- TODO: Phase 10 Implementation
			create Result.make_empty
		ensure
			result_not_void: Result /= Void
			bytes_received_updated: bytes_received >= 0
		end

	receive_string: STRING
			-- Receive as string (UTF-8). Empty string on EOF.
		require
			not_closed: not is_closed
		do
			-- TODO: Phase 10 Implementation
			create Result.make_empty
		ensure
			result_not_void: Result /= Void
			bytes_received_updated: bytes_received >= 0
		end

	close
			-- Close connection
		do
			is_closed_impl := True
		ensure
			is_closed: is_closed
		end

invariant
	address_not_void: remote_address_impl /= Void
	timeout_positive: timeout > 0.0
	bytes_non_negative: bytes_sent >= 0 and bytes_received >= 0

end
