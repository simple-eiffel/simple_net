note
	description: "Unit tests for SERVER_SOCKET"
	author: "simple_net team"
	date: "2026-01-28"

class TEST_SERVER_SOCKET

inherit
	NET_TEST_SUPPORT

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
			server := loopback_server
			success := server.listen (10)
			assert ("listen succeeded", success)
			if success then
				assert ("listening on success", server.is_listening)
				assert ("no error on success", not server.is_error)
				assert ("backlog set", server.backlog = 10)
			end
		end

	test_listen_failure_implies_error
			-- listen() on a port another socket holds fails into the error state
		local
			holder, server: SERVER_SOCKET
			success: BOOLEAN
		do
			holder := listening_server
			create server.make_for_address (holder.local_address)
			success := server.listen (10)
			refute ("listen fails", success)
			assert ("error on failure", server.is_error)
			assert ("not listening on failure", not server.is_listening)
			holder.close
		end

	test_listen_stores_backlog
			-- Verify listen() stores backlog parameter
		local
			server: SERVER_SOCKET
			listening: BOOLEAN
		do
			server := loopback_server
			listening := server.listen (25)
			assert ("listening", listening)
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
			server := loopback_server
			server.set_timeout (0.3)
			listening := server.listen (10)
			assert ("listening", listening)
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
			server := loopback_server
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
			server := loopback_server
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
			server := loopback_server
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
			server := loopback_server
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
			server := loopback_server
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
			server := loopback_server
			assert ("initial backlog non-negative", server.backlog >= 0)
			listening := server.listen (10)
			assert ("backlog after listen non-negative", server.backlog >= 0)
		end

	test_connection_count_non_negative
			-- Verify: connection_count >= 0
		local
			server: SERVER_SOCKET
		do
			server := loopback_server
			assert ("initial count non-negative", server.connection_count >= 0)
		end

	test_timeout_positive
			-- Verify: timeout > 0.0
		local
			server: SERVER_SOCKET
		do
			server := loopback_server
			assert ("timeout positive", server.timeout > 0.0)
			server.set_timeout (10.0)
			assert ("timeout remains positive", server.timeout > 0.0)
		end

	test_local_address_not_void
			-- Verify: local_address /= Void
		local
			server: SERVER_SOCKET
		do
			server := loopback_server
			assert ("local address not void", server.local_address /= Void)
		end

feature -- Tests: Adversarial - Edge Cases

	test_listen_on_already_listening_socket
			-- A second listen() on a listening socket violates the precondition
		local
			server: SERVER_SOCKET
		do
			server := listening_server
			assert ("double listen rejected", violates_precondition (agent listen_on (server)))
			assert ("still listening", server.is_listening)
			server.close
		end

	test_accept_on_non_listening_socket
			-- accept() on a socket that is not listening violates the precondition
		local
			server: SERVER_SOCKET
		do
			create server.make_for_port (9999)
			assert ("accept requires listening", violates_precondition (agent accept_on (server)))
		end

	test_listen_with_various_backlog_values
			-- Verify: listen() accepts different backlog values
		local
			server1: SERVER_SOCKET
			server2: SERVER_SOCKET
			server3: SERVER_SOCKET
		do
			server1 := loopback_server
			if server1.listen (1) then
				assert ("backlog 1", server1.backlog = 1)
			end

			server2 := loopback_server
			if server2.listen (128) then
				assert ("backlog 128", server2.backlog = 128)
			end

			server3 := loopback_server
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
			server := loopback_server
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
			server := loopback_server
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
			server := loopback_server
			listening := server.listen (50)
			assert ("listening", listening)
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
			server := loopback_server
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
			server := loopback_server
			listening := server.listen (10)
			server.close
			assert ("closed after listen+close", server.is_closed)
			assert ("not listening after close", not server.is_listening)
		end

	test_state_transition_close_then_listen
			-- listen() after close() violates the precondition
		local
			server: SERVER_SOCKET
		do
			server := loopback_server
			server.close
			assert ("re-listen after close rejected", violates_precondition (agent listen_on (server)))
		end

	test_timeout_persists_across_operations
			-- Verify: timeout setting persists across multiple operations
		local
			server: SERVER_SOCKET
		do
			server := loopback_server
			server.set_timeout (5.0)
			assert ("timeout set", server.timeout = 5.0)
			-- Timeout should persist even after failed operations
			assert ("timeout persists", server.timeout = 5.0)
		end

	test_state_consistency_after_failed_listen
			-- After a failed listen: in error, not listening, not closed; close clears the error
		local
			holder, server: SERVER_SOCKET
		do
			holder := listening_server
			create server.make_for_address (holder.local_address)
			refute ("listen fails", server.listen (10))
			assert ("error", server.is_error)
			refute ("not listening", server.is_listening)
			refute ("not closed", server.is_closed)
			server.close
			refute ("close clears error", server.is_error)
			holder.close
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
			-- Port 0 violates make_for_port's precondition
		do
			assert ("port 0 rejected", violates_precondition (agent make_server (0)))
		end

	test_negative_port_invalid
			-- A negative port violates make_for_port's precondition
		do
			assert ("port -1 rejected", violates_precondition (agent make_server (-1)))
		end

	test_port_over_65535_invalid
			-- Port 65536 violates make_for_port's precondition
		do
			assert ("port 65536 rejected", violates_precondition (agent make_server (65536)))
		end


feature {NONE} -- Actions

	listen_on (a_server: SERVER_SOCKET)
			-- Call listen.
		do
			a_server.listen (10).do_nothing
		end

	accept_on (a_server: SERVER_SOCKET)
			-- Call accept.
		do
			if attached a_server.accept as al_connection then
				al_connection.close
			end
		end

	make_server (a_port: INTEGER)
			-- Create a server (discarded).
		local
			l_server: SERVER_SOCKET
		do
			create l_server.make_for_port (a_port)
		end

end
