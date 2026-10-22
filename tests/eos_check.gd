extends SceneTree
## Live EOS check (needs eos_credentials.cfg and the plugin binaries):
##   godot --headless --path . -s res://tests/eos_check.gd
## Initialises EOS, signs in anonymously, creates a room and joins it by code.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var net := root.get_node("Net")
	net.status_changed.connect(func(t): print("status: ", t))
	net.host_failed.connect(func(t): print("HOST FAILED: ", t))
	net.join_failed.connect(func(t): print("JOIN FAILED: ", t))
	var got_code := []
	net.hosted.connect(func(c): got_code.append(c))
	net.host_eos()
	var waited := 0.0
	while got_code.is_empty() and waited < 30.0:
		await create_timer(0.25).timeout
		waited += 0.25
	if got_code.is_empty():
		print("RESULT: FAILED (no room created)")
		quit(1)
		return
	print("room created: ", got_code[0], " puid=", root.get_node("EOSGRuntime").local_product_user_id)

	# Join our own room by code through the lobby API (same device => same user,
	# so this only proves the code lookup, not a second client).
	var lobby = await root.get_node("HLobbies").join_by_id_async(net.CODE_PREFIX + got_code[0])
	print("join by code: ", "found lobby " + str(lobby.lobby_id) if lobby else "not found")
	print("RESULT: ", "OK" if lobby else "PARTIAL (room created, join by id failed)")
	net.leave()
	await create_timer(1.0).timeout
	quit(0)
