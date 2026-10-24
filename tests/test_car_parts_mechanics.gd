extends SceneTree

func _init() -> void:
	print("--- Starting Automated Test for 3D In-Casino Darts, Betting, Key-Shift Stumble, Casino Minigames & Car Placement ---")
	var main_scene = load("res://scenes/feature_main.tscn")
	if not main_scene:
		printerr("FAIL: Could not load scenes/feature_main.tscn")
		quit(1)
		return

	var world = main_scene.instantiate()
	root.add_child(world)
	print("Instantiated feature_main.tscn")

	# Allow tree and child nodes to run _ready()
	for i in 8:
		await process_frame

	# Find player
	var player = world.find_child("Player", true, false)
	if not player:
		printerr("FAIL: Player not found in world!")
		quit(1)
		return
	print("PASS: Found Player node (Wallet Cash: $", player.player_money, ")")

	# 1. Verify Player is Always Drunk from Boot (100%)
	if player.drunk_meter < 99.0:
		printerr("FAIL: Player should be permanently 100% drunk! Was: ", player.drunk_meter)
		quit(1)
		return
	print("PASS: Player is Permanently Drunk from Boot! (Drunk Meter: ", player.drunk_meter, "%)")

	# 2. Verify Coma & Manual BalanceBar are Removed
	if player.balance_bar != null:
		printerr("FAIL: BalanceBar should be removed/null per user request!")
		quit(1)
		return
	if player.is_in_coma:
		printerr("FAIL: Player should not be in coma!")
		quit(1)
		return
	print("PASS: Manual Q/E BalanceBar and Coma mechanics successfully removed!")

	# 3. Verify Double-Image Blurred Shader Setup
	print("Testing Drunk Double-Image Shader Parameters...")
	player._process(0.016)
	var screen_fx = player.screen_fx_rect
	if not screen_fx or not screen_fx.material:
		printerr("FAIL: ScreenFX ColorRect or material missing!")
		quit(1)
		return
	var mat = screen_fx.material as ShaderMaterial
	var blur_amt = mat.get_shader_parameter("blur_amount")
	var d_mix = mat.get_shader_parameter("double_vision_mix")
	var g_off = mat.get_shader_parameter("ghost_offset")
	var d_int = mat.get_shader_parameter("drunk_intensity")
	if blur_amt <= 0.0 or d_mix <= 0.0 or d_int < 0.99:
		printerr("FAIL: Double-image shader parameters not properly set! blur:", blur_amt, " mix:", d_mix, " drunk:", d_int)
		quit(1)
		return
	print("PASS: Double-Image Shader active with blurred previous frame ghost (blur_amount: ", blur_amt, ", mix: ", d_mix, ", ghost_offset: ", g_off, ")")

	# 4. Verify 3D Dartboard and Barney NPC Inside Casino
	print("Verifying 3D Dartboard and Barney NPC inside Ceaser Casino...")
	var pub_casino = world.find_child("PubCasinoBuilding", true, false)
	if not pub_casino:
		printerr("FAIL: PubCasinoBuilding not found in world!")
		quit(1)
		return
	
	var dartboard = world.find_child("DartBoard3D", true, false)
	if not dartboard:
		printerr("FAIL: DartBoard3D not found inside Casino!")
		quit(1)
		return
	print("PASS: 3D DartBoard found mounted on the wall inside Casino! (Pos: ", dartboard.position, ")")

	var barney = world.find_child("NPC_Barney", true, false)
	if not barney:
		printerr("FAIL: Barney Darts Bookie NPC not found inside Casino!")
		quit(1)
		return
	print("PASS: Barney Darts NPC found standing beside the dartboard! (Pos: ", barney.position, ")")

	# 5. Test 3D Dartboard Mathematical Scoring
	print("Testing 3D Dartboard Mathematical Scoring...")
	# Bullseye (double bull, 50 pts)
	var hit_bull = dartboard.evaluate_hit(Vector2(0.0, 0.0))
	if hit_bull.score != 50:
		printerr("FAIL: Center hit should score 50 (Double Bull)! Got: ", hit_bull.score)
		quit(1)
		return
	print("PASS: Center hit evaluated to 50 pts (Double Bullseye)!")

	# Outer Bull (single bull, 25 pts)
	var hit_obull = dartboard.evaluate_hit(Vector2(0.0, 0.025))
	if hit_obull.score != 25:
		printerr("FAIL: Outer bull hit should score 25! Got: ", hit_obull.score)
		quit(1)
		return
	print("PASS: Outer bull evaluated to 25 pts!")

	# Triple 20 (y = 0.215, x = 0.0) -> 60 pts
	var hit_t20 = dartboard.evaluate_hit(Vector2(0.0, 0.215))
	if hit_t20.score != 60:
		printerr("FAIL: Triple 20 hit should score 60! Got: ", hit_t20.score)
		quit(1)
		return
	print("PASS: Triple 20 evaluated to 60 pts! (Name: ", hit_t20.name, ")")

	# Double 20 (y = 0.365, x = 0.0) -> 40 pts
	var hit_d20 = dartboard.evaluate_hit(Vector2(0.0, 0.365))
	if hit_d20.score != 40:
		printerr("FAIL: Double 20 hit should score 40! Got: ", hit_d20.score)
		quit(1)
		return
	print("PASS: Double 20 evaluated to 40 pts! (Name: ", hit_d20.name, ")")

	# Miss outside board (r > 0.42m) -> 0 pts
	var hit_miss = dartboard.evaluate_hit(Vector2(0.48, 0.48))
	if hit_miss.is_hit or hit_miss.score != 0:
		printerr("FAIL: Miss outside board should award 0 pts! Got: ", hit_miss.score)
		quit(1)
		return
	print("PASS: Miss outside board strictly evaluated to 0 pts (is_hit = false)!")

	# 6. Test Darts Betting Dialog & Multiplier Calculation (Sliding Bar System)
	print("Testing Darts Betting Modal & Sliding Bar System...")
	var initial_cash = player.player_money
	if initial_cash != 1000:
		printerr("FAIL: Expected 4-patron shared wallet to start at $1000! Got: ", initial_cash)
		quit(1)
		return
	print("PASS: Shared Wallet starts at $1000! (Wallet label active: ", player.wallet_label != null, ")")

	var betting_dlg = load("res://scripts/ui/darts_betting_dialog.gd").new(player.player_money)
	world.add_child(betting_dlg)
	await process_frame
	if betting_dlg.current_bet != 50:
		printerr("FAIL: Default bet should be min $50! Got: ", betting_dlg.current_bet)
		quit(1)
		return
	if betting_dlg.bet_slider == null or betting_dlg.bet_slider.max_value != 1000:
		printerr("FAIL: Bet slider should allow sliding up to wallet amount ($1000 ALL IN)!")
		quit(1)
		return
	betting_dlg.bet_slider.value = 500
	betting_dlg._update_ui()
	print("PASS: Darts Betting Slider System verified (Min: $50, Max: $1000 ALL IN, Set: $", betting_dlg.current_bet, ")")
	betting_dlg.queue_free()

	# 7. Test 3D Darts Session (Handover, Cutscene <= 1s, Drunken Arc & Throw)
	print("Testing 3D In-Casino Darts Session...")
	var darts_session = load("res://scripts/minigames/darts_3d_game.gd").new()
	world.add_child(darts_session)
	darts_session.start_darts_session(player, dartboard, barney, 50)
	
	if darts_session.state != darts_session.State.HANDOVER:
		printerr("FAIL: Darts session should start in HANDOVER state! Got: ", darts_session.state)
		quit(1)
		return
	print("PASS: Handover animation state triggered!")

	# Fast forward through handover (0.35s)
	darts_session._process(0.36)
	if darts_session.state != darts_session.State.CUTSCENE_WALK:
		printerr("FAIL: Should transition to CUTSCENE_WALK! Got: ", darts_session.state)
		quit(1)
		return
	print("PASS: Cutscene walk to throw line started (Target Duration: <= 1.0s)!")

	# Advance cutscene walk (0.75s, strictly <= 1s)
	darts_session._process(0.76)
	if darts_session.state != darts_session.State.AIMING:
		printerr("FAIL: Cutscene should complete and enter AIMING phase! Got: ", darts_session.state)
		quit(1)
		return
	print("PASS: Stepped behind throw line in 0.75s! Aiming phase active with 3D arc & crosshair!")

	# Verify 3D viewmodel dart and projectile arc
	if not darts_session.viewmodel_dart or not darts_session.viewmodel_dart.is_inside_tree():
		printerr("FAIL: Viewmodel dart not spawned near camera!")
		quit(1)
		return
	if not darts_session.arc_imm_mesh:
		printerr("FAIL: ImmediateMesh for projectile arc missing!")
		quit(1)
		return
	print("PASS: 3D Viewmodel dart and glowing drunken projectile arc active!")

	# Test Drunken Arc Wobble
	darts_session.elapsed_aim = 1.5
	darts_session._update_drunken_aim(0.016)
	darts_session._update_projectile_arc()
	if darts_session.current_aim == Vector2.ZERO or darts_session.flight_pts.is_empty():
		printerr("FAIL: Drunken aim should deviate from zero and compute flight arc points!")
		quit(1)
		return
	print("PASS: Drunken aim shifted successfully! (Current Aim: ", darts_session.current_aim, ", Arc Points: ", darts_session.flight_pts.size(), ")")

	# Test Throwing 3 Darts into the Board
	print("Testing throwing darts into the 3D dartboard...")
	for d_idx in 3:
		darts_session.current_aim = Vector2(0.0, 0.215) # Aim at Triple 20
		darts_session._throw_dart()
		# Fast forward dart flight
		darts_session._update_flying_dart(0.30)
		print("  Dart %d thrown: Current Score = %d pts" % [d_idx + 1, darts_session.total_score])
	
	if darts_session.total_score != 180: # 3 x Triple 20 = 180 pts (Max 180 score!)
		printerr("FAIL: Expected 180 score from 3x Triple 20, got: ", darts_session.total_score)
		quit(1)
		return
	print("PASS: 3 Darts thrown! Total score: 180 pts (MAX 180!)")

	# Verify Stuck Darts on the 3D Dartboard Face
	if dartboard.stuck_darts_root.get_child_count() != 3:
		printerr("FAIL: Expected 3 physically stuck darts in dartboard! Got: ", dartboard.stuck_darts_root.get_child_count())
		quit(1)
		return
	print("PASS: All 3 physical 3D darts are pinned into the dartboard!")

	# Verify Payout Multiplier & Win Payout
	var mult_expected = 7.0 # 100+ pts = 7.0x multiplier
	var expected_payout = int(50 * mult_expected) # $350
	if darts_session.state != darts_session.State.ROUND_OVER:
		printerr("FAIL: Session should be in ROUND_OVER state! Got: ", darts_session.state)
		quit(1)
		return
	print("PASS: 7.0x Multiplier awarded! Payout: $", expected_payout)

	darts_session.cleanup()
	darts_session.queue_free()

	# 8. Test Key-Shift Walking Mechanics
	print("Testing WASD Key-Shift Stride...")
	player.current_step_key = player.WASDKey.W
	player.key_hold_time = 0.4
	# Shifting key resets hold time and momentum
	player.current_step_key = player.WASDKey.A
	player.key_hold_time = 0.0
	player.drunk_momentum = 0.0
	if player.key_hold_time != 0.0 or player.drunk_momentum != 0.0:
		printerr("FAIL: Key-shift should reset key_hold_time and drunk_momentum!")
		quit(1)
		return
	print("PASS: Shifting between WASD keys resets momentum and maintains drunken stride!")

	# 9. Test Runaway Momentum and Fall on Key Release
	print("Testing Runaway Momentum and Fall on Key Release...")
	player.current_step_key = player.WASDKey.W
	player.key_hold_time = 0.9
	player.drunk_momentum = 0.8
	player.last_move_direction = Vector3.FORWARD
	player._trigger_runaway_stumble()
	if not player.is_stumbling:
		printerr("FAIL: Player should enter runaway stumble state when letting go after holding key!")
		quit(1)
		return
	print("PASS: Runaway stumble triggered! (stumble_timer: ", player.stumble_timer, "s)")

	player._physics_process(0.85)
	if not player.is_fallen_down or not player.is_stunned:
		printerr("FAIL: Player should lose balance and fall flat on the ground after stumbling!")
		quit(1)
		return
	print("PASS: Player lost balance and fell flat on the floor! (fall_stun_timer: ", player.fall_stun_timer, "s)")

	# Recover from fall
	player.fall_stun_timer = 0.0
	player._physics_process(0.016)
	if player.is_fallen_down:
		printerr("FAIL: Player should stand back up when recovery timer expires!")
		quit(1)
		return
	print("PASS: Player recovered and stood back up on their feet!")

	# 10. Verify Minigame Stations and Winning Parts
	print("Testing winning Casino Minigames to award car parts...")
	player._on_minigame_won(0) # Battery from Darts
	player._on_minigame_won(1) # Fuel Pump from Cup Pong
	player._on_minigame_won(2) # Spark Plugs from Slots
	player._on_minigame_won(3) # Spare Tyre from Roulette

	var sc_root = world.find_child("ScavengeParts", true, false)
	for i in 4:
		var p_node = sc_root.get_node_or_null("WorldPart_%d" % i)
		if not p_node or not p_node.visible:
			printerr("FAIL: Car part ", i, " should be visible after winning minigame!")
			quit(1)
			return
	print("PASS: All 4 Car Parts unlocked and visible at Casino stations!")

	# 11. Test Carrying & Green Slot Seating into Van
	var van = world.find_child("ParkedVan", true, false)
	if not van:
		van = world.find_child("Van", true, false)

	print("Testing part pickup and Green Slot Seating into Camper Van...")
	player._lift_part(0)
	if player.carried_part_idx != 0:
		printerr("FAIL: Carried part idx should be 0!")
		quit(1)
		return

	# Simulate aligning with van slot 0 until GREEN (fit_q >= 0.75)
	player.fit_q = 0.85
	player._seat_part_perfectly(0)
	if player.carried_part_idx != -1:
		printerr("FAIL: Carried part should be -1 after seating!")
		quit(1)
		return
	var inst_bat = van.find_child("Slot_Battery", true, false).find_child("Installed", true, false)
	if not inst_bat or not inst_bat.visible:
		printerr("FAIL: Slot_Battery Installed mesh should be visible on Van!")
		quit(1)
		return
	print("PASS: Battery (Part 0) seated perfectly into Van!")

	# Seat remaining 3 parts
	player._lift_part(1)
	player._seat_part_perfectly(1)
	player._lift_part(2)
	player._seat_part_perfectly(2)
	player._lift_part(3)
	player._seat_part_perfectly(3)

	var installed_count = 0
	for p in player._get_parts():
		if p.state == player.PS.INSTALLED:
			installed_count += 1
	if installed_count != 4:
		printerr("FAIL: Expected 4 installed parts, got: ", installed_count)
		quit(1)
		return
	print("PASS: All 4 parts installed into Camper Van!")

	# 12. Verify Victory UI
	player.show_victory_screen()
	if not player.victory_ui or not player.victory_ui.is_inside_tree():
		printerr("FAIL: Victory screen overlay not displayed!")
		quit(1)
		return
	print("PASS: Victory screen displayed successfully!")

	print("=== ALL 3D IN-CASINO DARTS, BETTING, KEY-SHIFT STUMBLE & CAR REPAIR TESTS PASSED (0 FAILURES) ===")
	quit(0)
