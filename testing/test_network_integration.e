note
	description: "[
		Real TCP tests over loopback. The far end is either a SERVER_SOCKET in
		this processor (listening only: the kernel completes the handshake
		from the backlog) or a NET_TEST_PEER on its own SCOOP processor, so
		client and peer block in Winsock concurrently.
	]"
	author: "simple_net team"
	date: "2026-10-08"

class TEST_NETWORK_INTEGRATION

inherit
	NET_TEST_SUPPORT

feature -- Round trips (framed echo peer)

	test_round_trip_zero_length
			-- A zero-length frame round-trips, and the stream stays in step.
		local
			l_peer: separate NET_TEST_PEER
			l_client: CLIENT_SOCKET
		do
			create l_peer.make ({NET_TEST_PEER}.Mode_framed_echo)
			l_client := connected_client (peer_port (l_peer))
			start_peer (l_peer)
			assert ("empty send succeeds", l_client.send (create {ARRAY [NATURAL_8]}.make_empty))
			assert_integers_equal ("empty echo", 0, framed_round_trip (l_client, create {ARRAY [NATURAL_8]}.make_empty).count)
			assert ("next frame intact", framed_round_trip (l_client, bytes_of_text ("ok")) ~ bytes_of_text ("ok"))
			l_client.close
			assert_integers_equal ("peer echoed two frames", 2, peer_frames (l_peer))
			assert ("peer saw clean end", peer_clean_end (l_peer))
		end

	test_round_trip_nul_bytes
			-- 1000 zero-valued bytes come back unchanged.
		local
			l_peer: separate NET_TEST_PEER
			l_client: CLIENT_SOCKET
			l_payload: ARRAY [NATURAL_8]
		do
			create l_peer.make ({NET_TEST_PEER}.Mode_framed_echo)
			l_client := connected_client (peer_port (l_peer))
			start_peer (l_peer)
			create l_payload.make_filled (0, 1, 1000)
			assert ("nul bytes echoed", framed_round_trip (l_client, l_payload) ~ l_payload)
			l_client.close
			assert_integers_equal ("peer frames", 1, peer_frames (l_peer))
		end

	test_round_trip_all_byte_values
			-- Every byte value 0..255, ascending then descending, comes back unchanged.
		local
			l_peer: separate NET_TEST_PEER
			l_client: CLIENT_SOCKET
			l_payload, l_echo: ARRAY [NATURAL_8]
			i: INTEGER
		do
			create l_peer.make ({NET_TEST_PEER}.Mode_framed_echo)
			l_client := connected_client (peer_port (l_peer))
			start_peer (l_peer)
			create l_payload.make_filled (0, 1, 512)
			from i := 0 until i > 255 loop
				l_payload [i + 1] := i.to_natural_8
				l_payload [512 - i] := i.to_natural_8
				i := i + 1
			end
			l_echo := framed_round_trip (l_client, l_payload)
			assert_integers_equal ("echo count", 512, l_echo.count)
			assert ("all 256 values echoed", l_echo ~ l_payload)
			assert_integers_equal ("bytes_sent counts header + payload", 516, l_client.bytes_sent)
			assert_integers_equal ("bytes_received counts the echoed payload", 512, l_client.bytes_received)
			l_client.close
			assert_integers_equal ("peer saw payload", 512, peer_bytes (l_peer))
		end

	test_round_trip_one_megabyte
			-- 1 MiB of patterned bytes comes back unchanged.
		local
			l_peer: separate NET_TEST_PEER
			l_client: CLIENT_SOCKET
			l_payload, l_echo: ARRAY [NATURAL_8]
			i: INTEGER
		do
			create l_peer.make ({NET_TEST_PEER}.Mode_framed_echo)
			l_client := connected_client (peer_port (l_peer))
			start_peer (l_peer)
			create l_payload.make_filled (0, 1, 1_048_576)
			from i := 1 until i > l_payload.count loop
				l_payload [i] := ((i * 31 + 7) \\ 256).to_natural_8
				i := i + 1
			end
			l_echo := framed_round_trip (l_client, l_payload)
			assert_integers_equal ("echo count", 1_048_576, l_echo.count)
			assert ("1 MiB echoed intact", l_echo ~ l_payload)
			l_client.close
			assert_integers_equal ("peer saw 1 MiB", 1_048_576, peer_bytes (l_peer))
		end

	test_hostname_localhost
			-- "localhost" resolves and connects.
		local
			l_peer: separate NET_TEST_PEER
			l_client: CLIENT_SOCKET
		do
			create l_peer.make ({NET_TEST_PEER}.Mode_framed_echo)
			create l_client.make_for_host_port ("localhost", peer_port (l_peer))
			l_client.set_timeout (10.0)
			start_peer (l_peer)
			assert ("connected by name", l_client.connect)
			assert ("local address known", l_client.has_local_address)
			assert_equal ("local host is loopback", "127.0.0.1", l_client.local_address.host)
			assert ("echo by name", framed_round_trip (l_client, bytes_of_text ("hello")) ~ bytes_of_text ("hello"))
			l_client.close
			assert ("peer saw clean end", peer_clean_end (l_peer))
		end

feature -- Peer behaviour

	test_peer_closes_mid_receive
			-- The peer sends 3 bytes then closes while the client waits for 10:
			-- receive_exactly returns the 3, with a clean end of stream.
		local
			l_peer: separate NET_TEST_PEER
			l_client: CLIENT_SOCKET
			l_data: ARRAY [NATURAL_8]
		do
			create l_peer.make ({NET_TEST_PEER}.Mode_partial_then_close)
			l_client := connected_client (peer_port (l_peer))
			start_peer (l_peer)
			l_data := l_client.receive_exactly (10)
			assert_integers_equal ("got the 3 bytes sent", 3, l_data.count)
			assert ("bytes intact", l_data ~ {ARRAY [NATURAL_8]} <<1, 2, 3>>)
			assert ("end of stream", l_client.is_at_end_of_stream)
			refute ("not an error", l_client.is_error)
			assert ("still connected (half-closed)", l_client.is_connected)
			assert_integers_equal ("receive after EOF is empty", 0, l_client.receive (10).count)
			l_client.close
			assert ("peer finished", peer_failure (l_peer).is_empty)
		end

	test_close_is_graceful
			-- After send + close, the peer reads every byte and a clean EOF.
		local
			l_peer: separate NET_TEST_PEER
			l_client: CLIENT_SOCKET
		do
			create l_peer.make ({NET_TEST_PEER}.Mode_drain)
			l_client := connected_client (peer_port (l_peer))
			start_peer (l_peer)
			assert ("sent", l_client.send_string ("goodbye"))
			l_client.close
			assert ("closed", l_client.is_closed)
			assert_integers_equal ("peer read all bytes", 7, peer_bytes (l_peer))
			assert ("peer saw clean EOF", peer_clean_end (l_peer))
		end

feature -- Failures

	test_connection_refused
			-- Nothing listening: connect fails with WSAECONNREFUSED (10061).
		local
			l_client: CLIENT_SOCKET
		do
			create l_client.make_for_host_port ("127.0.0.1", unused_port)
			l_client.set_timeout (10.0)
			refute ("connect fails", l_client.connect)
			assert ("in error", l_client.is_error)
			refute ("not connected", l_client.is_connected)
			assert ("classified refused", l_client.error_classification.is_connection_refused)
			assert_integers_equal ("WSA code", 10061, l_client.last_error_code)
			assert ("message names code", l_client.last_error_string.has_substring ("10061"))
			assert ("message names refusal", l_client.last_error_string.has_substring ("refused"))
			l_client.close
			assert_integers_equal ("code kept after close", 10061, l_client.last_error_code)
		end

	test_receive_timeout
			-- Connected, nothing sent: receive gives up after the timeout with 10060.
		local
			l_server: SERVER_SOCKET
			l_client: CLIENT_SOCKET
		do
			l_server := listening_server
			l_client := connected_client (l_server.local_address.port)
			l_client.set_timeout (0.5)
			assert_integers_equal ("nothing received", 0, l_client.receive (10).count)
			assert ("in error", l_client.is_error)
			assert ("timed out", l_client.operation_timed_out)
			assert_integers_equal ("WSA code", 10060, l_client.last_error_code)
			refute ("not connected after timeout", l_client.is_connected)
			l_client.close
			l_server.close
		end

	test_receive_exactly_timeout
			-- receive_exactly stops at the timeout with what it has (nothing here).
		local
			l_server: SERVER_SOCKET
			l_client: CLIENT_SOCKET
		do
			l_server := listening_server
			l_client := connected_client (l_server.local_address.port)
			l_client.set_timeout (0.3)
			assert_integers_equal ("nothing", 0, l_client.receive_exactly (8).count)
			assert ("timed out", l_client.operation_timed_out)
			l_client.close
			l_server.close
		end

	test_connect_timeout
			-- A non-routable address: connect fails by the timeout (10060), or at once
			-- if the machine has no route (10051/10065). Either way it fails, in error.
		local
			l_client: CLIENT_SOCKET
		do
			create l_client.make_for_host_port ("10.255.255.1", 9)
			l_client.set_timeout (0.5)
			refute ("connect fails", l_client.connect)
			assert ("in error", l_client.is_error)
			assert ("timed out or unreachable", l_client.operation_timed_out
				or l_client.last_error_code = 10051 or l_client.last_error_code = 10065)
		end

	test_host_not_found
			-- An unresolvable name fails with a host-not-found code (11001..11004).
		local
			l_client: CLIENT_SOCKET
		do
			create l_client.make_for_host_port ("no-such-host.invalid", 80)
			l_client.set_timeout (5.0)
			refute ("connect fails", l_client.connect)
			assert ("host not found", l_client.error_classification.is_host_not_found)
		end

	test_accept_timeout
			-- No client: accept returns Void after the timeout, with 10060.
		local
			l_server: SERVER_SOCKET
		do
			l_server := listening_server
			l_server.set_timeout (0.3)
			assert ("no connection", l_server.accept = Void)
			assert ("timed out", l_server.operation_timed_out)
			assert_integers_equal ("WSA code", 10060, l_server.last_error_code)
			refute ("no longer listening", l_server.is_listening)
			l_server.close
		end

	test_port_in_use
			-- A second listener on a bound port fails with a bind error.
		local
			l_first, l_second: SERVER_SOCKET
		do
			l_first := listening_server
			create l_second.make_for_address (l_first.local_address)
			refute ("second listen fails", l_second.listen (1))
			assert ("bind error", l_second.error_classification.is_bind_error or l_second.last_error_code = 10013)
			assert ("message names code", l_second.last_error_string.has_substring ("WSA"))
			l_second.close
			l_first.close
		end

	test_server_accepts_and_exchanges
			-- Same processor: connect via the backlog, accept, exchange both ways.
		local
			l_server: SERVER_SOCKET
			l_client: CLIENT_SOCKET
		do
			l_server := listening_server
			l_client := connected_client (l_server.local_address.port)
			if attached l_server.accept as al_connection then
				assert_integers_equal ("one accepted", 1, l_server.connection_count)
				assert_equal ("peer is loopback", "127.0.0.1", al_connection.remote_address.host)
				assert ("client sends", l_client.send_string ("ping"))
				assert_equal ("server reads", "ping", al_connection.receive_string)
				assert ("server sends", al_connection.send_string ("pong"))
				assert_equal ("client reads", "pong", l_client.receive_string (16))
				al_connection.close
				assert_integers_equal ("client sees EOF", 0, l_client.receive (4).count)
				assert ("EOF flagged", l_client.is_at_end_of_stream)
			else
				assert ("accepted", False)
			end
			l_client.close
			l_server.close
		end

feature {NONE} -- SCOOP helpers

	peer_port (a_peer: separate NET_TEST_PEER): INTEGER
			-- Port `a_peer' listens on; fails the test if it found none.
		do
			Result := a_peer.port
			assert ("peer listening", a_peer.is_listening)
		end

	start_peer (a_peer: separate NET_TEST_PEER)
			-- Let `a_peer' serve its one client (runs asynchronously).
		do
			a_peer.serve
		end

	peer_frames (a_peer: separate NET_TEST_PEER): INTEGER
			-- Frames echoed, once `a_peer' has finished serving.
		require
			finished: a_peer.is_done
		do
			Result := a_peer.frames_echoed
		end

	peer_bytes (a_peer: separate NET_TEST_PEER): INTEGER
			-- Payload bytes seen, once `a_peer' has finished serving.
		require
			finished: a_peer.is_done
		do
			Result := a_peer.bytes_seen
		end

	peer_clean_end (a_peer: separate NET_TEST_PEER): BOOLEAN
			-- Did the client's stream end cleanly, once `a_peer' has finished?
		require
			finished: a_peer.is_done
		do
			Result := a_peer.saw_clean_end and a_peer.failure.is_empty
		end

	peer_failure (a_peer: separate NET_TEST_PEER): STRING
			-- What went wrong on the peer's side, once it has finished.
		require
			finished: a_peer.is_done
		do
			create Result.make_from_separate (a_peer.failure)
		end

feature {NONE} -- Helpers

	framed_round_trip (a_client: CLIENT_SOCKET; a_payload: ARRAY [NATURAL_8]): ARRAY [NATURAL_8]
			-- Send `a_payload' as one frame (4-byte big-endian length first) and
			-- read the echoed payload back.
		require
			connected: a_client.is_connected
		local
			l_count: INTEGER
		do
			l_count := a_payload.count
			assert ("header sent", a_client.send ({ARRAY [NATURAL_8]} <<
				((l_count |>> 24) & 0xFF).to_natural_8, ((l_count |>> 16) & 0xFF).to_natural_8,
				((l_count |>> 8) & 0xFF).to_natural_8, (l_count & 0xFF).to_natural_8>>))
			assert ("payload sent", a_client.send (a_payload))
			Result := a_client.receive_exactly (l_count)
			if a_client.is_error then
				assert ("receive: " + a_client.last_error_string, False)
			end
		end

end
