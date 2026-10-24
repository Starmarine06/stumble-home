extends SceneTree

func _init() -> void:
	print("--- Starting Verification for Step Climbing, UI Camera Freezing, Mouse Capture & Slider ---")

	var main_scene = load("res://scenes/feature_main.tscn")
	if not main_scene:
		printerr("FAIL: Could not load feature_main.tscn")
		quit(1)
		return
	var main_root = main_scene.instantiate()
	root.add_child(main_root)

	for i in 8:
		await process_frame

	var player = main_root.find_child("Player", true, false)
	if not player:
		printerr("FAIL: Player not found")
		quit(1)
		return
	assert(player.is_inside_tree(), "Player must be inside scene tree")
	print("PASS: Player node loaded inside scene tree successfully")

	# 1. Test Step Climbing Logic
	print("Testing _apply_step_climb helper...")
	assert(player.has_method("_apply_step_climb"), "Player must have _apply_step_climb method")

	# Create a low 0.25m curb obstacle in front of the player
	var step_body = StaticBody3D.new()
	step_body.position = player.global_position + Vector3(0, 0.125, -0.20)
	var step_col = CollisionShape3D.new()
	var step_box = BoxShape3D.new()
	step_box.size = Vector3(2.0, 0.25, 0.30)
	step_col.shape = step_box
	step_body.add_child(step_col)
	main_root.add_child(step_body)

	for i in 5:
		await physics_frame

	var y_before = player.global_position.y
	player.velocity = Vector3(0, 0, -3.0)
	player._apply_step_climb(Vector3(0, 0, -1.0), 0.016)
	print("Step climb test result: Y before = %.3f, Y after = %.3f" % [y_before, player.global_position.y])
	assert(player.global_position.y >= y_before + 0.40, "Step climb should elevate player above low step!")
	print("PASS: Player stepped up over low 0.25m curb!")

	main_root.remove_child(step_body)
	step_body.free()

	for i in 5:
		await process_frame
		await physics_frame

	# Reset player Y and test tall wall (3.0m)
	player.global_position.y = y_before
	player.velocity = Vector3(0, 0, -3.0)
	var wall_body = StaticBody3D.new()
	wall_body.position = player.global_position + Vector3(0, 1.5, -0.60)
	var wall_col = CollisionShape3D.new()
	var wall_box = BoxShape3D.new()
	wall_box.size = Vector3(4.0, 3.0, 0.30)
	wall_col.shape = wall_box
	wall_body.add_child(wall_col)
	main_root.add_child(wall_body)

	for i in 5:
		await process_frame
		await physics_frame

	print("Wall test: player pos = ", player.global_position, ", wall pos = ", wall_body.global_position)
	var fwd_m = Vector3(0, 0, -1.0) * clampf(player.velocity.length() * 0.016 + 0.14, 0.08, 0.28)
	var t1 = player.test_move(player.global_transform, fwd_m)
	var up_t = player.global_transform
	up_t.origin.y += 0.42
	var t3 = player.test_move(up_t, fwd_m)
	print("Wall test: t1 = ", t1, ", t3 = ", t3)

	var y_wall_before = player.global_position.y
	player._apply_step_climb(Vector3(0, 0, -1.0), 0.016)
	assert(player.global_position.y == y_wall_before, "Player must NOT step climb over a 3.0m wall!")
	print("PASS: Player blocked by tall 3.0m wall (no illegitimate step climbing)")

	main_root.remove_child(wall_body)
	wall_body.free()

	# 2. Test Darts Betting Slider System
	print("Testing Darts Betting Dialog & Enhanced Slider...")
	var DartsBettingDialogClass = load("res://scripts/ui/darts_betting_dialog.gd")
	var dialog = DartsBettingDialogClass.new(1000)
	main_root.add_child(dialog)

	# Verify mouse is visible while dialog is open
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse must be visible while betting dialog is open")
	assert(player.is_ui_active() == true, "is_ui_active() must return true when betting dialog is child")
	assert(player.is_modal_dialog_open() == true, "is_modal_dialog_open() must return true")

	# Test camera freeze: send mouse motion event to player
	var cam_yaw_before = player.rotation.y
	var head_pitch_before = player.head.rotation.x if player.head else 0.0
	var motion_ev = InputEventMouseMotion.new()
	motion_ev.relative = Vector2(25.0, 15.0)
	player._input(motion_ev)
	assert(player.rotation.y == cam_yaw_before, "Camera YAW must NOT rotate while UI is active!")
	if player.head:
		assert(player.head.rotation.x == head_pitch_before, "Head PITCH must NOT rotate while UI is active!")
	print("PASS: Camera look rotation is completely frozen while UI is open!")

	# Verify slider track, grabber and stepper buttons
	assert(dialog.bet_slider != null, "bet_slider must exist")
	assert(dialog.bet_slider.min_value == 50.0, "Slider min must be $50")
	assert(dialog.bet_slider.max_value == 1000.0, "Slider max must be wallet total ($1000)")
	assert(dialog.bet_slider.has_theme_stylebox_override("slider"), "Custom slider track background must be set")
	assert(dialog.bet_slider.has_theme_stylebox_override("grabber_area"), "Glowing gold grabber_area must be set")
	print("PASS: Enhanced slider track and grabber styling verified")

	# Test stepping
	dialog.bet_slider.value = 100.0
	assert(dialog.current_bet == 100, "Current bet must update to 100")
	dialog.bet_slider.value = 250.0
	assert(dialog.current_bet == 250, "Current bet must update to 250")
	print("PASS: Slider value adjustment verified")

	# Test closing dialog -> mouse must be captured and hidden immediately
	dialog.queue_free()
	await dialog.tree_exited
	await process_frame
	var is_headless = (DisplayServer.get_name() == "headless" or DisplayServer.get_name() == "dummy")
	if not is_headless:
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Mouse must be CAPTURED and hidden after closing betting dialog!")
	assert(player.is_mouse_unlocked == false, "Player is_mouse_unlocked must be false after closing UI!")
	print("PASS: Mouse cursor is automatically hidden/captured upon closing betting dialog!")

	# 3. Test 2D Minigames Mouse Recapture
	print("Testing 2D minigames mouse lifecycle...")
	var CupPongClass = load("res://scripts/minigames/cup_pong_game.gd")
	var cp = CupPongClass.new()
	main_root.add_child(cp)
	cp.queue_free()
	await cp.tree_exited
	if not is_headless:
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Mouse must be CAPTURED after leaving Cup Pong")
	print("PASS: Cup Pong mouse lifecycle verified")

	var SlotsClass = load("res://scripts/minigames/slots_game.gd")
	var sl = SlotsClass.new()
	main_root.add_child(sl)
	sl.queue_free()
	await sl.tree_exited
	if not is_headless:
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Mouse must be CAPTURED after leaving Slots")
	print("PASS: Slots mouse lifecycle verified")

	var RouletteClass = load("res://scripts/minigames/roulette_game.gd")
	var rl = RouletteClass.new()
	main_root.add_child(rl)
	rl.queue_free()
	await rl.tree_exited
	if not is_headless:
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Mouse must be CAPTURED after leaving Roulette")
	print("PASS: Roulette mouse lifecycle verified")

	# 4. Test _close_all_modals via ESC
	print("Testing ESC closing all modals...")
	var dialog2 = DartsBettingDialogClass.new(1000)
	main_root.add_child(dialog2)
	var esc_ev = InputEventKey.new()
	esc_ev.pressed = true
	esc_ev.keycode = KEY_ESCAPE
	player._input(esc_ev)
	await dialog2.tree_exited
	if not is_headless:
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "ESC must recapture mouse and close modals")
	assert(player.is_mouse_unlocked == false, "ESC must lock player mouse")
	print("PASS: ESC key cleanly closes modals and recaptures mouse")

	print("\n=== ALL STEP CLIMB, UI CAMERA FREEZE, MOUSE CAPTURE & SLIDER TESTS PASSED! ===")
	quit(0)
