note
	description: "simple_net test suite root"
	author: "simple_net team"
	date: "2026-01-28"

class TEST_SUITE

inherit
	TEST_SET_BASE

feature -- Test Registration

	tests: LINKED_LIST [TEST_SET_BASE]
			-- List of all test classes
		do
			create Result.make
			Result.extend (create {TEST_ADDRESS})
			Result.extend (create {TEST_ERROR_TYPE})
			Result.extend (create {TEST_CLIENT_SOCKET})
			Result.extend (create {TEST_SERVER_SOCKET})
			Result.extend (create {TEST_SCOOP_CONSUMER})
		end

end
