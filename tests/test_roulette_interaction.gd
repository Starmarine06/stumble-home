extends SceneTree

func _init():
	print("--- Testing Live Roulette Interaction in feature_main.tscn ---")
	var main_scene = load("res://scenes/feature_main.tscn")
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame

	var player = main_node.find_child("Player", true, false)
	assert(player != null, "Player must exist")

	var table = get_first_node_in_group("roulette_tables")
	if not table:
		table = main_node.find_child("RouletteTable3D", true, false)
	print("Table found:", table != null)
	if table:
		print("Table inside tree:", table.is_inside_tree(), "global_pos:", table.global_position)

	var antoine = main_node.find_child("NPC_Antoine", true, false)
	print("Antoine found:", antoine != null)
	if antoine:
		print("Antoine inside tree:", antoine.is_inside_tree(), "global_pos:", antoine.global_position)

	var npcs = get_nodes_in_group("npcs")
	print("NPCs in group 'npcs':", npcs.size())
	for n in npcs:
		print("  - NPC:", n.name, "pos:", (n as Node3D).global_position)

	# Move player in front of roulette table at (18.0, 0.8, -32.8)
	player.global_position = Vector3(18.0, 0.8, -32.8)
	await process_frame
	await process_frame

	# Check detection
	print("Player pos:", player.global_position)
	print("InteractPrompt visible:", player.interact_prompt_lbl.visible if player.interact_prompt_lbl else "no prompt")
	print("InteractPrompt text:", player.interact_prompt_lbl.text if player.interact_prompt_lbl else "")

	# Press E key
	print("Simulating pressing KEY_E...")
	var ev = InputEventKey.new()
	ev.keycode = KEY_E
	ev.pressed = true
	player._input(ev)
	await process_frame
	await process_frame

	var dlg = root.find_child("RouletteBettingDialog", true, false)
	print("RouletteBettingDialog opened:", dlg != null)
	assert(dlg != null, "RouletteBettingDialog MUST OPEN upon pressing E!")

	if dlg:
		var modal = dlg.find_child("ModalPanel", true, false)
		print("Modal panel size:", modal.size, "global_pos:", modal.global_position)
		var spin_btn = modal.find_child("SpinBtn", true, false)
		print("Spin button visible:", spin_btn != null and spin_btn.is_visible_in_tree(), "pos:", spin_btn.global_position if spin_btn else "")

	print("=== LIVE ROULETTE INTERACTION VERIFIED SUCCESSFULLY! ===")
	quit(0)
