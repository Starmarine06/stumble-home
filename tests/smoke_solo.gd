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

	# Economy: parts are bought, not found
	_check(game.money == 200, "night 1 starts with the opening pool")
	_check(game.parts[0].state == game.PS.SHELF, "parts start on the shelf")
	game.s_pickup(0)
	_check(game.parts[0].state == game.PS.SHELF, "an unbought part cannot be lifted")
	game.s_buy(0)
	_check(game.parts[0].state == game.PS.SHELF and game.money == 200, "cannot buy a part you cannot afford")
	var stakes: Array = []
	game.stake_result.connect(func(k, ok, bet): stakes.append([k, ok, bet]))
	game.s_stake("roulette", 500)
	_check(game.money == 200 and stakes.back() == ["roulette", false, 500], "cannot stake more than the pool")
	game.s_stake("poker", 10)
	_check(game.money == 200 and not stakes.back()[1], "unknown casino game is refused")
	game.s_payout("roulette", 50)
	_check(game.money == 200, "no payout without a stake")
	game.s_stake("roulette", 100)
	_check(game.money == 100 and stakes.back() == ["roulette", true, 100], "stake leaves the pool")
	game.s_payout("roulette", 100 * 37)
	_check(game.money == 100, "payout above the game's limit is refused")
	game.s_payout("roulette", 3600)
	_check(game.money == 3700, "winning payout is paid against the stake")
	game.s_payout("roulette", 3600)
	_check(game.money == 3700, "a stake pays out only once")
	game.s_stake("darts", 700)
	game.s_payout("darts", 0)
	_check(game.money == 3000, "a lost round stays lost")
	game.money = 200
	game.earn(PartsShop.total(), "test")
	game.s_buy(0)
	_check(game.parts[0].state == game.PS.WORLD and game.money == 200 + PartsShop.total() - PartsShop.price(0), "buying takes the price and drops the part by the car")
	game.s_buy(0)
	_check(game.money == 200 + PartsShop.total() - PartsShop.price(0), "cannot buy the same part twice")
	for bi in range(1, game.parts.size()):
		game.s_buy(bi)
	_check(game.money == 200, "all four parts bought at list price")
	_check(world.terminal != null, "parts terminal in the world")
	world.terminal.activate(world.local_player())
	await _wait(0.1)
	_check(world.shop_panel != null and world.local_player().ui_lock, "terminal opens the shop panel and locks the player")
	var close_btn: Button = null
	for b in world.shop_panel.find_children("*", "Button", true, false):
		if b.text == "Close":
			close_btn = b
	_check(world.shop_panel.get_parent().layer > 10, "shop panels sit above the HUD and the drunk effect")
	close_btn.pressed.emit()
	await _wait(0.2)
	_check(world.shop_panel == null and not world.local_player().ui_lock, "the Close button closes the panel and frees the player")
	_check(world.get_node_or_null("ModalLayer") == null, "the panel layer is cleaned up")

	var g0 := 0
	while game.parts[0].state != game.PS.CARRIED and g0 < 60:
		game.s_pickup(0)
		g0 += 1
	game.s_place(0.1)
	_check(game.parts[0].state == game.PS.INSTALLED and game.parts[0].loose_t > 0.0, "crooked fit is loose")
	_check(game.build_damage > 10.0, "crooked fit damages the car")
	game._tick_loose(100.0)
	_check(game.parts[0].state == game.PS.WORLD, "loose part falls off the car")
	game.s_pickup(0)
	_check(game.parts[0].state == game.PS.CARRIED, "part lifted with the hands")
	var wanted_pre_drop: float = game.wanted
	game.s_drop(Vector3(5, 0, 6), 1.0, 7.0)
	_check(game.parts[0].state == game.PS.WORLD and game.parts[0].pos.is_equal_approx(Vector3(5, 0, 6)), "dropped part rests where it landed")
	_check(game.wanted > wanted_pre_drop, "a hard drop clangs and raises wanted")
	_check(load("res://scripts/player/player.gd").quality_for(0.0, 0.0, 0.0) > 0.99, "perfect placement scores ~1")
	_check(load("res://scripts/player/player.gd").quality_for(0.45, 0.5, 3.0) < 0.3, "sloppy placement scores low")
	for i in game.parts.size():
		var guard := 0
		while game.parts[i].state != game.PS.CARRIED and guard < 60:
			game.s_pickup(i)
			guard += 1
		_check(game.parts[i].state == game.PS.CARRIED, "picked up %s (%d tries)" % [game.parts[i].name, guard])
		game.s_place(1.0)
		_check(game.parts[i].state == game.PS.INSTALLED, "installed %s" % game.parts[i].name)
	game.fatigue.clear()
	game.names[99] = "Pal"
	game._tire(99, 1.0)
	_check(game.is_out(99), "non-mechanic hauler passes out")
	game._tire(1, 5.0)
	_check(not game.is_out(1), "mechanic never tires")
	game._tick_fatigue(game.PASSOUT_SECS + 1.0)
	_check(not game.is_out(99), "passed-out hauler wakes after a long while")
	game.names.erase(99)
	await _wait(3.6)
	_check(game.phase == game.Phase.DRIVE, "drive phase starts after last part")
	_check(world.drive != null, "drive built")
	await _wait(0.5)
	var d = world.drive
	_check(d.pts.size() >= 5 and d.turns.size() == d.pts.size() - 2, "route through the city has %d points and %d turns" % [d.pts.size(), d.turns.size()])
	_check(d.pts[0].distance_to(game.CAR_POS) < 0.01, "the drive starts at the car park")
	_check(d.pts[0].distance_to(d.pts[-1]) > 800.0, "home is a long way from the car park (%d m)" % d.pts[0].distance_to(d.pts[-1]))
	_check(world.city.loaded_blocks().size() >= 9, "city blocks stream in around the car")
	var nav = d.nav()
	_check(nav.dist > 30.0 and nav.dir != 0, "navigator sees first corner (%dm, dir %d)" % [nav.dist, nav.dir])

	# Overheat + cooling
	game.engine_hot = true
	game.s_cool(true)
	_check(not game.engine_hot, "mechanic cools engine")
	# Cop event
	game._cop_open = true
	game._cop_left = 7.0
	var wanted_before: float = game.wanted
	game.s_cop_result(false)
	_check(game.wanted > wanted_before, "failed cop signal raises wanted")
	# Hazards
	_check(d.hazards != null and not d.hazards.events.is_empty() and d.hazards.events.all(func(e): return e.kind == "checkpoint"), "night 1 drive has police checkpoints and nothing else")
	var hz_hits: Array = []
	game.hazard_hit.connect(func(k): hz_hits.append(k))
	var hp0: float = game.car_hp
	var w0: float = game.wanted
	game.s_hazard("dog")
	_check(game.car_hp < hp0 and game.wanted > w0, "dog hit lowers car hp and raises wanted")
	_check(hz_hits == ["dog"], "hazard_hit signal fires")
	await _wait(0.9)
	hp0 = game.car_hp
	w0 = game.wanted
	game.s_hazard("unicorn")
	_check(game.car_hp == hp0 and game.wanted == w0, "unknown hazard kind changes nothing")
	game.s_hazard("mugger")
	game.s_hazard("traffic")
	_check(hz_hits == ["dog", "mugger"], "hazard hits are rate-limited")
	await _wait(0.5)
	var hd = load("res://scripts/world/drive.gd").new()
	var fake_car := Node3D.new()
	hd.setup(d._seed, fake_car, {"traffic_count": 3, "dog_count": 4, "mugger_count": 2})
	_check(not hd.hazards.events.is_empty(), "hazard params build events")
	hd.free()
	fake_car.free()
	game.phase = game.Phase.SCAVENGE
	hp0 = game.car_hp
	game.s_hazard("dog")
	game.phase = game.Phase.DRIVE
	_check(game.car_hp == hp0, "hazard outside the drive changes nothing")
	# Kebab shop
	_check(d.shop == null, "night 1 drive builds no kebab shop")
	var kd = load("res://scripts/world/drive.gd").new()
	var kcar := Node3D.new()
	kd.setup(d._seed, kcar, {"traffic_count": 0, "dog_count": 0, "mugger_count": 0}, true)
	_check(kd.shop != null and kd.path_query(kd.shop.position).d > kd.ROAD_W * 0.5, "kebab flag builds a shop beside the road")
	_check(kd.in_shop_zone(kd.shop.position) and not kd.in_shop_zone(kd.pts[0]), "shop zone is local to the shop")
	kd.free()
	kcar.free()
	game.s_kebab_open()
	_check(not game.kebab_is_open, "shop disabled: s_kebab_open refused")
	game.kebab_shop_enabled = true
	game.s_kebab_pick("Lamb")
	_check(game._kebab == null, "s_kebab_pick before opening does nothing")
	game.wanted = 50.0
	game.car_hp = 60.0
	game.s_kebab_open()
	await _wait(0.1)
	_check(game.kebab_is_open and game._kebab != null, "s_kebab_open enters the kebab state")
	_check(world.get_node_or_null("KebabLayer/KebabPanel") != null, "kebab panel exists under World")
	_check(world.kebab_panel.reader, "solo Navigator is the order reader")
	var wanted_open: float = game.wanted
	var guard_k := 0
	while game.kebab_is_open and guard_k < 60:
		var k = game._kebab
		var n: int = k.items.size()
		if n > 0 and k.items[n - 1] != k.order[n - 1]:
			game.s_kebab_undo()
		else:
			game.s_kebab_pick(k.order[n])
		await _wait(0.08)
		guard_k += 1
	_check(not game.kebab_is_open and game._kebab == null, "correct picks finish the order and close the shop (%d steps)" % guard_k)
	_check(game.wanted < wanted_open and game.car_hp > 60.0, "kebab reward lowers wanted (%.1f -> %.1f) and raises car hp (%.1f)" % [wanted_open, game.wanted, game.car_hp])
	_check(world.get_node_or_null("KebabLayer") == null, "kebab panel gone after the order")
	game.s_kebab_open()
	_check(not game.kebab_is_open, "second kebab visit in the same drive refused")
	hp0 = game.car_hp
	w0 = game.wanted
	game.s_kebab_pick("Lamb")
	game.s_kebab_undo()
	_check(game._kebab == null and game.car_hp == hp0 and game.wanted == w0, "kebab picks outside the kebab state do nothing")
	game.kebab_shop_enabled = false
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

	# Campaign: night 1 won, roll into night 2
	_check(game.night == 0 and game.has_next_night(), "won night 1, a next night is on offer")
	var def_cop: float = Tuning.defaults().cop_first_min
	game.next_night()
	await _wait(0.5)
	_check(game.phase == game.Phase.SCAVENGE and game.night == 1, "next night advances the night index")
	_check(game.kebab_shop_enabled, "night 2 turns the kebab shop on")
	_check(Tuning.cop_first_min == 11.0 and Tuning.cop_first_min != def_cop, "Tuning reflects the night 2 overrides")
	world = root.get_node_or_null("Main/World")
	_check(world != null, "fresh world for night 2")
	await _wait(0.5)
	_check(game.parts.size() == 4, "night 2 parts laid out")
	_check(game.money == 300, "night 2 starts with its own opening pool")
	for p in game.parts:
		_check(p.state == game.PS.SHELF, "night 2 part starts on the shelf")
	game.earn(PartsShop.total(), "test")
	for i in game.parts.size():
		game.s_buy(i)
		var br := Vector2(game.parts[i].pos.x, game.parts[i].pos.z).length()
		_check(game.parts[i].state == game.PS.WORLD and absf(br - game.DELIVERY_R) < 0.01, "bought part %d lands beside the car" % i)
	for i in game.parts.size():
		var gd := 0
		while game.parts[i].state != game.PS.CARRIED and gd < 60:
			game.s_pickup(i)
			gd += 1
		game.s_place(1.0)
	await _wait(3.6)
	_check(game.phase == game.Phase.DRIVE, "night 2 drive phase starts")
	await _wait(0.5)
	d = world.drive
	var n2: Dictionary = Nights.get_night(1)
	var hb: Array = n2.home_blocks
	var blocks_away: int = CityLayout.grid_dist(game.city.home_block, game.city.casino_block)
	_check(blocks_away >= int(hb[0]) and blocks_away <= int(hb[1]), "night 2 home is %d blocks from the casino" % blocks_away)
	_check(d.hazards != null and not d.hazards.events.is_empty(), "night 2 drive has hazard events")
	_check(d.shop != null, "night 2 drive has a kebab shop")

	# Lose it and retry: same night
	game.won = false
	game._finish(false, "Busted.")
	await _wait(0.2)
	_check(game.phase == game.Phase.RESULT and not game.won and not game.has_next_night(), "lost night 2: no next night on offer")
	game.retry_night()
	await _wait(0.5)
	_check(game.phase == game.Phase.SCAVENGE and game.night == 1, "retry after a loss keeps the night index")
	_check(Tuning.cop_first_min == 11.0 and game.kebab_shop_enabled, "retry re-applies night 2 tuning and shop")

	# Lobby and fresh start: back to night 1 with default tuning
	game.return_to_lobby()
	await _wait(0.3)
	_check(game.phase == game.Phase.LOBBY, "back to lobby after result")
	_check(game.night == 0 and not game.kebab_shop_enabled and Tuning.cop_first_min == def_cop, "lobby resets to night 1 and default Tuning")
	game.start_game()
	await _wait(0.5)
	_check(game.night == 0 and not game.kebab_shop_enabled and Tuning.cop_first_min == def_cop, "fresh start is night 1 with default Tuning")
	print("\nRESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails else 0)
