note
	description: "Unit tests for ERROR_TYPE class"
	author: "simple_net team"
	date: "2026-01-28"

class TEST_ERROR_TYPE

inherit
	TEST_SET_BASE

feature -- Tests: Creation

	test_make_creates_error_type
			-- Verify make creates error with correct code
		local
			err: ERROR_TYPE
		do
			create err.make (111)  -- ECONNREFUSED
			assert ("code set", err.code = 111)
		end

feature -- Tests: Classification

	test_is_no_error
			-- Verify is_no_error detects code 0
		local
			no_err: ERROR_TYPE
		do
			create no_err.make (0)
			assert ("is no error", no_err.is_no_error)
		end

	test_is_connection_refused_linux
			-- Verify connection refused detection (Linux code 111)
		local
			err: ERROR_TYPE
		do
			create err.make (111)
			assert ("is connection refused", err.is_connection_refused)
		end

	test_is_connection_refused_windows
			-- Verify connection refused detection (Windows code 10061)
		local
			err: ERROR_TYPE
		do
			create err.make (10061)
			assert ("is connection refused", err.is_connection_refused)
		end

	test_is_connection_timeout
			-- Verify timeout detection
		local
			err_timeout: ERROR_TYPE
			err_other: ERROR_TYPE
		do
			create err_timeout.make (110)
			assert ("is timeout", err_timeout.is_connection_timeout)

			create err_other.make (111)
			assert ("not timeout", not err_other.is_connection_timeout)
		end

	test_is_connection_reset
			-- Verify connection reset detection
		local
			err: ERROR_TYPE
		do
			create err.make (104)
			assert ("is connection reset", err.is_connection_reset)
		end

	test_is_read_error
			-- Verify read error detection
		local
			err: ERROR_TYPE
		do
			create err.make (9)  -- EBADF
			assert ("is read error", err.is_read_error)
		end

	test_is_write_error
			-- Verify write error detection
		local
			err: ERROR_TYPE
		do
			create err.make (32)  -- EPIPE
			assert ("is write error", err.is_write_error)
		end

	test_is_bind_error
			-- Verify bind error detection
		local
			err: ERROR_TYPE
		do
			create err.make (98)  -- EADDRINUSE
			assert ("is bind error", err.is_bind_error)
		end

	test_is_address_not_available
			-- Verify address error detection
		local
			err: ERROR_TYPE
		do
			create err.make (99)  -- EADDRNOTAVAIL
			assert ("is address error", err.is_address_not_available)
		end

feature -- Tests: Properties

	test_is_retriable_connection_refused
			-- Verify connection refused is retriable
		local
			err: ERROR_TYPE
		do
			create err.make (111)
			assert ("is retriable", err.is_retriable)
		end

	test_is_retriable_timeout
			-- Verify timeout is retriable
		local
			err: ERROR_TYPE
		do
			create err.make (110)
			assert ("is retriable", err.is_retriable)
		end

	test_is_fatal_bind_error
			-- Verify bind error is fatal
		local
			err: ERROR_TYPE
		do
			create err.make (98)
			assert ("is fatal", err.is_fatal)
		end

	test_is_fatal_address_error
			-- Verify address error is fatal
		local
			err: ERROR_TYPE
		do
			create err.make (99)
			assert ("is fatal", err.is_fatal)
		end

feature -- Tests: String Representation

	test_to_string_no_error
			-- Verify string representation of no error
		local
			err: ERROR_TYPE
		do
			create err.make (0)
			assert ("contains 'No error'", err.to_string.is_equal ("No error"))
		end

	test_to_string_connection_refused
			-- Verify string representation of connection refused
		local
			err: ERROR_TYPE
		do
			create err.make (111)
			assert ("contains 'refused'", err.to_string.has_substring ("refused"))
		end

	test_to_string_unknown_error
			-- Verify string representation of unknown error includes code
		local
			err: ERROR_TYPE
			s: STRING
		do
			create err.make (99999)
			s := err.to_string
			assert ("contains code", s.has_substring ("99999") or s.has_substring ("Unknown"))
		end

end
