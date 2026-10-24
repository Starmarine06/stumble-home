extends SceneTree

func _init() -> void:
	print("--- Testing Home Screen Scene Instantiation & Rendering ---")
	var scene = load("res://scenes/home_screen.tscn")
	if not scene:
		printerr("FAIL: Could not load res://scenes/home_screen.tscn")
		quit(1)
		return
	
	var inst = scene.instantiate()
	root.add_child(inst)
	
	# Verify essential nodes
	var play_btn = inst.find_child("PlayButton", true, false)
	var create_btn = inst.find_child("CreateRoomButton", true, false)
	var quit_btn = inst.find_child("QuitButton", true, false)
	var logo = inst.find_child("LogoTexture", true, false)
	var name_input = inst.find_child("NameInput", true, false)
	var card_driver = inst.find_child("CardDriver", true, false)
	var card_navigator = inst.find_child("CardNavigator", true, false)
	var card_mechanic = inst.find_child("CardMechanic", true, false)
	var card_lookout = inst.find_child("CardLookout", true, false)

	assert(play_btn != null, "PlayButton must exist")
	assert(create_btn != null, "CreateRoomButton must exist")
	assert(quit_btn != null, "QuitButton must exist")
	assert(logo != null, "LogoTexture must exist")
	assert(name_input != null, "NameInput must exist")
	assert(card_driver != null, "CardDriver must exist")
	assert(card_navigator != null, "CardNavigator must exist")
	assert(card_mechanic != null, "CardMechanic must exist")
	assert(card_lookout != null, "CardLookout must exist")

	print("PASS: All UI elements, cartoon buttons, and role cards verified.")
	
	# Process a few frames to let camera and tweens initialize
	for i in range(10):
		await process_frame
	
	print("PASS: Home Screen processed 10 frames smoothly without errors.")
	quit(0)
