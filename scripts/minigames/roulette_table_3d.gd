class_name RouletteTable3D
extends Node3D

## Real-Life 3D Casino Roulette Table Station
## Features:
## - Full 3D mahogany table with green felt betting layout
## - Undistorted planar radial circular mesh for the 37-number European wheel face
## - Physical 3D ivory ball with realtime centrifugal physics, deflector bounce & fret settling
## - Live in-world realtime spinning (player can freely walk around and inspect from any angle)
## - 3D floating announcement above wheel and croupier
## - Payout calculation & Spare Tyre car part award

signal spin_finished(won: bool, number: int, color_name: String, payout: int)

const WHEEL_NUMBERS := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const RED_NUMBERS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

# Radii for physics and rendering
const BOWL_CENTER_LOCAL := Vector3(-0.68, 0.88, 0.0)
const TRACK_RADIUS := 0.42
const DEFLECTOR_RADIUS := 0.36
const POCKET_RADIUS := 0.30

enum SpinPhase {
	IDLE,
	RIM_ORBIT,
	SPIRAL_DROP,
	DEFLECTOR_BOUNCE,
	FRET_HOPPING,
	SETTLED
}

var phase: SpinPhase = SpinPhase.IDLE
var phase_timer: float = 0.0
var is_spinning: bool = false

# Betting round info
var active_player: CharacterBody3D = null
var current_bet_amount: int = 50
var current_bet_type: String = "RED"
var current_bet_param: Variant = null

# Sub-nodes
var table_body: StaticBody3D = null
var rotor_node: Node3D = null
var ball_mesh: MeshInstance3D = null
var win_marker: MeshInstance3D = null
var overhead_light: SpotLight3D = null
var bowl_root: Node3D = null
var status_label_3d: Label3D = null

# Materials
var mahogany_mat: StandardMaterial3D
var felt_mat: StandardMaterial3D
var brass_mat: StandardMaterial3D
var wheel_mat: StandardMaterial3D
var ivory_mat: StandardMaterial3D
var gold_glow_mat: StandardMaterial3D

# Physics State
var rotor_angle: float = 0.0
var rotor_speed: float = 0.0
var rotor_friction: float = 0.24

var ball_angle: float = 0.0
var ball_speed: float = 0.0
var ball_friction: float = 1.85
var ball_radius: float = TRACK_RADIUS
var ball_y: float = -0.018

var winning_pocket_idx: int = 0
var winning_number: int = 0
var winning_color: String = "GREEN"

func _ready() -> void:
	add_to_group("roulette_tables")
	if table_body != null:
		return
	setup_materials()
	build_roulette_table()

func setup_materials() -> void:
	mahogany_mat = StandardMaterial3D.new()
	mahogany_mat.albedo_color = Color(0.22, 0.09, 0.05) # Deep rich mahogany
	mahogany_mat.roughness = 0.28
	mahogany_mat.metallic = 0.12

	felt_mat = StandardMaterial3D.new()
	var felt_tex = load("res://assets/textures/roulette_table_felt.png") as Texture2D
	if felt_tex:
		felt_mat.albedo_texture = felt_tex
	else:
		felt_mat.albedo_color = Color(0.08, 0.42, 0.18)
	felt_mat.roughness = 0.85
	felt_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	brass_mat = StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.92, 0.76, 0.28)
	brass_mat.metallic = 0.90
	brass_mat.roughness = 0.22

	wheel_mat = StandardMaterial3D.new()
	var wheel_tex = load("res://assets/textures/roulette_wheel_face.png") as Texture2D
	if wheel_tex:
		wheel_mat.albedo_texture = wheel_tex
	else:
		wheel_mat.albedo_color = Color(0.15, 0.15, 0.16)
	wheel_mat.roughness = 0.30
	wheel_mat.metallic = 0.20
	wheel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wheel_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	ivory_mat = StandardMaterial3D.new()
	ivory_mat.albedo_color = Color(0.98, 0.96, 0.92) # Polished ivory
	ivory_mat.roughness = 0.18
	ivory_mat.metallic = 0.05

	gold_glow_mat = StandardMaterial3D.new()
	gold_glow_mat.albedo_color = Color(1.0, 0.85, 0.2)
	gold_glow_mat.emission_enabled = true
	gold_glow_mat.emission = Color(1.0, 0.85, 0.2)
	gold_glow_mat.emission_energy_multiplier = 4.0

func build_roulette_table() -> void:
	table_body = StaticBody3D.new()
	table_body.name = "TableBody"
	add_child(table_body)

	# 1. Table Top Base (Mahogany Slab) - Size: 2.30m x 1.25m x 0.14m at Y = 0.80m
	var slab = MeshInstance3D.new()
	var slab_mesh = BoxMesh.new()
	slab_mesh.size = Vector3(2.30, 0.14, 1.25)
	slab.mesh = slab_mesh
	slab.material_override = mahogany_mat
	slab.position = Vector3(0.0, 0.80, 0.0)
	table_body.add_child(slab)

	var slab_col = CollisionShape3D.new()
	var slab_cbox = BoxShape3D.new()
	slab_cbox.size = Vector3(2.30, 0.14, 1.25)
	slab_col.shape = slab_cbox
	slab_col.position = Vector3(0.0, 0.80, 0.0)
	table_body.add_child(slab_col)

	# 2. Table Raised Padded Rim (Leather / Mahogany Armrest border)
	var rim_fwd = MeshInstance3D.new()
	var rim_fwd_mesh = BoxMesh.new()
	rim_fwd_mesh.size = Vector3(2.34, 0.08, 0.08)
	rim_fwd.mesh = rim_fwd_mesh
	rim_fwd.material_override = mahogany_mat
	rim_fwd.position = Vector3(0.0, 0.89, 0.60)
	table_body.add_child(rim_fwd)

	var rim_back = MeshInstance3D.new()
	rim_back.mesh = rim_fwd_mesh
	rim_back.material_override = mahogany_mat
	rim_back.position = Vector3(0.0, 0.89, -0.60)
	table_body.add_child(rim_back)

	var rim_end = MeshInstance3D.new()
	var rim_end_mesh = BoxMesh.new()
	rim_end_mesh.size = Vector3(0.08, 0.08, 1.25)
	rim_end.mesh = rim_end_mesh
	rim_end.material_override = mahogany_mat
	rim_end.position = Vector3(1.13, 0.89, 0.0)
	table_body.add_child(rim_end)

	var rim_left = MeshInstance3D.new()
	rim_left.mesh = rim_end_mesh
	rim_left.material_override = mahogany_mat
	rim_left.position = Vector3(-1.13, 0.89, 0.0)
	table_body.add_child(rim_left)

	# 3. 4 Wooden Legs with Brass Caps
	var leg_coords := [
		Vector3(-1.0, 0.38, -0.50),
		Vector3(1.0, 0.38, -0.50),
		Vector3(-1.0, 0.38, 0.50),
		Vector3(1.0, 0.38, 0.50)
	]
	for lc in leg_coords:
		var leg = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.065
		cyl.bottom_radius = 0.05
		cyl.height = 0.74
		leg.mesh = cyl
		leg.material_override = mahogany_mat
		leg.position = lc
		table_body.add_child(leg)

		var foot = MeshInstance3D.new()
		var fcyl = CylinderMesh.new()
		fcyl.top_radius = 0.055
		fcyl.bottom_radius = 0.075
		fcyl.height = 0.08
		foot.mesh = fcyl
		foot.material_override = brass_mat
		foot.position = Vector3(lc.x, 0.04, lc.z)
		table_body.add_child(foot)

	# 4. Green Felt Layout (Right side of table, 2:1 aspect ratio)
	var felt = MeshInstance3D.new()
	var felt_plane = PlaneMesh.new()
	felt_plane.size = Vector2(1.30, 0.65)
	felt.mesh = felt_plane
	felt.material_override = felt_mat
	felt.position = Vector3(0.42, 0.872, 0.0)
	table_body.add_child(felt)

	# 5. Chip Stacks on Felt
	build_chip_stacks(table_body)

	# 6. Sunk Roulette Bowl Assembly on Left Side
	bowl_root = Node3D.new()
	bowl_root.name = "RouletteBowl"
	bowl_root.position = BOWL_CENTER_LOCAL
	add_child(bowl_root)

	build_roulette_bowl(bowl_root)

	# 7. Overhead Vintage Brass Pendant Lamp
	var lamp = Node3D.new()
	lamp.name = "PendantLamp"
	lamp.position = Vector3(-0.68, 2.30, 0.0)
	add_child(lamp)

	var lamp_shade = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.06
	cone.bottom_radius = 0.32
	cone.height = 0.22
	lamp_shade.mesh = cone
	lamp_shade.material_override = brass_mat
	lamp_shade.position.y = 0.11
	lamp.add_child(lamp_shade)

	var lamp_cord = MeshInstance3D.new()
	var ccyl = CylinderMesh.new()
	ccyl.top_radius = 0.008
	ccyl.bottom_radius = 0.008
	ccyl.height = 1.10
	lamp_cord.mesh = ccyl
	lamp_cord.material_override = mahogany_mat
	lamp_cord.position.y = 0.76
	lamp.add_child(lamp_cord)

	overhead_light = SpotLight3D.new()
	overhead_light.name = "BowlSpot"
	overhead_light.position = Vector3(0, 0.0, 0)
	overhead_light.rotation.x = deg_to_rad(-90.0)
	overhead_light.light_color = Color(1.0, 0.92, 0.74)
	overhead_light.light_energy = 5.0
	overhead_light.spot_range = 3.8
	overhead_light.spot_angle = 45.0
	overhead_light.shadow_enabled = true
	lamp.add_child(overhead_light)

	# 8. Floating 3D Announcement Label above the table
	status_label_3d = Label3D.new()
	status_label_3d.name = "StatusLabel3D"
	status_label_3d.position = Vector3(-0.68, 1.85, 0.0)
	status_label_3d.text = "🎲 VIP ROULETTE\nPress [E] to Bet & Win Spare Tyre"
	status_label_3d.font_size = 32
	status_label_3d.modulate = Color(1.0, 0.88, 0.3)
	status_label_3d.outline_size = 8
	status_label_3d.outline_modulate = Color(0.05, 0.05, 0.08)
	status_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(status_label_3d)

func build_chip_stacks(parent: Node) -> void:
	var chip_cols := [
		Color(0.85, 0.15, 0.15), # $5 Red
		Color(0.18, 0.65, 0.22), # $25 Green
		Color(0.12, 0.12, 0.15), # $100 Black
		Color(0.92, 0.68, 0.18)  # $500 Gold
	]
	var stack_pos := [
		Vector3(0.08, 0.88, 0.36),
		Vector3(0.16, 0.88, 0.36),
		Vector3(0.24, 0.88, 0.36),
		Vector3(0.32, 0.88, 0.36),
		Vector3(0.08, 0.88, -0.36),
		Vector3(0.16, 0.88, -0.36)
	]
	for i in stack_pos.size():
		var col = chip_cols[i % chip_cols.size()]
		var stack_h = 4 + (i * 2) % 5
		for ch in stack_h:
			var chip = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.024
			cyl.bottom_radius = 0.024
			cyl.height = 0.008
			chip.mesh = cyl
			var c_mat = StandardMaterial3D.new()
			c_mat.albedo_color = col
			c_mat.roughness = 0.4
			chip.material_override = c_mat
			chip.position = stack_pos[i] + Vector3(0, ch * 0.0085, 0)
			parent.add_child(chip)

func build_roulette_bowl(parent: Node3D) -> void:
	# 1. Outer Mahogany Bowl Rim (Sunk basin)
	var rim = MeshInstance3D.new()
	var rim_mesh = CylinderMesh.new()
	rim_mesh.top_radius = 0.48
	rim_mesh.bottom_radius = 0.46
	rim_mesh.height = 0.06
	rim.mesh = rim_mesh
	rim.material_override = mahogany_mat
	rim.position.y = 0.0
	parent.add_child(rim)

	# 2. Sloping Polished Brass Ball Track
	var track = MeshInstance3D.new()
	var track_mesh = CylinderMesh.new()
	track_mesh.top_radius = 0.45
	track_mesh.bottom_radius = 0.37
	track_mesh.height = 0.05
	track.mesh = track_mesh
	track.material_override = brass_mat
	track.position.y = -0.022
	parent.add_child(track)

	# 3. 8 Deflector Diamonds / Pins (Brass Canoes)
	for i in 8:
		var angle = (float(i) / 8.0) * TAU
		var pin = MeshInstance3D.new()
		var p_mesh = BoxMesh.new()
		if i % 2 == 0:
			p_mesh.size = Vector3(0.025, 0.014, 0.008)
		else:
			p_mesh.size = Vector3(0.008, 0.014, 0.025)
		pin.mesh = p_mesh
		pin.material_override = brass_mat
		pin.position = Vector3(cos(angle) * DEFLECTOR_RADIUS, -0.038, sin(angle) * DEFLECTOR_RADIUS)
		pin.rotation.y = angle
		parent.add_child(pin)

	# 4. Central Spinning Rotor Turntable (`rotor_node`)
	rotor_node = Node3D.new()
	rotor_node.name = "RotorTurntable"
	rotor_node.position = Vector3(0.0, -0.046, 0.0)
	parent.add_child(rotor_node)

	# 4a. Photorealistic Circular Planar Mesh with Radial UVs
	# Maps roulette_wheel_face.png with ZERO distortion!
	var rotor_disc = MeshInstance3D.new()
	rotor_disc.name = "WheelFaceMesh"
	rotor_disc.mesh = _create_circle_mesh(0.35, 74)
	rotor_disc.material_override = wheel_mat
	rotor_disc.position.y = 0.006
	# Sector 0 is aligned with -Z (angle -PI/2)
	rotor_disc.rotation.y = 0.0
	rotor_node.add_child(rotor_disc)

	# 4b. Center Brass Cone & 4-Handled Turret Spindle
	var cone = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.12
	cm.height = 0.06
	cone.mesh = cm
	cone.material_override = brass_mat
	cone.position.y = 0.035
	rotor_node.add_child(cone)

	var spindle = MeshInstance3D.new()
	var sm = CylinderMesh.new()
	sm.top_radius = 0.02
	sm.bottom_radius = 0.02
	sm.height = 0.10
	spindle.mesh = sm
	spindle.material_override = brass_mat
	spindle.position.y = 0.09
	rotor_node.add_child(spindle)

	# 4 Turret handles extending horizontally
	for i in 4:
		var handle = MeshInstance3D.new()
		var hm = CylinderMesh.new()
		hm.top_radius = 0.006
		hm.bottom_radius = 0.006
		hm.height = 0.10
		handle.mesh = hm
		handle.material_override = brass_mat
		var ha = i * (PI * 0.5)
		handle.rotation.z = deg_to_rad(90.0)
		handle.rotation.y = ha
		handle.position = Vector3(cos(ha) * 0.06, 0.11, sin(ha) * 0.06)
		rotor_node.add_child(handle)

		var knob = MeshInstance3D.new()
		var km = SphereMesh.new()
		km.radius = 0.014
		km.height = 0.028
		knob.mesh = km
		knob.material_override = brass_mat
		knob.position = Vector3(cos(ha) * 0.11, 0.11, sin(ha) * 0.11)
		rotor_node.add_child(knob)

	# 5. 3D Ivory Ball
	ball_mesh = MeshInstance3D.new()
	ball_mesh.name = "IvoryBall"
	var bm = SphereMesh.new()
	bm.radius = 0.016
	bm.height = 0.032
	ball_mesh.mesh = bm
	ball_mesh.material_override = ivory_mat
	# Initially resting in pocket 0
	ball_mesh.position = Vector3(0.0, -0.040, -POCKET_RADIUS)
	parent.add_child(ball_mesh)

	# 6. Winning Pocket Golden Ring Marker
	win_marker = MeshInstance3D.new()
	win_marker.name = "WinMarker"
	var wmm = TorusMesh.new()
	wmm.inner_radius = 0.022
	wmm.outer_radius = 0.038
	win_marker.mesh = wmm
	win_marker.material_override = gold_glow_mat
	win_marker.visible = false
	rotor_node.add_child(win_marker)

## Helper that constructs a circular planar mesh with radial (0..1) UV coordinates
func _create_circle_mesh(radius: float, segments: int = 64) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0.5, 0.5))
	st.add_vertex(Vector3.ZERO)

	for i in range(segments + 1):
		var angle = (float(i) / float(segments)) * TAU
		var x = cos(angle) * radius
		var z = sin(angle) * radius
		var u = 0.5 + 0.5 * cos(angle)
		var v = 0.5 + 0.5 * sin(angle)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(u, v))
		st.add_vertex(Vector3(x, 0.0, z))

	for i in range(1, segments + 1):
		st.add_index(0)
		st.add_index(i + 1)
		st.add_index(i)

	return st.commit()

# ----------------- REALTIME IN-WORLD SPINNING & PHYSICS -----------------

## Starts an interactive physical spin round. Player is 100% free to move around!
func start_spin(
	p_player: CharacterBody3D,
	p_bet_amt: int,
	p_bet_type: String,
	p_param: Variant = null
) -> void:
	active_player = p_player
	current_bet_amount = p_bet_amt
	current_bet_type = p_bet_type
	current_bet_param = p_param
	is_spinning = true

	clear_win_marker()
	_play_sfx(&"clang")

	# Launch: Rotor clockwise (+), Ball counter-clockwise (-)
	rotor_speed = 5.4 + randf_range(-0.3, 0.3) # ~52 RPM
	rotor_angle = randf() * TAU

	ball_speed = -22.5 + randf_range(-1.5, 1.5) # ~215 RPM
	ball_angle = randf() * TAU
	ball_radius = TRACK_RADIUS
	ball_y = -0.016

	phase = SpinPhase.RIM_ORBIT
	phase_timer = 2.4

	if status_label_3d:
		status_label_3d.text = "🎲 BALL IN PLAY!\nWager: $%d on %s" % [current_bet_amount, current_bet_type]
		status_label_3d.modulate = Color(1.0, 0.9, 0.3)

func _process(delta: float) -> void:
	# 1. Rotor continuous physics (gradual deceleration)
	if rotor_speed > 0.0:
		rotor_speed = maxf(0.0, rotor_speed - rotor_friction * delta)
		rotor_angle = fmod(rotor_angle + rotor_speed * delta, TAU)
		set_rotor_rotation(rotor_angle)
	elif not is_spinning:
		# Very gentle subtle idle rotation when waiting
		rotor_angle = fmod(rotor_angle + 0.15 * delta, TAU)
		set_rotor_rotation(rotor_angle)

	# 2. In-play Ball Physics State Machine
	if not is_spinning:
		return

	match phase:
		SpinPhase.RIM_ORBIT:
			# High speed outer track rim orbit: glued by centrifugal force
			ball_speed = minf(-10.5, ball_speed + ball_friction * delta)
			ball_angle = fmod(ball_angle + ball_speed * delta, TAU)
			ball_radius = TRACK_RADIUS
			ball_y = -0.016 + sin(ball_angle * 2.0) * 0.002
			set_ball_position(ball_radius, ball_angle, ball_y)

			phase_timer -= delta
			if phase_timer <= 0.0 or absf(ball_speed) < 11.2:
				phase = SpinPhase.SPIRAL_DROP
				phase_timer = 1.6

		SpinPhase.SPIRAL_DROP:
			# Centrifugal force decays: ball spirals down inward into the bowl
			ball_speed = minf(-5.5, ball_speed + (ball_friction * 1.5) * delta)
			ball_angle = fmod(ball_angle + ball_speed * delta, TAU)
			var drop_t = clampf(1.0 - (phase_timer / 1.6), 0.0, 1.0)
			ball_radius = lerpf(TRACK_RADIUS, DEFLECTOR_RADIUS, drop_t)
			ball_y = lerpf(-0.016, -0.035, drop_t)
			set_ball_position(ball_radius, ball_angle, ball_y)

			phase_timer -= delta
			if phase_timer <= 0.0:
				phase = SpinPhase.DEFLECTOR_BOUNCE
				phase_timer = 1.4
				_play_sfx(&"crash")

		SpinPhase.DEFLECTOR_BOUNCE:
			# Ball hits deflector pins (diamonds): hops, chatters, and deflects
			ball_speed = minf(-3.2, ball_speed + (ball_friction * 2.0) * delta)
			ball_angle = fmod(ball_angle + ball_speed * delta, TAU)
			var bounce_t = clampf(1.0 - (phase_timer / 1.4), 0.0, 1.0)
			ball_radius = lerpf(DEFLECTOR_RADIUS, POCKET_RADIUS, bounce_t)

			var hop_wave = absf(sin(phase_timer * 18.0))
			ball_y = -0.038 + hop_wave * 0.012
			if hop_wave > 0.85 and randf() < 0.35:
				_play_sfx(&"clang")

			set_ball_position(ball_radius, ball_angle, ball_y)

			phase_timer -= delta
			if phase_timer <= 0.0:
				phase = SpinPhase.FRET_HOPPING
				phase_timer = 1.2

		SpinPhase.FRET_HOPPING:
			# Ball drops onto the spinning pocket frets, bouncing across dividers
			ball_speed = lerpf(ball_speed, rotor_speed, delta * 3.8)
			ball_angle = fmod(ball_angle + ball_speed * delta, TAU)
			ball_radius = POCKET_RADIUS
			var fret_chatter = absf(sin(phase_timer * 22.0)) * (phase_timer / 1.2)
			ball_y = -0.042 + fret_chatter * 0.007
			if fret_chatter > 0.004 and randf() < 0.25:
				_play_sfx(&"rattle")

			set_ball_position(ball_radius, ball_angle, ball_y)

			phase_timer -= delta
			if phase_timer <= 0.0 or absf(ball_speed - rotor_speed) < 0.4:
				_settle_ball()

		SpinPhase.SETTLED:
			# Ball settled: firmly locked to winning pocket on spinning rotor
			_update_settled_ball_position()
			phase_timer -= delta
			if phase_timer <= 0.0:
				phase = SpinPhase.IDLE
				is_spinning = false

func _settle_ball() -> void:
	phase = SpinPhase.SETTLED
	phase_timer = 4.5
	_play_sfx(&"clang")

	# Evaluate pocket sector from relative angle
	var sector_rad = TAU / 37.0
	var rel_angle = fposmod(ball_angle - rotor_angle - deg_to_rad(-90.0), TAU)
	winning_pocket_idx = int(round(rel_angle / sector_rad)) % 37

	winning_number = WHEEL_NUMBERS[winning_pocket_idx]
	if winning_number == 0:
		winning_color = "GREEN"
	elif winning_number in RED_NUMBERS:
		winning_color = "RED"
	else:
		winning_color = "BLACK"

	highlight_pocket(winning_pocket_idx)
	_evaluate_payout()

func _update_settled_ball_position() -> void:
	var sector_rad = TAU / 37.0
	var pocket_rel_angle = deg_to_rad(-90.0) + float(winning_pocket_idx) * sector_rad
	var final_world_angle = rotor_angle + pocket_rel_angle
	set_ball_position(POCKET_RADIUS, final_world_angle, -0.038)

func _evaluate_payout() -> void:
	var won = false
	var mult = 0

	match current_bet_type:
		"RED":
			if winning_color == "RED":
				won = true
				mult = 2
		"BLACK":
			if winning_color == "BLACK":
				won = true
				mult = 2
		"EVEN":
			if winning_number > 0 and winning_number % 2 == 0:
				won = true
				mult = 2
		"ODD":
			if winning_number % 2 == 1:
				won = true
				mult = 2
		"LOW":
			if winning_number >= 1 and winning_number <= 18:
				won = true
				mult = 2
		"HIGH":
			if winning_number >= 19 and winning_number <= 36:
				won = true
				mult = 2
		"1ST_12":
			if winning_number >= 1 and winning_number <= 12:
				won = true
				mult = 3
		"2ND_12":
			if winning_number >= 13 and winning_number <= 24:
				won = true
				mult = 3
		"3RD_12":
			if winning_number >= 25 and winning_number <= 36:
				won = true
				mult = 3
		"NUMBER":
			if winning_number == int(current_bet_param):
				won = true
				mult = 36

	var payout = current_bet_amount * mult

	if won:
		_play_sfx(&"win")
		_play_sfx(&"horn")
		if active_player and ("player_money" in active_player):
			active_player.player_money += payout
		if active_player and active_player.has_method("_on_minigame_won"):
			active_player._on_minigame_won(3) # Award Spare Tyre!

		if status_label_3d:
			status_label_3d.text = "🎉 WINNER! NUMBER %d (%s)!\nPayout: +$%d  •  SPARE TYRE WON!" % [winning_number, winning_color, payout]
			status_label_3d.modulate = Color(0.35, 1.0, 0.45)
	else:
		_play_sfx(&"part_fit_bad")
		if status_label_3d:
			status_label_3d.text = "🎯 NUMBER %d (%s)\nBetter luck next spin! [E] to Bet Again" % [winning_number, winning_color]
			status_label_3d.modulate = Color(0.95, 0.65, 0.35)

	spin_finished.emit(won, winning_number, winning_color, payout)

# ----------------- RIG METHODS -----------------

func set_rotor_rotation(angle_rad: float) -> void:
	if rotor_node:
		rotor_node.rotation.y = angle_rad

func set_ball_position(radius: float, angle_rad: float, y_offset: float) -> void:
	if ball_mesh:
		ball_mesh.position = Vector3(
			cos(angle_rad) * radius,
			y_offset,
			sin(angle_rad) * radius
		)

func highlight_pocket(pocket_idx: int) -> void:
	if not win_marker or not rotor_node:
		return
	if pocket_idx < 0 or pocket_idx >= WHEEL_NUMBERS.size():
		win_marker.visible = false
		return
	var sector_deg = 360.0 / 37.0
	var pocket_angle_rad = deg_to_rad(-90.0 + float(pocket_idx) * sector_deg)
	win_marker.position = Vector3(
		cos(pocket_angle_rad) * POCKET_RADIUS,
		0.015,
		sin(pocket_angle_rad) * POCKET_RADIUS
	)
	win_marker.visible = true

func clear_win_marker() -> void:
	if win_marker:
		win_marker.visible = false

func _play_sfx(event: StringName) -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").play(event)
