note
	description: "[
		An object that may own one open socket handle.

		The handle is released by the owner's close/error paths through
		`release_handle'; `dispose' releases it if the object is collected while
		the handle is still open, so a forgotten `close' does not leak a socket.
		`dispose' touches no other Eiffel object (they may already be gone): it
		closes the stored handle only.
	]"
	author: "simple_net team"
	date: "2026-10-08"
	void_safety: "all"

deferred class
	NET_HANDLE_OWNER

inherit
	DISPOSABLE

	NET_SOCKET_PRIMITIVES

feature {NONE} -- Handle

	handle: POINTER
			-- Open socket handle; meaningful only when `has_handle'.

	has_handle: BOOLEAN
			-- Is an open handle owned?

	set_handle (a_handle: POINTER)
			-- Take ownership of `a_handle'.
		require
			none_owned: not has_handle
		do
			handle := a_handle
			has_handle := True
		ensure
			owned: has_handle and handle = a_handle
		end

	release_handle (a_graceful: BOOLEAN)
			-- Close the owned handle, if any; when `a_graceful', send FIN first.
		do
			if has_handle then
				if a_graceful then
					c_owner_shutdown_send (handle)
				end
				c_owner_close (handle)
				has_handle := False
				handle := default_pointer
			end
		ensure
			released: not has_handle
		end

	dispose
			-- Close a handle still open at collection time.
		do
			if has_handle then
				c_owner_close (handle)
				has_handle := False
			end
		end

end
