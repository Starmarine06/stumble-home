@tool
extends SceneTree

func _init() -> void:
	print("--- Starting High World & Scene Builder (Ceaser Exterior Windows, Addiction Coma, Drunk Meter, Enterable Van) ---")
	create_materials()
	create_street_light_scene()
	create_van_scene()
	create_pub_casino_scene()
	create_parking_lot_scene()
	create_player_scene()
	create_main_scene()
	create_home_screen_scene()
	print("--- All Scenes and Resources Built Successfully! ---")
	quit(0)

func set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		set_owner_recursive(child, scene_root)

func create_npc_node(npc_name: String, role: String, dialogues: Array[String], pos: Vector3, rot_y: float, shirt_color: Color, pants_color: Color, hair_color: Color, skin_color: Color = Color(0.88, 0.72, 0.60)) -> CharacterBody3D:
	var npc = CharacterBody3D.new()
	npc.name = "NPC_" + npc_name.replace(" ", "_")
	npc.set_script(load("res://scripts/npc.gd"))
	npc.set("character_name", npc_name)
	npc.set("role_title", role)
	npc.set("dialogues", dialogues)
	npc.add_to_group("npcs")
	npc.position = pos
	npc.rotation.y = rot_y

	# Collision Capsule
	var col = CollisionShape3D.new()
	col.name = "Collision"
	var cap = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	col.shape = cap
	col.position = Vector3(0, 0.88, 0)
	npc.add_child(col)

	# Materials
	var s_mat = StandardMaterial3D.new()
	s_mat.albedo_color = shirt_color
	s_mat.roughness = 0.7

	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = pants_color
	p_mat.roughness = 0.8

	var h_mat = StandardMaterial3D.new()
	h_mat.albedo_color = hair_color
	h_mat.roughness = 0.9

	var sk_mat = StandardMaterial3D.new()
	sk_mat.albedo_color = skin_color
	sk_mat.roughness = 0.55

	var shoe_mat = StandardMaterial3D.new()
	shoe_mat.albedo_color = Color(0.12, 0.12, 0.14)

	var model = Node3D.new()
	model.name = "Model"
	npc.add_child(model)

	# Shoes
	for sx in [-0.15, 0.15]:
		var shoe = MeshInstance3D.new()
		var b_shoe = BoxMesh.new()
		b_shoe.size = Vector3(0.15, 0.12, 0.25)
		b_shoe.material = shoe_mat
		shoe.mesh = b_shoe
		shoe.position = Vector3(sx, 0.06, 0.03)
		model.add_child(shoe)

	# Legs
	for lx in [-0.15, 0.15]:
		var leg = MeshInstance3D.new()
		var cap_l = CapsuleMesh.new()
		cap_l.radius = 0.10
		cap_l.height = 0.72
		cap_l.material = p_mat
		leg.mesh = cap_l
		leg.position = Vector3(lx, 0.44, 0.0)
		model.add_child(leg)

	# Pelvis
	var pelvis = MeshInstance3D.new()
	var b_pelvis = BoxMesh.new()
	b_pelvis.size = Vector3(0.38, 0.20, 0.25)
	b_pelvis.material = p_mat
	pelvis.mesh = b_pelvis
	pelvis.position = Vector3(0, 0.78, 0.0)
	model.add_child(pelvis)

	# Torso / Chest
	var chest = MeshInstance3D.new()
	chest.name = "Chest"
	var b_chest = BoxMesh.new()
	b_chest.size = Vector3(0.42, 0.54, 0.27)
	b_chest.material = s_mat
	chest.mesh = b_chest
	chest.position = Vector3(0, 1.13, 0.0)
	model.add_child(chest)

	# Arms & Hands
	for ax in [-0.27, 0.27]:
		var arm = MeshInstance3D.new()
		var cap_a = CapsuleMesh.new()
		cap_a.radius = 0.08
		cap_a.height = 0.52
		cap_a.material = s_mat
		arm.mesh = cap_a
		arm.position = Vector3(ax, 1.12, 0.02)
		model.add_child(arm)

		var hand = MeshInstance3D.new()
		var sp_h = SphereMesh.new()
		sp_h.radius = 0.065
		sp_h.height = 0.13
		sp_h.material = sk_mat
		hand.mesh = sp_h
		hand.position = Vector3(ax, 0.82, 0.05)
		model.add_child(hand)

	# Head Pivot & Mesh
	var head_node = Node3D.new()
	head_node.name = "Head"
	head_node.position = Vector3(0, 1.45, 0.0)
	model.add_child(head_node)

	var head_m = MeshInstance3D.new()
	var sp_head = SphereMesh.new()
	sp_head.radius = 0.15
	sp_head.height = 0.27
	sp_head.material = sk_mat
	head_m.mesh = sp_head
	head_m.position = Vector3(0, 0.13, 0.0)
	head_node.add_child(head_m)

	# Hair / Cap
	var hair_m = MeshInstance3D.new()
	var sp_hair = SphereMesh.new()
	sp_hair.radius = 0.155
	sp_hair.height = 0.22
	sp_hair.material = h_mat
	hair_m.mesh = sp_hair
	hair_m.position = Vector3(0, 0.21, -0.02)
	head_node.add_child(hair_m)

	# Floating 3D NameTag
	var name_tag = Label3D.new()
	name_tag.name = "NameTag"
	name_tag.text = "[ %s ]\n%s" % [npc_name, role]
	name_tag.font_size = 28
	name_tag.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	name_tag.modulate = Color(1.0, 0.88, 0.45)
	name_tag.outline_modulate = Color(0.1, 0.1, 0.1, 0.95)
	name_tag.outline_size = 6
	name_tag.position = Vector3(0, 2.15, 0)
	npc.add_child(name_tag)

	# Floating 3D SpeechBubble
	var speech = Label3D.new()
	speech.name = "SpeechBubble"
	speech.text = ""
	speech.font_size = 32
	speech.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	speech.modulate = Color(0.3, 0.95, 1.0)
	speech.outline_modulate = Color(0.0, 0.2, 0.3, 0.95)
	speech.outline_size = 6
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD
	speech.width = 340.0
	speech.position = Vector3(0, 2.55, 0)
	speech.visible = false
	npc.add_child(speech)

	return npc

func create_materials() -> void:
	print("Creating materials...")
	
	# Asphalt Material
	var asphalt = StandardMaterial3D.new()
	var asphalt_tex = load("res://assets/textures/asphalt_albedo.png")
	var asphalt_rough = load("res://assets/textures/asphalt_roughness.png")
	if asphalt_tex:
		asphalt.albedo_texture = asphalt_tex
	else:
		asphalt.albedo_color = Color(0.14, 0.14, 0.15)
	if asphalt_rough:
		asphalt.roughness_texture = asphalt_rough
	asphalt.roughness = 0.88
	asphalt.uv1_scale = Vector3(32, 32, 1)
	ResourceSaver.save(asphalt, "res://assets/materials/asphalt_mat.tres")

	# Concrete Curb Material
	var curb = StandardMaterial3D.new()
	var curb_tex = load("res://assets/textures/concrete_albedo.png")
	if curb_tex:
		curb.albedo_texture = curb_tex
	else:
		curb.albedo_color = Color(0.58, 0.58, 0.6)
	curb.roughness = 0.8
	curb.uv1_scale = Vector3(6, 1, 1)
	ResourceSaver.save(curb, "res://assets/materials/curb_mat.tres")

	# Yellow Parking Line Material
	var line_yellow = StandardMaterial3D.new()
	line_yellow.albedo_color = Color(0.98, 0.82, 0.12)
	line_yellow.roughness = 0.4
	ResourceSaver.save(line_yellow, "res://assets/materials/parking_line_yellow.tres")

	# White Parking Line Material
	var line_white = StandardMaterial3D.new()
	line_white.albedo_color = Color(0.94, 0.94, 0.96)
	line_white.roughness = 0.4
	ResourceSaver.save(line_white, "res://assets/materials/parking_line_white.tres")

	# Blue Handicap Stall Material
	var blue_mat = StandardMaterial3D.new()
	blue_mat.albedo_color = Color(0.08, 0.45, 0.92)
	blue_mat.roughness = 0.45
	ResourceSaver.save(blue_mat, "res://assets/materials/parking_blue_mat.tres")

	# Handicap Decal Material
	var hc_mat = StandardMaterial3D.new()
	var hc_tex = load("res://assets/textures/handicap_symbol.png")
	if hc_tex:
		hc_mat.albedo_texture = hc_tex
		hc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		hc_mat.albedo_color = Color(0.1, 0.5, 0.95)
	hc_mat.roughness = 0.5
	ResourceSaver.save(hc_mat, "res://assets/materials/handicap_mat.tres")

	# Road Arrow Material
	var arrow_mat = StandardMaterial3D.new()
	var arrow_tex = load("res://assets/textures/road_arrow.png")
	if arrow_tex:
		arrow_mat.albedo_texture = arrow_tex
		arrow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		arrow_mat.albedo_color = Color(0.9, 0.9, 0.95)
	arrow_mat.roughness = 0.4
	ResourceSaver.save(arrow_mat, "res://assets/materials/road_arrow_mat.tres")

	# Parking Signboard Material
	var sign_mat = StandardMaterial3D.new()
	var sign_tex = load("res://assets/textures/parking_sign.png")
	if sign_tex:
		sign_mat.albedo_texture = sign_tex
	else:
		sign_mat.albedo_color = Color(0.1, 0.3, 0.8)
	sign_mat.roughness = 0.3
	ResourceSaver.save(sign_mat, "res://assets/materials/parking_sign_mat.tres")

	# Casino Wall Material
	var wall = StandardMaterial3D.new()
	var wall_tex = load("res://assets/textures/casino_wall.png")
	if wall_tex:
		wall.albedo_texture = wall_tex
	else:
		wall.albedo_color = Color(0.12, 0.13, 0.16)
	wall.roughness = 0.35
	wall.uv1_scale = Vector3(12, 6, 1)
	ResourceSaver.save(wall, "res://assets/materials/casino_wall_mat.tres")

	# Casino Window Material (Glowing Warm Windows)
	var win = StandardMaterial3D.new()
	var win_tex = load("res://assets/textures/building_windows.png")
	if win_tex:
		win.albedo_texture = win_tex
		win.emission_enabled = true
		win.emission_texture = win_tex
		win.emission_energy_multiplier = 1.6
	else:
		win.albedo_color = Color(0.8, 0.65, 0.3)
	ResourceSaver.save(win, "res://assets/materials/casino_window_mat.tres")

	# Transparent Casino Panoramic Windows Material (Real see-through glass from outside!)
	var c_glass = StandardMaterial3D.new()
	c_glass.albedo_color = Color(0.12, 0.18, 0.25, 0.28)
	c_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	c_glass.roughness = 0.04
	c_glass.metallic = 0.35
	ResourceSaver.save(c_glass, "res://assets/materials/casino_glass_translucent.tres")

	# Gold Trim Material
	var gold = StandardMaterial3D.new()
	gold.albedo_color = Color(0.92, 0.78, 0.28)
	gold.metallic = 0.85
	gold.roughness = 0.25
	ResourceSaver.save(gold, "res://assets/materials/gold_trim_mat.tres")

	# Neon Colors
	var neon_c = StandardMaterial3D.new()
	neon_c.albedo_color = Color(0.1, 0.9, 1.0)
	neon_c.emission_enabled = true
	neon_c.emission = Color(0.1, 0.9, 1.0)
	neon_c.emission_energy_multiplier = 5.0
	ResourceSaver.save(neon_c, "res://assets/materials/neon_cyan.tres")

	var neon_m = StandardMaterial3D.new()
	neon_m.albedo_color = Color(1.0, 0.1, 0.8)
	neon_m.emission_enabled = true
	neon_m.emission = Color(1.0, 0.1, 0.8)
	neon_m.emission_energy_multiplier = 4.5
	ResourceSaver.save(neon_m, "res://assets/materials/neon_magenta.tres")

	var neon_a = StandardMaterial3D.new()
	neon_a.albedo_color = Color(1.0, 0.6, 0.05)
	neon_a.emission_enabled = true
	neon_a.emission = Color(1.0, 0.6, 0.05)
	neon_a.emission_energy_multiplier = 4.0
	ResourceSaver.save(neon_a, "res://assets/materials/neon_amber.tres")

	# Street Light Metal & Glow
	var lamp_metal = StandardMaterial3D.new()
	lamp_metal.albedo_color = Color(0.18, 0.2, 0.22)
	lamp_metal.metallic = 0.85
	lamp_metal.roughness = 0.3
	ResourceSaver.save(lamp_metal, "res://assets/materials/lamp_metal.tres")

	var lamp_glow = StandardMaterial3D.new()
	lamp_glow.albedo_color = Color(1.0, 0.92, 0.75)
	lamp_glow.emission_enabled = true
	lamp_glow.emission = Color(1.0, 0.88, 0.65)
	lamp_glow.emission_energy_multiplier = 6.0
	ResourceSaver.save(lamp_glow, "res://assets/materials/lamp_glow.tres")

	# Moon Material
	var moon = StandardMaterial3D.new()
	moon.albedo_color = Color(0.96, 0.96, 1.0)
	moon.emission_enabled = true
	moon.emission = Color(0.92, 0.94, 1.0)
	moon.emission_energy_multiplier = 3.0
	ResourceSaver.save(moon, "res://assets/materials/moon_mat.tres")

	# ----------------- WHITE & BROWN VAN MATERIALS -----------------
	var van_white = StandardMaterial3D.new()
	van_white.albedo_color = Color(0.93, 0.92, 0.88)
	van_white.metallic = 0.12
	van_white.roughness = 0.32
	ResourceSaver.save(van_white, "res://assets/materials/van_white_mat.tres")

	var van_brown = StandardMaterial3D.new()
	van_brown.albedo_color = Color(0.32, 0.18, 0.10)
	van_brown.metallic = 0.15
	van_brown.roughness = 0.35
	ResourceSaver.save(van_brown, "res://assets/materials/van_brown_mat.tres")

	var van_stripe = StandardMaterial3D.new()
	van_stripe.albedo_color = Color(0.85, 0.62, 0.25)
	van_stripe.metallic = 0.75
	van_stripe.roughness = 0.28
	ResourceSaver.save(van_stripe, "res://assets/materials/van_stripe_mat.tres")

	var van_glass = StandardMaterial3D.new()
	van_glass.albedo_color = Color(0.08, 0.10, 0.12, 0.88)
	van_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	van_glass.roughness = 0.05
	ResourceSaver.save(van_glass, "res://assets/materials/van_glass_mat.tres")

	var van_bumper = StandardMaterial3D.new()
	van_bumper.albedo_color = Color(0.20, 0.16, 0.14)
	van_bumper.roughness = 0.65
	ResourceSaver.save(van_bumper, "res://assets/materials/van_bumper_mat.tres")

	var van_tire = StandardMaterial3D.new()
	van_tire.albedo_color = Color(0.12, 0.12, 0.13)
	van_tire.roughness = 0.85
	ResourceSaver.save(van_tire, "res://assets/materials/van_tire_mat.tres")

	var van_rim = StandardMaterial3D.new()
	van_rim.albedo_color = Color(0.88, 0.88, 0.90)
	van_rim.metallic = 0.92
	van_rim.roughness = 0.20
	ResourceSaver.save(van_rim, "res://assets/materials/van_rim_mat.tres")

	var van_wood = StandardMaterial3D.new()
	van_wood.albedo_color = Color(0.55, 0.35, 0.20)
	van_wood.roughness = 0.75
	ResourceSaver.save(van_wood, "res://assets/materials/van_wood_mat.tres")

	var van_cushion = StandardMaterial3D.new()
	van_cushion.albedo_color = Color(0.78, 0.52, 0.26)
	van_cushion.roughness = 0.80
	ResourceSaver.save(van_cushion, "res://assets/materials/van_cushion_mat.tres")

	var van_hl = StandardMaterial3D.new()
	van_hl.albedo_color = Color(1.0, 0.98, 0.90)
	van_hl.emission_enabled = true
	van_hl.emission = Color(1.0, 0.95, 0.85)
	van_hl.emission_energy_multiplier = 4.5
	ResourceSaver.save(van_hl, "res://assets/materials/van_headlight.tres")

	var van_tl = StandardMaterial3D.new()
	van_tl.albedo_color = Color(0.9, 0.05, 0.05)
	van_tl.emission_enabled = true
	van_tl.emission = Color(0.9, 0.05, 0.05)
	van_tl.emission_energy_multiplier = 3.5
	ResourceSaver.save(van_tl, "res://assets/materials/van_taillight.tres")

	# ----------------- CEASER PUB & CASINO INTERIOR MATERIALS -----------------
	var casino_carpet = StandardMaterial3D.new()
	casino_carpet.albedo_color = Color(0.35, 0.07, 0.11)
	casino_carpet.roughness = 0.90
	ResourceSaver.save(casino_carpet, "res://assets/materials/casino_carpet_mat.tres")

	var pub_wood = StandardMaterial3D.new()
	pub_wood.albedo_color = Color(0.24, 0.12, 0.08)
	pub_wood.roughness = 0.35
	ResourceSaver.save(pub_wood, "res://assets/materials/pub_wood_mat.tres")

	var felt_green = StandardMaterial3D.new()
	felt_green.albedo_color = Color(0.08, 0.42, 0.18)
	felt_green.roughness = 0.88
	ResourceSaver.save(felt_green, "res://assets/materials/casino_felt_green.tres")

	var vip_velvet = StandardMaterial3D.new()
	vip_velvet.albedo_color = Color(0.48, 0.08, 0.12)
	vip_velvet.roughness = 0.65
	ResourceSaver.save(vip_velvet, "res://assets/materials/vip_velvet_mat.tres")

	var slot_metal = StandardMaterial3D.new()
	slot_metal.albedo_color = Color(0.22, 0.24, 0.28)
	slot_metal.metallic = 0.85
	slot_metal.roughness = 0.25
	ResourceSaver.save(slot_metal, "res://assets/materials/slot_metal_mat.tres")

	var slot_screen = StandardMaterial3D.new()
	slot_screen.albedo_color = Color(0.95, 0.85, 0.20)
	slot_screen.emission_enabled = true
	slot_screen.emission = Color(1.0, 0.90, 0.30)
	slot_screen.emission_energy_multiplier = 3.0
	ResourceSaver.save(slot_screen, "res://assets/materials/slot_screen_mat.tres")

	# ----------------- VIEWMODEL MATERIALS -----------------
	var cig_paper = StandardMaterial3D.new()
	cig_paper.albedo_color = Color(0.96, 0.96, 0.94)
	cig_paper.roughness = 0.85
	ResourceSaver.save(cig_paper, "res://assets/materials/cig_paper.tres")

	var cig_filter = StandardMaterial3D.new()
	cig_filter.albedo_color = Color(0.85, 0.58, 0.30)
	cig_filter.roughness = 0.9
	ResourceSaver.save(cig_filter, "res://assets/materials/cig_filter.tres")

	var cig_ember = StandardMaterial3D.new()
	cig_ember.albedo_color = Color(1.0, 0.35, 0.05)
	cig_ember.emission_enabled = true
	cig_ember.emission = Color(1.0, 0.28, 0.02)
	cig_ember.emission_energy_multiplier = 4.0
	ResourceSaver.save(cig_ember, "res://assets/materials/cig_ember.tres")

	var smoke_mat = StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(0.88, 0.88, 0.92, 0.35)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	ResourceSaver.save(smoke_mat, "res://assets/materials/smoke_mat.tres")

	var bottle_glass = StandardMaterial3D.new()
	bottle_glass.albedo_color = Color(0.12, 0.32, 0.16, 0.85)
	bottle_glass.roughness = 0.08
	bottle_glass.metallic = 0.15
	ResourceSaver.save(bottle_glass, "res://assets/materials/bottle_glass.tres")

	var bottle_lbl = StandardMaterial3D.new()
	bottle_lbl.albedo_color = Color(0.94, 0.90, 0.80)
	bottle_lbl.roughness = 0.65
	ResourceSaver.save(bottle_lbl, "res://assets/materials/bottle_label.tres")

	var can_cyan = StandardMaterial3D.new()
	can_cyan.albedo_color = Color(0.05, 0.85, 0.95)
	can_cyan.metallic = 0.88
	can_cyan.roughness = 0.22
	ResourceSaver.save(can_cyan, "res://assets/materials/energy_can_mat.tres")

	var can_alu = StandardMaterial3D.new()
	can_alu.albedo_color = Color(0.92, 0.94, 0.96)
	can_alu.metallic = 0.95
	can_alu.roughness = 0.15
	ResourceSaver.save(can_alu, "res://assets/materials/can_alu_mat.tres")

	# Cigarette Pack Materials
	var pack_red = StandardMaterial3D.new()
	pack_red.albedo_color = Color(0.85, 0.12, 0.12)
	pack_red.roughness = 0.45
	ResourceSaver.save(pack_red, "res://assets/materials/pack_red.tres")

	var pack_white = StandardMaterial3D.new()
	pack_white.albedo_color = Color(0.96, 0.95, 0.92)
	pack_white.roughness = 0.55
	ResourceSaver.save(pack_white, "res://assets/materials/pack_white.tres")

	var pack_foil = StandardMaterial3D.new()
	pack_foil.albedo_color = Color(0.92, 0.85, 0.65)
	pack_foil.metallic = 0.85
	pack_foil.roughness = 0.25
	ResourceSaver.save(pack_foil, "res://assets/materials/pack_foil.tres")

	# Lighter Materials
	var lighter_metal = StandardMaterial3D.new()
	lighter_metal.albedo_color = Color(0.88, 0.82, 0.60)
	lighter_metal.metallic = 0.92
	lighter_metal.roughness = 0.22
	ResourceSaver.save(lighter_metal, "res://assets/materials/lighter_metal.tres")

	var lighter_flame = StandardMaterial3D.new()
	lighter_flame.albedo_color = Color(1.0, 0.72, 0.18)
	lighter_flame.emission_enabled = true
	lighter_flame.emission = Color(1.0, 0.65, 0.1)
	lighter_flame.emission_energy_multiplier = 16.0
	lighter_flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ResourceSaver.save(lighter_flame, "res://assets/materials/lighter_flame.tres")

	# Ash Material
	var cig_ash = StandardMaterial3D.new()
	cig_ash.albedo_color = Color(0.28, 0.28, 0.28)
	cig_ash.roughness = 0.95
	ResourceSaver.save(cig_ash, "res://assets/materials/cig_ash.tres")

func create_street_light_scene() -> void:
	print("Creating Street Light scene...")
	var root = StaticBody3D.new()
	root.name = "StreetLight"

	var metal_mat = load("res://assets/materials/lamp_metal.tres")
	var glow_mat = load("res://assets/materials/lamp_glow.tres")

	var base = MeshInstance3D.new()
	base.name = "Base"
	var cyl_base = CylinderMesh.new()
	cyl_base.top_radius = 0.35
	cyl_base.bottom_radius = 0.45
	cyl_base.height = 0.5
	cyl_base.material = metal_mat
	base.mesh = cyl_base
	base.position = Vector3(0, 0.25, 0)
	root.add_child(base)

	var pole = MeshInstance3D.new()
	pole.name = "Pole"
	var cyl_pole = CylinderMesh.new()
	cyl_pole.top_radius = 0.12
	cyl_pole.bottom_radius = 0.18
	cyl_pole.height = 7.0
	cyl_pole.material = metal_mat
	pole.mesh = cyl_pole
	pole.position = Vector3(0, 3.8, 0)
	root.add_child(pole)

	var arm = MeshInstance3D.new()
	arm.name = "Arm"
	var box_arm = BoxMesh.new()
	box_arm.size = Vector3(0.18, 0.18, 2.4)
	box_arm.material = metal_mat
	arm.mesh = box_arm
	arm.position = Vector3(0, 7.2, -1.0)
	root.add_child(arm)

	var fixture = MeshInstance3D.new()
	fixture.name = "Fixture"
	var box_fix = BoxMesh.new()
	box_fix.size = Vector3(0.5, 0.25, 0.8)
	box_fix.material = metal_mat
	fixture.mesh = box_fix
	fixture.position = Vector3(0, 7.15, -2.0)
	root.add_child(fixture)

	var lamp = MeshInstance3D.new()
	lamp.name = "Lamp"
	var box_lamp = BoxMesh.new()
	box_lamp.size = Vector3(0.42, 0.08, 0.7)
	box_lamp.material = glow_mat
	lamp.mesh = box_lamp
	lamp.position = Vector3(0, 7.02, -2.0)
	root.add_child(lamp)

	var spot = SpotLight3D.new()
	spot.name = "SpotLight"
	spot.position = Vector3(0, 6.95, -2.0)
	spot.rotation.x = deg_to_rad(-90.0)
	spot.light_color = Color(1.0, 0.88, 0.65)
	spot.light_energy = 8.0
	spot.spot_range = 18.0
	spot.spot_angle = 55.0
	spot.shadow_enabled = true
	spot.shadow_bias = 0.05
	root.add_child(spot)

	var omni = OmniLight3D.new()
	omni.name = "FixtureGlow"
	omni.position = Vector3(0, 7.0, -2.0)
	omni.light_color = Color(1.0, 0.88, 0.65)
	omni.light_energy = 2.5
	omni.omni_range = 4.0
	root.add_child(omni)

	var col = CollisionShape3D.new()
	col.name = "PoleCollision"
	var cyl_shape = CylinderShape3D.new()
	cyl_shape.radius = 0.38
	cyl_shape.height = 7.5
	col.shape = cyl_shape
	col.position = Vector3(0, 3.75, 0)
	root.add_child(col)

	set_owner_recursive(root, root)
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/street_light.tscn")

# ----------------- ENTERABLE 100% CUSTOM WHITE & BROWN VAN -----------------

func create_van_scene() -> void:
	print("Creating 100% Custom Enterable White & Brown Van scene...")
	var root = StaticBody3D.new()
	root.name = "ParkedVan"

	var white_mat = load("res://assets/materials/van_white_mat.tres")
	var brown_mat = load("res://assets/materials/van_brown_mat.tres")
	var stripe_mat = load("res://assets/materials/van_stripe_mat.tres")
	var wood_mat = load("res://assets/materials/van_wood_mat.tres")
	var cushion_mat = load("res://assets/materials/van_cushion_mat.tres")
	var glass_mat = load("res://assets/materials/van_glass_mat.tres")
	var bumper_mat = load("res://assets/materials/van_bumper_mat.tres")
	var tire_mat = load("res://assets/materials/van_tire_mat.tres")
	var rim_mat = load("res://assets/materials/van_rim_mat.tres")
	var hl_mat = load("res://assets/materials/van_headlight.tres")
	var tl_mat = load("res://assets/materials/van_taillight.tres")
	var chrome_mat = load("res://assets/materials/gold_trim_mat.tres")

	# --- HOLLOW COLLISION SYSTEM (Allows player to walk straight inside!) ---
	var col_floor = CollisionShape3D.new()
	col_floor.name = "FloorCollision"
	var box_fl = BoxShape3D.new()
	box_fl.size = Vector3(2.15, 0.35, 4.8)
	col_floor.shape = box_fl
	col_floor.position = Vector3(0, 0.175, 0.25)
	root.add_child(col_floor)

	var col_step = CollisionShape3D.new()
	col_step.name = "StepCollision"
	var box_step = BoxShape3D.new()
	box_step.size = Vector3(0.35, 0.18, 1.6)
	col_step.shape = box_step
	col_step.position = Vector3(1.15, 0.09, 0.5)
	root.add_child(col_step)

	var col_left = CollisionShape3D.new()
	col_left.name = "LeftWallCollision"
	var box_lw = BoxShape3D.new()
	box_lw.size = Vector3(0.18, 1.75, 4.8)
	col_left.shape = box_lw
	col_left.position = Vector3(-1.10, 1.22, 0.25)
	root.add_child(col_left)

	var col_rf = CollisionShape3D.new()
	col_rf.name = "RightWallFrontCollision"
	var box_rf = BoxShape3D.new()
	box_rf.size = Vector3(0.18, 1.75, 1.8)
	col_rf.shape = box_rf
	col_rf.position = Vector3(1.10, 1.22, -1.2)
	root.add_child(col_rf)

	var col_rr = CollisionShape3D.new()
	col_rr.name = "RightWallRearCollision"
	var box_rr = BoxShape3D.new()
	box_rr.size = Vector3(0.18, 1.75, 1.3)
	col_rr.shape = box_rr
	col_rr.position = Vector3(1.10, 1.22, 1.95)
	root.add_child(col_rr)

	var col_front = CollisionShape3D.new()
	col_front.name = "FrontCabCollision"
	var box_fc = BoxShape3D.new()
	box_fc.size = Vector3(2.15, 1.4, 0.9)
	col_front.shape = box_fc
	col_front.position = Vector3(0, 1.0, -2.15)
	root.add_child(col_front)

	var col_back = CollisionShape3D.new()
	col_back.name = "RearWallCollision"
	var box_rw = BoxShape3D.new()
	box_rw.size = Vector3(2.15, 1.75, 0.18)
	col_back.shape = box_rw
	col_back.position = Vector3(0, 1.22, 2.65)
	root.add_child(col_back)

	var col_roof = CollisionShape3D.new()
	col_roof.name = "RoofCollision"
	var box_rc = BoxShape3D.new()
	box_rc.size = Vector3(2.15, 0.20, 4.8)
	col_roof.shape = box_rc
	col_roof.position = Vector3(0, 2.20, 0.25)
	root.add_child(col_roof)

	# --- VAN GEOMETRY (WHITE AND BROWN TWO-TONE) ---
	var chassis = MeshInstance3D.new()
	chassis.name = "Chassis"
	var box_ch = BoxMesh.new()
	box_ch.size = Vector3(2.15, 0.28, 5.2)
	box_ch.material = bumper_mat
	chassis.mesh = box_ch
	chassis.position = Vector3(0, 0.20, 0)
	root.add_child(chassis)

	var van_floor = MeshInstance3D.new()
	van_floor.name = "VanFloor"
	var box_vf = BoxMesh.new()
	box_vf.size = Vector3(2.05, 0.08, 4.6)
	box_vf.material = wood_mat
	van_floor.mesh = box_vf
	van_floor.position = Vector3(0, 0.35, 0.25)
	root.add_child(van_floor)

	var step_m = MeshInstance3D.new()
	step_m.name = "EntranceStep"
	var box_sm = BoxMesh.new()
	box_sm.size = Vector3(0.35, 0.14, 1.6)
	box_sm.material = bumper_mat
	step_m.mesh = box_sm
	step_m.position = Vector3(1.15, 0.12, 0.5)
	root.add_child(step_m)

	# Left Wall (Driver side)
	var left_lower = MeshInstance3D.new()
	left_lower.name = "LeftLowerBody"
	var box_ll = BoxMesh.new()
	box_ll.size = Vector3(0.12, 0.85, 4.8)
	box_ll.material = brown_mat
	left_lower.mesh = box_ll
	left_lower.position = Vector3(-1.10, 0.77, 0.25)
	root.add_child(left_lower)

	var left_stripe = MeshInstance3D.new()
	left_stripe.name = "LeftStripe"
	var box_ls = BoxMesh.new()
	box_ls.size = Vector3(0.14, 0.08, 4.8)
	box_ls.material = stripe_mat
	left_stripe.mesh = box_ls
	left_stripe.position = Vector3(-1.10, 1.22, 0.25)
	root.add_child(left_stripe)

	var left_upper = MeshInstance3D.new()
	left_upper.name = "LeftUpperBody"
	var box_lu = BoxMesh.new()
	box_lu.size = Vector3(0.12, 0.85, 4.8)
	box_lu.material = white_mat
	left_upper.mesh = box_lu
	left_upper.position = Vector3(-1.10, 1.68, 0.25)
	root.add_child(left_upper)

	for l_wz in [-0.6, 1.2]:
		var lwin = MeshInstance3D.new()
		var wbox = BoxMesh.new()
		wbox.size = Vector3(0.14, 0.45, 1.0)
		wbox.material = glass_mat
		lwin.mesh = wbox
		lwin.position = Vector3(-1.10, 1.68, l_wz)
		root.add_child(lwin)

	# Right Wall Front Section
	var rf_lower = MeshInstance3D.new()
	var box_rfl = BoxMesh.new()
	box_rfl.size = Vector3(0.12, 0.85, 1.8)
	box_rfl.material = brown_mat
	rf_lower.mesh = box_rfl
	rf_lower.position = Vector3(1.10, 0.77, -1.2)
	root.add_child(rf_lower)

	var rf_stripe = MeshInstance3D.new()
	var box_rfs = BoxMesh.new()
	box_rfs.size = Vector3(0.14, 0.08, 1.8)
	box_rfs.material = stripe_mat
	rf_stripe.mesh = box_rfs
	rf_stripe.position = Vector3(1.10, 1.22, -1.2)
	root.add_child(rf_stripe)

	var rf_upper = MeshInstance3D.new()
	var box_rfu = BoxMesh.new()
	box_rfu.size = Vector3(0.12, 0.85, 1.8)
	box_rfu.material = white_mat
	rf_upper.mesh = box_rfu
	rf_upper.position = Vector3(1.10, 1.68, -1.2)
	root.add_child(rf_upper)

	var rf_win = MeshInstance3D.new()
	var box_rfw = BoxMesh.new()
	box_rfw.size = Vector3(0.14, 0.45, 0.9)
	box_rfw.material = glass_mat
	rf_win.mesh = box_rfw
	rf_win.position = Vector3(1.10, 1.68, -1.2)
	root.add_child(rf_win)

	# Right Wall Rear Section
	var rr_lower = MeshInstance3D.new()
	var box_rrl = BoxMesh.new()
	box_rrl.size = Vector3(0.12, 0.85, 1.3)
	box_rrl.material = brown_mat
	rr_lower.mesh = box_rrl
	rr_lower.position = Vector3(1.10, 0.77, 1.95)
	root.add_child(rr_lower)

	var rr_stripe = MeshInstance3D.new()
	var box_rrs = BoxMesh.new()
	box_rrs.size = Vector3(0.14, 0.08, 1.3)
	box_rrs.material = stripe_mat
	rr_stripe.mesh = box_rrs
	rr_stripe.position = Vector3(1.10, 1.22, 1.95)
	root.add_child(rr_stripe)

	var rr_upper = MeshInstance3D.new()
	var box_rru = BoxMesh.new()
	box_rru.size = Vector3(0.12, 0.85, 1.3)
	box_rru.material = white_mat
	rr_upper.mesh = box_rru
	rr_upper.position = Vector3(1.10, 1.68, 1.95)
	root.add_child(rr_upper)

	# Open Sliding Door Panel (Slid open!)
	var slide_door = MeshInstance3D.new()
	slide_door.name = "SlidingDoorOpen"
	var box_sd = BoxMesh.new()
	box_sd.size = Vector3(0.08, 1.65, 1.55)
	box_sd.material = brown_mat
	slide_door.mesh = box_sd
	slide_door.position = Vector3(1.20, 1.20, 1.85)
	root.add_child(slide_door)

	var sd_upper = MeshInstance3D.new()
	var box_sdu = BoxMesh.new()
	box_sdu.size = Vector3(0.09, 0.75, 1.55)
	box_sdu.material = white_mat
	sd_upper.mesh = box_sdu
	sd_upper.position = Vector3(1.20, 1.65, 1.85)
	root.add_child(sd_upper)

	var sd_handle = MeshInstance3D.new()
	var box_sdh = BoxMesh.new()
	box_sdh.size = Vector3(0.05, 0.12, 0.04)
	box_sdh.material = chrome_mat
	sd_handle.mesh = box_sdh
	sd_handle.position = Vector3(1.26, 1.15, 1.20)
	root.add_child(sd_handle)

	# Roof & Roof Rack
	var roof = MeshInstance3D.new()
	roof.name = "HighTopRoof"
	var box_roof = BoxMesh.new()
	box_roof.size = Vector3(2.18, 0.25, 5.1)
	box_roof.material = white_mat
	roof.mesh = box_roof
	roof.position = Vector3(0, 2.15, 0.25)
	root.add_child(roof)

	for rail_x in [-0.85, 0.85]:
		var rail = MeshInstance3D.new()
		var rbox = BoxMesh.new()
		rbox.size = Vector3(0.06, 0.08, 4.4)
		rbox.material = bumper_mat
		rail.mesh = rbox
		rail.position = Vector3(rail_x, 2.32, 0.25)
		root.add_child(rail)

	for cb_z in [-1.0, 0.2, 1.4]:
		var cbar = MeshInstance3D.new()
		var cbbox = BoxMesh.new()
		cbbox.size = Vector3(1.76, 0.05, 0.06)
		cbbox.material = bumper_mat
		cbar.mesh = cbbox
		cbar.position = Vector3(0, 2.35, cb_z)
		root.add_child(cbar)

	# Front Cab Hood & Windshield
	var hood = MeshInstance3D.new()
	hood.name = "CabHood"
	var box_hood = BoxMesh.new()
	box_hood.size = Vector3(2.20, 0.52, 1.35)
	box_hood.material = white_mat
	hood.mesh = box_hood
	hood.position = Vector3(0, 0.88, -2.18)
	root.add_child(hood)

	var ws = MeshInstance3D.new()
	ws.name = "Windshield"
	var box_ws = BoxMesh.new()
	box_ws.size = Vector3(2.05, 0.85, 0.08)
	box_ws.material = glass_mat
	ws.mesh = box_ws
	ws.position = Vector3(0, 1.50, -1.48)
	ws.rotation.x = deg_to_rad(-28.0)
	root.add_child(ws)

	var front_bumper = MeshInstance3D.new()
	front_bumper.name = "FrontBumper"
	var box_fb = BoxMesh.new()
	box_fb.size = Vector3(2.28, 0.45, 0.35)
	box_fb.material = brown_mat
	front_bumper.mesh = box_fb
	front_bumper.position = Vector3(0, 0.45, -2.85)
	root.add_child(front_bumper)

	for hl_x in [-0.75, 0.75]:
		var hl = MeshInstance3D.new()
		var cyl_hl = CylinderMesh.new()
		cyl_hl.top_radius = 0.16
		cyl_hl.bottom_radius = 0.16
		cyl_hl.height = 0.08
		cyl_hl.material = hl_mat
		hl.mesh = cyl_hl
		hl.rotation.x = deg_to_rad(90.0)
		hl.position = Vector3(hl_x, 0.75, -2.86)
		root.add_child(hl)

		var hl_spot = SpotLight3D.new()
		hl_spot.position = Vector3(hl_x, 0.75, -2.90)
		hl_spot.rotation.x = deg_to_rad(175.0)
		hl_spot.light_color = Color(1.0, 0.95, 0.85)
		hl_spot.light_energy = 5.0
		hl_spot.spot_range = 24.0
		hl_spot.spot_angle = 35.0
		hl_spot.shadow_enabled = true
		root.add_child(hl_spot)

	# Rear Doors in White & Brown
	var rear_lower = MeshInstance3D.new()
	var box_rl = BoxMesh.new()
	box_rl.size = Vector3(2.15, 0.85, 0.12)
	box_rl.material = brown_mat
	rear_lower.mesh = box_rl
	rear_lower.position = Vector3(0, 0.77, 2.65)
	root.add_child(rear_lower)

	var rear_upper = MeshInstance3D.new()
	var box_ru = BoxMesh.new()
	box_ru.size = Vector3(2.15, 0.85, 0.12)
	box_ru.material = white_mat
	rear_upper.mesh = box_ru
	rear_upper.position = Vector3(0, 1.68, 2.65)
	root.add_child(rear_upper)

	var rear_bumper = MeshInstance3D.new()
	var box_rb = BoxMesh.new()
	box_rb.size = Vector3(2.28, 0.40, 0.35)
	box_rb.material = brown_mat
	rear_bumper.mesh = box_rb
	rear_bumper.position = Vector3(0, 0.45, 2.82)
	root.add_child(rear_bumper)

	for tl_x in [-0.95, 0.95]:
		var tl = MeshInstance3D.new()
		var box_tl = BoxMesh.new()
		box_tl.size = Vector3(0.12, 0.45, 0.05)
		box_tl.material = tl_mat
		tl.mesh = box_tl
		tl.position = Vector3(tl_x, 1.15, 2.72)
		root.add_child(tl)

	for lp_side in [-1, 1]:
		var plate = Label3D.new()
		plate.text = "VAN-777"
		plate.font_size = 28
		plate.outline_size = 6
		plate.position = Vector3(0, 0.38, lp_side * 2.88)
		if lp_side == 1:
			plate.rotation.y = deg_to_rad(180.0)
		root.add_child(plate)

	# Wheels
	var wheel_positions = [
		Vector3(-1.12, 0.38, -1.6),
		Vector3(1.12,  0.38, -1.6),
		Vector3(-1.12, 0.38,  1.6),
		Vector3(1.12,  0.38,  1.6)
	]
	for idx in range(wheel_positions.size()):
		var w_root = Node3D.new()
		w_root.position = wheel_positions[idx]
		root.add_child(w_root)

		var tire = MeshInstance3D.new()
		var cyl_tire = CylinderMesh.new()
		cyl_tire.top_radius = 0.38
		cyl_tire.bottom_radius = 0.38
		cyl_tire.height = 0.24
		cyl_tire.material = tire_mat
		tire.mesh = cyl_tire
		tire.rotation.z = deg_to_rad(90.0)
		w_root.add_child(tire)

		var rim = MeshInstance3D.new()
		var cyl_rim = CylinderMesh.new()
		cyl_rim.top_radius = 0.24
		cyl_rim.bottom_radius = 0.24
		cyl_rim.height = 0.25
		cyl_rim.material = rim_mat
		rim.mesh = cyl_rim
		rim.rotation.z = deg_to_rad(90.0)
		w_root.add_child(rim)

	# --- VAN INTERIOR ---
	for sx in [-0.55, 0.55]:
		var seat = MeshInstance3D.new()
		var s_box = BoxMesh.new()
		s_box.size = Vector3(0.50, 0.45, 0.50)
		s_box.material = brown_mat
		seat.mesh = s_box
		seat.position = Vector3(sx, 0.60, -1.2)
		root.add_child(seat)

		var backrest = MeshInstance3D.new()
		var br_box = BoxMesh.new()
		br_box.size = Vector3(0.48, 0.60, 0.12)
		br_box.material = brown_mat
		backrest.mesh = br_box
		backrest.position = Vector3(sx, 0.95, -0.98)
		root.add_child(backrest)

	var dash = MeshInstance3D.new()
	var dbox = BoxMesh.new()
	dbox.size = Vector3(1.90, 0.45, 0.40)
	dbox.material = brown_mat
	dash.mesh = dbox
	dash.position = Vector3(0, 0.90, -1.65)
	root.add_child(dash)

	var swheel = MeshInstance3D.new()
	var sw_cyl = CylinderMesh.new()
	sw_cyl.top_radius = 0.20
	sw_cyl.bottom_radius = 0.20
	sw_cyl.height = 0.04
	sw_cyl.material = bumper_mat
	swheel.mesh = sw_cyl
	swheel.position = Vector3(-0.55, 1.05, -1.45)
	swheel.rotation.x = deg_to_rad(45.0)
	root.add_child(swheel)

	var mattress = MeshInstance3D.new()
	mattress.name = "LoungeMattress"
	var m_box = BoxMesh.new()
	m_box.size = Vector3(1.95, 0.22, 1.40)
	m_box.material = cushion_mat
	mattress.mesh = m_box
	mattress.position = Vector3(0, 0.46, 1.85)
	root.add_child(mattress)

	for px in [-0.55, 0.55]:
		var pillow = MeshInstance3D.new()
		var p_box = BoxMesh.new()
		p_box.size = Vector3(0.35, 0.14, 0.35)
		var pil_mat = StandardMaterial3D.new()
		pil_mat.albedo_color = Color(0.92, 0.85, 0.70)
		pillow.mesh = p_box
		pillow.material_override = pil_mat
		pillow.position = Vector3(px, 0.62, 2.30)
		pillow.rotation.x = deg_to_rad(-20.0)
		root.add_child(pillow)

	var cab = MeshInstance3D.new()
	var c_box = BoxMesh.new()
	c_box.size = Vector3(0.40, 0.50, 0.60)
	c_box.material = wood_mat
	cab.mesh = c_box
	cab.position = Vector3(-0.85, 0.62, 0.45)
	root.add_child(cab)

	var dome_light = OmniLight3D.new()
	dome_light.name = "InteriorDomeLight"
	dome_light.position = Vector3(0, 2.05, 0.50)
	dome_light.light_color = Color(1.0, 0.88, 0.68)
	dome_light.light_energy = 2.4
	dome_light.omni_range = 4.2
	root.add_child(dome_light)

	# --- 4 CAR PART SLOTS (FOR REPAIR & BALANCE MECHANICS) ---
	# Slot 0: Battery (Front Hood Engine Bay)
	var slot_bat = Node3D.new()
	slot_bat.name = "Slot_Battery"
	slot_bat.position = Vector3(0.4, 0.9, -2.1)
	root.add_child(slot_bat)

	var ghost_bat = MeshInstance3D.new()
	ghost_bat.name = "Ghost"
	var bm0 = BoxMesh.new()
	bm0.size = Vector3(0.5, 0.35, 0.35)
	ghost_bat.mesh = bm0
	var ghost_m0 = StandardMaterial3D.new()
	ghost_m0.albedo_color = Color(0.9, 0.2, 0.2, 0.35)
	ghost_m0.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_m0.emission_enabled = true
	ghost_m0.emission = Color(0.9, 0.2, 0.2)
	ghost_m0.emission_energy_multiplier = 0.5
	ghost_bat.material_override = ghost_m0
	slot_bat.add_child(ghost_bat)

	var inst_bat = MeshInstance3D.new()
	inst_bat.name = "Installed"
	inst_bat.mesh = bm0
	var real_m0 = StandardMaterial3D.new()
	real_m0.albedo_color = Color(0.85, 0.15, 0.15)
	real_m0.roughness = 0.4
	inst_bat.material_override = real_m0
	inst_bat.visible = false
	slot_bat.add_child(inst_bat)

	# Slot 1: Fuel Pump (Side Rear Left)
	var slot_fuel = Node3D.new()
	slot_fuel.name = "Slot_FuelPump"
	slot_fuel.position = Vector3(-1.15, 0.8, 1.8)
	root.add_child(slot_fuel)

	var ghost_fuel = MeshInstance3D.new()
	ghost_fuel.name = "Ghost"
	var cm_f = CylinderMesh.new()
	cm_f.top_radius = 0.18
	cm_f.bottom_radius = 0.18
	cm_f.height = 0.5
	ghost_fuel.mesh = cm_f
	var ghost_m1 = StandardMaterial3D.new()
	ghost_m1.albedo_color = Color(0.9, 0.75, 0.2, 0.35)
	ghost_m1.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_m1.emission_enabled = true
	ghost_m1.emission = Color(0.9, 0.75, 0.2)
	ghost_fuel.material_override = ghost_m1
	slot_fuel.add_child(ghost_fuel)

	var inst_fuel = MeshInstance3D.new()
	inst_fuel.name = "Installed"
	inst_fuel.mesh = cm_f
	var real_m1 = StandardMaterial3D.new()
	real_m1.albedo_color = Color(0.95, 0.75, 0.2)
	inst_fuel.material_override = real_m1
	inst_fuel.visible = false
	slot_fuel.add_child(inst_fuel)

	# Slot 2: Spark Plugs (Front Hood Engine Bay)
	var slot_plugs = Node3D.new()
	slot_plugs.name = "Slot_SparkPlugs"
	slot_plugs.position = Vector3(-0.4, 0.9, -2.1)
	root.add_child(slot_plugs)

	var ghost_plugs = MeshInstance3D.new()
	ghost_plugs.name = "Ghost"
	var bm_p = BoxMesh.new()
	bm_p.size = Vector3(0.3, 0.25, 0.3)
	ghost_plugs.mesh = bm_p
	var ghost_m2 = StandardMaterial3D.new()
	ghost_m2.albedo_color = Color(0.3, 0.9, 0.9, 0.35)
	ghost_m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_m2.emission_enabled = true
	ghost_m2.emission = Color(0.3, 0.9, 0.9)
	ghost_plugs.material_override = ghost_m2
	slot_plugs.add_child(ghost_plugs)

	var inst_plugs = MeshInstance3D.new()
	inst_plugs.name = "Installed"
	inst_plugs.mesh = bm_p
	var real_m2 = StandardMaterial3D.new()
	real_m2.albedo_color = Color(0.2, 0.85, 0.85)
	inst_plugs.material_override = real_m2
	inst_plugs.visible = false
	slot_plugs.add_child(inst_plugs)

	# Slot 3: Spare Tyre (Mounted on Rear Van Door)
	var slot_tyre = Node3D.new()
	slot_tyre.name = "Slot_SpareTyre"
	slot_tyre.position = Vector3(0.0, 1.1, 2.72)
	root.add_child(slot_tyre)

	var ghost_tyre = MeshInstance3D.new()
	ghost_tyre.name = "Ghost"
	var tm = TorusMesh.new()
	tm.inner_radius = 0.20
	tm.outer_radius = 0.44
	ghost_tyre.mesh = tm
	ghost_tyre.rotation.x = deg_to_rad(90.0)
	var ghost_m3 = StandardMaterial3D.new()
	ghost_m3.albedo_color = Color(0.6, 0.6, 0.6, 0.35)
	ghost_m3.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_m3.emission_enabled = true
	ghost_m3.emission = Color(0.6, 0.6, 0.6)
	ghost_tyre.material_override = ghost_m3
	slot_tyre.add_child(ghost_tyre)

	var inst_tyre = MeshInstance3D.new()
	inst_tyre.name = "Installed"
	inst_tyre.mesh = tm
	inst_tyre.rotation.x = deg_to_rad(90.0)
	inst_tyre.material_override = load("res://assets/materials/van_tire_mat.tres")
	inst_tyre.visible = false
	slot_tyre.add_child(inst_tyre)

	set_owner_recursive(root, root)
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/van.tscn")

# ----------------- ENTERABLE CEASER PUB & CASINO (WITH REAL WINDOWS & LIGHTS) -----------------

func create_pub_casino_scene() -> void:
	print("Creating Ceaser Pub & Casino with Transparent Windows & Interior Lights visible from outside...")
	var root = StaticBody3D.new()
	root.name = "PubCasinoBuilding"

	var wall_mat = load("res://assets/materials/casino_wall_mat.tres")
	var gold_mat = load("res://assets/materials/gold_trim_mat.tres")
	var curb_mat = load("res://assets/materials/curb_mat.tres")
	var carpet_mat = load("res://assets/materials/casino_carpet_mat.tres")
	var pub_wood = load("res://assets/materials/pub_wood_mat.tres")
	var felt_green = load("res://assets/materials/casino_felt_green.tres")
	var velvet_mat = load("res://assets/materials/vip_velvet_mat.tres")
	var slot_mat = load("res://assets/materials/slot_metal_mat.tres")
	var screen_mat = load("res://assets/materials/slot_screen_mat.tres")
	var c_glass = load("res://assets/materials/casino_glass_translucent.tres")

	# --- EXTERIOR ROOF & NEON SIGNAGE ---
	var roof_crown = MeshInstance3D.new()
	roof_crown.name = "RoofCrown"
	var box_crown = BoxMesh.new()
	box_crown.size = Vector3(65.0, 1.4, 29.0)
	box_crown.material = gold_mat
	roof_crown.mesh = box_crown
	roof_crown.position = Vector3(0, 24.7, 0)
	root.add_child(roof_crown)

	var pediment = MeshInstance3D.new()
	pediment.name = "RooftopPediment"
	var box_ped = BoxMesh.new()
	box_ped.size = Vector3(28.0, 4.5, 2.5)
	box_ped.material = wall_mat
	pediment.mesh = box_ped
	pediment.position = Vector3(0, 27.2, 13.0)
	root.add_child(pediment)

	var ped_frame = MeshInstance3D.new()
	ped_frame.name = "PedimentGoldTrim"
	var box_frame = BoxMesh.new()
	box_frame.size = Vector3(28.4, 0.45, 2.7)
	box_frame.material = gold_mat
	ped_frame.mesh = box_frame
	ped_frame.position = Vector3(0, 29.5, 13.0)
	root.add_child(ped_frame)

	# Rooftop Neon: "ceaser"
	var sign_ceaser = Label3D.new()
	sign_ceaser.name = "NeonCeaserRooftop"
	sign_ceaser.text = "ceaser"
	sign_ceaser.font_size = 230
	sign_ceaser.modulate = Color(0.15, 0.95, 1.0, 1.0)
	sign_ceaser.outline_modulate = Color(0.0, 0.5, 0.9, 1.0)
	sign_ceaser.outline_size = 28
	sign_ceaser.position = Vector3(0, 27.2, 14.4)
	root.add_child(sign_ceaser)

	var ceaser_omni = OmniLight3D.new()
	ceaser_omni.name = "CeaserNeonLight"
	ceaser_omni.position = Vector3(0, 27.2, 15.0)
	ceaser_omni.light_color = Color(0.1, 0.9, 1.0)
	ceaser_omni.light_energy = 6.0
	ceaser_omni.omni_range = 18.0
	root.add_child(ceaser_omni)

	# Entrance Canopy & Marquee "ceaser"
	var canopy = MeshInstance3D.new()
	canopy.name = "EntranceCanopy"
	var box_canopy = BoxMesh.new()
	box_canopy.size = Vector3(24.0, 1.0, 7.5)
	box_canopy.material = wall_mat
	canopy.mesh = box_canopy
	canopy.position = Vector3(0, 6.5, 17.5)
	root.add_child(canopy)

	var canopy_trim = MeshInstance3D.new()
	canopy_trim.name = "CanopyTrim"
	var box_ctrim = BoxMesh.new()
	box_ctrim.size = Vector3(24.4, 0.3, 7.7)
	box_ctrim.material = gold_mat
	canopy_trim.mesh = box_ctrim
	canopy_trim.position = Vector3(0, 6.9, 17.5)
	root.add_child(canopy_trim)

	var marquee_box = MeshInstance3D.new()
	var box_mb = BoxMesh.new()
	box_mb.size = Vector3(18.0, 2.0, 0.3)
	box_mb.material = wall_mat
	marquee_box.mesh = box_mb
	marquee_box.position = Vector3(0, 7.8, 21.2)
	root.add_child(marquee_box)

	var marquee_text = Label3D.new()
	marquee_text.name = "NeonCeaserMarquee"
	marquee_text.text = "ceaser"
	marquee_text.font_size = 170
	marquee_text.modulate = Color(1.0, 0.65, 0.1, 1.0)
	marquee_text.outline_modulate = Color(1.0, 0.2, 0.0, 1.0)
	marquee_text.outline_size = 24
	marquee_text.position = Vector3(0, 7.8, 21.4)
	root.add_child(marquee_text)

	var marquee_light = OmniLight3D.new()
	marquee_light.position = Vector3(0, 7.8, 22.0)
	marquee_light.light_color = Color(1.0, 0.55, 0.1)
	marquee_light.light_energy = 5.0
	marquee_light.omni_range = 14.0
	root.add_child(marquee_light)

	# Columns & Canopy Lights
	var column_positions = [
		Vector3(-10.5, 3.5, 20.8),
		Vector3(-6.3, 3.5, 20.8),
		Vector3(-2.1, 3.5, 20.8),
		Vector3(2.1, 3.5, 20.8),
		Vector3(6.3, 3.5, 20.8),
		Vector3(10.5, 3.5, 20.8)
	]
	for idx in range(column_positions.size()):
		var col_mesh = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.42
		cyl.bottom_radius = 0.46
		cyl.height = 5.8
		cyl.material = gold_mat
		col_mesh.mesh = cyl
		col_mesh.position = column_positions[idx]
		root.add_child(col_mesh)

	for lx in [-7.0, 0.0, 7.0]:
		var dl = SpotLight3D.new()
		dl.position = Vector3(lx, 6.0, 17.5)
		dl.rotation.x = deg_to_rad(-90.0)
		dl.light_color = Color(1.0, 0.88, 0.65)
		dl.light_energy = 5.5
		dl.spot_range = 10.0
		dl.spot_angle = 65.0
		root.add_child(dl)

	# Porch & Smooth Entrance Ramp
	var porch = MeshInstance3D.new()
	porch.name = "PorchPlatform"
	var box_porch = BoxMesh.new()
	box_porch.size = Vector3(24.0, 0.8, 6.0)
	box_porch.material = curb_mat
	porch.mesh = box_porch
	porch.position = Vector3(0, 0.4, 16.5)
	root.add_child(porch)

	var porch_col = CollisionShape3D.new()
	var box_pcol = BoxShape3D.new()
	box_pcol.size = Vector3(24.0, 0.8, 5.7)
	porch_col.shape = box_pcol
	porch_col.position = Vector3(0, 0.4, 16.35)
	root.add_child(porch_col)

	# Smooth Entrance Collision Ramp (Allows walking smoothly up into the casino without jumping!)
	var ramp_col = CollisionShape3D.new()
	ramp_col.name = "EntranceRampCollision"
	var box_ramp = BoxShape3D.new()
	box_ramp.size = Vector3(26.0, 0.20, 2.45)
	ramp_col.shape = box_ramp
	ramp_col.position = Vector3(0, 0.30, 20.35)
	ramp_col.rotation.x = deg_to_rad(19.2)
	root.add_child(ramp_col)

	for step_idx in range(2):
		var step = MeshInstance3D.new()
		var step_box = BoxMesh.new()
		step_box.size = Vector3(25.0 + step_idx * 1.0, 0.25, 1.2)
		step_box.material = curb_mat
		step.mesh = step_box
		step.position = Vector3(0, 0.125 + step_idx * 0.25, 19.8 + (1 - step_idx) * 0.8)
		root.add_child(step)

	# Open Double Doors & Velvet Ropes
	var door_left = MeshInstance3D.new()
	var b_dl = BoxMesh.new()
	b_dl.size = Vector3(0.18, 4.2, 2.2)
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.28, 0.14, 0.08)
	door_mat.roughness = 0.4
	door_left.mesh = b_dl
	door_left.material_override = door_mat
	door_left.position = Vector3(-2.8, 2.9, 12.8)
	root.add_child(door_left)

	var door_right = MeshInstance3D.new()
	var b_dr = BoxMesh.new()
	b_dr.size = Vector3(0.18, 4.2, 2.2)
	door_right.mesh = b_dr
	door_right.material_override = door_mat
	door_right.position = Vector3(2.8, 2.9, 12.8)
	root.add_child(door_right)

	for r_side in [-3.2, 3.2]:
		var stanch = MeshInstance3D.new()
		var cyl_s = CylinderMesh.new()
		cyl_s.top_radius = 0.05
		cyl_s.bottom_radius = 0.15
		cyl_s.height = 1.0
		cyl_s.material = gold_mat
		stanch.mesh = cyl_s
		stanch.position = Vector3(r_side, 1.3, 14.8)
		root.add_child(stanch)

	var entrance_light = OmniLight3D.new()
	entrance_light.name = "EntranceFoyerGlow"
	entrance_light.position = Vector3(0, 4.0, 13.5)
	entrance_light.light_color = Color(1.0, 0.85, 0.55)
	entrance_light.light_energy = 5.0
	entrance_light.omni_range = 9.0
	root.add_child(entrance_light)

	# --- REAL TRANSPARENT PANORAMIC FRONT WINDOWS (VISIBLE FROM OUTSIDE!) ---
	# 1. Lower Wall Curbs under Windows
	for wx in [-16.5, 16.5]:
		var base_curb = MeshInstance3D.new()
		var b_curb = BoxMesh.new()
		b_curb.size = Vector3(25.0, 0.8, 0.8)
		b_curb.material = wall_mat
		base_curb.mesh = b_curb
		base_curb.position = Vector3(wx, 1.2, 13.6)
		root.add_child(base_curb)

		var c_bcol = CollisionShape3D.new()
		var box_cb = BoxShape3D.new()
		box_cb.size = Vector3(25.0, 0.8, 0.8)
		c_bcol.shape = box_cb
		c_bcol.position = Vector3(wx, 1.2, 13.6)
		root.add_child(c_bcol)

	# 2. Upper Lintel Beams above Windows
	for wx in [-16.5, 16.5]:
		var lintel = MeshInstance3D.new()
		var b_lin = BoxMesh.new()
		b_lin.size = Vector3(25.0, 1.4, 0.8)
		b_lin.material = wall_mat
		lintel.mesh = b_lin
		lintel.position = Vector3(wx, 7.3, 13.6)
		root.add_child(lintel)

		var c_lcol = CollisionShape3D.new()
		var box_cl = BoxShape3D.new()
		box_cl.size = Vector3(25.0, 1.4, 0.8)
		c_lcol.shape = box_cl
		c_lcol.position = Vector3(wx, 7.3, 13.6)
		root.add_child(c_lcol)

	# 3. Outer Corner Pillars & Entrance Flanking Pillars
	var pillar_coords = [-29.5, -3.2, 3.2, 29.5]
	for px in pillar_coords:
		var pil = MeshInstance3D.new()
		var b_pil = BoxMesh.new()
		b_pil.size = Vector3(1.4, 7.5, 0.8)
		b_pil.material = wall_mat
		pil.mesh = b_pil
		pil.position = Vector3(px, 4.55, 13.6)
		root.add_child(pil)

		var c_pil = CollisionShape3D.new()
		var box_cp = BoxShape3D.new()
		box_cp.size = Vector3(1.4, 7.5, 0.8)
		c_pil.shape = box_cp
		c_pil.position = Vector3(px, 4.55, 13.6)
		root.add_child(c_pil)

	# 4. HUGE CRYSTAL CLEAR PANORAMIC GLASS WINDOWS!
	# Left Panoramic Window (Shows Slot Machines & Lucky Lou inside!)
	var win_left = MeshInstance3D.new()
	win_left.name = "PanoramicWindowLeft"
	var b_wl = BoxMesh.new()
	b_wl.size = Vector3(24.5, 4.8, 0.12)
	b_wl.material = c_glass
	win_left.mesh = b_wl
	win_left.position = Vector3(-16.3, 4.2, 13.6)
	root.add_child(win_left)

	var col_wl = CollisionShape3D.new()
	var b_cwl = BoxShape3D.new()
	b_cwl.size = Vector3(24.5, 4.8, 0.12)
	col_wl.shape = b_cwl
	col_wl.position = Vector3(-16.3, 4.2, 13.6)
	root.add_child(col_wl)

	# Right Panoramic Window (Shows Blackjack Table, Elena & Vincent inside!)
	var win_right = MeshInstance3D.new()
	win_right.name = "PanoramicWindowRight"
	var b_wr = BoxMesh.new()
	b_wr.size = Vector3(24.5, 4.8, 0.12)
	b_wr.material = c_glass
	win_right.mesh = b_wr
	win_right.position = Vector3(16.3, 4.2, 13.6)
	root.add_child(win_right)

	var col_wr = CollisionShape3D.new()
	var b_cwr = BoxShape3D.new()
	b_cwr.size = Vector3(24.5, 4.8, 0.12)
	col_wr.shape = b_cwr
	col_wr.position = Vector3(16.3, 4.2, 13.6)
	root.add_child(col_wr)

	# Gold Window Mullions / Grid Bars
	for wx in [-16.3, 16.3]:
		for mx in [-8.0, 0.0, 8.0]:
			var mullion = MeshInstance3D.new()
			var b_m = BoxMesh.new()
			b_m.size = Vector3(0.12, 4.8, 0.16)
			b_m.material = gold_mat
			mullion.mesh = b_m
			mullion.position = Vector3(wx + mx, 4.2, 13.6)
			root.add_child(mullion)

	# 5. POWERFUL INTERIOR WINDOW SPOTLIGHTS (Shining out onto the porch and parking lot!)
	for wx in [-16.0, 16.0]:
		var win_spot = SpotLight3D.new()
		win_spot.name = "WindowSpot_%s" % ("L" if wx < 0 else "R")
		win_spot.position = Vector3(wx, 5.8, 12.0)
		win_spot.rotation.x = deg_to_rad(15.0) # Shining forward and slightly down through glass!
		win_spot.light_color = Color(1.0, 0.88, 0.65)
		win_spot.light_energy = 8.0
		win_spot.spot_range = 28.0
		win_spot.spot_angle = 55.0
		win_spot.shadow_enabled = true
		root.add_child(win_spot)

	# Doorway Lintel / Header (Y = 5.0 to 8.0 over the center entrance door)
	var door_header = MeshInstance3D.new()
	var b_dh = BoxMesh.new()
	b_dh.size = Vector3(6.0, 3.2, 0.8)
	b_dh.material = wall_mat
	door_header.mesh = b_dh
	door_header.position = Vector3(0, 6.6, 13.6)
	root.add_child(door_header)

	var col_dhead = CollisionShape3D.new()
	var b_cdh = BoxShape3D.new()
	b_cdh.size = Vector3(6.0, 3.2, 0.8)
	col_dhead.shape = b_cdh
	col_dhead.position = Vector3(0, 6.6, 13.6)
	root.add_child(col_dhead)

	# Interior Floor & Ceiling
	var int_floor = MeshInstance3D.new()
	int_floor.name = "InteriorCarpetFloor"
	var b_if = BoxMesh.new()
	b_if.size = Vector3(60.0, 0.8, 26.0)
	b_if.material = carpet_mat
	int_floor.mesh = b_if
	int_floor.position = Vector3(0, 0.4, 0.5)
	root.add_child(int_floor)

	var col_ifloor = CollisionShape3D.new()
	var box_cif = BoxShape3D.new()
	box_cif.size = Vector3(60.0, 0.8, 26.0)
	col_ifloor.shape = box_cif
	col_ifloor.position = Vector3(0, 0.4, 0.5)
	root.add_child(col_ifloor)

	var int_ceiling = MeshInstance3D.new()
	var b_ic = BoxMesh.new()
	b_ic.size = Vector3(60.0, 0.6, 26.0)
	b_ic.material = pub_wood
	int_ceiling.mesh = b_ic
	int_ceiling.position = Vector3(0, 8.2, 0.5)
	root.add_child(int_ceiling)

	var col_iceil = CollisionShape3D.new()
	var box_cic = BoxShape3D.new()
	box_cic.size = Vector3(60.0, 0.6, 26.0)
	col_iceil.shape = box_cic
	col_iceil.position = Vector3(0, 8.2, 0.5)
	root.add_child(col_iceil)

	# Back & Side Walls
	var back_wall = MeshInstance3D.new()
	var b_bw = BoxMesh.new()
	b_bw.size = Vector3(62.0, 7.5, 0.8)
	b_bw.material = wall_mat
	back_wall.mesh = b_bw
	back_wall.position = Vector3(0, 4.55, -12.5)
	root.add_child(back_wall)

	var col_bwall = CollisionShape3D.new()
	var b_cbw = BoxShape3D.new()
	b_cbw.size = Vector3(62.0, 7.5, 0.8)
	col_bwall.shape = b_cbw
	col_bwall.position = Vector3(0, 4.55, -12.5)
	root.add_child(col_bwall)

	for wx in [-30.0, 30.0]:
		var side_w = MeshInstance3D.new()
		var b_sw = BoxMesh.new()
		b_sw.size = Vector3(0.8, 7.5, 27.0)
		side_w.mesh = b_sw
		side_w.material_override = wall_mat
		side_w.position = Vector3(wx, 4.55, 0.5)
		root.add_child(side_w)

		var col_sw = CollisionShape3D.new()
		var b_csw = BoxShape3D.new()
		b_csw.size = Vector3(0.8, 7.5, 27.0)
		col_sw.shape = b_csw
		col_sw.position = Vector3(wx, 4.55, 0.5)
		root.add_child(col_sw)

	var upper_facade = MeshInstance3D.new()
	upper_facade.name = "UpperFacade"
	var b_uf = BoxMesh.new()
	b_uf.size = Vector3(64.0, 16.5, 28.0)
	b_uf.material = wall_mat
	upper_facade.mesh = b_uf
	upper_facade.position = Vector3(0, 16.5, 0)
	root.add_child(upper_facade)

	# Interior Chandeliers
	var chandelier_coords = [
		Vector3(-14.0, 7.2, 4.0),
		Vector3(0.0,   7.2, 4.0),
		Vector3(14.0,  7.2, 4.0),
		Vector3(-14.0, 7.2, -4.0),
		Vector3(0.0,   7.2, -4.0),
		Vector3(14.0,  7.2, -4.0)
	]
	for c_idx in range(chandelier_coords.size()):
		var ch_pos = chandelier_coords[c_idx]
		var fixture_m = MeshInstance3D.new()
		var cyl_ch = CylinderMesh.new()
		cyl_ch.top_radius = 0.8
		cyl_ch.bottom_radius = 0.4
		cyl_ch.height = 0.6
		cyl_ch.material = gold_mat
		fixture_m.mesh = cyl_ch
		fixture_m.position = ch_pos
		root.add_child(fixture_m)

		var ch_light = OmniLight3D.new()
		ch_light.position = ch_pos + Vector3(0, -0.4, 0)
		ch_light.light_color = Color(1.0, 0.84, 0.60)
		ch_light.light_energy = 3.6
		ch_light.omni_range = 15.0
		root.add_child(ch_light)

	# Central Pub Bar
	var bar_front = MeshInstance3D.new()
	var b_bf = BoxMesh.new()
	b_bf.size = Vector3(14.0, 1.15, 1.2)
	bar_front.mesh = b_bf
	bar_front.material_override = pub_wood
	bar_front.position = Vector3(0, 1.38, 2.5)
	root.add_child(bar_front)

	var col_bar = CollisionShape3D.new()
	var b_cb = BoxShape3D.new()
	b_cb.size = Vector3(14.0, 1.15, 1.2)
	col_bar.shape = b_cb
	col_bar.position = Vector3(0, 1.38, 2.5)
	root.add_child(col_bar)

	var backbar = MeshInstance3D.new()
	var b_bb = BoxMesh.new()
	b_bb.size = Vector3(14.0, 3.8, 0.8)
	backbar.mesh = b_bb
	backbar.material_override = pub_wood
	backbar.position = Vector3(0, 2.7, -0.8)
	root.add_child(backbar)

	var bottle_colors = [Color(0.85, 0.55, 0.1), Color(0.12, 0.45, 0.18), Color(0.85, 0.1, 0.15)]
	for b_shelf in [1.8, 2.6, 3.4]:
		for bx in range(-5, 6):
			var b_mesh = MeshInstance3D.new()
			var cyl_bot = CylinderMesh.new()
			cyl_bot.top_radius = 0.04
			cyl_bot.bottom_radius = 0.05
			cyl_bot.height = 0.28
			var bmat = StandardMaterial3D.new()
			bmat.albedo_color = bottle_colors[abs(bx + int(b_shelf * 10)) % 3]
			bmat.roughness = 0.1
			bmat.metallic = 0.2
			b_mesh.mesh = cyl_bot
			b_mesh.material_override = bmat
			b_mesh.position = Vector3(bx * 0.9 + 0.1, b_shelf, -0.3)
			root.add_child(b_mesh)

	for sx in range(-5, 6):
		var stool = MeshInstance3D.new()
		var cyl_seat = CylinderMesh.new()
		cyl_seat.top_radius = 0.28
		cyl_seat.bottom_radius = 0.28
		cyl_seat.height = 0.08
		stool.mesh = cyl_seat
		stool.material_override = velvet_mat
		stool.position = Vector3(sx * 1.1, 1.25, 3.8)
		root.add_child(stool)

		var st_leg = MeshInstance3D.new()
		var cyl_leg = CylinderMesh.new()
		cyl_leg.top_radius = 0.04
		cyl_leg.bottom_radius = 0.14
		cyl_leg.height = 0.75
		st_leg.mesh = cyl_leg
		st_leg.material_override = gold_mat
		st_leg.position = Vector3(0, -0.42, 0)
		stool.add_child(st_leg)

	# Casino Tables
	var bj_table = MeshInstance3D.new()
	var cyl_bj = CylinderMesh.new()
	cyl_bj.top_radius = 1.9
	cyl_bj.bottom_radius = 1.9
	cyl_bj.height = 0.95
	bj_table.mesh = cyl_bj
	bj_table.material_override = felt_green
	bj_table.position = Vector3(18.0, 1.28, 2.0)
	root.add_child(bj_table)

	var col_bj = CollisionShape3D.new()
	var cyl_cbj = CylinderShape3D.new()
	cyl_cbj.radius = 1.9
	cyl_cbj.height = 0.95
	col_bj.shape = cyl_cbj
	col_bj.position = Vector3(18.0, 1.28, 2.0)
	root.add_child(col_bj)

	var pk_table = MeshInstance3D.new()
	var box_pk = BoxMesh.new()
	box_pk.size = Vector3(3.8, 0.95, 2.4)
	pk_table.mesh = box_pk
	pk_table.material_override = felt_green
	pk_table.position = Vector3(18.0, 1.28, -6.0)
	root.add_child(pk_table)

	var col_pk = CollisionShape3D.new()
	var box_cpk = BoxShape3D.new()
	box_cpk.size = Vector3(3.8, 0.95, 2.4)
	col_pk.shape = box_cpk
	col_pk.position = Vector3(18.0, 1.28, -6.0)
	root.add_child(col_pk)

	# 3D Real-Life Roulette Table at Z = -2.0 (World Z = -34.0)
	var roulette_table_script = load("res://scripts/minigames/roulette_table_3d.gd")
	var roulette_table = Node3D.new()
	roulette_table.set_script(roulette_table_script)
	roulette_table.name = "RouletteTable3D"
	roulette_table.position = Vector3(18.0, 0.8, -2.0)
	root.add_child(roulette_table)

	# 3D Croupier NPC Antoine standing behind the Roulette Table
	var antoine = create_npc_node(
		"Antoine", "VIP Roulette Croupier",
		[
			"Mesdames et Messieurs, welcome to the VIP European Roulette table at Ceaser!",
			"Place your bets on Red, Black, Dozens, or your lucky single number!",
			"Hit your bet to double or 36x your cash and win the Camper Van Spare Tyre!",
			"Rien ne va plus! No more bets once the ivory ball is launched!"
		],
		Vector3(18.0, 0.8, -1.25), deg_to_rad(180.0),
		Color(0.88, 0.88, 0.92), Color(0.12, 0.12, 0.15), Color(0.45, 0.15, 0.18)
	)
	antoine.name = "NPC_Antoine"
	antoine.set_meta("is_roulette_npc", true)
	root.add_child(antoine)

	# Slot Machines
	var slot_titles = ["777", "JACKPOT", "CHERRY", "BAR"]
	for s_idx in range(4):
		var sm = MeshInstance3D.new()
		var box_sm = BoxMesh.new()
		box_sm.size = Vector3(1.2, 2.4, 0.9)
		sm.mesh = box_sm
		sm.material_override = slot_mat
		sm.position = Vector3(-18.0, 2.0, 4.0 - s_idx * 2.8)
		sm.rotation.y = deg_to_rad(90.0)
		root.add_child(sm)

		var s_col = CollisionShape3D.new()
		var box_sc = BoxShape3D.new()
		box_sc.size = Vector3(1.2, 2.4, 0.9)
		s_col.shape = box_sc
		s_col.position = sm.position
		s_col.rotation.y = sm.rotation.y
		root.add_child(s_col)

		var sc_mesh = MeshInstance3D.new()
		var box_screen = BoxMesh.new()
		box_screen.size = Vector3(0.85, 0.70, 0.05)
		sc_mesh.mesh = box_screen
		sc_mesh.material_override = screen_mat
		sc_mesh.position = Vector3(0, 0.20, 0.46)
		sm.add_child(sc_mesh)

		var s_label = Label3D.new()
		s_label.text = slot_titles[s_idx]
		s_label.font_size = 42
		s_label.modulate = Color(1.0, 0.9, 0.2)
		s_label.outline_size = 8
		s_label.position = Vector3(0, 0.95, 0.46)
		sm.add_child(s_label)

	# VIP Lounge
	var sofa = MeshInstance3D.new()
	var b_sofa = BoxMesh.new()
	b_sofa.size = Vector3(7.0, 0.75, 1.8)
	sofa.mesh = b_sofa
	sofa.material_override = velvet_mat
	sofa.position = Vector3(-15.0, 1.18, -10.5)
	root.add_child(sofa)

	var s_table = MeshInstance3D.new()
	var b_st = BoxMesh.new()
	b_st.size = Vector3(4.0, 0.45, 1.2)
	s_table.mesh = b_st
	s_table.material_override = pub_wood
	s_table.position = Vector3(-15.0, 1.05, -8.6)
	root.add_child(s_table)

	# Ceaser NPCs
	var boris = create_npc_node(
		"Boris", "Head Bouncer",
		[
			"Welcome to ceaser. Keep your hands clean and your conduct orderly.",
			"Doors are open 24/7. Head on in—bar is straight ahead, tables to the right, slots to the left.",
			"Look at that vibrant glass facade—you can see the whole action from right out here on the porch!"
		],
		Vector3(3.6, 0.8, 15.2), deg_to_rad(180.0),
		Color(0.12, 0.12, 0.14), Color(0.10, 0.10, 0.12), Color(0.18, 0.15, 0.12)
	)
	root.add_child(boris)

	var marcus = create_npc_node(
		"Marcus", "Bartender",
		[
			"Welcome to ceaser! What can I get started for you tonight?",
			"Careful with that craft brew—one bottle inverts your motor skills, and if you drink too much, even your mouse goes opposite!",
			"Keep your buzz up with drinks or smokes, or you'll fall asleep and slip into a coma!",
			"If your controls get crazy, grab an energy can with [3] to sober up instantly."
		],
		Vector3(0.0, 0.8, 0.6), deg_to_rad(0.0),
		Color(0.92, 0.92, 0.95), Color(0.15, 0.15, 0.18), Color(0.35, 0.22, 0.14)
	)
	root.add_child(marcus)

	var elena = create_npc_node(
		"Elena", "Casino Dealer",
		[
			"Welcome to the high-limit blackjack table at ceaser! Place your bets.",
			"Dealer stands on all 17s. Blackjack pays 3 to 2!",
			"The panoramic windows look stunning from out in the parking lot tonight!"
		],
		Vector3(18.0, 0.8, 0.6), deg_to_rad(0.0),
		Color(0.85, 0.15, 0.22), Color(0.12, 0.12, 0.14), Color(0.85, 0.75, 0.40)
	)
	root.add_child(elena)

	var vincent = create_npc_node(
		"Vincent", "High Roller",
		[
			"Another winning hand! I'm up ten grand tonight at ceaser!",
			"Never split tens, and always double down on eleven!",
			"ceaser is the only place in town with this kind of electricity."
		],
		Vector3(19.5, 0.8, -5.5), deg_to_rad(-90.0),
		Color(0.18, 0.24, 0.38), Color(0.20, 0.20, 0.22), Color(0.15, 0.15, 0.15)
	)
	root.add_child(vincent)

	var lou = create_npc_node(
		"Lucky Lou", "Slot Fanatic",
		[
			"Just one more pull! I can feel the jackpot coming on this machine!",
			"Triple sevens pay out 10,000 to one! I'm not leaving until the sirens go off."
		],
		Vector3(-16.8, 0.8, 1.2), deg_to_rad(-90.0),
		Color(0.92, 0.55, 0.15), Color(0.25, 0.35, 0.55), Color(0.45, 0.45, 0.48)
	)
	root.add_child(lou)

	var chloe = create_npc_node(
		"Chloe", "VIP Patron",
		[
			"The ambiance here in ceaser is just gorgeous tonight, isn't it?",
			"Check out the white and brown van outside! You can step right inside with [E] and sit in the driver's seat."
		],
		Vector3(-14.5, 0.8, -10.0), deg_to_rad(20.0),
		Color(0.15, 0.75, 0.75), Color(0.12, 0.60, 0.60), Color(0.65, 0.25, 0.15)
	)
	root.add_child(chloe)

	# Barney "Bullseye" Briggs - Darts Bookie & Master
	var barney = create_npc_node(
		"Barney", "Darts Bookie",
		[
			"Fancy your aim with the arrows, mate? Step up to the board!",
			"Put down a stake with [E]. Score 50+ points and you'll walk away with multiplied cash AND the Camper Van Battery!",
			"Keep your elbow steady—that Ceaser craft brew gives a wicked wobble to your throwing arm!"
		],
		Vector3(14.0, 0.8, -10.6), deg_to_rad(140.0),
		Color(0.25, 0.45, 0.22), Color(0.18, 0.15, 0.12), Color(0.85, 0.75, 0.35)
	)
	barney.name = "NPC_Barney"
	barney.set_meta("is_darts_npc", true)
	root.add_child(barney)

	# 3D Dartboard on the Interior Back Wall inside Ceaser Casino
	# Back wall front surface is at Z = -12.10, floor surface is at Y = 0.80
	var dartboard_script = load("res://scripts/minigames/dart_board_3d.gd")
	var dartboard_node = Node3D.new()
	dartboard_node.set_script(dartboard_script)
	dartboard_node.name = "DartBoard3D"
	dartboard_node.position = Vector3(12.0, 2.25, -12.05)
	dartboard_node.setup_dartboard()
	root.add_child(dartboard_node)

	# Permanent Baked Throw Line (Oche) on Casino Floor (2.4m in front of Dartboard)
	var oche_line = MeshInstance3D.new()
	oche_line.name = "ThrowLineOche"
	var box_oche = BoxMesh.new()
	box_oche.size = Vector3(1.8, 0.05, 0.16)
	oche_line.mesh = box_oche
	var oche_mat = StandardMaterial3D.new()
	oche_mat.albedo_color = Color(0.95, 0.78, 0.22)
	oche_mat.metallic = 0.85
	oche_mat.roughness = 0.25
	oche_mat.emission_enabled = true
	oche_mat.emission = Color(0.95, 0.78, 0.22)
	oche_mat.emission_energy_multiplier = 0.4
	oche_line.material_override = oche_mat
	oche_line.position = Vector3(12.0, 0.825, -9.65)
	root.add_child(oche_line)

	var oche_lbl = Label3D.new()
	oche_lbl.name = "ThrowLineLabel"
	oche_lbl.text = "►► THROW LINE (OCHE) — STAND BEHIND ◄◄"
	oche_lbl.font_size = 32
	oche_lbl.modulate = Color(1.0, 0.88, 0.25)
	oche_lbl.outline_size = 6
	oche_lbl.outline_modulate = Color(0.1, 0.1, 0.1)
	oche_lbl.rotation.x = deg_to_rad(-90.0)
	oche_lbl.position = Vector3(12.0, 0.81, -9.35)
	root.add_child(oche_lbl)

	# Small Pub Table for Darts & Prizes next to Barney
	var d_table = MeshInstance3D.new()
	var box_dt = BoxMesh.new()
	box_dt.size = Vector3(1.2, 0.85, 1.2)
	d_table.mesh = box_dt
	d_table.material_override = pub_wood
	d_table.position = Vector3(14.2, 0.825, -11.2)
	root.add_child(d_table)

	var col_dt = CollisionShape3D.new()
	var box_cdt = BoxShape3D.new()
	box_cdt.size = Vector3(1.2, 0.85, 1.2)
	col_dt.shape = box_cdt
	col_dt.position = d_table.position
	root.add_child(col_dt)

	set_owner_recursive(root, root)
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/pub_casino.tscn")

# ----------------- PARKING LOT SCENE -----------------

func create_parking_lot_scene() -> void:
	print("Creating Detailed Parking Lot scene...")
	var root = StaticBody3D.new()
	root.name = "ParkingLot"

	var asphalt_mat = load("res://assets/materials/asphalt_mat.tres")
	var curb_mat = load("res://assets/materials/curb_mat.tres")
	var yellow_mat = load("res://assets/materials/parking_line_yellow.tres")
	var white_mat = load("res://assets/materials/parking_line_white.tres")
	var sign_mat = load("res://assets/materials/parking_sign_mat.tres")
	var metal_mat = load("res://assets/materials/lamp_metal.tres")

	# Asphalt Foundation
	var foundation = MeshInstance3D.new()
	var box_asph = BoxMesh.new()
	box_asph.size = Vector3(80.0, 1.0, 70.0)
	box_asph.material = asphalt_mat
	foundation.mesh = box_asph
	foundation.position = Vector3(0, -0.5, 8.0)
	root.add_child(foundation)

	var col_f = CollisionShape3D.new()
	var box_col = BoxShape3D.new()
	box_col.size = Vector3(80.0, 1.0, 70.0)
	col_f.shape = box_col
	col_f.position = Vector3(0, -0.5, 8.0)
	root.add_child(col_f)

	# Raised Perimeter Sidewalks
	var curbs_config = [
		{"name": "Sidewalk_West",  "size": Vector3(3.0, 0.35, 70.0), "pos": Vector3(-27.5, 0.175, 8.0)},
		{"name": "Sidewalk_East",  "size": Vector3(3.0, 0.35, 70.0), "pos": Vector3(27.5, 0.175, 8.0)},
		{"name": "Sidewalk_South", "size": Vector3(58.0, 0.35, 3.0), "pos": Vector3(0.0, 0.175, 35.0)}
	]
	for cfg in curbs_config:
		var curb_m = MeshInstance3D.new()
		var cbox = BoxMesh.new()
		cbox.size = cfg["size"]
		cbox.material = curb_mat
		curb_m.mesh = cbox
		curb_m.position = cfg["pos"]
		root.add_child(curb_m)

		var c_col = CollisionShape3D.new()
		var c_box = BoxShape3D.new()
		c_box.size = cfg["size"]
		c_col.shape = c_box
		c_col.position = cfg["pos"]
		root.add_child(c_col)

	# Parking Bays
	var stall_z_coords = [-10.0, -6.0, -2.0, 2.0, 6.0, 10.0, 14.0]
	for z in stall_z_coords:
		var w_line = MeshInstance3D.new()
		var l_box = BoxMesh.new()
		l_box.size = Vector3(5.5, 0.02, 0.14)
		l_box.material = yellow_mat
		w_line.mesh = l_box
		w_line.position = Vector3(-16.0, 0.01, z)
		root.add_child(w_line)

		var e_line = MeshInstance3D.new()
		e_line.mesh = l_box
		e_line.material_override = yellow_mat
		e_line.position = Vector3(16.0, 0.01, z)
		root.add_child(e_line)

		for side_x in [-19.5, 19.5]:
			var ws = MeshInstance3D.new()
			var wsb = BoxMesh.new()
			wsb.size = Vector3(0.28, 0.16, 2.0)
			wsb.material = curb_mat
			ws.mesh = wsb
			ws.position = Vector3(side_x, 0.08, z)
			root.add_child(ws)

			var ws_col = CollisionShape3D.new()
			var ws_cbox = BoxShape3D.new()
			ws_cbox.size = Vector3(0.28, 0.16, 2.0)
			ws_col.shape = ws_cbox
			ws_col.position = Vector3(side_x, 0.08, z)
			root.add_child(ws_col)

	var cl_mesh = MeshInstance3D.new()
	var cl_box = BoxMesh.new()
	cl_box.size = Vector3(0.14, 0.02, 44.0)
	cl_box.material = white_mat
	cl_mesh.mesh = cl_box
	cl_mesh.position = Vector3(0, 0.01, 8.0)
	root.add_child(cl_mesh)

	for c_idx in range(-6, 7):
		var cw = MeshInstance3D.new()
		var cw_box = BoxMesh.new()
		cw_box.size = Vector3(0.55, 0.02, 3.2)
		cw_box.material = white_mat
		cw.mesh = cw_box
		cw.position = Vector3(c_idx * 1.0, 0.015, -13.0)
		root.add_child(cw)

	for sign_side in [-1, 1]:
		var post = MeshInstance3D.new()
		var cyl_p = CylinderMesh.new()
		cyl_p.top_radius = 0.06
		cyl_p.bottom_radius = 0.08
		cyl_p.height = 2.8
		cyl_p.material = metal_mat
		post.mesh = cyl_p
		post.position = Vector3(sign_side * 7.5, 1.4, 30.0)
		root.add_child(post)

		var board = MeshInstance3D.new()
		var bbox = BoxMesh.new()
		bbox.size = Vector3(1.3, 1.3, 0.06)
		bbox.material = sign_mat
		board.mesh = bbox
		board.position = Vector3(0, 1.1, 0)
		post.add_child(board)

		var lbl = Label3D.new()
		lbl.text = "🅿️ ceaser\nPARKING"
		lbl.font_size = 38
		lbl.modulate = Color(1.0, 0.95, 0.3)
		lbl.outline_size = 8
		lbl.position = Vector3(0, 1.1, 0.04)
		post.add_child(lbl)

	var sl_scene = load("res://scenes/street_light.tscn")
	var street_light_configs = [
		{"pos": Vector3(-24.5, 0.25, -5.0), "rot_y": deg_to_rad(-90.0)},
		{"pos": Vector3(-24.5, 0.25, 8.0),  "rot_y": deg_to_rad(-90.0)},
		{"pos": Vector3(-24.5, 0.25, 21.0), "rot_y": deg_to_rad(-90.0)},
		{"pos": Vector3(24.5, 0.25, -5.0),  "rot_y": deg_to_rad(90.0)},
		{"pos": Vector3(24.5, 0.25, 8.0),   "rot_y": deg_to_rad(90.0)},
		{"pos": Vector3(24.5, 0.25, 21.0),  "rot_y": deg_to_rad(90.0)}
	]
	for i in range(street_light_configs.size()):
		var sl = sl_scene.instantiate()
		sl.name = "StreetLight_%d" % i
		sl.position = street_light_configs[i]["pos"]
		sl.rotation.y = street_light_configs[i]["rot_y"]
		root.add_child(sl)

	set_owner_recursive(root, root)
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/parking_lot.tscn")

# ----------------- PLAYER SCENE (VIEWMODELS, METERS HUD & COMA UI) -----------------

func create_player_scene() -> void:
	print("Creating Player scene with ViewModels, Meters HUD & Coma UI...")
	var player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(load("res://scripts/player.gd"))

	# Collision
	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	col.shape = capsule
	col.position = Vector3(0, 0.9, 0)
	player.add_child(col)

	# Head & Camera
	var head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.65, 0)
	player.add_child(head)

	var camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 75.0
	camera.current = true
	head.add_child(camera)

	var fl = SpotLight3D.new()
	fl.name = "Flashlight"
	fl.light_color = Color(1.0, 0.98, 0.92)
	fl.light_energy = 3.5
	fl.spot_range = 28.0
	fl.spot_angle = 38.0
	fl.shadow_enabled = true
	camera.add_child(fl)

	# Viewmodels Root
	var vm_root = Node3D.new()
	vm_root.name = "ViewModels"
	camera.add_child(vm_root)

	# Carried Car Part Viewmodels
	var carried_root = Node3D.new()
	carried_root.name = "CarriedPart"
	carried_root.visible = false
	vm_root.add_child(carried_root)

	# 0: Battery
	var c_bat = MeshInstance3D.new()
	c_bat.name = "Mesh_0_Battery"
	var c_bm0 = BoxMesh.new()
	c_bm0.size = Vector3(0.55, 0.38, 0.35)
	c_bat.mesh = c_bm0
	var c_m0 = StandardMaterial3D.new()
	c_m0.albedo_color = Color(0.9, 0.2, 0.2)
	c_m0.roughness = 0.4
	c_bat.material_override = c_m0
	carried_root.add_child(c_bat)

	# 1: Fuel Pump
	var c_fuel = MeshInstance3D.new()
	c_fuel.name = "Mesh_1_FuelPump"
	var c_cm1 = CylinderMesh.new()
	c_cm1.top_radius = 0.16
	c_cm1.bottom_radius = 0.16
	c_cm1.height = 0.55
	c_fuel.mesh = c_cm1
	var c_m1 = StandardMaterial3D.new()
	c_m1.albedo_color = Color(0.95, 0.75, 0.2)
	c_fuel.material_override = c_m1
	c_fuel.visible = false
	carried_root.add_child(c_fuel)

	# 2: Spark Plugs
	var c_plugs = MeshInstance3D.new()
	c_plugs.name = "Mesh_2_SparkPlugs"
	var c_cm2 = CylinderMesh.new()
	c_cm2.top_radius = 0.08
	c_cm2.bottom_radius = 0.08
	c_cm2.height = 0.45
	c_plugs.mesh = c_cm2
	var c_m2 = StandardMaterial3D.new()
	c_m2.albedo_color = Color(0.2, 0.85, 0.85)
	c_plugs.material_override = c_m2
	c_plugs.visible = false
	carried_root.add_child(c_plugs)

	# 3: Spare Tyre
	var c_tyre = MeshInstance3D.new()
	c_tyre.name = "Mesh_3_SpareTyre"
	var c_tm3 = TorusMesh.new()
	c_tm3.inner_radius = 0.18
	c_tm3.outer_radius = 0.42
	c_tyre.mesh = c_tm3
	c_tyre.material_override = load("res://assets/materials/van_tire_mat.tres")
	c_tyre.visible = false
	carried_root.add_child(c_tyre)

	# Materials for Smoking viewmodels
	var cig_paper_mat = load("res://assets/materials/cig_paper.tres")
	var cig_filter_mat = load("res://assets/materials/cig_filter.tres")
	var cig_ember_mat = load("res://assets/materials/cig_ember.tres")
	var smoke_mat = load("res://assets/materials/smoke_mat.tres")
	var pack_red_mat = load("res://assets/materials/pack_red.tres")
	var pack_white_mat = load("res://assets/materials/pack_white.tres")
	var pack_foil_mat = load("res://assets/materials/pack_foil.tres")
	var lighter_metal_mat = load("res://assets/materials/lighter_metal.tres")
	var lighter_flame_mat = load("res://assets/materials/lighter_flame.tres")
	var cig_ash_mat = load("res://assets/materials/cig_ash.tres")
	var gold_trim_mat = load("res://assets/materials/gold_trim_mat.tres")

	# --- 1A. CIGARETTE PACK VIEWMODEL ---
	var cig_pack = Node3D.new()
	cig_pack.name = "CigarettePack"
	cig_pack.position = Vector3(-0.30, -0.55, -0.35)
	cig_pack.rotation = Vector3(deg_to_rad(15.0), deg_to_rad(25.0), deg_to_rad(-8.0))
	cig_pack.visible = false
	vm_root.add_child(cig_pack)

	# Red Cardboard Box Base
	var pack_base = MeshInstance3D.new()
	var b_pbase = BoxMesh.new()
	b_pbase.size = Vector3(0.056, 0.072, 0.024)
	b_pbase.material = pack_red_mat
	pack_base.mesh = b_pbase
	pack_base.position = Vector3(0, -0.012, 0)
	cig_pack.add_child(pack_base)

	# White Label Chevron on Front
	var pack_lbl = MeshInstance3D.new()
	var b_plbl = BoxMesh.new()
	b_plbl.size = Vector3(0.0562, 0.034, 0.001)
	b_plbl.material = pack_white_mat
	pack_lbl.mesh = b_plbl
	pack_lbl.position = Vector3(0, -0.008, -0.0121)
	cig_pack.add_child(pack_lbl)

	# Gold Crest Stripe
	var pack_stripe = MeshInstance3D.new()
	var b_pstr = BoxMesh.new()
	b_pstr.size = Vector3(0.0564, 0.006, 0.001)
	b_pstr.material = gold_trim_mat
	pack_stripe.mesh = b_pstr
	pack_stripe.position = Vector3(0, 0.012, -0.0122)
	cig_pack.add_child(pack_stripe)

	# Gold Foil Inner Collar
	var pack_foil_mesh = MeshInstance3D.new()
	var b_pfoil = BoxMesh.new()
	b_pfoil.size = Vector3(0.052, 0.014, 0.020)
	b_pfoil.material = pack_foil_mat
	pack_foil_mesh.mesh = b_pfoil
	pack_foil_mesh.position = Vector3(0, 0.028, 0)
	cig_pack.add_child(pack_foil_mesh)

	# Stationary Filter Tips inside pack
	for fx in [-0.015, 0.015]:
		var filter_peek = MeshInstance3D.new()
		var cyl_fp = CylinderMesh.new()
		cyl_fp.top_radius = 0.0062
		cyl_fp.bottom_radius = 0.0062
		cyl_fp.height = 0.022
		cyl_fp.material = cig_filter_mat
		filter_peek.mesh = cyl_fp
		filter_peek.rotation.x = deg_to_rad(90.0)
		filter_peek.position = Vector3(fx, 0.036, 0)
		cig_pack.add_child(filter_peek)

	# Extracted Cigarette (Slides out when pack opens)
	var ext_cig = Node3D.new()
	ext_cig.name = "ExtractedCig"
	ext_cig.position = Vector3(0, 0.035, 0)
	cig_pack.add_child(ext_cig)

	var ext_filter = MeshInstance3D.new()
	var cyl_ef = CylinderMesh.new()
	cyl_ef.top_radius = 0.0064
	cyl_ef.bottom_radius = 0.0064
	cyl_ef.height = 0.024
	cyl_ef.material = cig_filter_mat
	ext_filter.mesh = cyl_ef
	ext_filter.rotation.x = deg_to_rad(90.0)
	ext_cig.add_child(ext_filter)

	var ext_paper = MeshInstance3D.new()
	var cyl_ep = CylinderMesh.new()
	cyl_ep.top_radius = 0.0063
	cyl_ep.bottom_radius = 0.0063
	cyl_ep.height = 0.065
	cyl_ep.material = cig_paper_mat
	ext_paper.mesh = cyl_ep
	ext_paper.rotation.x = deg_to_rad(90.0)
	ext_paper.position = Vector3(0, 0, -0.044)
	ext_cig.add_child(ext_paper)

	# Hinged Pack Lid
	var pack_lid = Node3D.new()
	pack_lid.name = "PackLid"
	pack_lid.position = Vector3(0, 0.025, 0.012)
	cig_pack.add_child(pack_lid)

	var lid_mesh = MeshInstance3D.new()
	var b_lid = BoxMesh.new()
	b_lid.size = Vector3(0.0564, 0.026, 0.0244)
	b_lid.material = pack_red_mat
	lid_mesh.mesh = b_lid
	lid_mesh.position = Vector3(0, 0.013, -0.012)
	pack_lid.add_child(lid_mesh)

	# --- 1B. LIGHTER VIEWMODEL ---
	var lighter = Node3D.new()
	lighter.name = "Lighter"
	lighter.position = Vector3(0.32, -0.55, -0.30)
	lighter.rotation = Vector3(deg_to_rad(10.0), deg_to_rad(-20.0), deg_to_rad(5.0))
	lighter.visible = false
	vm_root.add_child(lighter)

	# Metallic Lower Casing
	var l_body = MeshInstance3D.new()
	var b_lbody = BoxMesh.new()
	b_lbody.size = Vector3(0.036, 0.052, 0.015)
	b_lbody.material = lighter_metal_mat
	l_body.mesh = b_lbody
	l_body.position = Vector3(0, -0.005, 0)
	lighter.add_child(l_body)

	# Chimney / Windguard
	var l_chimney = MeshInstance3D.new()
	var b_lchim = BoxMesh.new()
	b_lchim.size = Vector3(0.022, 0.018, 0.012)
	b_lchim.material = lighter_metal_mat
	l_chimney.mesh = b_lchim
	l_chimney.position = Vector3(0.003, 0.030, 0)
	lighter.add_child(l_chimney)

	# Spark Wheel
	var l_wheel = MeshInstance3D.new()
	var cyl_lw = CylinderMesh.new()
	cyl_lw.top_radius = 0.005
	cyl_lw.bottom_radius = 0.005
	cyl_lw.height = 0.004
	cyl_lw.material = lighter_metal_mat
	l_wheel.mesh = cyl_lw
	l_wheel.rotation.z = deg_to_rad(90.0)
	l_wheel.position = Vector3(-0.009, 0.033, 0)
	lighter.add_child(l_wheel)

	# Hinged Lighter Lid
	var lighter_lid = Node3D.new()
	lighter_lid.name = "LighterLid"
	lighter_lid.position = Vector3(-0.018, 0.021, 0)
	lighter.add_child(lighter_lid)

	var l_lid_mesh = MeshInstance3D.new()
	var b_llid = BoxMesh.new()
	b_llid.size = Vector3(0.037, 0.028, 0.016)
	b_llid.material = lighter_metal_mat
	l_lid_mesh.mesh = b_llid
	l_lid_mesh.position = Vector3(0.018, 0.014, 0)
	lighter_lid.add_child(l_lid_mesh)

	# Flame & Light
	var l_flame = MeshInstance3D.new()
	l_flame.name = "LighterFlame"
	var sph_flame = SphereMesh.new()
	sph_flame.radius = 0.007
	sph_flame.height = 0.022
	sph_flame.material = lighter_flame_mat
	l_flame.mesh = sph_flame
	l_flame.position = Vector3(0.004, 0.048, 0)
	l_flame.visible = false
	lighter.add_child(l_flame)

	var l_light = OmniLight3D.new()
	l_light.name = "LighterLight"
	l_light.light_color = Color(1.0, 0.72, 0.2)
	l_light.light_energy = 4.5
	l_light.omni_range = 2.5
	l_light.position = Vector3(0.004, 0.052, 0)
	l_light.visible = false
	lighter.add_child(l_light)

	# --- 1C. ACTIVE CIGARETTE VIEWMODEL (BURNS DOWN AS SMOKED) ---
	var cig = Node3D.new()
	cig.name = "Cigarette"
	cig.position = Vector3(0.20, -0.28, -0.35)
	cig.visible = false
	vm_root.add_child(cig)

	# Fixed Orange Filter at base
	var c_filter = MeshInstance3D.new()
	c_filter.name = "FilterMesh"
	var cyl_cf = CylinderMesh.new()
	cyl_cf.top_radius = 0.0066
	cyl_cf.bottom_radius = 0.0066
	cyl_cf.height = 0.024
	cyl_cf.material = cig_filter_mat
	c_filter.mesh = cyl_cf
	c_filter.rotation.x = deg_to_rad(90.0)
	c_filter.position = Vector3(0, 0, 0.005)
	cig.add_child(c_filter)

	# Scalable White Paper Tube (shrinks as smoked)
	var c_paper = MeshInstance3D.new()
	c_paper.name = "PaperMesh"
	var cyl_cb = CylinderMesh.new()
	cyl_cb.top_radius = 0.0065
	cyl_cb.bottom_radius = 0.0065
	cyl_cb.height = 0.065
	cyl_cb.material = cig_paper_mat
	c_paper.mesh = cyl_cb
	c_paper.rotation.x = deg_to_rad(90.0)
	c_paper.position = Vector3(0, 0, -0.0445)
	cig.add_child(c_paper)

	# Burning Tip Assembly (Tracks the burning edge of paper)
	var tip_assembly = Node3D.new()
	tip_assembly.name = "TipAssembly"
	tip_assembly.position = Vector3(0, 0, -0.077)
	cig.add_child(tip_assembly)

	var c_tip = MeshInstance3D.new()
	c_tip.name = "EmberTip"
	var cyl_ct = CylinderMesh.new()
	cyl_ct.top_radius = 0.0062
	cyl_ct.bottom_radius = 0.0062
	cyl_ct.height = 0.006
	cyl_ct.material = cig_ember_mat
	c_tip.mesh = cyl_ct
	c_tip.rotation.x = deg_to_rad(90.0)
	c_tip.set_surface_override_material(0, cig_ember_mat)
	tip_assembly.add_child(c_tip)

	var c_ash = MeshInstance3D.new()
	c_ash.name = "AshTip"
	var cyl_ash = CylinderMesh.new()
	cyl_ash.top_radius = 0.0058
	cyl_ash.bottom_radius = 0.0058
	cyl_ash.height = 0.004
	cyl_ash.material = cig_ash_mat
	c_ash.mesh = cyl_ash
	c_ash.rotation.x = deg_to_rad(90.0)
	c_ash.position = Vector3(0, 0, -0.004)
	tip_assembly.add_child(c_ash)

	var ember_light = OmniLight3D.new()
	ember_light.name = "EmberLight"
	ember_light.light_color = Color(1.0, 0.35, 0.05)
	ember_light.light_energy = 1.0
	ember_light.omni_range = 1.5
	ember_light.position = Vector3(0, 0, -0.005)
	tip_assembly.add_child(ember_light)

	var smoke = CPUParticles3D.new()
	smoke.name = "SmokeParticles"
	smoke.position = Vector3(0, 0.004, -0.006)
	smoke.emitting = false
	smoke.amount = 20
	smoke.lifetime = 1.4
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 24.0
	smoke.gravity = Vector3(0, 0.75, 0)
	smoke.initial_velocity_min = 0.08
	smoke.initial_velocity_max = 0.22
	smoke.scale_amount_min = 0.015
	smoke.scale_amount_max = 0.045
	var pmesh = SphereMesh.new()
	pmesh.radius = 0.02
	pmesh.height = 0.04
	pmesh.material = smoke_mat
	smoke.mesh = pmesh
	tip_assembly.add_child(smoke)

	# --- 1D. EXHALE SMOKE PARTICLES (AT MOUTH / CAMERA) ---
	var exhale = CPUParticles3D.new()
	exhale.name = "ExhaleSmoke"
	exhale.position = Vector3(0, -0.07, -0.22)
	exhale.emitting = false
	exhale.one_shot = true
	exhale.explosiveness = 0.75
	exhale.amount = 24
	exhale.lifetime = 1.6
	exhale.direction = Vector3(0, 0.15, -1.0)
	exhale.spread = 26.0
	exhale.gravity = Vector3(0, 0.35, 0)
	exhale.initial_velocity_min = 0.25
	exhale.initial_velocity_max = 0.60
	exhale.scale_amount_min = 0.03
	exhale.scale_amount_max = 0.09
	var epmesh = SphereMesh.new()
	epmesh.radius = 0.025
	epmesh.height = 0.05
	epmesh.material = smoke_mat
	exhale.mesh = epmesh
	camera.add_child(exhale)

	# 2. Beer Bottle Viewmodel (Key 2) - Open Nozzle pointing towards player
	var bot = Node3D.new()
	bot.name = "Bottle"
	bot.position = Vector3(0.24, -0.42, -0.38)
	bot.visible = false
	vm_root.add_child(bot)

	var bot_glass_mat = load("res://assets/materials/bottle_glass.tres")
	var bot_lbl_mat = load("res://assets/materials/bottle_label.tres")

	var b_body = MeshInstance3D.new()
	var cyl_bb = CylinderMesh.new()
	cyl_bb.top_radius = 0.038
	cyl_bb.bottom_radius = 0.038
	cyl_bb.height = 0.15
	cyl_bb.material = bot_glass_mat
	b_body.mesh = cyl_bb
	b_body.position = Vector3(0, 0.075, 0)
	bot.add_child(b_body)

	var b_neck = MeshInstance3D.new()
	var cyl_bn = CylinderMesh.new()
	cyl_bn.top_radius = 0.016
	cyl_bn.bottom_radius = 0.035
	cyl_bn.height = 0.08
	cyl_bn.material = bot_glass_mat
	b_neck.mesh = cyl_bn
	b_neck.position = Vector3(0, 0.18, 0)
	bot.add_child(b_neck)

	var b_lip = MeshInstance3D.new()
	b_lip.name = "NozzleLip"
	var cyl_blip = CylinderMesh.new()
	cyl_blip.top_radius = 0.018
	cyl_blip.bottom_radius = 0.018
	cyl_blip.height = 0.015
	cyl_blip.material = bot_glass_mat
	b_lip.mesh = cyl_blip
	b_lip.position = Vector3(0, 0.225, 0)
	bot.add_child(b_lip)

	var b_hole = MeshInstance3D.new()
	var cyl_hole = CylinderMesh.new()
	cyl_hole.top_radius = 0.012
	cyl_hole.bottom_radius = 0.012
	cyl_hole.height = 0.008
	var hole_mat = StandardMaterial3D.new()
	hole_mat.albedo_color = Color(0.04, 0.08, 0.04)
	b_hole.mesh = cyl_hole
	b_hole.material_override = hole_mat
	b_hole.position = Vector3(0, 0.231, 0)
	bot.add_child(b_hole)

	var b_label = MeshInstance3D.new()
	var cyl_bl = CylinderMesh.new()
	cyl_bl.top_radius = 0.039
	cyl_bl.bottom_radius = 0.039
	cyl_bl.height = 0.075
	cyl_bl.material = bot_lbl_mat
	b_label.mesh = cyl_bl
	b_label.position = Vector3(0, 0.075, 0)
	bot.add_child(b_label)

	# 3. Energy Can Viewmodel (Key 3)
	var can = Node3D.new()
	can.name = "EnergyCan"
	can.position = Vector3(0.26, -0.42, -0.40)
	can.visible = false
	vm_root.add_child(can)

	var can_cyan_mat = load("res://assets/materials/energy_can_mat.tres")
	var can_alu_mat = load("res://assets/materials/can_alu_mat.tres")

	var can_body = MeshInstance3D.new()
	var cyl_cb2 = CylinderMesh.new()
	cyl_cb2.top_radius = 0.034
	cyl_cb2.bottom_radius = 0.034
	cyl_cb2.height = 0.14
	cyl_cb2.material = can_cyan_mat
	can_body.mesh = cyl_cb2
	can_body.position = Vector3(0, 0.07, 0)
	can.add_child(can_body)

	var can_top = MeshInstance3D.new()
	var cyl_ct2 = CylinderMesh.new()
	cyl_ct2.top_radius = 0.031
	cyl_ct2.bottom_radius = 0.031
	cyl_ct2.height = 0.012
	cyl_ct2.material = can_alu_mat
	can_top.mesh = cyl_ct2
	can_top.position = Vector3(0, 0.142, 0)
	can.add_child(can_top)

	# --- CANVAS HUD ---
	var canvas = CanvasLayer.new()
	canvas.name = "HUD"
	player.add_child(canvas)

	# Post-Processing Shader
	var shader = load("res://shaders/screen_fx.gdshader")
	var sh_mat = ShaderMaterial.new()
	sh_mat.shader = shader
	sh_mat.set_shader_parameter("dizzy_intensity", 0.0)
	sh_mat.set_shader_parameter("drunk_intensity", 0.0)
	sh_mat.set_shader_parameter("smoke_intensity", 0.0)
	sh_mat.set_shader_parameter("coma_fade", 0.0)
	sh_mat.set_shader_parameter("fx_time", 0.0)

	var screen_rect = ColorRect.new()
	screen_rect.name = "ScreenFX"
	screen_rect.material = sh_mat
	screen_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(screen_rect)

	# Crosshair
	var center = CenterContainer.new()
	center.name = "Crosshair"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center)

	var crosshair = ColorRect.new()
	crosshair.name = "Dot"
	crosshair.custom_minimum_size = Vector2(4, 4)
	crosshair.color = Color(1.0, 1.0, 1.0, 0.8)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(crosshair)

	var shaky_holder = CenterContainer.new()
	shaky_holder.name = "ShakyHolder"
	shaky_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	shaky_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(shaky_holder)

	# Controls & Status UI Overlay
	var margin = MarginContainer.new()
	margin.name = "ControlsUI"
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(margin)

	var panel = PanelContainer.new()
	panel.name = "PanelContainer"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = "HIGH  •  ceaser"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	var strain_box = HBoxContainer.new()
	strain_box.name = "StrainContainer"
	strain_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(strain_box)

	var strain_lbl = Label.new()
	strain_lbl.name = "StrainLabel"
	strain_lbl.text = "💪 ARM STRAIN: 0% (Drop with [Q] if exhausted)"
	strain_lbl.add_theme_font_size_override("font_size", 12)
	strain_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.35))
	strain_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strain_box.add_child(strain_lbl)

	var strain_bar = ProgressBar.new()
	strain_bar.name = "StrainBar"
	strain_bar.min_value = 0.0
	strain_bar.max_value = 100.0
	strain_bar.value = 0.0
	strain_bar.custom_minimum_size = Vector2(240, 14)
	strain_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strain_box.add_child(strain_bar)

	# --- 1. COMA LIFELINE RED BAR (AVOID COMA: KEEP SMOKING OR DRINKING!) ---
	var buzz_box = HBoxContainer.new()
	buzz_box.name = "BuzzContainer"
	buzz_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(buzz_box)

	var b_lbl = Label.new()
	b_lbl.name = "BuzzLabel"
	b_lbl.text = "🚨 COMA RED BAR: 100% (Keep smoking or drinking to keep it up!)"
	b_lbl.add_theme_font_size_override("font_size", 12)
	b_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	b_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buzz_box.add_child(b_lbl)

	var b_bar = ProgressBar.new()
	b_bar.name = "BuzzBar"
	b_bar.min_value = 0.0
	b_bar.max_value = 100.0
	b_bar.value = 100.0
	b_bar.custom_minimum_size = Vector2(240, 16)
	b_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Prominent red fill and dark red background styleboxes
	var red_fill = StyleBoxFlat.new()
	red_fill.bg_color = Color(0.95, 0.12, 0.18) # Bright crimson red
	red_fill.corner_radius_top_left = 3
	red_fill.corner_radius_top_right = 3
	red_fill.corner_radius_bottom_left = 3
	red_fill.corner_radius_bottom_right = 3
	b_bar.add_theme_stylebox_override("fill", red_fill)

	var red_bg = StyleBoxFlat.new()
	red_bg.bg_color = Color(0.20, 0.04, 0.06, 0.90) # Dark maroon background
	red_bg.border_width_left = 1
	red_bg.border_width_top = 1
	red_bg.border_width_right = 1
	red_bg.border_width_bottom = 1
	red_bg.border_color = Color(0.85, 0.20, 0.25, 0.70)
	red_bg.corner_radius_top_left = 3
	red_bg.corner_radius_top_right = 3
	red_bg.corner_radius_bottom_left = 3
	red_bg.corner_radius_bottom_right = 3
	b_bar.add_theme_stylebox_override("background", red_bg)

	buzz_box.add_child(b_bar)

	# --- 2. DRUNKENNESS METER (INVERTS WASD & MOUSE) ---
	var drunk_box = HBoxContainer.new()
	drunk_box.name = "DrunkContainer"
	drunk_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(drunk_box)

	var d_lbl = Label.new()
	d_lbl.name = "DrunkLabel"
	d_lbl.text = "DRUNKENNESS METER: 0% (Sober / Normal)"
	d_lbl.add_theme_font_size_override("font_size", 12)
	d_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	d_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drunk_box.add_child(d_lbl)

	var d_bar = ProgressBar.new()
	d_bar.name = "DrunkBar"
	d_bar.min_value = 0.0
	d_bar.max_value = 100.0
	d_bar.value = 0.0
	d_bar.custom_minimum_size = Vector2(200, 14)
	d_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drunk_box.add_child(d_bar)

	# --- 3. SMOKE DENSITY METER (WEIRD WARP & SMOKE CLOUD) ---
	var smoke_box = HBoxContainer.new()
	smoke_box.name = "SmokeContainer"
	smoke_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(smoke_box)

	var s_lbl = Label.new()
	s_lbl.name = "SmokeLabel"
	s_lbl.text = "SMOKE DENSITY: 0%"
	s_lbl.add_theme_font_size_override("font_size", 12)
	s_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	s_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smoke_box.add_child(s_lbl)

	var s_bar = ProgressBar.new()
	s_bar.name = "SmokeBar"
	s_bar.min_value = 0.0
	s_bar.max_value = 100.0
	s_bar.value = 0.0
	s_bar.custom_minimum_size = Vector2(200, 14)
	s_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smoke_box.add_child(s_bar)

	# --- 4. CIGARETTE LIFE & SCROLL TO SMOKE INDICATOR ---
	var cig_box = HBoxContainer.new()
	cig_box.name = "CigContainer"
	cig_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cig_box)

	var cig_hud_lbl = Label.new()
	cig_hud_lbl.name = "CigLabel"
	cig_hud_lbl.text = "🚬 CIGARETTE: None (Press [1] to pull out pack & light)"
	cig_hud_lbl.add_theme_font_size_override("font_size", 12)
	cig_hud_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	cig_hud_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cig_box.add_child(cig_hud_lbl)

	var cig_hud_bar = ProgressBar.new()
	cig_hud_bar.name = "CigBar"
	cig_hud_bar.min_value = 0.0
	cig_hud_bar.max_value = 100.0
	cig_hud_bar.value = 0.0
	cig_hud_bar.custom_minimum_size = Vector2(200, 14)
	cig_hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cig_box.add_child(cig_hud_bar)

	# Action keys instructions
	var action_lbl = Label.new()
	action_lbl.name = "ActionKeys"
	action_lbl.text = "[1] Take/Light Cigarette (🖱️ Scroll Wheel to Smoke)   [2] Drink (+Buzz/Drunk)   [3] Energy Drink   [E] Van/Talk"
	action_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	action_lbl.add_theme_font_size_override("font_size", 12)
	action_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(action_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = "[W/A/S/D] Move 360° (Inverts when drunk!)   [Mouse] 360° Look (Inverts when 60%+ drunk!)   [Shift] Sprint   [F] Light"
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	var badge_lbl = Label.new()
	badge_lbl.name = "EffectBadge"
	badge_lbl.text = "Status: Awake • Normal"
	badge_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	badge_lbl.add_theme_font_size_override("font_size", 12)
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(badge_lbl)

	# Centered In-Game Interaction Prompt
	var interact_lbl = Label.new()
	interact_lbl.name = "InteractPrompt"
	interact_lbl.text = "[E] Interact"
	interact_lbl.set_anchors_preset(Control.PRESET_CENTER)
	interact_lbl.position = Vector2(560, 420)
	interact_lbl.add_theme_font_size_override("font_size", 16)
	interact_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35))
	interact_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interact_lbl.visible = false
	canvas.add_child(interact_lbl)

	# Dialogue UI Box
	var diag_card = PanelContainer.new()
	diag_card.name = "DialogueUI"
	diag_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	diag_card.offset_left = 280
	diag_card.offset_right = -280
	diag_card.offset_bottom = -135
	diag_card.offset_top = -230
	diag_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diag_card.visible = false
	canvas.add_child(diag_card)

	var d_margin = MarginContainer.new()
	d_margin.name = "Margin"
	d_margin.add_theme_constant_override("margin_left", 16)
	d_margin.add_theme_constant_override("margin_right", 16)
	d_margin.add_theme_constant_override("margin_top", 10)
	d_margin.add_theme_constant_override("margin_bottom", 10)
	d_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diag_card.add_child(d_margin)

	var d_vbox = VBoxContainer.new()
	d_vbox.name = "VBox"
	d_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d_margin.add_child(d_vbox)

	var speaker_lbl = Label.new()
	speaker_lbl.name = "SpeakerName"
	speaker_lbl.text = "Character Name"
	speaker_lbl.add_theme_font_size_override("font_size", 15)
	speaker_lbl.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
	speaker_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d_vbox.add_child(speaker_lbl)

	var text_lbl = Label.new()
	text_lbl.name = "DialogueText"
	text_lbl.text = "\"Welcome to ceaser!\""
	text_lbl.add_theme_font_size_override("font_size", 14)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d_vbox.add_child(text_lbl)

	# --- FULLSCREEN COMA GAME OVER SCREEN ---
	var coma_panel = PanelContainer.new()
	coma_panel.name = "ComaUI"
	coma_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	coma_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coma_panel.visible = false
	canvas.add_child(coma_panel)

	var coma_center = CenterContainer.new()
	coma_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	coma_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coma_panel.add_child(coma_center)

	var coma_vbox = VBoxContainer.new()
	coma_vbox.add_theme_constant_override("separation", 16)
	coma_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coma_center.add_child(coma_vbox)

	var coma_title = Label.new()
	coma_title.text = "YOU FELL ASLEEP & SLIPPED INTO A COMA"
	coma_title.add_theme_font_size_override("font_size", 38)
	coma_title.add_theme_color_override("font_color", Color(1.0, 0.15, 0.2))
	coma_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coma_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coma_vbox.add_child(coma_title)

	var coma_reason = Label.new()
	coma_reason.text = "You stopped smoking and drinking for too long..."
	coma_reason.add_theme_font_size_override("font_size", 18)
	coma_reason.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	coma_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coma_reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coma_vbox.add_child(coma_reason)

	var coma_restart = Label.new()
	coma_restart.text = "► Press [R] or [Space] to Restart the Game ◄"
	coma_restart.add_theme_font_size_override("font_size", 22)
	coma_restart.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	coma_restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coma_restart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coma_vbox.add_child(coma_restart)

	set_owner_recursive(player, player)
	var packed = PackedScene.new()
	packed.pack(player)
	ResourceSaver.save(packed, "res://scenes/player.tscn")

# ----------------- MAIN SCENE ASSEMBLY -----------------

func create_main_scene() -> void:
	print("Creating Main scene with Ceaser, Detailed Parking Lot, White & Brown Van (Empty, no NPC)...")
	var root = Node3D.new()
	root.name = "Main"

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

	# 2. Glowing Moon Sphere & Moonlight
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

	# 5. Custom Enterable White & Brown Van (100% empty, no NPC inside or around!)
	var van_scene = load("res://scenes/van.tscn")
	var van = van_scene.instantiate()
	van.name = "ParkedVan"
	van.position = Vector3(-15.5, 0.0, 2.0)
	van.rotation.y = deg_to_rad(90.0)
	root.add_child(van)

	# 6. Scavengeable Car Parts (Station Tables in/around Ceaser Pub & Casino)
	var parts_root = Node3D.new()
	parts_root.name = "ScavengeParts"
	root.add_child(parts_root)

	# Part 0: Battery (12 kg) - Won at Darts Station inside Casino
	var p0 = create_scavenge_part_node(0, "Battery", 12.0, Vector3(14.2, 1.35, -43.2), Color(0.92, 0.22, 0.22))
	p0.visible = false
	parts_root.add_child(p0)

	# Part 1: Fuel Pump (5 kg) - Won at Cup Pong Station inside Casino
	var p1 = create_scavenge_part_node(1, "Fuel Pump", 5.0, Vector3(-6.0, 1.35, -26.0), Color(0.95, 0.75, 0.2))
	p1.visible = false
	parts_root.add_child(p1)

	# Part 2: Spark Plugs (0.4 kg) - Won at Slot Machine Station inside Casino
	var p2 = create_scavenge_part_node(2, "Spark Plugs", 0.4, Vector3(-16.0, 1.35, -32.0), Color(0.3, 0.9, 0.9))
	p2.visible = false
	parts_root.add_child(p2)

	# Part 3: Spare Tyre (9 kg) - Won at Casino Roulette Station inside Casino
	var p3 = create_scavenge_part_node(3, "Spare Tyre", 9.0, Vector3(20.0, 0.95, -34.0), Color(0.18, 0.18, 0.22))
	p3.visible = false
	parts_root.add_child(p3)

	# 7. Casino Minigame Stations (All Inside the Ceaser Pub & Casino!)
	var stations_root = Node3D.new()
	stations_root.name = "MinigameStations"
	root.add_child(stations_root)

	var s0 = create_minigame_station_node(0, "Darts", "🎯 PLAY DARTS WITH BARNEY (BET & WIN BATTERY)", Vector3(13.8, 0.8, -42.8), Color(0.95, 0.25, 0.25))
	stations_root.add_child(s0)

	var s1 = create_minigame_station_node(1, "Cup Pong", "🏓 PLAY CUP PONG (WIN FUEL PUMP)", Vector3(-6.0, 0.8, -26.0), Color(0.95, 0.75, 0.20))
	stations_root.add_child(s1)

	var s2 = create_minigame_station_node(2, "Slots", "🎰 PLAY SLOTS (WIN SPARK PLUGS)", Vector3(-18.0, 0.8, -32.0), Color(0.30, 0.85, 0.95))
	stations_root.add_child(s2)

	var s3 = create_minigame_station_node(3, "Roulette", "🎲 PLAY 3D ROULETTE WITH ANTOINE (BET & WIN SPARE TYRE)", Vector3(18.0, 0.8, -34.0), Color(0.85, 0.20, 0.25))
	stations_root.add_child(s3)

	# 8. Player (spawns firmly at floor level Y = 0.0, Z = 24.0)
	var player_scene = load("res://scenes/player.tscn")
	var player = player_scene.instantiate()
	player.name = "Player"
	player.position = Vector3(0.0, 0.0, 24.0)
	root.add_child(player)

	set_owner_recursive(root, root)
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/feature_main.tscn")

func create_home_screen_scene() -> void:
	var builder = load("res://scripts/build_home_screen.gd").new()
	builder.build_home_screen()


func create_scavenge_part_node(idx: int, part_name: String, mass: float, pos: Vector3, col: Color) -> StaticBody3D:
	var sb = StaticBody3D.new()
	sb.name = "WorldPart_%d" % idx
	sb.position = pos
	sb.add_to_group("car_parts")
	sb.set_meta("part_idx", idx)
	sb.set_meta("part_name", part_name)
	sb.set_meta("part_mass", mass)

	var cs = CollisionShape3D.new()
	cs.name = "Collision"
	var sph = SphereShape3D.new()
	sph.radius = 0.6
	cs.shape = sph
	sb.add_child(cs)

	var mi = MeshInstance3D.new()
	mi.name = "Mesh"
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.5
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.45

	match idx:
		0: # Battery
			var b = BoxMesh.new()
			b.size = Vector3(0.55, 0.40, 0.35)
			mi.mesh = b
			mi.material_override = mat
			sb.add_child(mi)
			for tx in [-0.18, 0.18]:
				var term = MeshInstance3D.new()
				var cyl = CylinderMesh.new()
				cyl.top_radius = 0.04
				cyl.bottom_radius = 0.04
				cyl.height = 0.08
				term.mesh = cyl
				term.position = Vector3(tx, 0.22, 0.0)
				term.material_override = load("res://assets/materials/lighter_metal.tres")
				sb.add_child(term)
		1: # Fuel Pump
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.18
			cyl.bottom_radius = 0.18
			cyl.height = 0.65
			mi.mesh = cyl
			mi.material_override = mat
			sb.add_child(mi)
			var pipe = MeshInstance3D.new()
			var p_cyl = CylinderMesh.new()
			p_cyl.top_radius = 0.04
			p_cyl.bottom_radius = 0.04
			p_cyl.height = 0.4
			pipe.mesh = p_cyl
			pipe.rotation.z = deg_to_rad(65.0)
			pipe.position = Vector3(0.18, 0.15, 0.0)
			pipe.material_override = load("res://assets/materials/van_tire_mat.tres")
			sb.add_child(pipe)
		2: # Spark Plugs
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.08
			cyl.bottom_radius = 0.08
			cyl.height = 0.45
			mi.mesh = cyl
			mi.material_override = mat
			sb.add_child(mi)
		3: # Spare Tyre
			var tm = TorusMesh.new()
			tm.inner_radius = 0.20
			tm.outer_radius = 0.45
			mi.mesh = tm
			mi.material_override = load("res://assets/materials/van_tire_mat.tres")
			mi.rotation.x = deg_to_rad(90.0)
			sb.add_child(mi)
			var rim = MeshInstance3D.new()
			var rm = CylinderMesh.new()
			rm.top_radius = 0.22
			rm.bottom_radius = 0.22
			rm.height = 0.22
			rim.mesh = rm
			rim.rotation.x = deg_to_rad(90.0)
			rim.material_override = load("res://assets/materials/lighter_metal.tres")
			sb.add_child(rim)

	var glow = OmniLight3D.new()
	glow.name = "BeaconGlow"
	glow.light_color = col
	glow.light_energy = 1.2
	glow.omni_range = 4.5
	glow.position.y = 0.5
	sb.add_child(glow)

	return sb

func create_minigame_station_node(idx: int, game_name: String, label_text: String, pos: Vector3, col: Color) -> Node3D:
	var st = Area3D.new()
	st.name = "Station_%d_%s" % [idx, game_name]
	st.position = pos
	st.add_to_group("minigame_stations")
	st.set_meta("station_idx", idx)
	st.set_meta("game_name", game_name)
	st.set_meta("label_text", label_text)

	var cs = CollisionShape3D.new()
	var sph = SphereShape3D.new()
	sph.radius = 2.5
	cs.shape = sph
	st.add_child(cs)

	var lbl = Label3D.new()
	lbl.name = "FloatingLabel"
	lbl.text = label_text + "\n[E] Play Minigame"
	lbl.font_size = 28
	lbl.outline_size = 6
	lbl.modulate = col
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 1.4, 0)
	lbl.no_depth_test = false
	st.add_child(lbl)

	var glow = OmniLight3D.new()
	glow.name = "StationGlow"
	glow.light_color = col
	glow.light_energy = 1.6
	glow.omni_range = 3.5
	glow.position = Vector3(0, 0.5, 0)
	st.add_child(glow)

	var ped = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 0.45
	cm.height = 0.8
	ped.mesh = cm
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.12, 0.15)
	m.roughness = 0.4
	ped.material_override = m
	ped.position.y = 0.4
	st.add_child(ped)

	return st
