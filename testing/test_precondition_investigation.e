note
	description: "[
		Preconditions ARE enforced at run time in the test build (the ECF turns on
		full assertion monitoring). Until 1.2.0 the ECF used invalid <setting>
		tags, contracts were off, and these tests asserted the opposite.
	]"
	author: "simple_net team"
	date: "2026-10-08"

class TEST_PRECONDITION_INVESTIGATION

inherit
	NET_TEST_SUPPORT

feature -- Direct precondition violations

	test_direct_empty_host_violation
			-- An empty host violates ADDRESS.make_for_host_port's precondition.
		do
			assert ("empty host rejected", violates_precondition (agent make_address ("", 8080)))
		end

	test_direct_port_zero_violation
			-- Port 0 is rejected.
		do
			assert ("port 0 rejected", violates_precondition (agent make_address ("localhost", 0)))
		end

	test_direct_negative_port_violation
			-- A negative port is rejected.
		do
			assert ("port -1 rejected", violates_precondition (agent make_address ("localhost", -1)))
		end

	test_direct_port_over_65535_violation
			-- Port 65536 is rejected.
		do
			assert ("port 65536 rejected", violates_precondition (agent make_address ("localhost", 65536)))
		end

	test_violation_with_status_check
			-- A client socket cannot be made for an empty host either.
		do
			assert ("client empty host rejected", violates_precondition (agent make_client ("", 8080)))
		end

	test_object_state_after_invalid_creation
			-- After a rejected creation, valid creation still works.
		local
			addr: ADDRESS
		do
			assert ("rejected", violates_precondition (agent make_address ("", 8080)))
			create addr.make_for_host_port ("localhost", 8080)
			assert_equal ("host", "localhost", addr.host)
			assert_integers_equal ("port", 8080, addr.port)
		end

	test_invariant_violation_detection
			-- Valid inputs give an object that satisfies its invariant.
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("localhost", 8080)
			refute ("host not empty", addr.host.is_empty)
			assert ("port in range", addr.port >= 1 and addr.port <= 65535)
		end

	test_void_host_precondition
			-- A valid action raises nothing: the probe does not report false violations.
		do
			refute ("valid creation passes", violates_precondition (agent make_address ("localhost", 80)))
		end

feature {NONE} -- Actions

	make_address (a_host: STRING; a_port: INTEGER)
			-- Create an ADDRESS (the result is discarded).
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port (a_host, a_port)
		end

	make_client (a_host: STRING; a_port: INTEGER)
			-- Create a CLIENT_SOCKET (the result is discarded).
		local
			l_client: CLIENT_SOCKET
		do
			create l_client.make_for_host_port (a_host, a_port)
		end

end
