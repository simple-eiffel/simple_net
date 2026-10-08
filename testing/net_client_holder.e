note
	description: "[
		Owns a CLIENT_SOCKET on its own SCOOP processor. Created as a
		`separate' entity so the socket is built where its arguments (strings)
		are local; the creation call itself passes only an INTEGER.
	]"
	author: "simple_net team"
	date: "2026-10-08"

class
	NET_CLIENT_HOLDER

create
	make

feature {NONE} -- Initialization

	make (a_port: INTEGER)
			-- Hold a client for localhost:`a_port'.
		require
			port_valid: a_port >= 1 and a_port <= 65535
		do
			create client.make_for_host_port ("localhost", a_port)
		end

feature -- Access

	client: CLIENT_SOCKET
			-- The held client.

end
