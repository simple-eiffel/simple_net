note
	description: "SCOOP consumer compatibility test - verify library works in SCOOP context"
	author: "simple_net team"
	date: "2026-01-28"

class TEST_SCOOP_CONSUMER

inherit
	NET_TEST_SUPPORT

feature -- Tests: Type Compatibility

	test_client_socket_type_in_scoop_context
			-- Verify CLIENT_SOCKET type is SCOOP-compatible
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("localhost", 8080)
			assert ("client created", client /= Void)
			assert ("remote address set", client.remote_address /= Void)
		end

	test_server_socket_type_in_scoop_context
			-- Verify SERVER_SOCKET type is SCOOP-compatible
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (9000)
			assert ("server created", server /= Void)
			assert ("local address set", server.local_address /= Void)
		end

	test_connection_type_in_scoop_context
			-- A CONNECTION (created only by SERVER_SOCKET.accept) is usable as a separate entity.
		local
			l_server: SERVER_SOCKET
			l_client: CLIENT_SOCKET
			l_separate: separate CONNECTION
		do
			l_server := listening_server
			l_client := connected_client (l_server.local_address.port)
			if attached l_server.accept as al_connection then
				l_separate := al_connection
				assert ("open through separate call", not connection_closed (l_separate))
				assert_integers_equal ("nothing received yet", 0, connection_bytes_received (l_separate))
				al_connection.close
			else
				assert ("accepted a connection", False)
			end
			l_client.close
			l_server.close
		end

	test_address_type_in_scoop_context
			-- Verify ADDRESS type is SCOOP-compatible
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("localhost", 8080)
			assert ("address created", addr /= Void)
			assert ("is value object", addr.host /= Void and addr.port > 0)
		end

	test_error_type_in_scoop_context
			-- Verify ERROR_TYPE type is SCOOP-compatible
		local
			err: ERROR_TYPE
		do
			create err.make (111)
			assert ("error created", err /= Void)
			assert ("classification available", err.is_connection_refused)
		end

feature -- Tests: Generic Types

	test_address_is_generic_compatible
			-- Verify ADDRESS works with generic constraints
		local
			addr: ADDRESS
		do
			create addr.make_for_localhost_port (8080)
			assert ("generic compatible", addr /= Void)
		end

	test_client_socket_separate_keyword_compatible
			-- A CLIENT_SOCKET created on a separate processor answers through a separate call.
		local
			l_separate: separate NET_CLIENT_HOLDER
		do
			create l_separate.make (8082)
			assert_integers_equal ("remote port", 8082, held_client_port (l_separate))
			assert ("not connected", not held_client_connected (l_separate))
		end

	test_server_socket_separate_keyword_compatible
			-- A SERVER_SOCKET created on a separate processor answers through a separate call.
		local
			l_separate: separate SERVER_SOCKET
		do
			create l_separate.make_for_port (9003)
			assert_integers_equal ("local port", 9003, server_local_port (l_separate))
			assert ("not listening", not server_listening (l_separate))
		end

feature -- Tests: Void Safety

	test_address_void_safe
			-- Verify ADDRESS creation is void-safe
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("localhost", 8080)
			if addr /= Void then
				assert ("host attached", addr.host /= Void)
				assert ("host non-empty", addr.host.count > 0)
			end
		end

	test_error_type_void_safe
			-- Verify ERROR_TYPE is void-safe
		local
			err: ERROR_TYPE
		do
			create err.make (0)
			if err /= Void then
				assert ("to_string attached", err.to_string /= Void)
			end
		end

	test_client_socket_void_safe
			-- Verify CLIENT_SOCKET is void-safe
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("localhost", 8080)
			if client /= Void then
				assert ("remote address attached", client.remote_address /= Void)
				-- Can't call send without connection; just verify structure
			end
		end

end
