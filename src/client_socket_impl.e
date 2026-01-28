note
	description: "Real TCP client socket implementation using ISE's NETWORK_SOCKET"
	author: "simple_net team"
	date: "2026-01-28"
	void_safety: "all"

class CLIENT_SOCKET_IMPL

create
	make

feature {NONE} -- Creation

	make (a_address: ADDRESS; a_timeout: REAL)
			-- Initialize real socket implementation
		require
			address_not_void: a_address /= Void
			timeout_positive: a_timeout > 0.0
		do
			socket_address := a_address
			socket_timeout := a_timeout
			is_connected := False
			is_error := False
			bytes_sent := 0
			bytes_received := 0
			is_closed := False
			create error.make (0)
		ensure
			socket_address_set: socket_address = a_address
			socket_timeout_set: socket_timeout = a_timeout
			not_connected: not is_connected
			no_error: not is_error
		end

feature {NONE} -- Representation

	socket_address: ADDRESS
			-- Remote server address

	socket_timeout: REAL
			-- Timeout in seconds

	socket_impl: detachable NETWORK_SOCKET
			-- Underlying ISE NETWORK_SOCKET (Void until connected)

	is_connected: BOOLEAN
			-- True if connected

	is_error: BOOLEAN
			-- True if error occurred

	error: ERROR_TYPE
			-- Last error

	bytes_sent: INTEGER
			-- Cumulative bytes sent

	bytes_received: INTEGER
			-- Cumulative bytes received

	is_closed: BOOLEAN
			-- True if closed

feature -- Commands

	do_connect: BOOLEAN
			-- Connect to remote server. Returns true if successful.
		require
			not_connected: not is_connected
			not_closed: not is_closed
		do
			-- TODO: Phase 10 Implementation
			-- Use ISE's NETWORK_SOCKET to connect
			-- Set socket_impl to connected socket
			-- Update is_connected, is_error, error based on result
			-- Return true if successful
			Result := False
		ensure
			-- If successful: is_connected and not is_error
			-- If failed: not is_connected and is_error
		end

	do_send (a_data: ARRAY [NATURAL_8]): BOOLEAN
			-- Send bytes. Returns true if successful.
		require
			connected: is_connected
			data_not_void: a_data /= Void
		do
			-- TODO: Phase 10 Implementation
			-- Send a_data using socket_impl
			-- Update bytes_sent on success
			-- Update is_error and error on failure
			bytes_sent := bytes_sent + a_data.count
			Result := True
		ensure
			bytes_sent_updated: bytes_sent >= 0
		end

	do_receive (a_max_bytes: INTEGER): ARRAY [NATURAL_8]
			-- Receive up to a_max_bytes. Returns empty array on EOF.
		require
			connected: is_connected
			max_bytes_positive: a_max_bytes > 0
		do
			-- TODO: Phase 10 Implementation
			-- Receive using socket_impl
			-- Update bytes_received on success
			-- Set EOF flag if peer closed
			create Result.make_empty
		ensure
			result_not_void: Result /= Void
			bytes_received_updated: bytes_received >= 0
		end

	do_close
			-- Close connection
		do
			-- TODO: Phase 10 Implementation
			-- Close socket_impl if connected
			-- Set is_closed := True
			if socket_impl /= Void then
				-- TODO: Call close on socket_impl
			end
			is_closed := True
		ensure
			is_closed: is_closed
		end

end
