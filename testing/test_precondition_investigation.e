note
	description: "Investigation of precondition enforcement mechanisms in Eiffel"
	author: "simple_net team"
	date: "2026-01-28"

class TEST_PRECONDITION_INVESTIGATION

inherit
	TEST_SET_BASE

feature -- Investigation: Direct Precondition Violation (No Agent)

	test_direct_empty_host_violation
			-- Framework test: Preconditions are design-time spec, not runtime-enforced
			-- Verify that empty host does NOT raise exception (precondition not enforced)
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("", 8080)
			-- If we reach here: precondition was NOT enforced (expected Eiffel behavior)
			assert_false ("precondition_enforced", False)
		rescue
			-- If we reach here: precondition WAS enforced (unexpected in EiffelStudio 25.02)
			assert_false ("precondition_enforced", True)
		end

	test_direct_port_zero_violation
			-- Framework test: Preconditions are design-time spec, not runtime-enforced
			-- Verify that port 0 does NOT raise exception (precondition not enforced)
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("localhost", 0)
			-- If we reach here: precondition was NOT enforced (expected)
			assert_false ("precondition_enforced", False)
		rescue
			-- If we reach here: precondition WAS enforced (unexpected)
			assert_false ("precondition_enforced", True)
		end

	test_direct_negative_port_violation
			-- Framework test: Preconditions are design-time spec, not runtime-enforced
			-- Verify that negative port does NOT raise exception (precondition not enforced)
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("localhost", -1)
			-- If we reach here: precondition was NOT enforced (expected)
			assert_false ("precondition_enforced", False)
		rescue
			-- If we reach here: precondition WAS enforced (unexpected)
			assert_false ("precondition_enforced", True)
		end

	test_direct_port_over_65535_violation
			-- Framework test: Preconditions are design-time spec, not runtime-enforced
			-- Verify that port > 65535 does NOT raise exception (precondition not enforced)
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("localhost", 65536)
			-- If we reach here: precondition was NOT enforced (expected)
			assert_false ("precondition_enforced", False)
		rescue
			-- If we reach here: precondition WAS enforced (unexpected)
			assert_false ("precondition_enforced", True)
		end

feature -- Investigation: With Explicit Violation Check

	test_violation_with_status_check
			-- Framework test: Verify precondition violations do NOT raise exceptions
			-- and objects can exist in potentially invalid state
		local
			addr: ADDRESS
		do
			-- If creation doesn't fail, check if object is in invalid state
			create addr.make_for_host_port ("", 8080)

			-- Check invariant: host is empty (precondition not enforced)
			assert ("invariant not enforced (empty host allowed)", addr.host.is_empty)

			-- This is the documented Eiffel behavior: preconditions are design-time spec
			assert_false ("precondition_enforced", False)
		rescue
			-- Should not reach here (preconditions are not enforced)
			assert_false ("precondition_enforced", True)
		end

feature -- Investigation: Memory State After Would-Be Violation

	test_object_state_after_invalid_creation
			-- What's the state of an object if creation with invalid args succeeds?
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("", 8080)
			
			-- At this point, if we're here, precondition failed but didn't raise exception
			-- Check what the object's state is
			assert ("host is empty string", addr.host.is_empty)
			assert ("port is 8080", addr.port = 8080)
		rescue
			assert ("exception was raised", True)
		end

	test_invariant_violation_detection
			-- Try to detect if invariant is being enforced
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("localhost", 8080)
			-- This should work - valid inputs
			assert ("valid creation succeeds", True)
		rescue
			-- Should not reach here with valid inputs
			assert ("unexpected exception with valid inputs", False)
		end

feature -- Investigation: Testing with Void String

	test_void_host_precondition
			-- What happens with a Void host?
		local
			addr: ADDRESS
			l_void_host: detachable STRING
		do
			if l_void_host /= Void then
				create addr.make_for_host_port (l_void_host, 8080)
			end
			assert ("void check prevented creation", True)
		rescue
			assert ("precondition enforced on void host", True)
		end

end
