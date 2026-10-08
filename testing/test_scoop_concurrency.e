note
	description: "Real SCOOP concurrency tests for simple_net"
	author: "simple_net team"
	date: "2026-01-28"

class TEST_SCOOP_CONCURRENCY

inherit
	NET_TEST_SUPPORT

feature -- Tests: Concurrent Socket Type Compatibility
		-- Each test creates the object on its own SCOOP processor (`create' on a
		-- separate entity) and reads it back through a separate call.

	test_concurrent_client_socket_type
			-- A CLIENT_SOCKET created on its own processor keeps its state.
		local
			l_separate: separate NET_CLIENT_HOLDER
		do
			create l_separate.make (8080)
			assert_integers_equal ("remote port via separate call", 8080, held_client_port (l_separate))
			assert ("not connected", not held_client_connected (l_separate))
		end

	test_concurrent_server_socket_type
			-- A SERVER_SOCKET created on its own processor keeps its state.
		local
			l_separate: separate SERVER_SOCKET
		do
			create l_separate.make_for_port (9000)
			assert_integers_equal ("local port via separate call", 9000, server_local_port (l_separate))
			assert ("not listening", not server_listening (l_separate))
		end

	test_concurrent_address_type
			-- An ADDRESS created on its own processor keeps its state.
		local
			l_separate: separate ADDRESS
		do
			create l_separate.make_for_localhost_port (5000)
			assert_integers_equal ("port via separate call", 5000, address_port (l_separate))
			assert_integers_equal ("text length", ("127.0.0.1:5000").count, address_text_count (l_separate))
			assert ("loopback", address_loopback (l_separate))
		end

	test_concurrent_error_type
			-- An ERROR_TYPE created on its own processor keeps its classification.
		local
			l_separate: separate ERROR_TYPE
		do
			create l_separate.make (111)
			assert_integers_equal ("code via separate call", 111, error_code (l_separate))
			assert ("111 is a refusal", error_is_refused (l_separate))
		end

feature -- Tests: SCOOP Keyword Compatibility
		-- A plain (same-processor) object is assignable to a `separate' entity
		-- and reads the same through it.

	test_separate_object_type_conformance_client
			-- A CLIENT_SOCKET is assignable to separate CLIENT_SOCKET.
		local
			l_plain: CLIENT_SOCKET
			l_type: separate CLIENT_SOCKET
		do
			create l_plain.make_for_host_port ("127.0.0.1", 8081)
			l_type := l_plain
			assert_integers_equal ("same port", l_plain.remote_address.port, client_remote_port (l_type))
			assert_integers_equal ("same host length", l_plain.remote_address.host.count, client_remote_host_count (l_type))
		end

	test_separate_object_type_conformance_server
			-- A SERVER_SOCKET is assignable to separate SERVER_SOCKET.
		local
			l_plain: SERVER_SOCKET
			l_type: separate SERVER_SOCKET
		do
			create l_plain.make_for_port (9001)
			l_type := l_plain
			assert_integers_equal ("same port", l_plain.local_address.port, server_local_port (l_type))
			assert ("same listening state", l_plain.is_listening = server_listening (l_type))
		end

	test_separate_object_type_conformance_address
			-- An ADDRESS is assignable to separate ADDRESS.
		local
			l_plain: ADDRESS
			l_type: separate ADDRESS
		do
			create l_plain.make_for_host_port ("10.0.0.7", 4242)
			l_type := l_plain
			assert_integers_equal ("same port", l_plain.port, address_port (l_type))
			assert_integers_equal ("same text length", l_plain.as_string.count, address_text_count (l_type))
		end

	test_separate_object_type_conformance_error
			-- An ERROR_TYPE is assignable to separate ERROR_TYPE.
		local
			l_plain: ERROR_TYPE
			l_type: separate ERROR_TYPE
		do
			create l_plain.make (10061)
			l_type := l_plain
			assert_integers_equal ("same code", l_plain.code, error_code (l_type))
			assert ("same classification", l_plain.is_connection_refused = error_is_refused (l_type))
		end

feature -- Tests: Concurrent Object Semantics

	test_client_socket_void_safety_separate
			-- A separate CLIENT_SOCKET always has an attached remote address with a host.
		local
			l_separate: separate NET_CLIENT_HOLDER
		do
			create l_separate.make (8080)
			assert_integers_equal ("host attached through separate call", ("localhost").count, held_client_host_count (l_separate))
		end

	test_server_socket_void_safety_separate
			-- A separate SERVER_SOCKET always has an attached local address.
		local
			l_separate: separate SERVER_SOCKET
		do
			create l_separate.make_for_port (9002)
			assert_integers_equal ("local address attached through separate call", 9002, server_local_port (l_separate))
		end

	test_address_immutability_separate
			-- Mutating the string `as_string' returns never changes a separate ADDRESS.
		local
			l_separate: separate ADDRESS
		do
			create l_separate.make_for_localhost_port (8080)
			assert ("copy mutation leaves address unchanged", address_survives_copy_mutation (l_separate))
			assert_integers_equal ("port still 8080", 8080, address_port (l_separate))
		end

	test_connection_semantics_separate
			-- An accepted CONNECTION, reached as a separate entity, counts bytes and keeps its remote address.
		local
			l_server: SERVER_SOCKET
			l_client: CLIENT_SOCKET
			l_separate: separate CONNECTION
			l_port_before: INTEGER
		do
			l_server := listening_server
			l_client := connected_client (l_server.local_address.port)
			if attached l_server.accept as al_connection then
				l_separate := al_connection
				l_port_before := connection_remote_port (l_separate)
				assert ("client send", l_client.send_string ("hello"))
				assert_integers_equal ("received 5", 5, al_connection.receive (5).count)
				assert_integers_equal ("bytes_received via separate call", 5, connection_bytes_received (l_separate))
				assert_integers_equal ("remote port unchanged", l_port_before, connection_remote_port (l_separate))
				assert ("open", not connection_closed (l_separate))
				al_connection.close
				assert ("closed via separate call", connection_closed (l_separate))
			else
				assert ("accepted a connection", False)
			end
			l_client.close
			l_server.close
		end

end
