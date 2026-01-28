note
	description: "Detailed analysis of why preconditions aren't enforced"
	author: "simple_net team"
	date: "2026-01-28"

class TEST_PRECONDITION_ANALYSIS

inherit
	TEST_SET_BASE

feature -- Analysis 1: What Actually Happens

	test_what_happens_with_empty_host
			-- Create ADDRESS with invalid input and observe state
		local
			addr: ADDRESS
		do
			-- This should fail precondition, but does it?
			create addr.make_for_host_port ("", 8080)
			
			-- If we reach here, precondition was NOT enforced at creation
			-- Check the actual state:
			print ("%N[ANALYSIS] Empty host creation succeeded%N")
			print ("[ANALYSIS] addr.host = '" + addr.host + "'%N")
			print ("[ANALYSIS] addr.host.is_empty = " + addr.host.is_empty.out + "%N")
			print ("[ANALYSIS] addr.port = " + addr.port.out + "%N")
			
			-- The precondition says: "a_host.count > 0"
			-- But the object was created with a_host.count = 0
			assert ("precondition not enforced at creation", addr.host.count = 0)
		rescue
			print ("%N[ANALYSIS] Exception was raised - precondition IS enforced%N")
			assert ("precondition enforced", False)
		end

	test_what_happens_with_port_zero
			-- Create ADDRESS with port 0
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("localhost", 0)
			
			print ("%N[ANALYSIS] Port 0 creation succeeded%N")
			print ("[ANALYSIS] addr.port = " + addr.port.out + "%N")
			print ("[ANALYSIS] Precondition requires: a_port >= 1%N")
			
			-- The precondition says: "a_port >= 1"
			-- But the object was created with port = 0
			assert ("precondition not enforced: port is 0", addr.port = 0)
		rescue
			print ("%N[ANALYSIS] Exception was raised%N")
			assert ("unexpected exception", False)
		end

end
