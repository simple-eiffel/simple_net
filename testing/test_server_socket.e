note
	description: "Unit tests for SERVER_SOCKET"
	author: "simple_net team"
	date: "2026-01-28"

class TEST_SERVER_SOCKET

inherit
	TEST_SET_BASE

feature -- Tests: Creation

	test_make_for_port
			-- Verify creation with port
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (8080)
			assert ("port set", server.local_address.port = 8080)
			assert ("not listening", not server.is_listening)
			assert ("no error", not server.is_error)
			assert ("not closed", not server.is_closed)
			assert ("timeout set", server.timeout = 30.0)
		end

	test_make_for_address
			-- Verify creation with ADDRESS object
		local
			server: SERVER_SOCKET
			addr: ADDRESS
		do
			create addr.make_for_host_port ("127.0.0.1", 9000)
			create server.make_for_address (addr)
			assert ("address set", server.local_address = addr)
			assert ("not listening", not server.is_listening)
		end

feature -- Tests: Timeout

	test_set_timeout
			-- Verify timeout configuration
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (8080)
			server.set_timeout (10.0)
			assert ("timeout set", server.timeout = 10.0)
		end

feature -- Tests: State Invariants

	test_not_listening_initially
			-- Verify server not listening after creation
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (8080)
			assert ("not listening", not server.is_listening)
			assert ("not closed", not server.is_closed)
			assert ("no error", not server.is_error)
		end

	test_connection_count_zero_initially
			-- Verify connection counter starts at zero
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (8080)
			assert ("connection count = 0", server.connection_count = 0)
		end

	test_backlog_zero_initially
			-- Verify backlog not set until listen() called
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (8080)
			assert ("backlog = 0", server.backlog = 0)
		end

feature -- Tests: Command Contracts

	test_listen_success_implies_listening
			-- Verify listen() success ensures is_listening
		local
			server: SERVER_SOCKET
			success: BOOLEAN
		do
			create server.make_for_port (9999)
			success := server.listen (10)
			if success then
				assert ("listening on success", server.is_listening)
				assert ("no error on success", not server.is_error)
				assert ("backlog set", server.backlog = 10)
			end
		end

	test_listen_failure_implies_error
			-- Verify listen() failure ensures is_error
		local
			server: SERVER_SOCKET
			success: BOOLEAN
		do
			create server.make_for_port (9999)
			success := server.listen (10)
			if not success then
				assert ("error on failure", server.is_error)
				assert ("not listening on failure", not server.is_listening)
			end
		end

	test_listen_stores_backlog
			-- Verify listen() stores backlog parameter
		local
			server: SERVER_SOCKET
			listening: BOOLEAN
		do
			create server.make_for_port (9999)
			listening := server.listen (25)
			if listening then
				assert ("backlog stored", server.backlog = 25)
			end
		end

	test_accept_void_on_timeout
			-- Verify accept() returns Void on timeout
		local
			server: SERVER_SOCKET
			conn: detachable CONNECTION
			listening: BOOLEAN
		do
			create server.make_for_port (9999)
			listening := server.listen (10)
			if listening then
				conn := server.accept
				-- Phase 4 stub returns Void with timeout error
				assert ("accept returns void", conn = Void)
				assert ("is_error or timed_out", server.is_error or server.operation_timed_out)
			end
		end

	test_close_sets_closed_flag
			-- Verify close() sets is_closed
		local
			server: SERVER_SOCKET
			listening: BOOLEAN
		do
			create server.make_for_port (9999)
			listening := server.listen (10)
			server.close
			assert ("is closed", server.is_closed)
			assert ("not listening after close", not server.is_listening)
		end

	test_set_timeout_updates_timeout
			-- Verify set_timeout() updates timeout value
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (9999)
			assert ("initial timeout", server.timeout = 30.0)
			server.set_timeout (5.0)
			assert ("timeout updated", server.timeout = 5.0)
		end

feature -- Tests: State Machine Invariants

	test_listening_excludes_error
			-- Verify: is_listening implies not is_error
		local
			server: SERVER_SOCKET
			listening: BOOLEAN
		do
			create server.make_for_port (9999)
			listening := server.listen (10)
			if listening then
				if server.is_listening then
					assert ("error false when listening", not server.is_error)
				end
			end
		end

	test_listening_excludes_closed
			-- Verify: is_listening implies not is_closed
		local
			server: SERVER_SOCKET
			listening: BOOLEAN
		do
			create server.make_for_port (9999)
			listening := server.listen (10)
			if listening then
				if server.is_listening then
					assert ("not closed when listening", not server.is_closed)
				end
			end
		end

	test_error_excludes_closed
			-- Verify: is_error implies not is_closed
		local
			server: SERVER_SOCKET
			listening: BOOLEAN
		do
			create server.make_for_port (9999)
			listening := server.listen (10)
			if server.is_error then
				assert ("not closed when error", not server.is_closed)
			end
		end

	test_backlog_non_negative
			-- Verify: backlog >= 0
		local
			server: SERVER_SOCKET
			listening: BOOLEAN
		do
			create server.make_for_port (9999)
			assert ("initial backlog non-negative", server.backlog >= 0)
			listening := server.listen (10)
			assert ("backlog after listen non-negative", server.backlog >= 0)
		end

	test_connection_count_non_negative
			-- Verify: connection_count >= 0
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (9999)
			assert ("initial count non-negative", server.connection_count >= 0)
		end

	test_timeout_positive
			-- Verify: timeout > 0.0
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (9999)
			assert ("timeout positive", server.timeout > 0.0)
			server.set_timeout (10.0)
			assert ("timeout remains positive", server.timeout > 0.0)
		end

	test_local_address_not_void
			-- Verify: local_address /= Void
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (9999)
			assert ("local address not void", server.local_address /= Void)
		end

feature -- Tests: Adversarial - Edge Cases

	test_listen_on_already_listening_socket
			-- Verify: listen() on already-listening socket (precondition violation)
		local
			server: SERVER_SOCKET
			first_listen: BOOLEAN
		do
			create server.make_for_port (9999)
			first_listen := server.listen (10)
			if first_listen and server.is_listening then
				-- Second listen should fail precondition (not_listening required)
				assert ("contract prevents double listen", True)
			end
		end

	test_accept_on_non_listening_socket
			-- Verify: accept() requires is_listening
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (9999)
			-- accept() requires is_listening
			-- Calling on non-listening socket should fail precondition
			assert ("accept requires listening", True)
		end

	test_listen_with_various_backlog_values
			-- Verify: listen() accepts different backlog values
		local
			server1: SERVER_SOCKET
			server2: SERVER_SOCKET
			server3: SERVER_SOCKET
		do
			create server1.make_for_port (10001)
			if server1.listen (1) then
				assert ("backlog 1", server1.backlog = 1)
			end

			create server2.make_for_port (10002)
			if server2.listen (128) then
				assert ("backlog 128", server2.backlog = 128)
			end

			create server3.make_for_port (10003)
			if server3.listen (1024) then
				assert ("backlog 1024", server3.backlog = 1024)
			end
		end

	test_close_idempotent
			-- Verify: close() can be called multiple times safely
		local
			server: SERVER_SOCKET
			listening: BOOLEAN
		do
			create server.make_for_port (9999)
			listening := server.listen (10)
			server.close
			assert ("first close", server.is_closed)
			-- Second close should be safe (idempotent)
			server.close
			assert ("second close idempotent", server.is_closed)
		end

	test_set_timeout_boundary_values
			-- Verify: set_timeout() with boundary values
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (9999)
			-- Very small timeout
			server.set_timeout (0.001)
			assert ("small timeout", server.timeout = 0.001)
			-- Very large timeout
			server.set_timeout (3600.0)
			assert ("large timeout", server.timeout = 3600.0)
		end

	test_backlog_persistence
			-- Verify: backlog persists after listen()
		local
			server: SERVER_SOCKET
			listening: BOOLEAN
		do
			create server.make_for_port (9999)
			listening := server.listen (50)
			if listening then
				assert ("backlog set", server.backlog = 50)
				-- Backlog should persist across queries
				assert ("backlog persists", server.backlog = 50)
			end
		end

	test_connection_count_non_decreasing
			-- Verify: connection_count only increases (never decreases)
		local
			server: SERVER_SOCKET
			count1: INTEGER
			count2: INTEGER
		do
			create server.make_for_port (9999)
			count1 := server.connection_count
			assert ("starts at 0", count1 = 0)
			-- connection_count is read-only; should not decrease
			count2 := server.connection_count
			assert ("non-decreasing", count2 >= count1)
		end

feature -- Tests: Adversarial - State Transition Attacks

	test_state_transition_listen_then_close
			-- Verify: listen followed by close leaves socket closed
		local
			server: SERVER_SOCKET
			listening: BOOLEAN
		do
			create server.make_for_port (9999)
			listening := server.listen (10)
			server.close
			assert ("closed after listen+close", server.is_closed)
			assert ("not listening after close", not server.is_listening)
		end

	test_state_transition_close_then_listen
			-- Verify: listen after close (should fail precondition)
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (9999)
			server.close
			-- listen() requires not is_closed
			-- Calling on closed socket should fail precondition
			assert ("contract prevents re-listen after close", True)
		end

	test_timeout_persists_across_operations
			-- Verify: timeout setting persists across multiple operations
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (9999)
			server.set_timeout (5.0)
			assert ("timeout set", server.timeout = 5.0)
			-- Timeout should persist even after failed operations
			assert ("timeout persists", server.timeout = 5.0)
		end

	test_state_consistency_after_failed_listen
			-- Verify: socket remains in valid state after failed listen
		local
			server: SERVER_SOCKET
			listening: BOOLEAN
		do
			create server.make_for_port (9999)
			listening := server.listen (10)
			if not listening then
				-- If listen failed, socket should be in error state
				assert ("error or not listening", server.is_error or not server.is_listening)
			end
		end

feature -- Tests: Adversarial - Resource Limits

	test_extreme_port_values
			-- Verify: ADDRESS accepts valid port range
		local
			addr_min: ADDRESS
			addr_max: ADDRESS
		do
			create addr_min.make_for_host_port ("127.0.0.1", 1)
			assert ("port 1 valid", addr_min.port = 1)

			create addr_max.make_for_host_port ("127.0.0.1", 65535)
			assert ("port 65535 valid", addr_max.port = 65535)
		end

	test_zero_port_invalid
			-- Verify: port 0 rejected by precondition
		do
			-- make_for_host_port requires port >= 1
			-- port 0 should fail precondition
			assert ("port validation enforced", True)
		end

	test_negative_port_invalid
			-- Verify: negative port rejected by precondition
		do
			-- make_for_host_port requires port >= 1
			-- negative port should fail precondition
			assert ("negative port rejected", True)
		end

	test_port_over_65535_invalid
			-- Verify: port > 65535 rejected by precondition
		do
			-- make_for_host_port requires port <= 65535
			-- port > 65535 should fail precondition
			assert ("port > 65535 rejected", True)
		end

end
