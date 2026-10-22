extends SceneTree
## Headless smoke test: plays a full solo night by calling the host-side game
## functions directly. Run:
##   godot --headless --path . -s res://tests/smoke_solo.gd

var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	game.start_hosting()
	_check(game.phase == game.Phase.LOBBY, "lobby after hosting")
	game.claim_role(Roles.Id.NAVIGATOR)
	_check(game.role_owner.get(Roles.Id.NAVIGATOR) == 1, "claim role")
	game.start_game()
	await _wait(0.5)
	_check(game.phase == game.Phase.SCAVENGE, "scavenge phase")
	_check(game.role_owner.size() == 4, "all four roles assigned")
	var world := root.get_node_or_null("Main/World")
	_check(world != null, "world built")
	await _wait(0.5)
	_check(world.local_player() != null, "player spawned")

	for i in game.parts.size():
		var guard := 0
		while game.parts[i].state != game.PS.CARRIED and guard < 60:
			game.s_pickup(i)
			guard += 1
		_check(game.parts[i].state == game.PS.CARRIED, "picked up %s (%d tries)" % [game.parts[i].name, guard])
		game.s_deliver()
		_check(game.parts[i].state == game.PS.DELIVERED, "delivered %s" % game.parts[i].name)
		game.s_install(i, true)
		_check(game.parts[i].state == game.PS.INSTALLED, "installed %s" % game.parts[i].name)
	await _wait(3.6)
	_check(game.phase == game.Phase.DRIVE, "drive phase starts after last part")
	_check(world.drive != null, "drive built")
	await _wait(0.5)
	var d = world.drive
	_check(d.pts.size() == d.LEGS + 1, "route has %d points" % d.pts.size())
	_check(d.turns.size() == d.LEGS - 1, "route has %d turns" % d.turns.size())
	var nav = d.nav()
	_check(nav.dist > 30.0 and nav.dir != 0, "navigator sees first corner (%dm, dir %d)" % [nav.dist, nav.dir])

	# Overheat + cooling
	game.engine_hot = true
	game.s_cool(true)
	_check(not game.engine_hot, "mechanic cools engine")
	# Cop event
	game._cop_open = true
	game._cop_left = 7.0
	var w0: float = game.wanted
	game.s_cop_result(false)
	_check(game.wanted > w0, "failed cop signal raises wanted")
	# Drive along the route with the Driver's own simulation
	for i in 200:
		Input.action_press("forward")
		await physics_frame
	Input.action_release("forward")
	_check(d.speed > 5.0, "car accelerates (speed %.1f)" % d.speed)
	# Teleport to the end and arrive
	d.car.position = d.pts[-1]
	await _wait(0.3)
	_check(game.phase == game.Phase.RESULT and game.won, "arriving home wins")
	await _wait(0.2)
	game.return_to_lobby()
	await _wait(0.3)
	_check(game.phase == game.Phase.LOBBY, "back to lobby after result")
	print("\nRESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails else 0)
