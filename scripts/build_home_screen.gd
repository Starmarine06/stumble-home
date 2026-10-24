@tool
extends SceneTree

func _init() -> void:
	print("--- Building Cartoon Stumble Home Menu Scene (scenes/home_screen.tscn) ---")
	build_home_screen()
	print("--- scenes/home_screen.tscn Built Successfully! ---")
	quit(0)

func set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	if node != scene_root and node.scene_file_path != "":
		return
	for child in node.get_children():
		set_owner_recursive(child, scene_root)

func build_home_screen() -> void:
	var root = Node3D.new()
	root.name = "HomeScreen"
	root.set_script(load("res://scripts/home_screen.gd"))

	# 1. World Environment
	var we = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.04)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.06, 0.08, 0.12)
	env.volumetric_fog_emission = Color(0.01, 0.015, 0.025)
	we.environment = env
	root.add_child(we)

	# 2. Moon & Moonlight
	var moon = MeshInstance3D.new()
	moon.name = "Moon"
	var sp = SphereMesh.new()
	sp.radius = 18.0
	sp.height = 36.0
	sp.material = load("res://assets/materials/moon_mat.tres")
	moon.mesh = sp
	moon.position = Vector3(55.0, 95.0, -90.0)
	root.add_child(moon)

	var moon_light = DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.light_color = Color(0.68, 0.76, 0.95)
	moon_light.light_energy = 0.45
	moon_light.shadow_enabled = true
	moon_light.shadow_bias = 0.08
	moon_light.rotation_degrees = Vector3(-35.0, -22.0, 0.0)
	root.add_child(moon_light)

	# 3. Parking Lot
	var lot_scene = load("res://scenes/parking_lot.tscn")
	var parking_lot = lot_scene.instantiate()
	parking_lot.name = "ParkingLot"
	parking_lot.position = Vector3.ZERO
	root.add_child(parking_lot)

	# 4. Ceaser Pub & Casino Building
	var pub_casino_scene = load("res://scenes/pub_casino.tscn")
	var pub_casino = pub_casino_scene.instantiate()
	pub_casino.name = "PubCasinoBuilding"
	pub_casino.position = Vector3(0, 0, -32.0)
	root.add_child(pub_casino)

	# 5. Brown & White Van
	var van_scene = load("res://scenes/van.tscn")
	var van = van_scene.instantiate()
	van.name = "ParkedVan"
	van.position = Vector3(-15.5, 0.0, 2.0)
	van.rotation.y = deg_to_rad(90.0)
	root.add_child(van)

	# 6. Menu Camera
	var cam = Camera3D.new()
	cam.name = "MenuCamera"
	cam.position = Vector3(-4.0, 2.6, 14.5)
	cam.rotation_degrees = Vector3(-3.0, 10.0, 0.0)
	cam.fov = 65.0
	root.add_child(cam)

	# 7. UI Canvas Layer
	var ui = CanvasLayer.new()
	ui.name = "MenuUI"
	ui.layer = 10
	root.add_child(ui)

	# Root Control Container (1280x720)
	var root_ctrl = Control.new()
	root_ctrl.name = "RootControl"
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root_ctrl)

	# Dark vignette background shading to enhance contrast
	var vignette = ColorRect.new()
	vignette.name = "Vignette"
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.02, 0.03, 0.06, 0.38)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(vignette)

	# Top Right Name Moniker Bar
	var name_box = PanelContainer.new()
	name_box.name = "NameBox"
	name_box.position = Vector2(880, 24)
	name_box.custom_minimum_size = Vector2(360, 52)
	var name_sb = StyleBoxFlat.new()
	name_sb.bg_color = Color(0.08, 0.10, 0.16, 0.92)
	name_sb.border_color = Color(0.96, 0.76, 0.22, 0.9)
	name_sb.set_border_width_all(3)
	name_sb.set_corner_radius_all(14)
	name_sb.set_content_margin_all(8)
	name_box.add_theme_stylebox_override("panel", name_sb)
	root_ctrl.add_child(name_box)

	var name_hbox = HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 10)
	name_box.add_child(name_hbox)

	var name_lbl = Label.new()
	name_lbl.text = "🍺 MONIKER:"
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	name_hbox.add_child(name_lbl)

	var name_input = LineEdit.new()
	name_input.name = "NameInput"
	name_input.text = "Drunkard"
	name_input.placeholder_text = "Enter your drunk name"
	name_input.max_length = 16
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hbox.add_child(name_input)

	# Center Top: Cartoon Stumble Home Logo
	var logo_rect = TextureRect.new()
	logo_rect.name = "LogoTexture"
	logo_rect.texture = load("res://assets/textures/ui_logo_stumble.png")
	logo_rect.position = Vector2(190, 30)
	logo_rect.custom_minimum_size = Vector2(900, 320)
	logo_rect.pivot_offset = Vector2(450, 160)
	logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(logo_rect)

	# Main Layout (HBox: Left = Chunky Buttons, Right = 4 Drunk Role Cards)
	var main_hbox = HBoxContainer.new()
	main_hbox.name = "MainLayout"
	main_hbox.position = Vector2(80, 350)
	main_hbox.custom_minimum_size = Vector2(1120, 300)
	main_hbox.add_theme_constant_override("separation", 40)
	root_ctrl.add_child(main_hbox)

	# --- Left Column: Buttons ---
	var btn_vbox = VBoxContainer.new()
	btn_vbox.name = "ButtonColumn"
	btn_vbox.custom_minimum_size = Vector2(380, 260)
	btn_vbox.add_theme_constant_override("separation", 12)
	main_hbox.add_child(btn_vbox)

	# 1. Play Button
	var play_btn = TextureButton.new()
	play_btn.name = "PlayButton"
	play_btn.texture_normal = load("res://assets/textures/btn_play_normal.png")
	play_btn.texture_hover = load("res://assets/textures/btn_play_hover.png")
	play_btn.texture_pressed = load("res://assets/textures/btn_play_pressed.png")
	play_btn.custom_minimum_size = Vector2(380, 80)
	play_btn.pivot_offset = Vector2(190, 40)
	btn_vbox.add_child(play_btn)

	# 2. Create Room Button (Multiplayer)
	var create_btn = TextureButton.new()
	create_btn.name = "CreateRoomButton"
	create_btn.texture_normal = load("res://assets/textures/btn_create_normal.png")
	create_btn.texture_hover = load("res://assets/textures/btn_create_hover.png")
	create_btn.texture_pressed = load("res://assets/textures/btn_create_pressed.png")
	create_btn.custom_minimum_size = Vector2(380, 80)
	create_btn.pivot_offset = Vector2(190, 40)
	btn_vbox.add_child(create_btn)

	# 3. Quit Button
	var quit_btn = TextureButton.new()
	quit_btn.name = "QuitButton"
	quit_btn.texture_normal = load("res://assets/textures/btn_quit_normal.png")
	quit_btn.texture_hover = load("res://assets/textures/btn_quit_hover.png")
	quit_btn.texture_pressed = load("res://assets/textures/btn_quit_pressed.png")
	quit_btn.custom_minimum_size = Vector2(380, 80)
	quit_btn.pivot_offset = Vector2(190, 40)
	btn_vbox.add_child(quit_btn)

	# --- Right Column: The 4 Drunk Character Cards ---
	var right_vbox = VBoxContainer.new()
	right_vbox.name = "RosterColumn"
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 10)
	main_hbox.add_child(right_vbox)

	var roster_title = Label.new()
	roster_title.text = "★ THE FOUR DRUNKARDS (HOVER OR CLICK TO INSPECT) ★"
	roster_title.add_theme_font_size_override("font_size", 16)
	roster_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	roster_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(roster_title)

	# Cards Row
	var cards_hbox = HBoxContainer.new()
	cards_hbox.name = "CardsRow"
	cards_hbox.add_theme_constant_override("separation", 14)
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_child(cards_hbox)

	var roles_data = [
		{"name": "CardDriver", "tex": "ui_card_driver.png"},
		{"name": "CardNavigator", "tex": "ui_card_navigator.png"},
		{"name": "CardMechanic", "tex": "ui_card_mechanic.png"},
		{"name": "CardLookout", "tex": "ui_card_lookout.png"}
	]

	for r in roles_data:
		var card = TextureRect.new()
		card.name = r["name"]
		card.texture = load("res://assets/textures/" + r["tex"])
		card.custom_minimum_size = Vector2(160, 210)
		card.pivot_offset = Vector2(80, 105)
		cards_hbox.add_child(card)

	# Role Description Comic Box
	var desc_panel = PanelContainer.new()
	desc_panel.name = "DescPanel"
	var desc_sb = StyleBoxFlat.new()
	desc_sb.bg_color = Color(0.08, 0.10, 0.16, 0.95)
	desc_sb.border_color = Color(0.3, 0.8, 1.0, 0.8)
	desc_sb.set_border_width_all(2)
	desc_sb.set_corner_radius_all(10)
	desc_sb.set_content_margin_all(10)
	desc_panel.add_theme_stylebox_override("panel", desc_sb)
	right_vbox.add_child(desc_panel)

	var desc_lbl = Label.new()
	desc_lbl.name = "RoleDescriptionLabel"
	desc_lbl.text = "Hover over or click a drunk crew member to inspect their special perks, drunk level and quirks!"
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_panel.add_child(desc_lbl)

	# --- Status Toast (Popup speech bubble for Create Room) ---
	var toast = PanelContainer.new()
	toast.name = "StatusToast"
	toast.position = Vector2(360, 270)
	toast.custom_minimum_size = Vector2(560, 60)
	toast.pivot_offset = Vector2(280, 30)
	var toast_sb = StyleBoxFlat.new()
	toast_sb.bg_color = Color(0.12, 0.15, 0.24, 0.98)
	toast_sb.border_color = Color(1.0, 0.82, 0.2, 1.0)
	toast_sb.set_border_width_all(4)
	toast_sb.set_corner_radius_all(16)
	toast_sb.set_content_margin_all(12)
	toast.add_theme_stylebox_override("panel", toast_sb)
	toast.visible = false
	root_ctrl.add_child(toast)

	var toast_lbl = Label.new()
	toast_lbl.name = "StatusLabel"
	toast_lbl.text = "⚡ MULTIPLAYER: Room codes & matchmaking are coming soon!"
	toast_lbl.add_theme_font_size_override("font_size", 16)
	toast_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_child(toast_lbl)

	# --- Footer Label ---
	var footer = Label.new()
	footer.name = "FooterLabel"
	footer.text = "★ 18+ • PLEASE DRINK RESPONSIBLY IN REAL LIFE • [WASD] MOVE • [1] SMOKE • [2] DRINK • [E] ENTER VAN ★"
	footer.position = Vector2(0, 686)
	footer.custom_minimum_size = Vector2(1280, 24)
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.8))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_ctrl.add_child(footer)

	set_owner_recursive(root, root)
	var packed = PackedScene.new()
	var pack_err = packed.pack(root)
	print("Pack result: ", pack_err)
	var save_err = ResourceSaver.save(packed, "res://scenes/home_screen.tscn")
	print("Save result: ", save_err)
