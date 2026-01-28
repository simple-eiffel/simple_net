note
	description: "Real TCP server socket implementation using ISE's NETWORK_SOCKET"
	author: "simple_net team"
	date: "2026-01-28"
	void_safety: "all"

class SERVER_SOCKET_IMPL

create
	make

feature {NONE} -- Creation

	make (a_address: ADDRESS; a_timeout: REAL)
			-- Initialize real server socket
		require
			address_not_void: a_address /= Void
			timeout_positive: a_timeout > 0.0
		do
			socket_address := a_address
			socket_timeout := a_timeout
			is_listening := False
			is_error := False
			connection_count := 0
			is_closed := False
			backlog := 0
			create error.make (0)
		ensure
			socket_address_set: socket_address = a_address
			socket_timeout_set: socket_timeout = a_timeout
			not_listening: not is_listening
			no_error: not is_error
		end

feature {NONE} -- Representation

	socket_address: ADDRESS
			-- Local address to listen on

	socket_timeout: REAL
			-- Timeout in seconds

	socket_impl: detachable NETWORK_SOCKET
			-- Underlying ISE NETWORK_SOCKET (Void until listening)

	is_listening: BOOLEAN
			-- True if listening

	is_error: BOOLEAN
			-- True if error occurred

	error: ERROR_TYPE
			-- Last error

	connection_count: INTEGER
			-- Number of accepted connections

	is_closed: BOOLEAN
			-- True if closed

	backlog: INTEGER
			-- Listen backlog value

feature {NONE} -- Commands

	do_listen (a_backlog: INTEGER): BOOLEAN
			-- Start listening for connections with given backlog.
			-- Returns true if successful.
		require
			not_listening: not is_listening
			not_closed: not is_closed
			backlog_non_negative: a_backlog >= 0
		do
			-- TODO: Phase 10 Implementation
			-- Use ISE's NETWORK_SOCKET to listen
			-- Set socket_impl to listening socket
			-- Update is_listening, is_error, error based on result
			-- Store backlog value
			backlog := a_backlog
			Result := False
		ensure
			backlog_set: backlog = a_backlog
		end

	do_accept (a_timeout: REAL): detachable CONNECTION
			-- Accept incoming connection with timeout.
			-- Returns Void if timeout or error.
		require
			listening: is_listening
		do
			-- TODO: Phase 10 Implementation
			-- Accept using socket_impl with timeout
			-- Create CONNECTION wrapping accepted socket
			-- Increment connection_count on success
			-- Set is_error and error on failure/timeout
			-- Return Void on error/timeout
			Result := Void
		ensure
			connection_count_non_negative: connection_count >= 0
		end

	do_close
			-- Close listening socket
		do
			-- TODO: Phase 10 Implementation
			-- Close socket_impl if listening
			-- Set is_closed := True
			if socket_impl /= Void then
				-- TODO: Call close on socket_impl
			end
			is_closed := True
		ensure
			is_closed: is_closed
		end

end
