note
	description: "Network endpoint (host:port) value object"
	author: "simple_net team"
	date: "2026-01-28"
	void_safety: "all"
	scoop: "thread_safe"

class ADDRESS

create
	make_for_host_port,
	make_for_localhost_port

feature {NONE} -- Representation

	host_impl: STRING
			-- Hostname or IP address (immutable after creation)

	port_impl: INTEGER
			-- Port number 1-65535 (immutable after creation)

feature -- Creation

	make_for_host_port (a_host: STRING; a_port: INTEGER)
			-- Initialize address for `a_host' and `a_port'.
			-- `a_host': hostname (e.g., "example.com", "localhost") or IP address (e.g., "127.0.0.1", "192.168.1.1")
			-- `a_port': port number in range 1-65535
		require
			non_empty_host: a_host /= Void and then a_host.count > 0
			valid_port: a_port >= 1 and a_port <= 65535
		do
			host_impl := a_host.twin
			port_impl := a_port
		ensure
			host_set: host.is_equal (a_host)
			port_set: port = a_port
		end

	make_for_localhost_port (a_port: INTEGER)
			-- Initialize address for localhost (127.0.0.1) on `a_port'.
		require
			valid_port: a_port >= 1 and a_port <= 65535
		do
			host_impl := "127.0.0.1"
			port_impl := a_port
		ensure
			host_is_loopback: is_loopback
			port_set: port = a_port
		end

feature -- Access

	host: STRING
			-- Hostname or IP address
		do
			Result := host_impl
		end

	port: INTEGER
			-- Port number
		do
			Result := port_impl
		end

	as_string: STRING
			-- String representation (e.g., "example.com:8080" or "127.0.0.1:8080")
		do
			create Result.make_from_string (host_impl)
			Result.append (":")
			Result.append (port_impl.out)
		end

feature -- Status

	is_loopback: BOOLEAN
			-- Is this a loopback address (127.0.0.1 or localhost)?
		do
			Result := host_impl.is_equal ("127.0.0.1") or host_impl.is_equal ("localhost")
		end

	is_ipv4_address: BOOLEAN
			-- Is host an IPv4 address (e.g., "192.168.1.1")?
			-- Validates: exactly 4 octets, each 0-255, no leading zeros
		local
			parts: LIST [STRING]
			i: INTEGER
			octet_value: INTEGER
			is_valid: BOOLEAN
			octet: STRING
		do
			Result := False
			is_valid := True

			-- Must have exactly 3 dots (4 octets)
			if host.occurrences ('.') /= 3 then
				is_valid := False
			end

			if is_valid then
				parts := host.split ('.')
				-- Should have exactly 4 parts
				if parts.count /= 4 then
					is_valid := False
				else
					-- Check each octet
					from parts.start
					until parts.exhausted or not is_valid
					loop
						octet := parts.item
						-- Must be numeric (all digits)
						if octet.count = 0 or not is_all_digits (octet) then
							is_valid := False
						else
							-- Check range 0-255
							octet_value := octet.to_integer
							if octet_value < 0 or octet_value > 255 then
								is_valid := False
							end
							-- No leading zeros except "0" itself
							if is_valid and octet.count > 1 and octet [1] = '0' then
								is_valid := False
							end
						end
						parts.forth
					end
				end
			end

			Result := is_valid
		end

	is_all_digits (s: STRING): BOOLEAN
			-- Is string `s' composed entirely of digit characters?
		local
			i: INTEGER
		do
			Result := True
			from i := 1
			until i > s.count or not Result
			loop
				if not (s [i] >= '0' and s [i] <= '9') then
					Result := False
				end
				i := i + 1
			end
		end

invariant
	host_not_empty: host_impl.count > 0
	port_in_range: port_impl >= 1 and port_impl <= 65535

end
