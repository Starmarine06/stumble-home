class_name RouletteTable3D
extends Node3D

## Real-Life 3D Casino Roulette Table Station
## Features:
## - Full 3D mahogany table with sunken hollow bowl and green felt betting layout
## - Undistorted circular mesh for the 37-number European wheel face with vivid red/black/green zero
## - 37 3D physical brass pocket frets (dividers) around the pocket ring
## - 8 3D polished brass deflector diamond studs on the sloping brass ball track
## - Procedural HOLLOW bowl basin (outer mahogany rim ring + sloping brass ball track)
##   with ZERO lids or blocking geometry—everything inside is 100% visible!
## - Physical 3D ivory ball with visible croupier BALL DROP from above onto the rim track
## - Realtime in-world physics: rim centrifugal orbit, spiral drop, deflector bounces,
##   fret hopping chatter, and firm pocket settling
## - Player is 100% free to walk around and inspect the wheel from any angle while spinning
## - 3D floating announcement billboard & overhead vintage brass spotlight
## - Payout calculation & Camper Van Spare Tyre car part award

signal spin_finished(won: bool, number: int, color_name: String, payout: int)

const WHEEL_NUMBERS := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const RED_NUMBERS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

# Radii for physics and rendering
const BOWL_CENTER_LOCAL := Vector3(-0.68, 0.87, 0.0)
const TRACK_RADIUS := 0.40
const DEFLECTOR_RADIUS := 0.36
const POCKET_RADIUS := 0.28

enum SpinPhase {
	IDLE,
	BALL_DROP,
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
var rotor_friction: float = 0.22

var ball_angle: float = 0.0
var ball_speed: float = 0.0
var ball_friction: float = 1.85
var ball_radius: float = TRACK_RADIUS
var ball_y: float = 0.035

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
	mahogany_mat.albedo_color = Color(0.24, 0.10, 0.05) # Deep rich polished mahogany
	mahogany_mat.roughness = 0.25
	mahogany_mat.metallic = 0.10

	felt_mat = StandardMaterial3D.new()
	var felt_tex = load("res://assets/textures/roulette_table_felt.png") as Texture2D
	if felt_tex:
		felt_mat.albedo_texture = felt_tex
	else:
		felt_mat.albedo_color = Color(0.08, 0.42, 0.18)
	felt_mat.roughness = 0.85
	felt_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	brass_mat = StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.95, 0.80, 0.32) # Polished casino brass
	brass_mat.metallic = 0.95
	brass_mat.roughness = 0.16

	wheel_mat = StandardMaterial3D.new()
	var wheel_tex = load("res://assets/textures/roulette_wheel_face.png") as Texture2D
	if wheel_tex:
		wheel_mat.albedo_texture = wheel_tex
	else:
		wheel_mat.albedo_color = Color(0.18, 0.18, 0.22)
	wheel_mat.albedo_color = Color.WHITE
	wheel_mat.roughness = 0.22
	wheel_mat.metallic = 0.15
	wheel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wheel_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	ivory_mat = StandardMaterial3D.new()
	ivory_mat.albedo_color = Color(0.98, 0.97, 0.94) # Polished ivory ball
	ivory_mat.roughness = 0.12
	ivory_mat.metallic = 0.04

	gold_glow_mat = StandardMaterial3D.new()
	gold_glow_mat.albedo_color = Color(1.0, 0.88, 0.25)
	gold_glow_mat.emission_enabled = true
	gold_glow_mat.emission = Color(1.0, 0.88, 0.25)
	gold_glow_mat.emission_energy_multiplier = 4.5

func build_roulette_table() -> void:
	table_body = StaticBody3D.new()
	table_body.name = "TableBody"
	add_child(table_body)

	# 1. Table Frame with Sunken Circular Well for the Bowl
	# Right Slab (Under green felt layout): X = -0.18 to +1.15
	var right_slab = MeshInstance3D.new()
	var right_mesh = BoxMesh.new()
	right_mesh.size = Vector3(1.33, 0.14, 1.25)
	right_slab.mesh = right_mesh
	right_slab.material_override = mahogany_mat
	right_slab.position = Vector3(0.485, 0.80, 0.0)
	table_body.add_child(right_slab)

	# Left Surrounds (Around sunken bowl at X = -0.68)
	var fwd_surround = MeshInstance3D.new()
	var b_fwd = BoxMesh.new()
	b_fwd.size = Vector3(0.97, 0.14, 0.135)
	fwd_surround.mesh = b_fwd
	fwd_surround.material_override = mahogany_mat
	fwd_surround.position = Vector3(-0.68, 0.80, 0.557)
	table_body.add_child(fwd_surround)

	var back_surround = MeshInstance3D.new()
	back_surround.mesh = b_fwd
	back_surround.material_override = mahogany_mat
	back_surround.position = Vector3(-0.68, 0.80, -0.557)
	table_body.add_child(back_surround)

	var left_surround = MeshInstance3D.new()
	var b_left = BoxMesh.new()
	b_left.size = Vector3(0.12, 0.14, 0.98)
	left_surround.mesh = b_left
	left_surround.material_override = mahogany_mat
	left_surround.position = Vector3(-1.09, 0.80, 0.0)
	table_body.add_child(left_surround)

	# Sub-floor shelf supporting the sunken bowl from underneath
	var sub_floor = MeshInstance3D.new()
	var b_sub = BoxMesh.new()
	b_sub.size = Vector3(0.97, 0.02, 0.98)
	sub_floor.mesh = b_sub
	sub_floor.material_override = mahogany_mat
	sub_floor.position = Vector3(-0.68, 0.73, 0.0)
	table_body.add_child(sub_floor)

	# Table Collision (solid bounds)
	var col_right = CollisionShape3D.new()
	var c_box = BoxShape3D.new()
	c_box.size = Vector3(1.33, 0.14, 1.25)
	col_right.shape = c_box
	col_right.position = Vector3(0.485, 0.80, 0.0)
	table_body.add_child(col_right)

	# 2. Raised Padded Leather/Mahogany Armrest Perimeter Border
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

	# 3. 4 Sturdy Wooden Legs with Brass Footing Caps
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
	felt.position = Vector3(0.485, 0.872, 0.0)
	table_body.add_child(felt)

	# 5. Realistic Casino Chip Stacks on Felt
	build_chip_stacks(table_body)

	# 6. Sunk Hollow Roulette Bowl Assembly (Left side at X = -0.68)
	bowl_root = Node3D.new()
	bowl_root.name = "RouletteBowl"
	bowl_root.position = BOWL_CENTER_LOCAL
	add_child(bowl_root)

	build_roulette_bowl(bowl_root)

	# 7. Overhead Vintage Brass Pendant Lamp with Focused Bowl Spotlight
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
	overhead_light.light_color = Color(1.0, 0.94, 0.80)
	overhead_light.light_energy = 6.0
	overhead_light.spot_range = 4.2
	overhead_light.spot_angle = 48.0
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

## Builds an authentic, 100% HOLLOW roulette bowl with zero solid lids!
func build_roulette_bowl(parent: Node3D) -> void:
	var segs := 54

	# 1. Outer Mahogany Bowl Rim (Hollow Lathe Revolution Mesh)
	var st_rim = SurfaceTool.new()
	st_rim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim_prof := [
		Vector2(0.48, 0.00),
		Vector2(0.48, 0.05),
		Vector2(0.43, 0.05),
		Vector2(0.42, 0.035)
	]
	for s in range(segs + 1):
		var phi = (float(s) / float(segs)) * TAU
		for p in rim_prof:
			var pos = Vector3(cos(phi) * p.x, p.y, sin(phi) * p.x)
			st_rim.add_vertex(pos)
	for s in range(segs):
		for i in range(rim_prof.size() - 1):
			var c = s * rim_prof.size() + i
			var n = (s + 1) * rim_prof.size() + i
			st_rim.add_index(c)
			st_rim.add_index(n)
			st_rim.add_index(c + 1)
			st_rim.add_index(c + 1)
			st_rim.add_index(n)
			st_rim.add_index(n + 1)
	st_rim.generate_normals()
	var rim = MeshInstance3D.new()
	rim.name = "HollowMahoganyRim"
	rim.mesh = st_rim.commit()
	rim.material_override = mahogany_mat
	parent.add_child(rim)

	# 2. Sloping Polished Brass Ball Track (Hollow Lathe Revolution Mesh)
	var st_track = SurfaceTool.new()
	st_track.begin(Mesh.PRIMITIVE_TRIANGLES)
	var track_prof := [
		Vector2(0.42, 0.035),
		Vector2(0.36, -0.015)
	]
	for s in range(segs + 1):
		var phi = (float(s) / float(segs)) * TAU
		for p in track_prof:
			var pos = Vector3(cos(phi) * p.x, p.y, sin(phi) * p.x)
			st_track.add_vertex(pos)
	for s in range(segs):
		var c = s * 2
		var n = (s + 1) * 2
		st_track.add_index(c)
		st_track.add_index(n)
		st_track.add_index(c + 1)
		st_track.add_index(c + 1)
		st_track.add_index(n)
		st_track.add_index(n + 1)
	st_track.generate_normals()
	var track = MeshInstance3D.new()
	track.name = "SlopingBrassTrack"
	track.mesh = st_track.commit()
	track.material_override = brass_mat
	parent.add_child(track)

	# 3. 8 Deflector Diamonds / Pins (Brass Canoes on the sloping wall)
	for i in 8:
		var angle = (float(i) / 8.0) * TAU
		var pin = MeshInstance3D.new()
		var p_mesh = BoxMesh.new()
		p_mesh.size = Vector3(0.018, 0.012, 0.008)
		pin.mesh = p_mesh
		pin.material_override = brass_mat
		pin.position = Vector3(cos(angle) * 0.385, 0.008, sin(angle) * 0.385)
		pin.rotation.y = angle
		parent.add_child(pin)

	# 4. Central Spinning Rotor Turntable (`rotor_node`) at the bottom of the basin
	rotor_node = Node3D.new()
	rotor_node.name = "RotorTurntable"
	rotor_node.position = Vector3(0.0, -0.018, 0.0)
	parent.add_child(rotor_node)

	# 4a. Ultra-Vivid Numbered Wheel Face Mesh (Radius 0.355m)
	# Maps the full European 37-pocket face with zero distortion!
	var rotor_disc = MeshInstance3D.new()
	rotor_disc.name = "WheelFaceMesh"
	rotor_disc.mesh = _create_circle_mesh(0.355, 74)
	rotor_disc.material_override = wheel_mat
	rotor_disc.position.y = 0.001
	rotor_node.add_child(rotor_disc)

	# 4b. 37 Physical 3D Brass Pocket Frets (Dividers between pockets)
	var num_pockets = WHEEL_NUMBERS.size()
	var sector_rad = TAU / float(num_pockets)
	for i in num_pockets:
		var fret_angle = deg_to_rad(-90.0) + (float(i) + 0.5) * sector_rad
		var fret = MeshInstance3D.new()
		var f_mesh = BoxMesh.new()
		f_mesh.size = Vector3(0.003, 0.006, 0.08)
		fret.mesh = f_mesh
		fret.material_override = brass_mat
		var fr = 0.295
		fret.position = Vector3(cos(fret_angle) * fr, 0.004, sin(fret_angle) * fr)
		fret.rotation.y = -fret_angle + PI * 0.5
		rotor_node.add_child(fret)

	# 4c. Center Brass Cone & 4-Handled Turret Spindle
	var cone = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.08
	cm.height = 0.035
	cone.mesh = cm
	cone.material_override = brass_mat
	cone.position.y = 0.018
	rotor_node.add_child(cone)

	var spindle = MeshInstance3D.new()
	var sm = CylinderMesh.new()
	sm.top_radius = 0.015
	sm.bottom_radius = 0.015
	sm.height = 0.06
	spindle.mesh = sm
	spindle.material_override = brass_mat
	spindle.position.y = 0.05
	rotor_node.add_child(spindle)

	# 4 Turret handles extending horizontally with sphere knobs
	for i in 4:
		var handle = MeshInstance3D.new()
		var hm = CylinderMesh.new()
		hm.top_radius = 0.005
		hm.bottom_radius = 0.005
		hm.height = 0.08
		handle.mesh = hm
		handle.material_override = brass_mat
		var ha = float(i) * (PI * 0.5)
		handle.rotation.z = deg_to_rad(90.0)
		handle.rotation.y = ha
		handle.position = Vector3(cos(ha) * 0.05, 0.065, sin(ha) * 0.05)
		rotor_node.add_child(handle)

		var knob = MeshInstance3D.new()
		var km = SphereMesh.new()
		km.radius = 0.012
		km.height = 0.024
		knob.mesh = km
		knob.material_override = brass_mat
		knob.position = Vector3(cos(ha) * 0.09, 0.065, sin(ha) * 0.09)
		rotor_node.add_child(knob)

	# 5. 3D Ivory Ball (Sits in winning pocket or orbits the rim)
	ball_mesh = MeshInstance3D.new()
	ball_mesh.name = "IvoryBall"
	var bm = SphereMesh.new()
	bm.radius = 0.014
	bm.height = 0.028
	ball_mesh.mesh = bm
	ball_mesh.material_override = ivory_mat
	# Initially resting in pocket 0
	ball_mesh.position = Vector3(0.0, -0.012, -POCKET_RADIUS)
	parent.add_child(ball_mesh)

	# 6. Winning Pocket Golden Ring Marker
	win_marker = MeshInstance3D.new()
	win_marker.name = "WinMarker"
	var wmm = TorusMesh.new()
	wmm.inner_radius = 0.014
	wmm.outer_radius = 0.026
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

## Starts an interactive physical spin round with visible BALL DROP from above!
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

	# Launch: Rotor spins clockwise (+)
	rotor_speed = 5.6 + randf_range(-0.3, 0.3) # ~54 RPM
	rotor_angle = randf() * TAU

	# Ball launched counter-clockwise (-): Begins slightly above the rim for a visible drop!
	ball_speed = -24.0 + randf_range(-1.5, 1.5) # ~230 RPM
	ball_angle = randf() * TAU
	ball_radius = TRACK_RADIUS + 0.02
	ball_y = 0.08 # Dropping from above!
	set_ball_position(ball_radius, ball_angle, ball_y)

	phase = SpinPhase.BALL_DROP
	phase_timer = 0.35

	if status_label_3d:
		status_label_3d.text = "🎲 BALL DROPPING & LAUNCHED!\nWager: $%d on %s" % [current_bet_amount, current_bet_type]
		status_label_3d.modulate = Color(1.0, 0.9, 0.3)

func _process(delta: float) -> void:
	# 1. Rotor continuous physics (gradual deceleration)
	if rotor_speed > 0.0:
		rotor_speed = maxf(0.0, rotor_speed - rotor_friction * delta)
		rotor_angle = fmod(rotor_angle + rotor_speed * delta, TAU)
		set_rotor_rotation(rotor_angle)
	elif not is_spinning:
		# Gentle idle rotation when waiting
		rotor_angle = fmod(rotor_angle + 0.15 * delta, TAU)
		set_rotor_rotation(rotor_angle)

	# 2. In-play Ball Physics State Machine
	if not is_spinning:
		return

	match phase:
		SpinPhase.BALL_DROP:
			# Ball drops from above onto the high outer brass rim track
			var drop_t = clampf(1.0 - (phase_timer / 0.35), 0.0, 1.0)
			ball_y = lerpf(0.08, 0.035, drop_t)
			ball_radius = lerpf(TRACK_RADIUS + 0.02, TRACK_RADIUS, drop_t)
			ball_angle = fmod(ball_angle + ball_speed * delta * 0.6, TAU)
			set_ball_position(ball_radius, ball_angle, ball_y)

			phase_timer -= delta
			if phase_timer <= 0.0:
				_play_sfx(&"clang")
				phase = SpinPhase.RIM_ORBIT
				phase_timer = 2.8
				if status_label_3d:
					status_label_3d.text = "🎲 BALL IN PLAY!\nWatch the wheel spin in realtime..."
					status_label_3d.modulate = Color(1.0, 0.95, 0.4)

		SpinPhase.RIM_ORBIT:
			# High speed outer track rim orbit: glued by centrifugal force
			ball_speed = minf(-11.5, ball_speed + ball_friction * delta)
			ball_angle = fmod(ball_angle + ball_speed * delta, TAU)
			ball_radius = TRACK_RADIUS
			ball_y = 0.035 + sin(ball_angle * 2.0) * 0.0015
			set_ball_position(ball_radius, ball_angle, ball_y)

			phase_timer -= delta
			if phase_timer <= 0.0 or absf(ball_speed) < 12.0:
				phase = SpinPhase.SPIRAL_DROP
				phase_timer = 1.8

		SpinPhase.SPIRAL_DROP:
			# Centrifugal force decays: ball spirals down inward along sloping brass track
			ball_speed = minf(-5.5, ball_speed + (ball_friction * 1.5) * delta)
			ball_angle = fmod(ball_angle + ball_speed * delta, TAU)
			var drop_t = clampf(1.0 - (phase_timer / 1.8), 0.0, 1.0)
			ball_radius = lerpf(TRACK_RADIUS, DEFLECTOR_RADIUS, drop_t)
			ball_y = lerpf(0.035, 0.008, drop_t)
			set_ball_position(ball_radius, ball_angle, ball_y)

			phase_timer -= delta
			if phase_timer <= 0.0:
				phase = SpinPhase.DEFLECTOR_BOUNCE
				phase_timer = 1.5
				_play_sfx(&"crash")

		SpinPhase.DEFLECTOR_BOUNCE:
			# Ball hits deflector diamond pins: hops, chatters, and deflects
			ball_speed = minf(-3.2, ball_speed + (ball_friction * 2.0) * delta)
			ball_angle = fmod(ball_angle + ball_speed * delta, TAU)
			var bounce_t = clampf(1.0 - (phase_timer / 1.5), 0.0, 1.0)
			ball_radius = lerpf(DEFLECTOR_RADIUS, POCKET_RADIUS, bounce_t)

			var hop_wave = absf(sin(phase_timer * 18.0))
			ball_y = 0.005 + hop_wave * 0.012
			if hop_wave > 0.85 and randf() < 0.35:
				_play_sfx(&"clang")

			set_ball_position(ball_radius, ball_angle, ball_y)

			phase_timer -= delta
			if phase_timer <= 0.0:
				phase = SpinPhase.FRET_HOPPING
				phase_timer = 1.3
				if status_label_3d:
					status_label_3d.text = "🎯 Ball hopping across frets..."
					status_label_3d.modulate = Color(1.0, 0.85, 0.3)

		SpinPhase.FRET_HOPPING:
			# Ball drops onto spinning pocket frets, bouncing across dividers
			ball_speed = lerpf(ball_speed, rotor_speed, delta * 3.8)
			ball_angle = fmod(ball_angle + ball_speed * delta, TAU)
			ball_radius = POCKET_RADIUS
			var fret_chatter = absf(sin(phase_timer * 22.0)) * (phase_timer / 1.3)
			ball_y = -0.012 + fret_chatter * 0.007
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
	set_ball_position(POCKET_RADIUS, final_world_angle, -0.012)

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
	var sector_rad = TAU / 37.0
	var pocket_rel_angle = deg_to_rad(-90.0) + float(pocket_idx) * sector_rad
	win_marker.position = Vector3(
		cos(pocket_rel_angle) * POCKET_RADIUS,
		0.008,
		sin(pocket_rel_angle) * POCKET_RADIUS
	)
	win_marker.visible = true

func clear_win_marker() -> void:
	if win_marker:
		win_marker.visible = false

func _play_sfx(event: StringName) -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").play(event)
