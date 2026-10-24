@tool
extends SceneTree

func _init() -> void:
	print("--- Building 18+ Warning Splash Screen Scene (scenes/splash_screen.tscn) ---")
	build_splash_screen()
	print("--- scenes/splash_screen.tscn Built Successfully! ---")
	quit(0)

func set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		set_owner_recursive(child, scene_root)

func build_splash_screen() -> void:
	var root = Control.new()
	root.name = "SplashScreen"
	root.set_script(load("res://scripts/splash_screen.gd"))
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 1. Dark Backdrop
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.08, 1.0)
	root.add_child(bg)

	# 2. Content Center Container
	var center = CenterContainer.new()
	center.name = "ContentBox"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel = PanelContainer.new()
	panel.name = "WarningPanel"
	panel.custom_minimum_size = Vector2(820, 520)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.14, 0.96)
	sb.border_color = Color(0.9, 0.25, 0.28, 0.9)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(24)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Badge (18+ Cartoon Emblem)
	var badge_center = CenterContainer.new()
	vbox.add_child(badge_center)

	var badge = TextureRect.new()
	badge.name = "BadgeRect"
	badge.texture = load("res://assets/textures/ui_badge_18plus.png")
	badge.custom_minimum_size = Vector2(140, 140)
	badge.pivot_offset = Vector2(70, 70)
	badge_center.add_child(badge)

	# Advisory Header
	var advisory_lbl = Label.new()
	advisory_lbl.name = "AdvisoryLabel"
	advisory_lbl.text = "⚠️  CONTENT ADVISORY & RESPONSIBILITY WARNING  ⚠️"
	advisory_lbl.add_theme_font_size_override("font_size", 18)
	advisory_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	advisory_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(advisory_lbl)

	# Main Title
	var main_title = Label.new()
	main_title.name = "MainTitle"
	main_title.text = "PLEASE DRINK RESPONSIBLY"
	main_title.add_theme_font_size_override("font_size", 34)
	main_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	main_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(main_title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Disclaimer description
	var desc = Label.new()
	desc.name = "DisclaimerLabel"
	desc.text = "Stumble Home portrays comedic drunkenness, chain-smoking, and chaotic stumbling solely for slapstick video-game satire.\n\nIn real life, excessive alcohol and tobacco consumption carries severe health risks.\nNever drive or stumble under the influence. Look after your friends and know your limits."
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)

	# Spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Prompt
	var prompt = Label.new()
	prompt.name = "PromptLabel"
	prompt.text = "► Press Any Key or Click Anywhere to Continue ◄"
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

	# 3. Fade overlay for smooth fade-in & fade-out
	var fade = ColorRect.new()
	fade.name = "FadeOverlay"
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

	set_owner_recursive(root, root)
	var packed = PackedScene.new()
	packed.pack(root)
	var err = ResourceSaver.save(packed, "res://scenes/splash_screen.tscn")
	print("Splash screen save result: ", err)
