extends SceneTree

func _init() -> void:
	print("==================================================")
	print("🎲 COMPREHENSIVE END-TO-END ROULETTE FLOW TEST")
	print("==================================================")
	_run()

func _run() -> void:
	var main_scene = load("res://scenes/feature_main.tscn")
	assert(main_scene != null, "feature_main.tscn must exist")
	var main_node = main_scene.instantiate()
	root.add_child(main_node)

	for i in 3:
		await process_frame

	var player = main_node.find_child("Player", true, false)
	assert(player != null, "Player must exist in scene tree")
	print("✓ Player successfully instantiated. Starting wallet: $", player.player_money)
	assert(player.player_money == 1000, "Player must start with $1000")

	var table = get_first_node_in_group("roulette_tables")
	if not table:
		table = main_node.find_child("RouletteTable3D", true, false)
	assert(table != null, "RouletteTable3D must exist in the world")
	assert(table.is_inside_tree(), "RouletteTable3D must be inside scene tree")
	print("✓ RouletteTable3D resolved at global pos: ", table.global_position)

	var antoine = main_node.find_child("NPC_Antoine", true, false)
	assert(antoine != null, "NPC_Antoine must exist in the world")
	print("✓ Antoine resolved at global pos: ", antoine.global_position)

	# 1. Move player to Antoine and Roulette Table
	player.global_position = Vector3(18.0, 0.8, -32.8)
	for i in 2:
		await process_frame

	print("✓ Player moved near Roulette Station. Prompt visible: ", player.interact_prompt_lbl.visible)
	print("  Prompt text: ", player.interact_prompt_lbl.text)
	assert(player.interact_prompt_lbl.visible, "Prompt must be visible when player is near Antoine/Table")

	# 2. Simulate pressing E key
	print("Simulating [E] keypress to open Roulette Betting Dialog...")
	var ev_e = InputEventKey.new()
	ev_e.keycode = KEY_E
	ev_e.pressed = true
	player._input(ev_e)

	for i in 2:
		await process_frame

	var dlg = root.find_child("RouletteBettingDialog", true, false)
	assert(dlg != null, "RouletteBettingDialog must be open in the tree!")
	print("✓ RouletteBettingDialog is open! Mouse mode is: ", Input.mouse_mode)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse mode must be VISIBLE while betting dialog is open")

	# 3. Change bet
	print("Adjusting bet on dialog...")
	dlg._set_bet(250)
	dlg._select_bet_type("RED")
	assert(dlg.current_bet == 250, "Bet must be $250")
	assert(dlg.selected_bet_type == "RED", "Bet type must be RED")
	print("✓ Bet set to $250 on RED")

	# 4. Confirm bet & spin wheel via Enter key
	print("Simulating [ENTER] keypress on betting dialog...")
	var ev_enter = InputEventKey.new()
	ev_enter.keycode = KEY_ENTER
	ev_enter.pressed = true
	dlg._input(ev_enter)

	for i in 2:
		await process_frame

	# Verify dialog closed and player cash was deducted
	var dlg_after = root.find_child("RouletteBettingDialog", true, false)
	assert(dlg_after == null, "RouletteBettingDialog must be closed after confirming bet!")
	print("✓ RouletteBettingDialog closed cleanly.")
	print("✓ Remaining player wallet cash: $", player.player_money)
	assert(player.player_money == 750, "Player money must be $750 ($1000 - $250 wager)")
	assert(table.is_spinning == true, "RouletteTable3D.is_spinning must be true!")
	print("✓ RouletteTable3D is spinning in realtime!")
	print("✓ Player mouse unlocked flag: ", player.is_mouse_unlocked, " minigame_active: ", player.minigame_active)
	assert(player.is_mouse_unlocked == false, "Player mouse must be recaptured")
	assert(player.minigame_active == false, "Player must be free to move around")

	# 5. Advance table spinning physics
	print("Simulating physical ball spinning frames...")
	for f in 30:
		table._process(0.1)

	# 6. Force settle ball in a known RED pocket (e.g. pocket 1 -> Number 32 RED)
	table.ball_angle = 0.0
	table.rotor_angle = 0.0
	table._settle_ball()

	print("✓ Ball settled! Winning number: ", table.winning_number, " (", table.winning_color, ")")
	print("  Player money after win payout: $", player.player_money)
	assert(player.won_parts[3] == true, "Spare tyre (part 3) must be awarded!")
	print("✓ Spare Tyre awarded! Car part 3 state: ", player._get_parts()[3].state)

	print("\n==================================================")
	print("🎉 ALL ROULETTE FLOW CHECKS PASSED PERFECTLY!")
	print("==================================================")
	quit(0)
