note
	description: "Unit tests for CLIENT_SOCKET (I/O tests use a loopback SERVER_SOCKET in this processor)"
	author: "simple_net team"
	date: "2026-10-08"

class TEST_CLIENT_SOCKET

inherit
	NET_TEST_SUPPORT

feature -- Tests: Creation

	test_make_for_host_port
			-- Verify creation with host and port
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("example.com", 8080)
			assert ("host set", client.remote_address.host.is_equal ("example.com"))
			assert ("port set", client.remote_address.port = 8080)
			assert ("not connected", not client.is_connected)
			assert ("no error", not client.is_error)
			assert ("timeout set", client.timeout = 30.0)
		end

	test_make_for_address
			-- Verify creation with ADDRESS object
		local
			client: CLIENT_SOCKET
			addr: ADDRESS
		do
			create addr.make_for_host_port ("localhost", 9000)
			create client.make_for_address (addr)
			assert ("address set", client.remote_address = addr)
			assert ("not connected", not client.is_connected)
		end

feature -- Tests: Timeout

	test_set_timeout
			-- Verify timeout configuration
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("example.com", 8080)
			client.set_timeout (5.0)
			assert ("timeout set", client.timeout = 5.0)
		end

	test_set_timeout_updates_timeout
			-- Verify set_timeout() updates timeout value
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("example.com", 8080)
			assert ("initial timeout", client.timeout = 30.0)
			client.set_timeout (15.0)
			assert ("timeout updated", client.timeout = 15.0)
		end

	test_set_timeout_boundary_values
			-- Verify: set_timeout() with boundary values
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("example.com", 8080)
			client.set_timeout (0.001)
			assert ("small timeout", client.timeout = 0.001)
			client.set_timeout (3600.0)
			assert ("large timeout", client.timeout = 3600.0)
			assert ("zero timeout rejected", violates_precondition (agent set_client_timeout (client, 0.0)))
		end

	test_timeout_persists_across_operations
			-- Verify: timeout setting persists across a failed connect
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("127.0.0.1", unused_port)
			client.set_timeout (5.0)
			refute ("connect fails", client.connect)
			assert ("timeout persists", client.timeout = 5.0)
		end

feature -- Tests: State Invariants

	test_not_connected_initially
			-- Verify socket not connected after creation
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("example.com", 8080)
			assert ("not connected", not client.is_connected)
			assert ("not closed", not client.is_closed)
			assert ("no error", not client.is_error)
		end

	test_bytes_sent_zero_initially
			-- Verify byte counters initialized to zero
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("example.com", 8080)
			assert ("bytes sent = 0", client.bytes_sent = 0)
			assert ("bytes received = 0", client.bytes_received = 0)
		end

	test_not_at_eof_initially
			-- Verify EOF flag false initially
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("example.com", 8080)
			assert ("not at EOF", not client.is_at_end_of_stream)
		end

	test_bytes_non_negative
			-- Verify: bytes_sent >= 0 and bytes_received >= 0
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("example.com", 8080)
			assert ("bytes sent non-negative", client.bytes_sent >= 0)
			assert ("bytes received non-negative", client.bytes_received >= 0)
		end

	test_timeout_positive
			-- Verify: timeout > 0.0
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("example.com", 8080)
			assert ("timeout positive", client.timeout > 0.0)
			client.set_timeout (1.0)
			assert ("timeout remains positive", client.timeout > 0.0)
		end

	test_remote_address_not_void
			-- Verify: remote_address /= Void
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("example.com", 8080)
			assert ("remote address not void", client.remote_address /= Void)
		end

feature -- Tests: Command Contracts

	test_connect_success_implies_connected
			-- connect() to a listening loopback server succeeds and connects
		local
			server: SERVER_SOCKET
			client: CLIENT_SOCKET
		do
			server := listening_server
			create client.make_for_address (server.local_address)
			client.set_timeout (10.0)
			assert ("connect succeeds", client.connect)
			assert ("connected on success", client.is_connected)
			assert ("no error on success", not client.is_error)
			assert ("local address known", client.has_local_address)
			client.close
			server.close
		end

	test_connect_failure_implies_error
			-- connect() to a port nobody listens on fails into the error state
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("127.0.0.1", unused_port)
			client.set_timeout (10.0)
			refute ("connect fails", client.connect)
			assert ("error on failure", client.is_error)
			assert ("not connected on failure", not client.is_connected)
			assert ("refused", client.error_classification.is_connection_refused)
		end

	test_send_increments_bytes_sent
			-- Verify send() increments bytes_sent counter
		local
			server: SERVER_SOCKET
			client: CLIENT_SOCKET
		do
			server := listening_server
			client := connected_client (server.local_address.port)
			assert ("sent", client.send ({ARRAY [NATURAL_8]} <<65, 66>>))
			assert_integers_equal ("bytes incremented", 2, client.bytes_sent)
			client.close
			server.close
		end

	test_send_string_increments_bytes_sent
			-- Verify send_string() increments bytes_sent counter
		local
			server: SERVER_SOCKET
			client: CLIENT_SOCKET
		do
			server := listening_server
			client := connected_client (server.local_address.port)
			assert ("sent", client.send_string ("Hello"))
			assert_integers_equal ("bytes incremented", 5, client.bytes_sent)
			client.close
			server.close
		end

	test_receive_on_eof_returns_empty
			-- receive() returns an empty array once the peer has closed
		local
			server: SERVER_SOCKET
			client: CLIENT_SOCKET
		do
			server := listening_server
			client := connected_client (server.local_address.port)
			if attached server.accept as al_connection then
				al_connection.close
			else
				assert ("accepted", False)
			end
			assert_integers_equal ("empty on EOF", 0, client.receive (1024).count)
			assert ("EOF flagged", client.is_at_end_of_stream)
			refute ("not an error", client.is_error)
			client.close
			server.close
		end

	test_receive_string_returns_string
			-- receive_string() returns the bytes the peer sent
		local
			server: SERVER_SOCKET
			client: CLIENT_SOCKET
		do
			server := listening_server
			client := connected_client (server.local_address.port)
			if attached server.accept as al_connection then
				assert ("peer sends", al_connection.send_string ("hi there"))
				assert_equal ("received", "hi there", client.receive_string (1024))
				assert_integers_equal ("bytes received", 8, client.bytes_received)
				al_connection.close
			else
				assert ("accepted", False)
			end
			client.close
			server.close
		end

	test_close_sets_closed_flag
			-- Verify close() sets is_closed
		local
			server: SERVER_SOCKET
			client: CLIENT_SOCKET
		do
			server := listening_server
			client := connected_client (server.local_address.port)
			client.close
			assert ("is closed", client.is_closed)
			assert ("not connected after close", not client.is_connected)
			server.close
		end

feature -- Tests: State Machine Invariants

	test_connected_excludes_error
			-- Verify: is_connected implies not is_error
		local
			server: SERVER_SOCKET
			client: CLIENT_SOCKET
		do
			server := listening_server
			client := connected_client (server.local_address.port)
			assert ("error false when connected", not client.is_error)
			client.close
			server.close
		end

	test_connected_excludes_closed
			-- Verify: is_connected implies not is_closed
		local
			server: SERVER_SOCKET
			client: CLIENT_SOCKET
		do
			server := listening_server
			client := connected_client (server.local_address.port)
			assert ("not closed when connected", not client.is_closed)
			client.close
			server.close
		end

	test_error_excludes_closed
			-- Verify: is_error implies not is_closed (and close clears the error state)
		local
			client: CLIENT_SOCKET
			connected: BOOLEAN
		do
			create client.make_for_host_port ("127.0.0.1", unused_port)
			client.set_timeout (10.0)
			connected := client.connect
			refute ("not connected", connected)
			assert ("in error", client.is_error)
			assert ("not closed when error", not client.is_closed)
			client.close
			refute ("close clears error", client.is_error)
			assert ("closed", client.is_closed)
		end

	test_bytes_sent_monotonic_increasing
			-- Verify: bytes_sent only increases
		local
			server: SERVER_SOCKET
			client: CLIENT_SOCKET
			bytes1: INTEGER
		do
			server := listening_server
			client := connected_client (server.local_address.port)
			bytes1 := client.bytes_sent
			assert ("sent", client.send ({ARRAY [NATURAL_8]} <<65>>))
			assert ("bytes monotonic", client.bytes_sent > bytes1)
			client.close
			server.close
		end

	test_multiple_consecutive_sends
			-- Verify: multiple sends accumulate bytes correctly
		local
			server: SERVER_SOCKET
			client: CLIENT_SOCKET
		do
			server := listening_server
			client := connected_client (server.local_address.port)
			assert ("first", client.send ({ARRAY [NATURAL_8]} <<65>>))
			assert ("second", client.send ({ARRAY [NATURAL_8]} <<65, 66>>))
			assert_integers_equal ("accumulates bytes", 3, client.bytes_sent)
			client.close
			server.close
		end

feature -- Tests: Adversarial - State Transition Attacks

	test_state_transition_connect_then_close
			-- Verify: connect followed by close leaves socket closed
		local
			server: SERVER_SOCKET
			client: CLIENT_SOCKET
		do
			server := listening_server
			client := connected_client (server.local_address.port)
			client.close
			assert ("closed after connect+close", client.is_closed)
			assert ("not connected after close", not client.is_connected)
			server.close
		end

	test_state_transition_close_then_connect
			-- Verify: connect after close violates the precondition
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("127.0.0.1", 80)
			client.close
			assert ("reconnect after close rejected", violates_precondition (agent connect_client (client)))
		end

	test_connect_on_already_connected_socket
			-- Verify: connect() on an already-connected socket violates the precondition
		local
			server: SERVER_SOCKET
			client: CLIENT_SOCKET
		do
			server := listening_server
			client := connected_client (server.local_address.port)
			assert ("second connect rejected", violates_precondition (agent connect_client (client)))
			assert ("still connected", client.is_connected)
			client.close
			server.close
		end

	test_send_on_disconnected_socket
			-- Verify: send() on a never-connected socket violates the precondition
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("127.0.0.1", 80)
			assert ("send requires connected", violates_precondition (agent send_one_byte (client)))
		end

	test_receive_on_disconnected_socket
			-- Verify: receive() on a never-connected socket violates the precondition
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("127.0.0.1", 80)
			assert ("receive requires connected", violates_precondition (agent receive_some (client)))
		end

	test_close_idempotent
			-- Verify: close() can be called more than once
		local
			client: CLIENT_SOCKET
		do
			create client.make_for_host_port ("example.com", 8080)
			client.close
			assert ("first close", client.is_closed)
			client.close
			assert ("second close idempotent", client.is_closed)
		end

feature -- Tests: Adversarial - Resource Limits

	test_large_byte_count_tracking
			-- Verify: bytes_sent tracks a 32 KiB send exactly (fits loopback buffers in one thread)
		local
			server: SERVER_SOCKET
			client: CLIENT_SOCKET
			data: ARRAY [NATURAL_8]
		do
			server := listening_server
			client := connected_client (server.local_address.port)
			create data.make_filled (7, 1, 32_768)
			if attached server.accept as al_connection then
				assert ("sent", client.send (data))
				assert_integers_equal ("counted", 32_768, client.bytes_sent)
				assert_integers_equal ("peer got it all", 32_768, al_connection.receive_exactly (32_768).count)
				al_connection.close
			else
				assert ("accepted", False)
			end
			client.close
			server.close
		end

	test_extreme_port_values
			-- Verify: ADDRESS accepts valid port range
		local
			addr_min: ADDRESS
			addr_max: ADDRESS
		do
			create addr_min.make_for_host_port ("localhost", 1)
			assert ("port 1 valid", addr_min.port = 1)
			create addr_max.make_for_host_port ("localhost", 65535)
			assert ("port 65535 valid", addr_max.port = 65535)
		end

	test_socket_with_empty_hostname
			-- Verify: an empty host name violates the creation precondition
		do
			assert ("empty host rejected", violates_precondition (agent make_client ("", 8080)))
		end

	test_ipv4_validation_accuracy
			-- Verify: is_ipv4_address correctly identifies IPv4
		local
			valid_ipv4: ADDRESS
			invalid_ipv4: ADDRESS
		do
			create valid_ipv4.make_for_host_port ("192.168.1.1", 8080)
			assert ("valid ipv4 detected", valid_ipv4.is_ipv4_address)
			create invalid_ipv4.make_for_host_port ("256.256.256.256", 8080)
			refute ("octet over 255 rejected", invalid_ipv4.is_ipv4_address)
		end

feature {NONE} -- Actions

	set_client_timeout (a_client: CLIENT_SOCKET; a_seconds: REAL)
			-- Call set_timeout.
		do
			a_client.set_timeout (a_seconds)
		end

	connect_client (a_client: CLIENT_SOCKET)
			-- Call connect.
		do
			a_client.connect.do_nothing
		end

	send_one_byte (a_client: CLIENT_SOCKET)
			-- Call send.
		do
			a_client.send ({ARRAY [NATURAL_8]} <<1>>).do_nothing
		end

	receive_some (a_client: CLIENT_SOCKET)
			-- Call receive.
		do
			a_client.receive (1).do_nothing
		end

	make_client (a_host: STRING; a_port: INTEGER)
			-- Create a client (discarded).
		local
			l_client: CLIENT_SOCKET
		do
			create l_client.make_for_host_port (a_host, a_port)
		end

end
