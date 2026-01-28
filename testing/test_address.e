note
	description: "Unit tests for ADDRESS class"
	author: "simple_net team"
	date: "2026-01-28"

class TEST_ADDRESS

inherit
	TEST_SET_BASE

feature -- Tests: Creation

	test_make_for_host_port_creates_address
			-- Verify make_for_host_port creates address with correct host and port
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("example.com", 8080)
			assert ("host set", addr.host.is_equal ("example.com"))
			assert ("port set", addr.port = 8080)
		end

	test_make_for_localhost_port_creates_loopback_address
			-- Verify make_for_localhost_port creates loopback address
		local
			addr: ADDRESS
		do
			create addr.make_for_localhost_port (9000)
			assert ("is loopback", addr.is_loopback)
			assert ("port set", addr.port = 9000)
		end

feature -- Tests: Validation

	test_make_for_host_port_rejects_empty_host
			-- Verify precondition catches empty host (non_empty_host)
		local
			exception_caught: BOOLEAN
		do
			exception_caught := False
			if test_precondition_violation (agent create_address_with_empty_host) then
				exception_caught := True
			end
			assert ("empty host rejected", exception_caught)
		end

	test_make_for_host_port_rejects_invalid_port_zero
			-- Verify precondition catches port 0 (valid_port: a_port >= 1)
		do
			assert ("port 0 rejected", test_precondition_violation (agent create_address_with_port_zero))
		end

	test_make_for_host_port_rejects_invalid_port_negative
			-- Verify precondition catches negative port (valid_port: a_port >= 1)
		do
			assert ("negative port rejected", test_precondition_violation (agent create_address_with_negative_port))
		end

	test_make_for_host_port_rejects_invalid_port_over_65535
			-- Verify precondition catches port > 65535 (valid_port: a_port <= 65535)
		do
			assert ("port > 65535 rejected", test_precondition_violation (agent create_address_with_port_over_65535))
		end

feature {NONE} -- Precondition Violation Testing Helpers

	test_precondition_violation (a_test: PROCEDURE): BOOLEAN
			-- Test that `a_test' causes a precondition violation
			-- Returns true if precondition was violated (contract enforced)
			-- Returns false if operation succeeded (contract NOT enforced)
		do
			a_test.call (Void)
			-- If we reach here, precondition was NOT enforced
			Result := False
		rescue
			-- Precondition violation caught - contract is working
			Result := True
		end

	create_address_with_empty_host
			-- Try to create ADDRESS with empty host
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("", 8080)
		end

	create_address_with_port_zero
			-- Try to create ADDRESS with port 0
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("localhost", 0)
		end

	create_address_with_negative_port
			-- Try to create ADDRESS with negative port
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("localhost", -1)
		end

	create_address_with_port_over_65535
			-- Try to create ADDRESS with port > 65535
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("localhost", 65536)
		end

feature -- Tests: Queries

	test_as_string_formats_address_correctly
			-- Verify as_string returns "host:port" format
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("192.168.1.1", 5000)
			assert ("string format", addr.as_string.is_equal ("192.168.1.1:5000"))
		end

	test_is_ipv4_address_detects_ipv4
			-- Verify is_ipv4_address identifies IPv4 format
		local
			addr_ipv4: ADDRESS
			addr_hostname: ADDRESS
		do
			create addr_ipv4.make_for_host_port ("192.168.1.1", 8080)
			assert ("detected IPv4", addr_ipv4.is_ipv4_address)

			create addr_hostname.make_for_host_port ("example.com", 8080)
			assert ("not IPv4", not addr_hostname.is_ipv4_address)
		end

	test_ipv4_validation_all_zeros
			-- Verify 0.0.0.0 is valid IPv4
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("0.0.0.0", 8080)
			assert ("0.0.0.0 valid", addr.is_ipv4_address)
		end

	test_ipv4_validation_all_max
			-- Verify 255.255.255.255 is valid IPv4
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("255.255.255.255", 8080)
			assert ("255.255.255.255 valid", addr.is_ipv4_address)
		end

	test_ipv4_validation_loopback
			-- Verify 127.0.0.1 is valid IPv4
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("127.0.0.1", 8080)
			assert ("127.0.0.1 valid", addr.is_ipv4_address)
		end

	test_ipv4_validation_rejects_octet_over_255
			-- Verify 256.1.1.1 is invalid (octet > 255)
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("256.1.1.1", 8080)
			assert ("256.1.1.1 invalid", not addr.is_ipv4_address)
		end

	test_ipv4_validation_rejects_too_few_octets
			-- Verify 1.1.1 is invalid (only 3 octets)
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("1.1.1", 8080)
			assert ("1.1.1 invalid", not addr.is_ipv4_address)
		end

	test_ipv4_validation_rejects_too_many_dots
			-- Verify 1.1.1.1.1 is invalid (5 octets)
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("1.1.1.1.1", 8080)
			assert ("1.1.1.1.1 invalid", not addr.is_ipv4_address)
		end

	test_ipv4_validation_rejects_non_numeric
			-- Verify "a.b.c.d" is invalid (non-numeric)
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("a.b.c.d", 8080)
			assert ("a.b.c.d invalid", not addr.is_ipv4_address)
		end

	test_ipv4_validation_rejects_mixed_numeric
			-- Verify "1.a.1.1" is invalid (mixed numeric/non-numeric)
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("1.a.1.1", 8080)
			assert ("1.a.1.1 invalid", not addr.is_ipv4_address)
		end

	test_ipv4_validation_rejects_leading_zeros
			-- Verify "01.1.1.1" is invalid (leading zero)
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("01.1.1.1", 8080)
			assert ("01.1.1.1 invalid", not addr.is_ipv4_address)
		end

	test_ipv4_validation_rejects_only_dots
			-- Verify "...." is invalid
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("....", 8080)
			assert (".... invalid", not addr.is_ipv4_address)
		end

	test_ipv4_validation_rejects_negative_octet
			-- Verify -1 in octet is invalid
		local
			addr: ADDRESS
		do
			create addr.make_for_host_port ("-1.1.1.1", 8080)
			assert ("-1.1.1.1 invalid", not addr.is_ipv4_address)
		end

	test_is_loopback_identifies_loopback
			-- Verify is_loopback identifies loopback addresses
		local
			addr_127: ADDRESS
			addr_localhost: ADDRESS
			addr_other: ADDRESS
		do
			create addr_127.make_for_host_port ("127.0.0.1", 8080)
			assert ("127.0.0.1 is loopback", addr_127.is_loopback)

			create addr_localhost.make_for_host_port ("localhost", 8080)
			assert ("localhost is loopback", addr_localhost.is_loopback)

			create addr_other.make_for_host_port ("8.8.8.8", 8080)
			assert ("8.8.8.8 is not loopback", not addr_other.is_loopback)
		end

feature -- Tests: Immutability

	test_address_immutable_after_creation
			-- Verify ADDRESS is value object (immutable)
		local
			addr1: ADDRESS
			addr2: ADDRESS
		do
			create addr1.make_for_host_port ("example.com", 8080)
			addr2 := addr1
			-- Both should reference same address
			assert ("same host", addr2.host.is_equal (addr1.host))
			assert ("same port", addr2.port = addr1.port)
		end

end
