note
	description: "Simple direct test of contract violation"
	author: "simple_net team"
	date: "2026-10-08"

class TEST_SIMPLE_VIOLATION

inherit
	NET_TEST_SUPPORT

feature -- Direct Test

	test_simple_empty_host_direct
			-- Creating an ADDRESS with an empty host is caught by its precondition.
		local
			l_retried, l_caught: BOOLEAN
			addr: ADDRESS
		do
			if not l_retried then
				create addr.make_for_host_port ("", 8080)
			end
			assert ("violation caught", l_caught)
		rescue
			l_caught := attached (create {EXCEPTION_MANAGER}).last_exception as al_e
				and then attached {PRECONDITION_VIOLATION} al_e.original
			l_retried := True
			retry
		end

end
