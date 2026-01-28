note
	description: "Simple direct test of contract violation"
	author: "simple_net team"
	date: "2026-01-28"

class TEST_SIMPLE_VIOLATION

inherit
	TEST_SET_BASE

feature -- Direct Test

	test_simple_empty_host_direct
			-- Simplest possible test: just try to create with empty host
		do
			try_create_empty
		end

	try_create_empty
			-- Helper - called directly, not via agent
		local
			addr: ADDRESS
		do
			-- This call should violate precondition: non_empty_host
			create addr.make_for_host_port ("", 8080)
			
			-- If we get here, violation was allowed
			print ("%N[VIOLATION ALLOWED] Created with empty host%N")
			assert ("violation allowed", addr.host.is_empty)
		rescue
			-- If we get here, violation raised exception
			print ("%N[VIOLATION CAUGHT] Exception raised for empty host%N")
			assert ("violation caught", False)
		end

end
