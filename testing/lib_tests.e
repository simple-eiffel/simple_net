note
	description: "Library tests for SIMPLE_NET"
	author: "simple_net team"
	date: "2026-01-28"

class LIB_TESTS

inherit
	TEST_SET_BASE

feature -- Tests: ADDRESS

	test_address_creation
			-- Test ADDRESS creation
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("example.com", 8080)
			assert_equal ("host", "example.com", addr.host)
			assert_integers_equal ("port", 8080, addr.port)
		end

	test_address_loopback
			-- Test ADDRESS loopback identification
		local
			addr: ADDRESS
		do
			create addr.make_for_localhost_port (9000)
			assert_true ("is loopback", addr.is_loopback)
			assert_integers_equal ("port", 9000, addr.port)
		end

	test_address_as_string
			-- Test ADDRESS.as_string formatting
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("192.168.1.1", 5000)
			assert_equal ("format", "192.168.1.1:5000", addr.as_string)
		end

feature -- Tests: ERROR_TYPE

	test_error_type_creation
			-- Test ERROR_TYPE creation
		local
			err: ERROR_TYPE
		do
			create err.make (111)
			assert_integers_equal ("code", 111, err.code)
			assert_true ("is connection refused", err.is_connection_refused)
		end

	test_error_type_windows_codes
			-- Test ERROR_TYPE with Windows error codes
		local
			err: ERROR_TYPE
		do
			create err.make (10061)
			assert_true ("Windows connection refused", err.is_connection_refused)
		end

	test_error_type_classification
			-- Test ERROR_TYPE classification features
		local
			err_timeout: ERROR_TYPE
			err_refused: ERROR_TYPE
		do
			create err_timeout.make (110)
			assert_true ("timeout is timeout", err_timeout.is_connection_timeout)
			assert_true ("timeout is retriable", err_timeout.is_retriable)

			create err_refused.make (111)
			assert_true ("refused is not fatal", not err_refused.is_fatal)
		end

feature -- Tests: CLIENT_SOCKET

	test_client_socket_creation
			-- Test CLIENT_SOCKET creation
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("localhost", 8080)
			assert_true ("client created", client /= Void)
			assert_true ("remote address set", client.remote_address /= Void)
			assert_true ("not connected initially", not client.is_connected)
		end

	test_client_socket_timeout
			-- Test CLIENT_SOCKET timeout configuration
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("localhost", 8080)
			client.set_timeout (5.0)
			assert_true ("timeout set", client.timeout = 5.0)
		end

	test_client_socket_state_machine
			-- Test CLIENT_SOCKET state transitions
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("localhost", 8080)
			assert_true ("not connected", not client.is_connected)
			assert_true ("not error", not client.is_error)
			assert_true ("not closed", not client.is_closed)
		end

feature -- Tests: SERVER_SOCKET

	test_server_socket_creation
			-- Test SERVER_SOCKET creation
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (9000)
			assert_true ("server created", server /= Void)
			assert_true ("local address set", server.local_address /= Void)
			assert_true ("not listening initially", not server.is_listening)
		end

	test_server_socket_timeout
			-- Test SERVER_SOCKET timeout configuration
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (9000)
			server.set_timeout (10.0)
			assert_true ("timeout set", server.timeout = 10.0)
		end

	test_server_socket_state_machine
			-- Test SERVER_SOCKET state transitions
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (9000)
			assert_true ("not listening", not server.is_listening)
			assert_true ("not error", not server.is_error)
			assert_true ("not closed", not server.is_closed)
		end

end
