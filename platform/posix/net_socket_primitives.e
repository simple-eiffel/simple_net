note
	description: "[
		BSD socket calls behind NET_SOCKET_API and NET_HANDLE_OWNER (macOS and
		Linux). Clib/simple_net_posix.h holds the C. It reports the Winsock
		code for each failure, so `last_error_code' means one thing everywhere.

		The ECF selects this class off Windows and its namesake in
		platform/windows there.
	]"
	author: "simple_net team"
	void_safety: "all"

class
	NET_SOCKET_PRIMITIVES

feature {NONE} -- C externals

	c_wsa_startup: INTEGER
			-- Nothing to start here; 0.
		do
			Result := 0
		end

	c_connect (a_host: POINTER; a_port, a_timeout_ms: INTEGER; a_out: POINTER): INTEGER
			-- Connect to `a_host':`a_port' (IPv4). On success write the handle and
			-- local endpoint into `a_out' and return 0; else return the WSA code.
		external
			"C blocking inline use %"simple_net_posix.h%""
		alias
			"return (EIF_INTEGER) sn_connect ((const char *) $a_host, (int) $a_port, (int) $a_timeout_ms, (void *) $a_out);"
		end

	c_listen (a_host: POINTER; a_port, a_backlog: INTEGER; a_out: POINTER): INTEGER
			-- Bind and listen on `a_host':`a_port'. On success write the handle into
			-- `a_out' and return 0; else return the WSA code.
		external
			"C blocking inline use %"simple_net_posix.h%""
		alias
			"return (EIF_INTEGER) sn_listen ((const char *) $a_host, (int) $a_port, (int) $a_backlog, (void *) $a_out);"
		end

	c_accept (a_listener: POINTER; a_timeout_ms: INTEGER; a_out: POINTER): INTEGER
			-- Wait up to `a_timeout_ms' for a connection on `a_listener' and accept it.
			-- On success write the handle and peer endpoint into `a_out' and return 0.
		external
			"C blocking inline use %"simple_net_posix.h%""
		alias
			"return (EIF_INTEGER) sn_accept ((void *) $a_listener, (int) $a_timeout_ms, (void *) $a_out);"
		end

	c_send_all (a_socket, a_buffer: POINTER; a_count, a_timeout_ms: INTEGER): INTEGER
			-- Send `a_count' bytes at `a_buffer' on `a_socket'; 0 on success, else the WSA code.
			-- Each wait for the socket to become writable is bounded by `a_timeout_ms'.
		external
			"C blocking inline use %"simple_net_posix.h%""
		alias
			"return (EIF_INTEGER) sn_send_all ((void *) $a_socket, (const void *) $a_buffer, (int) $a_count, (int) $a_timeout_ms);"
		end

	c_recv (a_socket, a_buffer: POINTER; a_max, a_timeout_ms: INTEGER): INTEGER
			-- Wait up to `a_timeout_ms' for data on `a_socket', then read up to `a_max'
			-- bytes into `a_buffer'. Returns the count read (0 = peer closed), or
			-- minus the WSA code on failure.
		external
			"C blocking inline use %"simple_net_posix.h%""
		alias
			"return (EIF_INTEGER) sn_recv ((void *) $a_socket, (void *) $a_buffer, (int) $a_max, (int) $a_timeout_ms);"
		end

	c_owner_shutdown_send (a_socket: POINTER)
			-- Send FIN on `a_socket'. Does not wait.
		external
			"C inline use %"simple_net_posix.h%""
		alias
			"sn_shutdown_send ((void *) $a_socket);"
		end

	c_owner_close (a_socket: POINTER)
			-- Close; with the default (no SO_LINGER) this does not wait.
		external
			"C inline use %"simple_net_posix.h%""
		alias
			"sn_close ((void *) $a_socket);"
		end

end
