note
	description: "[
		Shared helpers for simple_net tests: loopback servers on free ports,
		connected clients, and a probe for contract (precondition) violations.
	]"
	author: "simple_net team"
	date: "2026-10-08"

deferred class
	NET_TEST_SUPPORT

inherit
	TEST_SET_BASE

feature {NONE} -- Contract probe

	violates_precondition (a_action: PROCEDURE): BOOLEAN
			-- Does running `a_action' raise a precondition violation?
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				a_action.call (Void)
			end
		rescue
			l_retried := True
			if attached (create {EXCEPTION_MANAGER}).last_exception as al_exception then
				Result := attached {PRECONDITION_VIOLATION} al_exception.original
			end
			retry
		end

feature {NONE} -- Sockets

	listening_server: SERVER_SOCKET
			-- A loopback server listening on a free port in 46100..46999.
		local
			l_port: INTEGER
			l_found: BOOLEAN
		do
			from
				l_port := 46100
				create Result.make_for_address (create {ADDRESS}.make_for_localhost_port (l_port))
			until
				l_found or l_port > 46999
			loop
				create Result.make_for_address (create {ADDRESS}.make_for_localhost_port (l_port))
				Result.set_timeout (10.0)
				l_found := Result.listen (4)
				l_port := l_port + 1
			variant
				46999 - l_port + 1
			end
			assert ("found a free port", l_found)
		ensure
			listening: Result.is_listening
		end

	loopback_server: SERVER_SOCKET
			-- A loopback server, not yet listening, on a port that was just free.
		do
			create Result.make_for_address (create {ADDRESS}.make_for_localhost_port (unused_port))
		ensure
			not_listening: not Result.is_listening
		end

	unused_port: INTEGER
			-- A loopback port nothing listens on: one we bound and released.
		local
			l_server: SERVER_SOCKET
		do
			l_server := listening_server
			Result := l_server.local_address.port
			l_server.close
		ensure
			valid: Result >= 1 and Result <= 65535
		end

	connected_client (a_port: INTEGER): CLIENT_SOCKET
			-- A client connected to 127.0.0.1:`a_port' (10 s timeout).
		require
			port_valid: a_port >= 1 and a_port <= 65535
		do
			create Result.make_for_host_port ("127.0.0.1", a_port)
			Result.set_timeout (10.0)
			if not Result.connect then
				assert ("connect: " + Result.last_error_string, False)
			end
		ensure
			connected: Result.is_connected
		end

	bytes_of_text (a_text: STRING): ARRAY [NATURAL_8]
			-- The 8-bit codes of `a_text'.
		local
			i: INTEGER
		do
			create Result.make_filled (0, 1, a_text.count)
			from
				i := 1
			until
				i > a_text.count
			loop
				Result [i] := a_text.code (i).to_natural_8
				i := i + 1
			end
		ensure
			same_count: Result.count = a_text.count
		end

end
