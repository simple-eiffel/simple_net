note
	description: "[
		Winsock 2 calls behind NET_SOCKET_API and NET_HANDLE_OWNER (Windows).

		The ECF selects this class on Windows and its namesake in
		platform/posix elsewhere, so no platform's headers reach another's
		build. Requires _WIN32_WINNT >= 0x0600 (getaddrinfo, inet_ntop); the
		library ECF sets it with an external_cflag. Each alias using those
		APIs stops the C build with a message if the flag is missing.
	]"
	author: "simple_net team"
	void_safety: "all"

class
	NET_SOCKET_PRIMITIVES

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

	c_owner_shutdown_send (a_socket: POINTER)
			-- Send FIN on `a_socket'. Does not wait.
		external
			"C inline use <winsock2.h>"
		alias
			"shutdown ((SOCKET) $a_socket, SD_SEND);"
		end

	c_owner_close (a_socket: POINTER)
			-- closesocket; with the default (no SO_LINGER) this does not wait.
		external
			"C inline use <winsock2.h>"
		alias
			"closesocket ((SOCKET) $a_socket);"
		end

end
