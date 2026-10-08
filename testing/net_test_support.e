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

feature {NONE} -- Probes through a separate reference
		-- Each takes a `separate' argument, so the call is made on the object's
		-- own processor; only basic values come back.

	client_remote_port (a_client: separate CLIENT_SOCKET): INTEGER
			-- Remote port of `a_client'.
		do
			Result := a_client.remote_address.port
		end

	client_remote_host_count (a_client: separate CLIENT_SOCKET): INTEGER
			-- Length of the remote host name of `a_client'.
		do
			Result := a_client.remote_address.host.count
		end

	held_client_port (a_holder: separate NET_CLIENT_HOLDER): INTEGER
			-- Remote port of the client `a_holder' owns.
		do
			Result := client_remote_port (a_holder.client)
		end

	held_client_host_count (a_holder: separate NET_CLIENT_HOLDER): INTEGER
			-- Remote host length of the client `a_holder' owns.
		do
			Result := client_remote_host_count (a_holder.client)
		end

	held_client_connected (a_holder: separate NET_CLIENT_HOLDER): BOOLEAN
			-- Is the client `a_holder' owns connected?
		do
			Result := client_connected (a_holder.client)
		end

	client_connected (a_client: separate CLIENT_SOCKET): BOOLEAN
			-- Is `a_client' connected?
		do
			Result := a_client.is_connected
		end

	server_local_port (a_server: separate SERVER_SOCKET): INTEGER
			-- Local port of `a_server'.
		do
			Result := a_server.local_address.port
		end

	server_listening (a_server: separate SERVER_SOCKET): BOOLEAN
			-- Is `a_server' listening?
		do
			Result := a_server.is_listening
		end

	address_port (a_address: separate ADDRESS): INTEGER
			-- Port of `a_address'.
		do
			Result := a_address.port
		end

	address_text_count (a_address: separate ADDRESS): INTEGER
			-- Length of `a_address.as_string'.
		do
			Result := a_address.as_string.count
		end

	address_loopback (a_address: separate ADDRESS): BOOLEAN
			-- Is `a_address' a loopback address?
		do
			Result := a_address.is_loopback
		end

	address_survives_copy_mutation (a_address: separate ADDRESS): BOOLEAN
			-- Does mutating the string returned by `as_string' leave `a_address' unchanged?
		local
			l_copy: STRING
			l_count, l_port: INTEGER
		do
			l_count := a_address.as_string.count
			l_port := a_address.port
			create l_copy.make_from_separate (a_address.as_string)
			l_copy.append ("-mutated")
			Result := a_address.as_string.count = l_count and a_address.port = l_port and l_copy.count = l_count + 8
		end

	error_code (a_error: separate ERROR_TYPE): INTEGER
			-- Code of `a_error'.
		do
			Result := a_error.code
		end

	error_is_refused (a_error: separate ERROR_TYPE): BOOLEAN
			-- Is `a_error' classified as a refused connection?
		do
			Result := a_error.is_connection_refused
		end

	connection_closed (a_connection: separate CONNECTION): BOOLEAN
			-- Is `a_connection' closed?
		do
			Result := a_connection.is_closed
		end

	connection_bytes_received (a_connection: separate CONNECTION): INTEGER
			-- Bytes received so far on `a_connection'.
		do
			Result := a_connection.bytes_received
		end

	connection_remote_port (a_connection: separate CONNECTION): INTEGER
			-- Remote (client) port of `a_connection'.
		do
			Result := a_connection.remote_address.port
		end

end
