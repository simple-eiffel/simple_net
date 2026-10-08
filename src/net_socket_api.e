note
	description: "[
		Winsock 2 TCP primitives for simple_net (Windows, IPv4), as inline C.

		Each socket object owns one NET_SOCKET_API. A call leaves its outcome in
		`last_error_code' (0 = success, else the Winsock code), and, depending
		on the call, in `last_handle', `last_data' and the endpoint fields.

		SCOOP: every external that can wait (DNS lookup, connect, select,
		accept, send, recv) is marked `blocking', so a processor waiting on the
		network does not hold up the garbage collector or other processors.
		Because the GC may move Eiffel objects while a blocking call runs, data
		crosses into C only through malloc'd memory (MANAGED_POINTER, C_STRING),
		never through the address of an Eiffel object.

		Requires _WIN32_WINNT >= 0x0600 (getaddrinfo, inet_ntop); the library
		ECF sets it with an external_cflag. Each alias using those APIs stops
		the C build with a message if the flag is missing.
	]"
	author: "simple_net team"
	date: "2026-10-08"
	void_safety: "all"

class
	NET_SOCKET_API

create
	make

feature {NONE} -- Initialization

	make
			-- Ready, with no call made yet.
		do
			create last_data.make_empty
			create last_endpoint_host.make_empty
		ensure
			ok: is_ok
			no_data: last_data.is_empty
		end

feature -- Access

	last_error_code: INTEGER
			-- Winsock error code of the last call; 0 when it succeeded.

	last_handle: POINTER
			-- Socket handle produced by the last successful `connect_to',
			-- `listen_on' or `accept_from'.

	last_data: ARRAY [NATURAL_8]
			-- Bytes read by the last `receive_some'; empty at end of stream or on error.

	last_endpoint_host: STRING
			-- IPv4 address from the last call: the local end after `connect_to',
			-- the peer after `accept_from'.

	last_endpoint_port: INTEGER
			-- Port matching `last_endpoint_host'.

feature -- Status report

	is_ok: BOOLEAN
			-- Did the last call succeed?
		do
			Result := last_error_code = 0
		end

feature -- Constants

	Wsa_timed_out: INTEGER = 10060
			-- WSAETIMEDOUT: an operation did not complete within its timeout.

	Max_chunk: INTEGER = 65536
			-- Largest buffer one `receive_some' reads into.

feature -- Operations

	connect_to (a_host: READABLE_STRING_8; a_port, a_timeout_ms: INTEGER)
			-- Resolve `a_host' (IPv4 literal or name) and connect to it on `a_port',
			-- waiting at most `a_timeout_ms' per candidate address.
		require
			host_not_empty: not a_host.is_empty
			port_valid: a_port >= 1 and a_port <= 65535
			timeout_positive: a_timeout_ms > 0
		local
			l_host: C_STRING
			l_out: MANAGED_POINTER
		do
			reset
			if winsock_started then
				create l_host.make (a_host)
				create l_out.make (Endpoint_buffer_size)
				last_error_code := c_connect (l_host.item, a_port, a_timeout_ms, l_out.item)
				if last_error_code = 0 then
					last_handle := l_out.read_pointer (0)
					read_endpoint (l_out)
				end
			end
		end

	listen_on (a_host: READABLE_STRING_8; a_port, a_backlog: INTEGER)
			-- Bind a listening socket to `a_host':`a_port' with queue depth `a_backlog'.
		require
			host_not_empty: not a_host.is_empty
			port_valid: a_port >= 1 and a_port <= 65535
			backlog_positive: a_backlog > 0
		local
			l_host: C_STRING
			l_out: MANAGED_POINTER
		do
			reset
			if winsock_started then
				create l_host.make (a_host)
				create l_out.make (Endpoint_buffer_size)
				last_error_code := c_listen (l_host.item, a_port, a_backlog, l_out.item)
				if last_error_code = 0 then
					last_handle := l_out.read_pointer (0)
				end
			end
		end

	accept_from (a_listener: POINTER; a_timeout_ms: INTEGER)
			-- Accept the next connection on `a_listener', waiting at most `a_timeout_ms'.
			-- The peer's address lands in `last_endpoint_host' and `last_endpoint_port'.
		require
			timeout_positive: a_timeout_ms > 0
		local
			l_out: MANAGED_POINTER
		do
			reset
			create l_out.make (Endpoint_buffer_size)
			last_error_code := c_accept (a_listener, a_timeout_ms, l_out.item)
			if last_error_code = 0 then
				last_handle := l_out.read_pointer (0)
				read_endpoint (l_out)
			end
		end

	send_all (a_handle: POINTER; a_data: ARRAY [NATURAL_8]; a_timeout_ms: INTEGER)
			-- Send every byte of `a_data' on `a_handle'; each wait for buffer space
			-- is bounded by `a_timeout_ms'.
		require
			data_not_empty: not a_data.is_empty
			timeout_positive: a_timeout_ms > 0
		local
			l_buffer: MANAGED_POINTER
		do
			reset
			create l_buffer.make (a_data.count)
			l_buffer.put_array (a_data, 0)
			last_error_code := c_send_all (a_handle, l_buffer.item, a_data.count, a_timeout_ms)
		end

	receive_some (a_handle: POINTER; a_max: INTEGER; a_timeout_ms: INTEGER)
			-- Read up to `a_max' bytes (at most `Max_chunk') from `a_handle' into
			-- `last_data', waiting at most `a_timeout_ms' for data to arrive.
			-- `is_ok' with empty `last_data' means the peer closed (end of stream).
		require
			max_positive: a_max > 0
			timeout_positive: a_timeout_ms > 0
		local
			l_buffer: MANAGED_POINTER
			l_count, l_n: INTEGER
		do
			reset
			l_count := a_max.min (Max_chunk)
			create l_buffer.make (l_count)
			l_n := c_recv (a_handle, l_buffer.item, l_count, a_timeout_ms)
			if l_n > 0 then
				last_data := l_buffer.read_array (0, l_n)
			elseif l_n < 0 then
				last_error_code := - l_n
			end
		ensure
			bounded: last_data.count <= a_max
			data_means_ok: not last_data.is_empty implies is_ok
		end

feature -- Conversion

	bytes_of (a_text: READABLE_STRING_8): ARRAY [NATURAL_8]
			-- The 8-bit character codes of `a_text', one byte each, unchanged.
		local
			i: INTEGER
		do
			create Result.make_filled (0, 1, a_text.count)
			from
				i := 1
			until
				i > a_text.count
			loop
				Result [i] := a_text.code (i).to_natural_8
				i := i + 1
			variant
				a_text.count - i + 1
			end
		ensure
			same_count: Result.count = a_text.count
		end

	string_of (a_bytes: ARRAY [NATURAL_8]): STRING
			-- `a_bytes' as 8-bit characters, one per byte, unchanged.
		do
			create Result.make (a_bytes.count)
			across a_bytes as ic loop
				Result.append_character (ic.to_character_8)
			end
		ensure
			same_count: Result.count = a_bytes.count
		end

	milliseconds (a_seconds: REAL): INTEGER
			-- `a_seconds' as whole milliseconds, at least 1 and at most 2_000_000_000.
		require
			positive: a_seconds > 0.0
		do
			if a_seconds >= 2_000_000.0 then
				Result := 2_000_000_000
			else
				Result := (a_seconds * 1000.0).rounded.max (1)
			end
		ensure
			positive: Result >= 1
		end

feature {NONE} -- Implementation

	Endpoint_buffer_size: INTEGER = 96
			-- Out buffer for C calls: handle at 0 (8 bytes), port at 8 (4 bytes),
			-- NUL-terminated IPv4 text at 16 (up to 64 bytes).

	reset
			-- Forget the outcome of the previous call.
		do
			last_error_code := 0
			last_handle := default_pointer
			create last_data.make_empty
			create last_endpoint_host.make_empty
			last_endpoint_port := 0
		ensure
			ok: is_ok
		end

	read_endpoint (a_out: MANAGED_POINTER)
			-- Read port and address text from an endpoint out buffer.
		require
			large_enough: a_out.count >= Endpoint_buffer_size
		local
			l_text: C_STRING
		do
			last_endpoint_port := a_out.read_integer_32 (8)
			create l_text.make_by_pointer (a_out.item + 16)
			last_endpoint_host := l_text.string
			if last_endpoint_host.is_empty then
				last_endpoint_host := "0.0.0.0"
			end
		end

	winsock_started: BOOLEAN
			-- Is Winsock 2.2 initialized for this process? Sets `last_error_code' if not.
		do
			last_error_code := winsock_startup_code
			Result := last_error_code = 0
		end

	winsock_startup_code: INTEGER
			-- Result of WSAStartup, called once per process.
		once ("PROCESS")
			Result := c_wsa_startup
		end

feature {NONE} -- C externals

	c_wsa_startup: INTEGER
			-- WSAStartup (2.2); 0 on success.
		external
			"C inline use <winsock2.h>"
		alias
			"[
				WSADATA wsa;
				return (EIF_INTEGER) WSAStartup (MAKEWORD (2, 2), &wsa);
			]"
		end

	c_connect (a_host: POINTER; a_port, a_timeout_ms: INTEGER; a_out: POINTER): INTEGER
			-- Connect to `a_host':`a_port' (IPv4). On success write the handle and
			-- local endpoint into `a_out' and return 0; else return the WSA code.
		external
			"C blocking inline use <winsock2.h>, <ws2tcpip.h>, <stdio.h>, <string.h>"
		alias
			"[
				#if _WIN32_WINNT < 0x0600
				#error "simple_net needs _WIN32_WINNT >= 0x0600: keep the external_cflag in simple_net.ecf"
				#endif
				struct addrinfo hints, *res = NULL, *ai;
				SOCKET s = INVALID_SOCKET;
				char port_str [16];
				int rc, err = WSAEHOSTUNREACH;
				u_long mode;

				memset (&hints, 0, sizeof (hints));
				hints.ai_family = AF_INET;
				hints.ai_socktype = SOCK_STREAM;
				hints.ai_protocol = IPPROTO_TCP;
				sprintf (port_str, "%d", (int) $a_port);
				rc = getaddrinfo ((const char *) $a_host, port_str, &hints, &res);
				if (rc != 0) return (EIF_INTEGER) rc;

				for (ai = res; ai != NULL; ai = ai->ai_next) {
					s = socket (ai->ai_family, ai->ai_socktype, ai->ai_protocol);
					if (s == INVALID_SOCKET) { err = WSAGetLastError (); continue; }
					mode = 1;
					ioctlsocket (s, FIONBIO, &mode);
					err = 0;
					if (connect (s, ai->ai_addr, (int) ai->ai_addrlen) == SOCKET_ERROR) {
						err = WSAGetLastError ();
						if (err == WSAEWOULDBLOCK) {
							fd_set wfds, efds;
							struct timeval tv;
							FD_ZERO (&wfds); FD_ZERO (&efds);
							FD_SET (s, &wfds); FD_SET (s, &efds);
							tv.tv_sec = (long) ($a_timeout_ms / 1000);
							tv.tv_usec = (long) (($a_timeout_ms % 1000) * 1000);
							rc = select (0, NULL, &wfds, &efds, &tv);
							if (rc == 0) {
								err = WSAETIMEDOUT;
							} else if (rc == SOCKET_ERROR) {
								err = WSAGetLastError ();
							} else {
								int so_err = 0;
								int len = (int) sizeof (so_err);
								getsockopt (s, SOL_SOCKET, SO_ERROR, (char *) &so_err, &len);
								err = so_err;
								if (err == 0 && FD_ISSET (s, &efds)) err = WSAECONNREFUSED;
							}
						}
					}
					if (err == 0) {
						mode = 0;
						ioctlsocket (s, FIONBIO, &mode);
						break;
					}
					closesocket (s);
					s = INVALID_SOCKET;
				}
				freeaddrinfo (res);
				if (s == INVALID_SOCKET) return (EIF_INTEGER) err;

				*(SOCKET *) $a_out = s;
				{
					struct sockaddr_in local;
					int len = (int) sizeof (local);
					char *text = ((char *) $a_out) + 16;
					text [0] = '\0';
					*(int *) (((char *) $a_out) + 8) = 0;
					if (getsockname (s, (struct sockaddr *) &local, &len) == 0) {
						inet_ntop (AF_INET, &local.sin_addr, text, 64);
						*(int *) (((char *) $a_out) + 8) = (int) ntohs (local.sin_port);
					}
				}
				return 0;
			]"
		end

	c_listen (a_host: POINTER; a_port, a_backlog: INTEGER; a_out: POINTER): INTEGER
			-- Bind and listen on `a_host':`a_port'. On success write the handle into
			-- `a_out' and return 0; else return the WSA code.
		external
			"C blocking inline use <winsock2.h>, <ws2tcpip.h>, <stdio.h>, <string.h>"
		alias
			"[
				#if _WIN32_WINNT < 0x0600
				#error "simple_net needs _WIN32_WINNT >= 0x0600: keep the external_cflag in simple_net.ecf"
				#endif
				struct addrinfo hints, *res = NULL;
				SOCKET s;
				char port_str [16];
				int rc, err;
				BOOL exclusive = TRUE;

				memset (&hints, 0, sizeof (hints));
				hints.ai_family = AF_INET;
				hints.ai_socktype = SOCK_STREAM;
				hints.ai_protocol = IPPROTO_TCP;
				hints.ai_flags = AI_PASSIVE;
				sprintf (port_str, "%d", (int) $a_port);
				rc = getaddrinfo ((const char *) $a_host, port_str, &hints, &res);
				if (rc != 0) return (EIF_INTEGER) rc;

				s = socket (res->ai_family, res->ai_socktype, res->ai_protocol);
				if (s == INVALID_SOCKET) {
					err = WSAGetLastError ();
					freeaddrinfo (res);
					return (EIF_INTEGER) err;
				}
				setsockopt (s, SOL_SOCKET, SO_EXCLUSIVEADDRUSE, (char *) &exclusive, (int) sizeof (exclusive));
				if (bind (s, res->ai_addr, (int) res->ai_addrlen) == SOCKET_ERROR) {
					err = WSAGetLastError ();
					closesocket (s);
					freeaddrinfo (res);
					return (EIF_INTEGER) err;
				}
				freeaddrinfo (res);
				if (listen (s, (int) $a_backlog) == SOCKET_ERROR) {
					err = WSAGetLastError ();
					closesocket (s);
					return (EIF_INTEGER) err;
				}
				*(SOCKET *) $a_out = s;
				return 0;
			]"
		end

	c_accept (a_listener: POINTER; a_timeout_ms: INTEGER; a_out: POINTER): INTEGER
			-- Wait up to `a_timeout_ms' for a connection on `a_listener' and accept it.
			-- On success write the handle and peer endpoint into `a_out' and return 0.
		external
			"C blocking inline use <winsock2.h>, <ws2tcpip.h>, <stdio.h>, <string.h>"
		alias
			"[
				#if _WIN32_WINNT < 0x0600
				#error "simple_net needs _WIN32_WINNT >= 0x0600: keep the external_cflag in simple_net.ecf"
				#endif
				SOCKET l = (SOCKET) $a_listener;
				SOCKET c;
				fd_set rfds;
				struct timeval tv;
				struct sockaddr_in peer;
				int len = (int) sizeof (peer);
				int rc;
				char *text = ((char *) $a_out) + 16;

				FD_ZERO (&rfds);
				FD_SET (l, &rfds);
				tv.tv_sec = (long) ($a_timeout_ms / 1000);
				tv.tv_usec = (long) (($a_timeout_ms % 1000) * 1000);
				rc = select (0, &rfds, NULL, NULL, &tv);
				if (rc == 0) return WSAETIMEDOUT;
				if (rc == SOCKET_ERROR) return (EIF_INTEGER) WSAGetLastError ();
				c = accept (l, (struct sockaddr *) &peer, &len);
				if (c == INVALID_SOCKET) return (EIF_INTEGER) WSAGetLastError ();
				*(SOCKET *) $a_out = c;
				text [0] = '\0';
				inet_ntop (AF_INET, &peer.sin_addr, text, 64);
				*(int *) (((char *) $a_out) + 8) = (int) ntohs (peer.sin_port);
				return 0;
			]"
		end

	c_send_all (a_socket, a_buffer: POINTER; a_count, a_timeout_ms: INTEGER): INTEGER
			-- Send `a_count' bytes at `a_buffer' on `a_socket'; 0 on success, else the WSA code.
			-- Each wait for the socket to become writable is bounded by `a_timeout_ms'.
		external
			"C blocking inline use <winsock2.h>"
		alias
			"[
				SOCKET s = (SOCKET) $a_socket;
				const char *p = (const char *) $a_buffer;
				int left = (int) $a_count;
				while (left > 0) {
					fd_set wfds;
					struct timeval tv;
					int rc, chunk;
					FD_ZERO (&wfds);
					FD_SET (s, &wfds);
					tv.tv_sec = (long) ($a_timeout_ms / 1000);
					tv.tv_usec = (long) (($a_timeout_ms % 1000) * 1000);
					rc = select (0, NULL, &wfds, NULL, &tv);
					if (rc == 0) return WSAETIMEDOUT;
					if (rc == SOCKET_ERROR) return (EIF_INTEGER) WSAGetLastError ();
					chunk = left < 65536 ? left : 65536;
					rc = send (s, p, chunk, 0);
					if (rc == SOCKET_ERROR) return (EIF_INTEGER) WSAGetLastError ();
					p += rc;
					left -= rc;
				}
				return 0;
			]"
		end

	c_recv (a_socket, a_buffer: POINTER; a_max, a_timeout_ms: INTEGER): INTEGER
			-- Wait up to `a_timeout_ms' for data on `a_socket', then read up to `a_max'
			-- bytes into `a_buffer'. Returns the count read (0 = peer closed), or
			-- minus the WSA code on failure.
		external
			"C blocking inline use <winsock2.h>"
		alias
			"[
				SOCKET s = (SOCKET) $a_socket;
				fd_set rfds;
				struct timeval tv;
				int rc;
				FD_ZERO (&rfds);
				FD_SET (s, &rfds);
				tv.tv_sec = (long) ($a_timeout_ms / 1000);
				tv.tv_usec = (long) (($a_timeout_ms % 1000) * 1000);
				rc = select (0, &rfds, NULL, NULL, &tv);
				if (rc == 0) return - WSAETIMEDOUT;
				if (rc == SOCKET_ERROR) return - (EIF_INTEGER) WSAGetLastError ();
				rc = recv (s, (char *) $a_buffer, (int) $a_max, 0);
				if (rc == SOCKET_ERROR) return - (EIF_INTEGER) WSAGetLastError ();
				return (EIF_INTEGER) rc;
			]"
		end

end
