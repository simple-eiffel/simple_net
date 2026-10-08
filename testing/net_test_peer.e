note
	description: "[
		A one-connection loopback TCP peer for the integration tests, meant to
		run on its own SCOOP processor (create it as `separate').

		`make' starts listening on a free port in 47100..47999 (see `port').
		`serve' accepts one client, acts according to `mode', then closes:
		- Mode_framed_echo: read frames (4-byte big-endian length + payload)
		  and send each payload back, until the client closes.
		- Mode_partial_then_close: send 3 bytes, wait 300 ms, close.
		- Mode_drain: read until the client closes; record what arrived.
	]"
	author: "simple_net team"
	date: "2026-10-08"

class
	NET_TEST_PEER

create
	make

feature {NONE} -- Initialization

	make (a_mode: INTEGER)
			-- Listen on a free loopback port, to serve in `a_mode'.
		require
			valid_mode: a_mode >= Mode_framed_echo and a_mode <= Mode_drain
		local
			l_port: INTEGER
			l_server: SERVER_SOCKET
		do
			mode := a_mode
			from
				l_port := First_port
			until
				is_listening or l_port > Last_port
			loop
				create l_server.make_for_address (create {ADDRESS}.make_for_localhost_port (l_port))
				l_server.set_timeout (10.0)
				if l_server.listen (4) then
					server := l_server
					port := l_port
					is_listening := True
				end
				l_port := l_port + 1
			variant
				Last_port - l_port + 1
			end
		ensure
			mode_set: mode = a_mode
			port_when_listening: is_listening implies port >= First_port
		end

feature -- Access

	mode: INTEGER
			-- What `serve' does with the client

	port: INTEGER
			-- Loopback port listened on (0 if none was free)

	frames_echoed: INTEGER
			-- Frames sent back (Mode_framed_echo)

	bytes_seen: INTEGER
			-- Payload bytes received from the client

	saw_clean_end: BOOLEAN
			-- Did the client's stream end with a clean EOF (no error)?

	failure: STRING
			-- What went wrong on this side, if anything
		attribute
			create Result.make_empty
		end

feature -- Status report

	is_listening: BOOLEAN
			-- Is the peer listening?

	is_done: BOOLEAN
			-- Has `serve' finished?

feature -- Constants

	Mode_framed_echo: INTEGER = 1
	Mode_partial_then_close: INTEGER = 2
	Mode_drain: INTEGER = 3

	First_port: INTEGER = 47100
	Last_port: INTEGER = 47999

feature -- Basic operations

	serve
			-- Accept one client, act per `mode', close everything.
		do
			if attached server as al_server and then al_server.is_listening then
				if attached al_server.accept as al_connection then
					al_connection.set_timeout (10.0)
					inspect mode
					when Mode_framed_echo then
						framed_echo (al_connection)
					when Mode_partial_then_close then
						if not al_connection.send ({ARRAY [NATURAL_8]} <<1, 2, 3>>) then
							failure := "partial send failed"
						end
						(create {EXECUTION_ENVIRONMENT}).sleep (300_000_000)
					else
						drain (al_connection)
					end
					al_connection.close
				else
					failure := "accept failed: " + al_server.last_error_string
				end
				al_server.close
			else
				failure := "not listening"
			end
			is_done := True
		ensure
			done: is_done
		end

feature {NONE} -- Implementation

	server: detachable SERVER_SOCKET
			-- Listening socket

	framed_echo (a_connection: CONNECTION)
			-- Echo frames until the client closes.
		local
			l_header, l_payload: ARRAY [NATURAL_8]
			l_length: INTEGER
			l_stop: BOOLEAN
		do
			from
			until
				l_stop
			loop
				l_header := a_connection.receive_exactly (4)
				if l_header.count < 4 then
					l_stop := True
					saw_clean_end := l_header.is_empty and a_connection.is_at_eof and not a_connection.is_error
				else
					l_length := (l_header [1].to_integer_32 |<< 24) | (l_header [2].to_integer_32 |<< 16)
						| (l_header [3].to_integer_32 |<< 8) | l_header [4].to_integer_32
					l_payload := a_connection.receive_exactly (l_length)
					bytes_seen := bytes_seen + l_payload.count
					if l_payload.count /= l_length then
						failure := "short frame"
						l_stop := True
					elseif a_connection.send (l_payload) then
						frames_echoed := frames_echoed + 1
					else
						failure := "echo send failed"
						l_stop := True
					end
				end
			end
		end

	drain (a_connection: CONNECTION)
			-- Read until the client closes.
		local
			l_chunk: ARRAY [NATURAL_8]
			l_stop: BOOLEAN
		do
			from
			until
				l_stop
			loop
				l_chunk := a_connection.receive (4096)
				if l_chunk.is_empty then
					l_stop := True
					saw_clean_end := a_connection.is_at_eof and not a_connection.is_error
				else
					bytes_seen := bytes_seen + l_chunk.count
				end
			end
		end

end
