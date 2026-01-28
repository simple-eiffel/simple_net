note
	description: "simple_net facade - TCP socket abstraction library"
	author: "simple_net team"
	date: "2026-01-28"
	void_safety: "all"

class SIMPLE_NET

create
	make

feature -- Creation

	make
			-- Initialize simple_net facade
		do
		end

feature -- Client Socket Factory

	new_client_for_host_port (a_host: STRING; a_port: INTEGER): CLIENT_SOCKET
			-- Create TCP client socket for remote `a_host:a_port'
		require
			host_not_empty: a_host /= Void and then a_host.count > 0
			port_valid: a_port >= 1 and a_port <= 65535
		do
			create Result.make_for_host_port (a_host, a_port)
		ensure
			result_not_void: Result /= Void
			host_set: Result.remote_address.host.is_equal (a_host)
			port_set: Result.remote_address.port = a_port
		end

	new_client_for_address (a_address: ADDRESS): CLIENT_SOCKET
			-- Create TCP client socket for remote `a_address'
		require
			address_not_void: a_address /= Void
		do
			create Result.make_for_address (a_address)
		ensure
			result_not_void: Result /= Void
			address_set: Result.remote_address = a_address
		end

feature -- Server Socket Factory

	new_server_for_port (a_port: INTEGER): SERVER_SOCKET
			-- Create TCP server socket listening on all interfaces at `a_port'
		require
			port_valid: a_port >= 1 and a_port <= 65535
		do
			create Result.make_for_port (a_port)
		ensure
			result_not_void: Result /= Void
			port_set: Result.local_address.port = a_port
		end

	new_server_for_address (a_address: ADDRESS): SERVER_SOCKET
			-- Create TCP server socket listening on `a_address'
		require
			address_not_void: a_address /= Void
		do
			create Result.make_for_address (a_address)
		ensure
			result_not_void: Result /= Void
			address_set: Result.local_address = a_address
		end

feature -- Address Factory

	new_address_for_host_port (a_host: STRING; a_port: INTEGER): ADDRESS
			-- Create network address for `a_host:a_port'
		require
			host_not_empty: a_host /= Void and then a_host.count > 0
			port_valid: a_port >= 1 and a_port <= 65535
		do
			create Result.make_for_host_port (a_host, a_port)
		ensure
			result_not_void: Result /= Void
			host_set: Result.host.is_equal (a_host)
			port_set: Result.port = a_port
		end

	new_address_for_localhost_port (a_port: INTEGER): ADDRESS
			-- Create loopback address (127.0.0.1:a_port)
		require
			port_valid: a_port >= 1 and a_port <= 65535
		do
			create Result.make_for_localhost_port (a_port)
		ensure
			result_not_void: Result /= Void
			is_loopback: Result.is_loopback
			port_set: Result.port = a_port
		end

feature -- Library Metadata

	version: STRING
			-- Library version number
		do
			Result := "1.0.0"
		ensure
			result_not_void: Result /= Void
		end

	description: STRING
			-- Library description
		do
			Result := "simple_net: TCP Socket Abstraction Library - Wrap ISE net.ecf with intuitive API"
		ensure
			result_not_void: Result /= Void
		end

end
