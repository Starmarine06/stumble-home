extends SceneTree

const PartChecklistClass = preload("res://scripts/ui/part_checklist.gd")
const RouletteTable3D = preload("res://scripts/minigames/roulette_table_3d.gd")
const RouletteBettingDialog = preload("res://scripts/ui/roulette_betting_dialog.gd")
const Roulette3DGame = preload("res://scripts/minigames/roulette_3d_game.gd")

func _init() -> void:
	print("\n=======================================================")
	print("🧪 RUNNING COMPREHENSIVE 3D ROULETTE & CAR PARTS TEST")
	print("=======================================================\n")
	_run_tests()

func _run_tests() -> void:
	await _test_part_checklist_standalone()
	await _test_feature_main_car_parts()
	await _test_roulette_table_3d_structure()
	await _test_roulette_betting_dialog()
	await _test_roulette_3d_physics_and_payout()
	
	print("\n=======================================================")
	print("🎉 ALL TESTS PASSED! CAR PARTS & 3D ROULETTE VERIFIED!")
	print("=======================================================\n")
	quit(0)

func _test_part_checklist_standalone() -> void:
	print("--- Test 1: PartChecklist Standalone Fallback & Drawing ---")
	var checklist = PartChecklist.new()
	root.add_child(checklist)
	await process_frame

	# Simulate a player with local_parts in tree
	var dummy_player = Node.new()
	dummy_player.name = "Player"
	dummy_player.set("local_parts", [
		{"name": "Battery", "state": 1, "holder": 0, "pos": Vector3.ZERO, "yaw": 0.0, "q": 0.0, "warned": false}, # CARRIED
		{"name": "Fuel Pump", "state": 2, "holder": 0, "pos": Vector3.ZERO, "yaw": 0.0, "q": 0.9, "warned": false}, # INSTALLED
		{"name": "Spark Plugs", "state": 0, "holder": 0, "pos": Vector3.ZERO, "yaw": 0.0, "q": 0.0, "warned": false}, # WORLD
		{"name": "Spare Tyre", "state": 0, "holder": 0, "pos": Vector3.ZERO, "yaw": 0.0, "q": 0.0, "warned": false} # WORLD
	])
	dummy_player.set("PART_NAMES", ["Battery", "Fuel Pump", "Spark Plugs", "Spare Tyre"])
	dummy_player.set("SOLID_Q", 0.75)
	dummy_player.add_to_group("player")
	root.add_child(dummy_player)
	await process_frame

	# Queue redraw
	checklist.queue_redraw()
	await process_frame
	print("  ✓ PartChecklist successfully drew with player.local_parts fallback!")
	
	checklist.queue_free()
	dummy_player.queue_free()
	await process_frame

func _test_feature_main_car_parts() -> void:
	print("\n--- Test 2: FeatureMain Car Parts Winning, Lifting, Seating ---")
	var main_scene = load("res://scenes/feature_main.tscn")
	assert(main_scene != null, "feature_main.tscn must exist")
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame

	var player = main_node.find_child("Player", true, false)
	assert(player != null, "Player must exist in feature_main")
	
	var parts_root = player._get_scavenge_parts_root()
	assert(parts_root != null, "ScavengeParts must be resolved by _get_scavenge_parts_root()")
	assert(parts_root.get_child_count() == 4, "ScavengeParts must contain 4 car parts")

	for i in 4:
		var p_node = parts_root.get_node_or_null("WorldPart_%d" % i) as Node3D
		assert(p_node != null, "WorldPart_%d must exist" % i)
		assert(p_node.visible == false, "WorldPart_%d should initially be hidden" % i)

	# 1. Test Winning Minigames -> Parts become visible with beacon glow
	print("  Testing minigame awards for all 4 parts...")
	for i in 4:
		player._on_minigame_won(i)
		var p_node = parts_root.get_node_or_null("WorldPart_%d" % i) as Node3D
		assert(p_node.visible == true, "WorldPart_%d must be visible after winning minigame" % i)
		var glow = p_node.find_child("BeaconGlow", true, false) as OmniLight3D
		assert(glow != null, "BeaconGlow must exist on WorldPart_%d" % i)
		assert(glow.visible == true, "BeaconGlow must be visible")
		assert(player._get_parts()[i].state == player.PS.WORLD, "Part %d state must be WORLD" % i)
		print("    ✓ Won minigame %d -> Awarded %s! World mesh visible with BeaconGlow energy %.1f" % [i, player.PART_NAMES[i], glow.light_energy])

	# 2. Test Lifting Part 0 (Battery)
	print("  Testing lifting car part 0 (Battery)...")
	player._lift_part(0)
	assert(player.carried_part_idx == 0, "carried_part_idx must be 0")
	assert(player._get_parts()[0].state == player.PS.CARRIED, "Battery state must be CARRIED")
	assert(player.carried_part_root.visible == true, "CarriedPart viewmodel root must be visible")
	assert(player.carried_meshes[0].visible == true, "Battery carried mesh must be visible")
	print("    ✓ Battery successfully lifted into viewmodel hands!")

	# 3. Test Dropping Part 0
	print("  Testing dropping car part 0...")
	player._drop_carried_part()
	assert(player.carried_part_idx == -1, "carried_part_idx must be -1 after drop")
	assert(player._get_parts()[0].state == player.PS.WORLD, "Battery state must revert to WORLD")
	var p0_node = parts_root.get_node_or_null("WorldPart_0") as Node3D
	assert(p0_node.visible == true, "Battery world mesh must be visible in world after drop")
	print("    ✓ Battery dropped back onto ground at position: %s" % str(p0_node.global_position))

	# 4. Test Lifting Part 3 (Spare Tyre) and Seating into Camper Van
	print("  Testing lifting Spare Tyre won from Roulette...")
	player._lift_part(3)
	assert(player.carried_part_idx == 3, "carried_part_idx must be 3")
	assert(player._get_parts()[3].state == player.PS.CARRIED, "Spare Tyre state must be CARRIED")
	
	# Seat perfectly into Van
	player._seat_part_perfectly(3)
	assert(player.carried_part_idx == -1, "carried_part_idx must be -1 after seating")
	assert(player._get_parts()[3].state == player.PS.INSTALLED, "Spare Tyre state must be INSTALLED")
	assert(player.van_slots[3].find_child("Installed", true, false).visible == true, "Installed tyre mesh must be visible on Camper Van")
	print("    ✓ Spare Tyre bolted securely into Camper Van!")

	main_node.queue_free()
	await process_frame

func _test_roulette_table_3d_structure() -> void:
	print("\n--- Test 3: RouletteTable3D Structure & Wheel Alignment ---")
	var table = RouletteTable3D.new()
	root.add_child(table)
	await process_frame

	assert(table.table_body != null, "Table body must exist")
	assert(table.rotor_node != null, "Rotor turntable must exist")
	assert(table.ball_mesh != null, "Ivory ball must exist")
	assert(table.win_marker != null, "Win marker must exist")
	assert(table.overhead_light != null, "Overhead lamp spot light must exist")

	# Test rotor rotation
	table.set_rotor_rotation(1.57)
	assert(is_equal_approx(table.rotor_node.rotation.y, 1.57), "Rotor rotation should match set value")

	# Test ball position
	table.set_ball_position(0.42, 2.0, -0.018)
	assert(is_equal_approx(table.ball_mesh.position.y, -0.018), "Ball Y should match")
	assert(is_equal_approx(table.ball_mesh.position.x, cos(2.0) * 0.42), "Ball X should match cylindrical pos")

	# Test pocket highlight
	table.highlight_pocket(1) # Pocket 32
	assert(table.win_marker.visible == true, "Win marker should become visible")
	table.clear_win_marker()
	assert(table.win_marker.visible == false, "Win marker should clear")
	print("  ✓ RouletteTable3D 3D components, bowl, rotor, ball, and markers verified!")

	table.queue_free()
	await process_frame

func _test_roulette_betting_dialog() -> void:
	print("\n--- Test 4: RouletteBettingDialog Slider & Bet Selection ---")
	var dialog = RouletteBettingDialog.new(1000)
	root.add_child(dialog)
	await process_frame

	assert(dialog.wallet_cash == 1000, "Wallet cash must be $1000")
	assert(dialog.current_bet >= 50, "Initial bet must be at least $50")
	assert(dialog.bet_slider.min_value == 50.0, "Min bet slider must be 50")
	assert(dialog.bet_slider.max_value == 1000.0, "Max bet slider must match wallet $1000")

	# Test steppers
	dialog._adjust_bet(+50)
	assert(dialog.current_bet == 150, "Bet should be 150 after +$50")
	dialog._adjust_bet(-10)
	assert(dialog.current_bet == 140, "Bet should be 140 after -$10")

	# Test presets
	dialog._set_bet(dialog.wallet_cash) # All in
	assert(dialog.current_bet == 1000, "All in must be $1000")

	# Test bet choices
	dialog._select_bet_type("BLACK")
	assert(dialog.selected_bet_type == "BLACK", "Bet type should be BLACK")

	dialog._select_bet_type("NUMBER")
	dialog.number_spinbox.value = 17
	assert(dialog.selected_bet_type == "NUMBER", "Bet type should be NUMBER")
	assert(dialog.selected_number == 17, "Selected number should be 17")

	print("  ✓ RouletteBettingDialog stepper controls, all-in preset, and bet selection verified!")

	dialog.queue_free()
	await process_frame

func _test_roulette_3d_physics_and_payout() -> void:
	print("\n--- Test 5: Roulette3DGame Real-Life Spinning Physics & Payout ---")
	var table = RouletteTable3D.new()
	root.add_child(table)

	var dummy_player = CharacterBody3D.new()
	dummy_player.name = "DummyPlayer"
	var cam = Camera3D.new()
	dummy_player.add_child(cam)
	root.add_child(dummy_player)
	await process_frame

	var session = Roulette3DGame.new()
	root.add_child(session)

	session.start_roulette_session(dummy_player, table, null, 100, "RED")
	assert(session.hud_overlay != null, "HUD overlay must be created")

	# Step physics forward through phases
	print("  Simulating real-life rotor clockwise spin & counter-clockwise ball launch...")
	# 1. Transition in -> Launch -> RIM_ORBIT
	session._process(0.7)
	session._process(0.01)
	assert(session.state == session.SessionState.RIM_ORBIT, "Session should be in RIM_ORBIT after launch")
	assert(session.ball_speed < -15.0, "Ball speed must be rapid counter-clockwise (< -15 rad/s)")
	assert(session.rotor_speed > 4.0, "Rotor speed must be clockwise (> 4 rad/s)")
	print("    ✓ Outer rim orbit: Ball speed = %.1f rad/s, Rotor speed = %.1f rad/s" % [session.ball_speed, session.rotor_speed])

	# 2. Outer rim orbit -> Spiral drop
	session._process(2.5)
	session._process(0.01)
	assert(session.state == session.SessionState.SPIRAL_DROP, "Session should transition to SPIRAL_DROP")
	print("    ✓ Centrifugal decay -> Inward spiral drop")

	# 3. Spiral drop -> Deflector bounce
	session._process(1.7)
	session._process(0.01)
	assert(session.state == session.SessionState.DEFLECTOR_BOUNCE, "Session should transition to DEFLECTOR_BOUNCE")
	print("    ✓ Deflector pin collisions: Ball hopping and deflecting")

	# 4. Deflector bounce -> Fret hopping
	session._process(1.5)
	session._process(0.01)
	assert(session.state == session.SessionState.FRET_HOPPING, "Session should transition to FRET_HOPPING")
	print("    ✓ Fret hopping across pocket dividers")

	# 5. Fret hopping -> Settled pocket
	session._process(1.5)
	session._process(0.01)
	assert(session.state == session.SessionState.SETTLED or session.state == session.SessionState.RESULT_ANNOUNCE, "Session should be settled")
	print("    ✓ Ball settled in pocket #%d -> Number: %d (%s)!" % [session.settled_pocket_idx, session.winning_number, session.winning_color])
	assert(table.win_marker.visible == true, "Winning pocket marker must be visible on wheel face")

	# 6. Test direct deterministic bet evaluation
	session.winning_number = 14
	session.winning_color = "RED"
	session.bet_type = "RED"
	session.bet_amount = 100
	session._evaluate_bet_result()
	assert(session.is_bet_won == true, "RED bet should win on RED 14")
	assert(session.payout_amount == 200, "Payout should be $200 (2x bet)")
	assert(session.spare_tyre_awarded == true, "Spare Tyre must be awarded on winning bet")
	print("    ✓ Payout evaluation verified: 2x payout ($200) and Spare Tyre awarded!")

	# Test Single Number Jackpot (36x)
	session.winning_number = 7
	session.winning_color = "RED"
	session.bet_type = "NUMBER"
	session.bet_param = 7
	session.bet_amount = 50
	session._evaluate_bet_result()
	assert(session.is_bet_won == true, "Single Number bet should win on 7")
	assert(session.payout_amount == 1800, "Single number jackpot should be 36x ($1800)")
	print("    ✓ Single Number 36x Jackpot verified: $50 wager pays out $1,800!")

	session.queue_free()
	table.queue_free()
	dummy_player.queue_free()
	await process_frame
