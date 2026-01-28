note
	description: "Socket error classification (enum)"
	author: "simple_net team"
	date: "2026-01-28"
	void_safety: "all"

class ERROR_TYPE

create
	make

feature {NONE} -- Representation

	code_impl: INTEGER
			-- OS error code or classification constant

feature -- Creation

	make (a_code: INTEGER)
			-- Initialize with error code
		do
			code_impl := a_code
		ensure
			code_set: code = a_code
		end

feature -- Access

	code: INTEGER
			-- Raw OS error code or classification constant
		do
			Result := code_impl
		end

feature -- Error Classification

	is_no_error: BOOLEAN
			-- No error occurred?
		do
			Result := code_impl = 0
		end

	is_connection_refused: BOOLEAN
			-- Connection refused by peer (ECONNREFUSED)?
		do
			Result := code_impl = 111 or code_impl = 10061  -- Linux ECONNREFUSED=111, Windows WSAECONNREFUSED=10061
		end

	is_connection_timeout: BOOLEAN
			-- Connection attempt timed out (ETIMEDOUT)?
		do
			Result := code_impl = 110 or code_impl = 10060  -- Linux ETIMEDOUT=110, Windows WSAETIMEDOUT=10060
		end

	is_connection_reset: BOOLEAN
			-- Peer reset connection (ECONNRESET)?
		do
			Result := code_impl = 104 or code_impl = 10054  -- Linux ECONNRESET=104, Windows WSAECONNRESET=10054
		end

	is_read_error: BOOLEAN
			-- Error reading data (EBADF, EIO, etc.)?
		do
			Result := code_impl = 9 or code_impl = 5  -- EBADF=9, EIO=5
		end

	is_write_error: BOOLEAN
			-- Error writing data (EPIPE, EBROKEN)?
		do
			Result := code_impl = 32 or code_impl = 54  -- EPIPE=32, ECONNRESET=54
		end

	is_bind_error: BOOLEAN
			-- Failed to bind socket (EADDRINUSE, EACCES)?
		do
			Result := code_impl = 98 or code_impl = 13 or code_impl = 10048  -- EADDRINUSE=98, EACCES=13, Windows=10048
		end

	is_address_not_available: BOOLEAN
			-- Invalid or unreachable address (EADDRNOTAVAIL)?
		do
			Result := code_impl = 99 or code_impl = 10049  -- EADDRNOTAVAIL=99, Windows=10049
		end

	is_timeout: BOOLEAN
			-- Timeout during operation?
		do
			Result := is_connection_timeout or code_impl = -1  -- -1 is generic timeout marker
		end

	is_retriable: BOOLEAN
			-- Is this error retriable (worth retrying)?
		do
			Result := is_connection_refused or is_connection_timeout or is_connection_reset
		end

	is_fatal: BOOLEAN
			-- Is this error fatal (don't retry)?
		do
			Result := is_address_not_available or is_bind_error
		end

feature -- String Representation

	to_string: STRING
			-- Human-readable error description
		do
			if is_no_error then
				Result := "No error"
			elseif is_connection_refused then
				Result := "Connection refused"
			elseif is_connection_timeout then
				Result := "Connection timeout"
			elseif is_connection_reset then
				Result := "Connection reset"
			elseif is_read_error then
				Result := "Read error"
			elseif is_write_error then
				Result := "Write error"
			elseif is_bind_error then
				Result := "Bind error (port in use?)"
			elseif is_address_not_available then
				Result := "Address not available"
			else
				create Result.make_from_string ("Unknown error (code: ")
				Result.append (code_impl.out)
				Result.append (")")
			end
		ensure
			result_not_empty: Result.count > 0
		end

invariant
	code_non_negative: code_impl >= -1

end
