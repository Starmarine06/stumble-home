class_name Darts3DGame
extends Node

## 3D In-Casino Darts Minigame Controller
## Handles the betting interaction with Barney NPC,
## the <= 1s cutscene stepping behind the throw line inside the casino,
## the viewmodel dart near the camera, dynamic drunken projectile arc and crosshair,
## strict board scoring (points ONLY awarded for landing on board), and payouts.

signal finished(won_battery: bool, payout: int)

const DartBoard3DClass = preload("res://scripts/minigames/dart_board_3d.gd")

# In-Casino World Coordinate Anchors
const CASINO_BOARD_WORLD_POS: Vector3 = Vector3(12.0, 2.25, -44.05)
const CASINO_THROW_LINE_POS: Vector3 = Vector3(12.0, 0.815, -41.65)
const CASINO_PLAYER_THROW_POS: Vector3 = Vector3(12.0, 0.80, -41.10)

var player: CharacterBody3D = null
var dart_board: Node3D = null
var barney_npc: Node = null

var bet_amount: int = 25
var darts_left: int = 3
var total_score: int = 0
var is_active: bool = false
var is_throwing: bool = false

# Cutscene & state machine
enum State { INACTIVE, HANDOVER, CUTSCENE_WALK, AIMING, FLYING_DART, ROUND_OVER }
var state: State = State.INACTIVE
var state_timer: float = 0.0

# Cutscene interpolation variables
var cutscene_start_player_pos: Vector3 = Vector3.ZERO
var cutscene_start_player_yaw: float = 0.0
var cutscene_start_head_pitch: float = 0.0
var board_world_pos: Vector3 = CASINO_BOARD_WORLD_POS
var target_player_throw_pos: Vector3 = CASINO_PLAYER_THROW_POS

# Aiming & Drunken wobble
var base_aim: Vector2 = Vector2.ZERO # Target offset on board in meters
var current_aim: Vector2 = Vector2.ZERO
var noise := FastNoiseLite.new()
var elapsed_aim: float = 0.0

# 3D Viewmodel & Arc nodes
var viewmodel_dart: Node3D = null
var arc_mesh_inst: MeshInstance3D = null
var arc_imm_mesh: ImmediateMesh = null
var arc_material: StandardMaterial3D = null
var arc_beads_root: Node3D = null
var arc_bead_meshes: Array[MeshInstance3D] = []
var crosshair_mesh_inst: MeshInstance3D = null

# Active flying dart
var flying_dart: Node3D = null
var flight_t: float = 0.0
var flight_pts: Array[Vector3] = []

# HUD overlay
var hud_container: Control = null
var score_label: Label = null
var info_label: Label = null

func _init() -> void:
	noise.seed = randi()
	noise.frequency = 0.85

func start_darts_session(p_player: CharacterBody3D, p_board: Node3D, p_barney: Node, p_bet: int) -> void:
	player = p_player
	dart_board = p_board
	barney_npc = p_barney
	bet_amount = p_bet
	darts_left = 3
	total_score = 0
	is_active = true

	# Resolve dartboard world position
	if dart_board and dart_board.is_inside_tree():
		board_world_pos = dart_board.global_position
	else:
		board_world_pos = CASINO_BOARD_WORLD_POS
	target_player_throw_pos = board_world_pos + Vector3(0.0, -1.45, 2.95)

	# Clear previous stuck darts on the board
	if dart_board and dart_board.has_method("clear_darts"):
		dart_board.clear_darts()

	# 1. State: Hand-over animation sequence (0.35s)
	state = State.HANDOVER
	state_timer = 0.35
	_play_sfx(&"clang")
	
	if player and ("interact_prompt_lbl" in player) and player.interact_prompt_lbl:
		player.interact_prompt_lbl.text = "🎯 Barney hands you 3 tournament darts..."
		player.interact_prompt_lbl.visible = true

	# Barney NPC arm gesture
	if barney_npc and is_instance_valid(barney_npc):
		var b_arm = barney_npc.find_child("RightArm", true, false) as Node3D
		if b_arm:
			var tw = create_tween()
			tw.tween_property(b_arm, "rotation:x", deg_to_rad(-65.0), 0.18)
			tw.tween_property(b_arm, "rotation:x", 0.0, 0.18).set_delay(0.20)

func _process(delta: float) -> void:
	if not is_active:
		return

	match state:
		State.HANDOVER:
			state_timer -= delta
			if state_timer <= 0.0:
				_start_cutscene_walk()

		State.CUTSCENE_WALK:
			state_timer += delta
			var duration = 0.65 # Strictly <= 1.0s cutscene per user request
			var t = clampf(state_timer / duration, 0.0, 1.0)
			var smooth_t = ease(t, -2.0)

			# Smoothly step player body behind the throw line facing the board
			if player:
				player.global_position = cutscene_start_player_pos.lerp(target_player_throw_pos, smooth_t)
				player.rotation.y = lerp_angle(cutscene_start_player_yaw, 0.0, smooth_t)
				if player.head:
					player.head.rotation.x = lerpf(cutscene_start_head_pitch, 0.0, smooth_t)
				if player.camera:
					player.camera.position = Vector3.ZERO
					player.camera.rotation = Vector3.ZERO

			if state_timer >= duration:
				_start_aiming_phase()

		State.AIMING:
			elapsed_aim += delta
			_update_drunken_aim(delta)
			_update_projectile_arc()
			_update_hud()

		State.FLYING_DART:
			_update_flying_dart(delta)

		State.ROUND_OVER:
			pass

func _start_cutscene_walk() -> void:
	state = State.CUTSCENE_WALK
	state_timer = 0.0

	if not player:
		_start_aiming_phase()
		return

	cutscene_start_player_pos = player.global_position
	cutscene_start_player_yaw = player.rotation.y
	cutscene_start_head_pitch = player.head.rotation.x if player.head else 0.0

	if player.interact_prompt_lbl:
		player.interact_prompt_lbl.text = "🚶 Stepping behind the throw line..."
		player.interact_prompt_lbl.visible = true

func _start_aiming_phase() -> void:
	state = State.AIMING
	elapsed_aim = 0.0
	base_aim = Vector2.ZERO
	current_aim = Vector2.ZERO
	is_throwing = false

	# Ensure player is strictly positioned behind the line inside the casino
	if player:
		player.global_position = target_player_throw_pos
		player.rotation.y = 0.0 # Facing -Z towards dartboard at -44.05
		if player.head:
			player.head.rotation.x = 0.0
		if player.camera:
			player.camera.position = Vector3.ZERO
			player.camera.rotation = Vector3.ZERO

	# Setup 3D Viewmodel Dart near camera
	_setup_viewmodel_dart()

	# Setup Projectile Arc & Crosshair meshes
	_setup_arc_and_crosshair()

	# Setup In-Game HUD overlay
	_setup_hud()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player and player.interact_prompt_lbl:
		player.interact_prompt_lbl.text = "🎯 [MOUSE] Aim Wobbling Dart   •   [LEFT-CLICK / SPACE] Throw Dart!"
		player.interact_prompt_lbl.visible = true

func _setup_viewmodel_dart() -> void:
	if not player or not player.camera:
		return
	
	if viewmodel_dart and is_instance_valid(viewmodel_dart):
		viewmodel_dart.queue_free()

	viewmodel_dart = Node3D.new()
	viewmodel_dart.name = "ViewmodelDart"
	# Position in right hand near camera foreground
	viewmodel_dart.position = Vector3(0.18, -0.15, -0.38)
	viewmodel_dart.rotation = Vector3(deg_to_rad(6.0), deg_to_rad(-4.0), 0.0)

	# Needle tip
	var tip = MeshInstance3D.new()
	var cyl_tip = CylinderMesh.new()
	cyl_tip.top_radius = 0.003
	cyl_tip.bottom_radius = 0.001
	cyl_tip.height = 0.04
	tip.mesh = cyl_tip
	tip.rotation.x = deg_to_rad(-90.0)
	tip.position = Vector3(0, 0, -0.02)
	var tip_mat = StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.9, 0.92, 0.95)
	tip_mat.metallic = 0.95
	tip_mat.roughness = 0.15
	tip.material_override = tip_mat
	viewmodel_dart.add_child(tip)

	# Dark Matte Tungsten Barrel (High-contrast obsidian black)
	var barrel = MeshInstance3D.new()
	var cyl_bar = CylinderMesh.new()
	cyl_bar.top_radius = 0.009
	cyl_bar.bottom_radius = 0.007
	cyl_bar.height = 0.065
	barrel.mesh = cyl_bar
	barrel.rotation.x = deg_to_rad(-90.0)
	barrel.position = Vector3(0, 0, 0.03)
	var bar_mat = StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.08, 0.08, 0.10) # Dark obsidian black
	bar_mat.metallic = 0.95
	bar_mat.roughness = 0.35
	barrel.material_override = bar_mat
	viewmodel_dart.add_child(barrel)

	# Pitch Black Carbon Shaft
	var shaft = MeshInstance3D.new()
	var cyl_sh = CylinderMesh.new()
	cyl_sh.top_radius = 0.004
	cyl_sh.bottom_radius = 0.004
	cyl_sh.height = 0.08
	shaft.mesh = cyl_sh
	shaft.rotation.x = deg_to_rad(-90.0)
	shaft.position = Vector3(0, 0, 0.10)
	var sh_mat = StandardMaterial3D.new()
	sh_mat.albedo_color = Color(0.03, 0.03, 0.04) # Pitch black
	shaft.material_override = sh_mat
	viewmodel_dart.add_child(shaft)

	# Dark Midnight Flights
	for f_rot in [0.0, 90.0]:
		var flight = MeshInstance3D.new()
		var box_fl = BoxMesh.new()
		box_fl.size = Vector3(0.040, 0.002, 0.048)
		flight.mesh = box_fl
		flight.rotation.z = deg_to_rad(f_rot)
		flight.position = Vector3(0, 0, 0.135)
		var fl_mat = StandardMaterial3D.new()
		fl_mat.albedo_color = Color(0.06, 0.06, 0.08) # Jet black flight
		flight.material_override = fl_mat
		viewmodel_dart.add_child(flight)

	player.camera.add_child(viewmodel_dart)

func _setup_arc_and_crosshair() -> void:
	if not arc_mesh_inst:
		arc_mesh_inst = MeshInstance3D.new()
		arc_mesh_inst.name = "DrunkProjectileArc"
		arc_imm_mesh = ImmediateMesh.new()
		arc_mesh_inst.mesh = arc_imm_mesh

		arc_material = StandardMaterial3D.new()
		arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		arc_material.albedo_color = Color(0.06, 0.06, 0.08, 1.0) # Dark jet-black trajectory line
		arc_mesh_inst.material_override = arc_material
		add_child(arc_mesh_inst)

	# Volumetric dark trajectory guide beads along the parabola
	if not arc_beads_root:
		arc_beads_root = Node3D.new()
		arc_beads_root.name = "ArcBeadsRoot"
		add_child(arc_beads_root)

		var bead_mat = StandardMaterial3D.new()
		bead_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bead_mat.albedo_color = Color(0.10, 0.02, 0.03, 1.0) # Deep dark obsidian crimson
		var bead_sph = SphereMesh.new()
		bead_sph.radius = 0.012
		bead_sph.height = 0.024
		bead_sph.radial_segments = 12
		bead_sph.rings = 6

		arc_bead_meshes.clear()
		for i in range(25):
			var bm = MeshInstance3D.new()
			bm.mesh = bead_sph
			bm.material_override = bead_mat
			arc_beads_root.add_child(bm)
			arc_bead_meshes.append(bm)

	# High-contrast, dark crosshair reticle on the board face
	if not crosshair_mesh_inst:
		crosshair_mesh_inst = MeshInstance3D.new()
		crosshair_mesh_inst.name = "3DDartsCrosshair"
		
		# Bold Dark Torus Ring Reticle
		var ring = TorusMesh.new()
		ring.inner_radius = 0.020
		ring.outer_radius = 0.034 # Thicker, high-contrast dark ring
		ring.ring_segments = 32
		crosshair_mesh_inst.mesh = ring
		crosshair_mesh_inst.rotation.x = deg_to_rad(90.0)

		var c_mat = StandardMaterial3D.new()
		c_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		c_mat.albedo_color = Color(0.05, 0.05, 0.07, 1.0) # Bold jet-black
		crosshair_mesh_inst.material_override = c_mat

		# Dark crosshair spokes (4 tick bars extending outward)
		for sp_rot in [0.0, 90.0]:
			var spoke = MeshInstance3D.new()
			var b_sp = BoxMesh.new()
			b_sp.size = Vector3(0.080, 0.005, 0.005)
			spoke.mesh = b_sp
			spoke.rotation.z = deg_to_rad(sp_rot)
			var sp_mat = StandardMaterial3D.new()
			sp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sp_mat.albedo_color = Color(0.04, 0.04, 0.06, 1.0) # Jet black spokes
			spoke.material_override = sp_mat
			crosshair_mesh_inst.add_child(spoke)

		# Dark Center Pip
		var pip = MeshInstance3D.new()
		var s_pip = SphereMesh.new()
		s_pip.radius = 0.005
		s_pip.height = 0.010
		pip.mesh = s_pip
		var pip_mat = StandardMaterial3D.new()
		pip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pip_mat.albedo_color = Color(0.25, 0.02, 0.03, 1.0)
		pip.material_override = pip_mat
		crosshair_mesh_inst.add_child(pip)

		add_child(crosshair_mesh_inst)

func _setup_hud() -> void:
	if hud_container and is_instance_valid(hud_container):
		hud_container.queue_free()

	hud_container = Control.new()
	hud_container.name = "Darts3DHUD"
	hud_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	sb.border_color = Color(0.95, 0.78, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(24, 80)
	panel.custom_minimum_size = Vector2(400, 155)
	hud_container.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title = Label.new()
	var wallet_amt = player.player_money if player and ("player_money" in player) else 1000
	title.text = "🎯 BARNEY'S DARTS  •  STAKE: $%d  •  WALLET: $%d" % [bet_amount, wallet_amt]
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	score_label = Label.new()
	score_label.text = "Darts Left: 3  |  Score: 0 pts"
	score_label.add_theme_font_size_override("font_size", 16)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(score_label)

	info_label = Label.new()
	info_label.text = "Target: 35+ pts to win, 100+ for 7x!\n🖱️ Dark Parabola & Crosshair Active — Points ONLY for board hits!"
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	vbox.add_child(info_label)

	if player:
		var hud_node = player.get_node_or_null("HUD")
		if hud_node:
			hud_node.add_child(hud_container)

func _update_drunken_aim(delta: float) -> void:
	# Heavy drunkenness: continuous Perlin noise shake + harmonic drift
	var tremor_x = noise.get_noise_1d(elapsed_aim * 9.0) * 0.15
	var tremor_y = noise.get_noise_1d(elapsed_aim * 9.0 + 100.0) * 0.13
	var drift_x = sin(elapsed_aim * 2.2) * 0.18
	var drift_y = cos(elapsed_aim * 1.8) * 0.15
	var jerk = sin(elapsed_aim * 7.5) * 0.04

	var target_aim = base_aim + Vector2(tremor_x + drift_x + jerk, tremor_y + drift_y)
	current_aim = current_aim.lerp(target_aim, clampf(delta * 12.0, 0.0, 1.0))

	# Subtle viewmodel hand breathing & drunken shake
	if viewmodel_dart and is_instance_valid(viewmodel_dart):
		var v_sway_x = sin(elapsed_aim * 3.2) * 0.008 + tremor_x * 0.04
		var v_sway_y = cos(elapsed_aim * 2.4) * 0.006 + tremor_y * 0.04
		viewmodel_dart.position = Vector3(0.18 + v_sway_x, -0.15 + v_sway_y, -0.38)
		viewmodel_dart.rotation.z = sin(elapsed_aim * 2.8) * 0.08

func _input(event: InputEvent) -> void:
	if not is_active or state != State.AIMING:
		return

	# Mouse aiming (adjusts base aim on the board)
	if event is InputEventMouseMotion:
		# Player guides crosshair across the 3D board
		base_aim.x += event.relative.x * 0.0014
		base_aim.y -= event.relative.y * 0.0014
		# Clamp within outer board and cabinet limits
		base_aim.x = clampf(base_aim.x, -0.55, 0.55)
		base_aim.y = clampf(base_aim.y, -0.55, 0.55)

	# Left Click or Space to Throw
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_throw_dart()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_throw_dart()

func _update_projectile_arc() -> void:
	if not arc_imm_mesh or not player or not player.camera:
		return

	# Start point P0: at the viewmodel dart tip in world space
	var cam = player.camera
	var cam_trans = cam.global_transform if cam.is_inside_tree() else player.global_transform
	var p0 = cam_trans.origin + cam_trans.basis * Vector3(0.18, -0.15, -0.38)
	
	# End point P1: target on the dartboard face with drunken drift applied
	var p1 = board_world_pos + Vector3(current_aim.x, current_aim.y, 0.04)

	# Update 3D Crosshair Position on the board face
	if crosshair_mesh_inst:
		crosshair_mesh_inst.global_position = p1
		crosshair_mesh_inst.visible = true

	# Compute 24 points along the wobbling parabolic arc
	flight_pts.clear()
	var steps = 24
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var pt = p0.lerp(p1, t)
		# Upward parabolic gravity arc
		pt.y += sin(t * PI) * 0.14
		# Drunken sinusoidal trajectory wave
		var wave = sin(t * 8.0 - elapsed_aim * 6.0) * 0.022 * sin(t * PI)
		pt.x += wave
		flight_pts.append(pt)

	# Render ImmediateMesh Line Strip & Dark Volumetric Beads
	arc_imm_mesh.clear_surfaces()
	arc_imm_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, arc_material)
	if arc_beads_root:
		arc_beads_root.visible = true
	for i in flight_pts.size():
		var pt = flight_pts[i]
		arc_imm_mesh.surface_add_vertex(pt)
		if i < arc_bead_meshes.size():
			arc_bead_meshes[i].global_position = pt
			arc_bead_meshes[i].visible = true
	arc_imm_mesh.surface_end()

func _throw_dart() -> void:
	if darts_left <= 0 or state != State.AIMING:
		return

	darts_left -= 1
	state = State.FLYING_DART
	flight_t = 0.0

	# Hide viewmodel dart, crosshair, and arc beads during flight
	if viewmodel_dart:
		viewmodel_dart.visible = false
	if arc_imm_mesh:
		arc_imm_mesh.clear_surfaces()
	if crosshair_mesh_inst:
		crosshair_mesh_inst.visible = false
	if arc_beads_root:
		arc_beads_root.visible = false

	# Play throw sound
	_play_sfx(&"clang")

	_spawn_flying_dart()

func _spawn_flying_dart() -> void:
	if flying_dart and is_instance_valid(flying_dart):
		flying_dart.queue_free()

	flying_dart = Node3D.new()
	flying_dart.name = "FlyingDart3D"
	get_tree().root.add_child(flying_dart)
	if flight_pts.size() > 0:
		flying_dart.global_position = flight_pts[0]

	# Dark Matte Tungsten barrel & tip
	var barrel = MeshInstance3D.new()
	var cyl_bar = CylinderMesh.new()
	cyl_bar.top_radius = 0.009
	cyl_bar.bottom_radius = 0.007
	cyl_bar.height = 0.08
	barrel.mesh = cyl_bar
	barrel.rotation.x = deg_to_rad(-90.0)
	var bar_mat = StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.08, 0.08, 0.10) # Dark obsidian black
	bar_mat.metallic = 0.95
	bar_mat.roughness = 0.35
	barrel.material_override = bar_mat
	flying_dart.add_child(barrel)

	# Dark Flights
	for f_rot in [0.0, 90.0]:
		var fl = MeshInstance3D.new()
		var b_fl = BoxMesh.new()
		b_fl.size = Vector3(0.038, 0.002, 0.045)
		fl.mesh = b_fl
		fl.rotation.z = deg_to_rad(f_rot)
		fl.position = Vector3(0, 0, 0.065)
		var fl_mat = StandardMaterial3D.new()
		fl_mat.albedo_color = Color(0.06, 0.06, 0.08) # Jet black flight
		fl.material_override = fl_mat
		flying_dart.add_child(fl)

func _update_flying_dart(delta: float) -> void:
	if not flying_dart or not is_instance_valid(flying_dart):
		return

	# Fast 0.26s flight time
	flight_t += delta / 0.26
	
	if flight_t >= 1.0:
		# Dart hits the board!
		_on_dart_hit_board()
		return

	# Sample position along trajectory curve
	var idx = int(flight_t * float(flight_pts.size() - 1))
	idx = clampi(idx, 0, flight_pts.size() - 1)
	var cur_pos = flight_pts[idx]
	flying_dart.global_position = cur_pos

	# Align rotation with velocity
	if idx + 1 < flight_pts.size():
		var next_pt = flight_pts[idx + 1]
		var dir = (next_pt - cur_pos).normalized()
		if dir != Vector3.ZERO:
			flying_dart.look_at(cur_pos + dir, Vector3.UP)

func _on_dart_hit_board() -> void:
	state = State.AIMING
	if flying_dart and is_instance_valid(flying_dart):
		flying_dart.queue_free()
		flying_dart = null

	# Strict evaluation on DartBoard3D: Points ONLY awarded if landed on the board!
	var hit_eval = dart_board.evaluate_hit(current_aim) if dart_board else {"is_hit": false, "score": 0, "name": "MISS", "color": Color.RED}
	var is_hit: bool = bool(hit_eval.get("is_hit", false))
	var pts: int = int(hit_eval.get("score", 0)) if is_hit else 0
	var hit_name: String = str(hit_eval.get("name", "MISS"))
	var hit_col: Color = hit_eval.get("color", Color.WHITE)

	if is_hit and pts > 0:
		total_score += pts
		_play_sfx(&"crash")
		if dart_board:
			dart_board.spawn_stuck_dart(current_aim)
			dart_board.spawn_score_popup(current_aim, "+%d %s" % [pts, hit_name], hit_col)
	else:
		# Dart landed outside the board face -> MISS (0 PTS)
		_play_sfx(&"part_fit_bad")
		if dart_board:
			dart_board.spawn_score_popup(current_aim, "MISS (0 PTS)", Color(1.0, 0.25, 0.25))

	_update_hud()

	if darts_left > 0:
		# Delay 0.35s then raise next dart into view
		get_tree().create_timer(0.35).timeout.connect(func():
			if viewmodel_dart and is_instance_valid(viewmodel_dart):
				viewmodel_dart.visible = true
		)
	else:
		# All 3 darts thrown! Complete the round
		_complete_round()

func _update_hud() -> void:
	if score_label:
		score_label.text = "Darts Left: %d  |  Total Score: %d pts" % [darts_left, total_score]
	if info_label:
		if total_score >= 100:
			info_label.text = "🔥 100+ PTS! 7.0x PAYOUT ($%d)!" % int(bet_amount * 7.0)
			info_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		elif total_score >= 75:
			info_label.text = "🎯 75+ PTS! 4.0x PAYOUT ($%d)!" % int(bet_amount * 4.0)
			info_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		elif total_score >= 50:
			info_label.text = "✅ 50+ PTS REACHED! 2.5x PAYOUT ($%d)!" % int(bet_amount * 2.5)
			info_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
		elif total_score >= 35:
			info_label.text = "★ 35+ PTS REACHED! 1.5x PAYOUT ($%d)" % int(bet_amount * 1.5)
			info_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
		else:
			info_label.text = "Need 35+ for a payout\n[Click / Space to Throw]"
			info_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))

func _complete_round() -> void:
	state = State.ROUND_OVER
	
	var won_battery = (total_score >= 50)
	var mult = 0.0
	if total_score >= 100:
		mult = 7.0
	elif total_score >= 75:
		mult = 4.0
	elif total_score >= 50:
		mult = 2.5
	elif total_score >= 35:
		mult = 1.5
	
	var payout = int(bet_amount * mult)

	if player and ("player_money" in player):
		player.player_money += payout

	if won_battery:
		_play_sfx(&"win")
		_play_sfx(&"horn")
	elif payout > 0:
		_play_sfx(&"win")
	else:
		_play_sfx(&"part_fit_bad")

	if player and player.interact_prompt_lbl:
		if won_battery:
			player.interact_prompt_lbl.text = "🎉 WON $%d PAYOUT! (Score: %d pts)" % [payout, total_score]
		elif payout > 0:
			player.interact_prompt_lbl.text = "★ WON $%d PAYOUT! (Score: %d pts)" % [payout, total_score]
		else:
			player.interact_prompt_lbl.text = "❌ Round Over! Scored %d/35 pts. Barney kept the $%d bet." % [total_score, bet_amount]
		player.interact_prompt_lbl.visible = true

	# Wait 2.2 seconds for celebration then restore free movement
	get_tree().create_timer(2.2).timeout.connect(func():
		cleanup()
		finished.emit(won_battery, payout)
	)

func cleanup() -> void:
	is_active = false
	state = State.INACTIVE
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if player:
		if player.camera:
			player.camera.position = Vector3.ZERO
			player.camera.rotation = Vector3.ZERO
		if player.head:
			player.head.rotation.x = 0.0

	if viewmodel_dart and is_instance_valid(viewmodel_dart):
		viewmodel_dart.queue_free()
	if arc_mesh_inst and is_instance_valid(arc_mesh_inst):
		arc_mesh_inst.queue_free()
	if arc_beads_root and is_instance_valid(arc_beads_root):
		arc_beads_root.queue_free()
	if crosshair_mesh_inst and is_instance_valid(crosshair_mesh_inst):
		crosshair_mesh_inst.queue_free()
	if hud_container and is_instance_valid(hud_container):
		hud_container.queue_free()

func _play_sfx(event: StringName) -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").play(event)
