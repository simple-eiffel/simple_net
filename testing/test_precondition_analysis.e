note
	description: "Preconditions on ADDRESS fire at run time (contracts are monitored in the test build)."
	author: "simple_net team"
	date: "2026-10-08"

class TEST_PRECONDITION_ANALYSIS

inherit
	NET_TEST_SUPPORT

feature -- Tests

	test_what_happens_with_empty_host
			-- An empty host raises a precondition violation.
		do
			assert ("empty host raises", violates_precondition (agent make_address ("", 8080)))
		end

	test_what_happens_with_port_zero
			-- Port 0 raises a precondition violation.
		do
			assert ("port 0 raises", violates_precondition (agent make_address ("localhost", 0)))
		end

feature {NONE} -- Actions

	make_address (a_host: STRING; a_port: INTEGER)
			-- Create an ADDRESS (the result is discarded).
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port (a_host, a_port)
		end

end
