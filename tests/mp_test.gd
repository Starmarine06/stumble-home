extends SceneTree
## Two-process multiplayer test over ENet (localhost). Run one host and one client:
##   godot --headless --path . -s res://tests/mp_test.gd -- host
##   godot --headless --path . -s res://tests/mp_test.gd -- client

const Game_CAR := Vector3.ZERO
var _fails := 0
var _game: Node
var _net: Node


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1


func _until(cond: Callable, timeout := 15.0) -> bool:
	var t := 0.0
	while not cond.call() and t < timeout:
		await create_timer(0.1).timeout
		t += 0.1
	return cond.call()


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	_run.call_deferred()


func _run() -> void:
	_game = root.get_node("Game")
	_net = root.get_node("Net")
	var args := OS.get_cmdline_user_args()
	if "host" in args:
		await _host()
	else:
		await _client()
	print("\nRESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails else 0)


func _world() -> Node:
	return root.get_node_or_null("Main/World")


func _host() -> void:
	_net.host_enet()
	_check(await _until(func(): return _game.names.size() == 2), "client joined the room")
	_game.claim_role(Roles.Id.DRIVER)
	_check(await _until(func(): return _game.role_owner.size() == 2), "both players claimed a role")
	_game.start_game()
	_check(await _until(func(): return _world() != null and _world().players.get_child_count() == 2), "host sees 2 players")
	for i in 90:
		Input.action_press("right")
		await physics_frame
	Input.action_release("right")
	for i in _game.parts.size():
		var guard := 0
		_game.fatigue.clear()
		while _game.parts[i].state != _game.PS.CARRIED and guard < 80:
			_game.s_pickup(i)
			guard += 1
		_game.s_place(1.0)
	_check(_game.all_installed(), "host installed all parts")
	_check(await _until(func(): return _game.phase == _game.Phase.DRIVE, 8.0), "host enters drive phase")
	await create_timer(1.0).timeout
	for i in 120:
		Input.action_press("forward")
		await physics_frame
	Input.action_release("forward")
	await create_timer(1.0).timeout
	var d = _world().drive
	d.car.position = d.pts[-1]
	_check(await _until(func(): return _game.phase == _game.Phase.RESULT, 5.0), "host sees result")
	await create_timer(1.5).timeout


func _client() -> void:
	await create_timer(1.0).timeout
	_net.join_enet("127.0.0.1")
	_check(await _until(func(): return _game.phase == _game.Phase.LOBBY), "client reaches lobby")
	_check(await _until(func(): return _game.names.size() == 2), "client sees both players")
	_game.claim_role(Roles.Id.NAVIGATOR)
	_check(await _until(func(): return _game.phase == _game.Phase.SCAVENGE), "client enters scavenge")
	_check(await _until(func(): return _world() != null and _world().players.get_child_count() == 2), "client sees 2 players (spawner replicated)")
	_check(_game.roles_of(_game.my_id()).has(Roles.Id.NAVIGATOR), "client keeps Navigator role")
	var spawn := Game_CAR + Vector3(cos(0.6) * 7.0, 1.0, sin(0.6) * 7.0)
	var host_player := _world().players.get_node_or_null("1") as Node3D
	_check(host_player != null and await _until(func(): return host_player.position.distance_to(spawn) > 1.5, 10.0), "host player's movement replicates to client")
	_check(await _until(func(): return _game.all_installed(), 20.0), "client sees all parts installed")
	_check(await _until(func(): return _world() != null and _world().drive != null, 10.0), "client drive built")
	var d = _world().drive
	var start: Vector3 = d.pts[0]
	_check(await _until(func(): return d.car.position.distance_to(start) > 5.0, 10.0), "car state streams to client")
	var nav = d.nav()
	_check(nav.dist > 0.0, "navigator HUD data available (%dm)" % nav.dist)
	_check(await _until(func(): return _game.phase == _game.Phase.RESULT, 10.0), "client sees result")
	_check(_game.won, "client sees the win")
