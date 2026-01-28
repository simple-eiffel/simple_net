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
			-- Local address this server listens on

	timeout_impl: REAL
			-- Timeout in seconds for accept operations
			-- Default: 30.0 seconds

	is_listening_impl: BOOLEAN
			-- True if successfully listening for connections

	is_error_impl: BOOLEAN
			-- True if bind/listen failed or error occurred

	error_impl: ERROR_TYPE
			-- Last error that occurred

	backlog_impl: INTEGER
			-- Connection queue depth (listen parameter)

	is_closed_impl: BOOLEAN
			-- True if server socket has been closed

	connection_count_impl: INTEGER
			-- Total connections accepted (lifetime counter)

feature -- Creation

	make_for_port (a_port: INTEGER)
			-- Initialize server socket to listen on all interfaces (0.0.0.0) on `a_port'
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
			-- Initialize server socket to listen on `a_address'
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
			-- Start listening for incoming connections with queue depth `a_backlog'.
			-- Returns true if successful, false on error (e.g., port already in use).
		require
			not_listening: not is_listening
			positive_backlog: a_backlog > 0
			not_already_closed: not is_closed
		do
			-- Phase 4 Stub: Return success (real implementation would use NETWORK_SOCKET)
			is_listening_impl := True
			backlog_impl := a_backlog
			is_error_impl := False
			error_impl.make (0)
			Result := True
		ensure
			success_means_listening: Result implies (is_listening and not is_error and backlog = a_backlog)
			failure_means_error: (not Result) implies (is_error and not is_listening)
			-- Frame conditions: what does NOT change
			local_address_unchanged: local_address = old local_address
			timeout_unchanged: timeout = old timeout
			connection_count_unchanged: connection_count = old connection_count
			closed_state_unchanged: is_closed = old is_closed
		end

	accept: detachable CONNECTION
			-- Wait for and accept next incoming client connection.
			-- Returns new CONNECTION object on success, Void on timeout or error.
			-- On error, is_error becomes true.
		require
			is_listening: is_listening
			not_in_error: not is_error
		do
			-- Phase 4 Stub: Return Void (timeout/error simulation)
			is_error_impl := True
			error_impl.make (-1)  -- -1 for generic timeout
			Result := Void
		ensure
			success_guarantee: (Result /= Void) implies (connection_count = old connection_count + 1 and not is_error)
			void_means_error_or_timeout: (Result = Void) implies (is_error or operation_timed_out)
			-- Frame conditions: what does NOT change
			local_address_unchanged: local_address = old local_address
			timeout_unchanged: timeout = old timeout
			backlog_unchanged: backlog = old backlog
			closed_state_unchanged: is_closed = old is_closed
		end

	close
			-- Stop listening and close server socket.
		require
			not_already_closed: not is_closed
		do
			is_closed_impl := True
			is_listening_impl := False
		ensure
			is_closed: is_closed
			not_listening: not is_listening
			-- Frame conditions: what does NOT change
			local_address_unchanged: local_address = old local_address
			timeout_unchanged: timeout = old timeout
			connection_count_unchanged: connection_count = old connection_count
			backlog_unchanged: backlog = old backlog
		end

	set_timeout (a_seconds: REAL)
			-- Set timeout for accept() calls
		require
			positive_timeout: a_seconds > 0.0
		do
			timeout_impl := a_seconds
		ensure
			timeout_set: timeout = a_seconds
			-- Frame conditions: what does NOT change
			local_address_unchanged: local_address = old local_address
			listening_state_unchanged: is_listening = old is_listening
			error_state_unchanged: is_error = old is_error
			closed_state_unchanged: is_closed = old is_closed
			connection_count_unchanged: connection_count = old connection_count
			backlog_unchanged: backlog = old backlog
		end

feature -- Queries

	is_listening: BOOLEAN
			-- Is server actively listening for connections?
		do
			Result := is_listening_impl and not is_error_impl and not is_closed_impl
		ensure
			listening_or_error: Result or not is_listening_impl or is_error_impl or is_closed_impl
		end

	is_closed: BOOLEAN
			-- Has server socket been closed?
		do
			Result := is_closed_impl
		end

	is_error: BOOLEAN
			-- Is server socket in error state?
		do
			Result := is_error_impl
		ensure
			error_xor_listening: Result or is_listening
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

	backlog: INTEGER
			-- Connection queue depth (set by listen)
		require
			is_listening or is_closed
		do
			Result := backlog_impl
		ensure
			non_negative: Result >= 0
		end

	connection_count: INTEGER
			-- Total connections accepted (lifetime counter)
		do
			Result := connection_count_impl
		ensure
			non_negative: Result >= 0
		end

	timeout: REAL
			-- Current timeout in seconds for accept()
		do
			Result := timeout_impl
		ensure
			positive: Result > 0.0
		end

	local_address: ADDRESS
			-- Local address this server listens on
		do
			Result := local_address_impl
		ensure
			result_not_void: Result /= Void
		end

	operation_timed_out: BOOLEAN
			-- Did last operation (accept) timeout?
		do
			Result := is_error and error_classification.is_timeout
		end

invariant
	listening_excludes_error: is_listening implies not is_error
	listening_excludes_closed: is_listening implies not is_closed
	error_excludes_closed: is_error implies not is_closed
	backlog_non_negative: backlog >= 0
	connection_count_non_negative: connection_count >= 0
	timeout_positive: timeout > 0.0
	local_address_not_void: local_address_impl /= Void

end
