class_name RouletteTable3D
extends Node3D

## 3D Casino Roulette Table Station
## Features:
## - Full mahogany casino table with green felt betting layout
## - Sunk roulette bowl with brass track and 8 deflector pins
## - Realistic 37-pocket rotor turntable (European 0-36 sequence) with roulette_wheel_face.png
## - Central brass turret spindle with 4 handles
## - 3D Ivory ball with centrifugal track orbit and deflector bouncing
## - Winning pocket golden spotlight marker
## - Overhead vintage casino pendant lamp

const WHEEL_NUMBERS := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const RED_NUMBERS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

# Radii for physics and rendering
const BOWL_CENTER_LOCAL := Vector3(-0.68, 0.88, 0.0) # Sunk bowl center on left of table
const TRACK_RADIUS := 0.42     # Outer brass track rim
const DEFLECTOR_RADIUS := 0.36 # 8 brass deflector diamonds
const POCKET_RADIUS := 0.30    # Inner pocket numbered ring
const TURRET_RADIUS := 0.09    # Center brass turret

# Sub-nodes
var table_body: StaticBody3D = null
var rotor_node: Node3D = null
var ball_mesh: MeshInstance3D = null
var win_marker: MeshInstance3D = null
var overhead_light: SpotLight3D = null
var bowl_root: Node3D = null

# Materials
var mahogany_mat: StandardMaterial3D
var felt_mat: StandardMaterial3D
var brass_mat: StandardMaterial3D
var wheel_mat: StandardMaterial3D
var ivory_mat: StandardMaterial3D
var gold_glow_mat: StandardMaterial3D

func _ready() -> void:
	setup_materials()
	build_roulette_table()

func setup_materials() -> void:
	mahogany_mat = StandardMaterial3D.new()
	mahogany_mat.albedo_color = Color(0.22, 0.09, 0.05) # Deep rich mahogany
	mahogany_mat.roughness = 0.28
	mahogany_mat.metallic = 0.12

	felt_mat = StandardMaterial3D.new()
	felt_mat.albedo_color = Color(0.95, 0.95, 0.95)
	var felt_tex = load("res://assets/textures/roulette_table_felt.png") as Texture2D
	if felt_tex:
		felt_mat.albedo_texture = felt_tex
	else:
		felt_mat.albedo_color = Color(0.08, 0.42, 0.18)
	felt_mat.roughness = 0.85

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
	wheel_mat.roughness = 0.32
	wheel_mat.metallic = 0.25

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
	# Main Table Static Body
	table_body = StaticBody3D.new()
	table_body.name = "TableBody"
	add_child(table_body)

	# 1. Table Top Base (Mahogany Slab with rounded corners) - Size: 2.30m x 1.25m x 0.14m at Y = 0.80m
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

	# 2. Table Raised Padded Rim (Leather Armrest border)
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

	# 3. 4 Fluted Wooden Legs with Brass Footings
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

	# 4. Green Felt Layout (Right side of table) - Size: 1.25m x 0.95m at Y = 0.875m
	var felt = MeshInstance3D.new()
	var felt_plane = PlaneMesh.new()
	felt_plane.size = Vector2(1.25, 0.95)
	felt.mesh = felt_plane
	felt.material_override = felt_mat
	felt.position = Vector3(0.42, 0.872, 0.0)
	table_body.add_child(felt)

	# 5. Chip Stacks on Felt for Authenticity
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
	overhead_light.light_energy = 4.5
	overhead_light.spot_range = 3.6
	overhead_light.spot_angle = 42.0
	overhead_light.shadow_enabled = true
	lamp.add_child(overhead_light)

func build_chip_stacks(parent: Node) -> void:
	var chip_cols := [
		Color(0.85, 0.15, 0.15), # $5 Red
		Color(0.18, 0.65, 0.22), # $25 Green
		Color(0.12, 0.12, 0.15), # $100 Black
		Color(0.92, 0.68, 0.18)  # $500 Gold
	]
	var stack_pos := [
		Vector3(0.08, 0.88, 0.38),
		Vector3(0.16, 0.88, 0.38),
		Vector3(0.24, 0.88, 0.38),
		Vector3(0.32, 0.88, 0.38),
		Vector3(0.08, 0.88, -0.38),
		Vector3(0.16, 0.88, -0.38)
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
	# 1. Outer Mahogany Bowl Rim (Torus/Cylinder)
	var rim = MeshInstance3D.new()
	var rim_mesh = CylinderMesh.new()
	rim_mesh.top_radius = 0.48
	rim_mesh.bottom_radius = 0.46
	rim_mesh.height = 0.06
	rim.mesh = rim_mesh
	rim.material_override = mahogany_mat
	rim.position.y = 0.0
	parent.add_child(rim)

	# 2. Sloping Brass Ball Track (Inward sloping cone/basin)
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
	# Positioned at radius 0.37m, alternating horizontal & vertical deflector pins
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

	# 4. Central Spinning Rotor Assembly (`rotor_node`)
	rotor_node = Node3D.new()
	rotor_node.name = "RotorTurntable"
	rotor_node.position = Vector3(0.0, -0.048, 0.0)
	parent.add_child(rotor_node)

	# 4a. Rotor Pocket Wheel Disc with roulette_wheel_face.png
	# In European roulette, 0 is at top (-Z direction in 3D)
	var rotor_disc = MeshInstance3D.new()
	var disc_mesh = CylinderMesh.new()
	disc_mesh.top_radius = 0.35
	disc_mesh.bottom_radius = 0.35
	disc_mesh.height = 0.012
	rotor_disc.mesh = disc_mesh
	rotor_disc.material_override = wheel_mat
	rotor_disc.position.y = 0.006
	# Rotate so pocket 0 aligns with forward -Z axis
	rotor_disc.rotation.y = deg_to_rad(-90.0)
	rotor_node.add_child(rotor_disc)

	# 4b. 37 Pocket Frets (Thin brass radial divider ridges)
	for i in 37:
		var fret_angle = (float(i) / 37.0) * TAU
		var fret = MeshInstance3D.new()
		var f_mesh = BoxMesh.new()
		f_mesh.size = Vector3(0.003, 0.012, 0.09)
		fret.mesh = f_mesh
		fret.material_override = brass_mat
		var fret_r = (POCKET_RADIUS + 0.35) * 0.5
		fret.position = Vector3(cos(fret_angle) * fret_r, 0.012, sin(fret_angle) * fret_r)
		fret.rotation.y = -fret_angle + deg_to_rad(90.0)
		rotor_node.add_child(fret)

	# 4c. Center Brass Cone & 4-Handled Turret Spindle
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
	bm.radius = 0.015
	bm.height = 0.030
	ball_mesh.mesh = bm
	ball_mesh.material_override = ivory_mat
	# Place resting quietly in pocket 0
	ball_mesh.position = Vector3(0.0, -0.035, -POCKET_RADIUS)
	parent.add_child(ball_mesh)

	# 6. Winning Pocket Golden Ring Marker (Hidden until win)
	win_marker = MeshInstance3D.new()
	win_marker.name = "WinMarker"
	var wmm = TorusMesh.new()
	wmm.inner_radius = 0.022
	wmm.outer_radius = 0.038
	win_marker.mesh = wmm
	win_marker.material_override = gold_glow_mat
	win_marker.visible = false
	rotor_node.add_child(win_marker)

# ----------------- WHEEL CONTROL & PHYSICS METHODS -----------------

## Sets the rotor turntable rotation in radians
func set_rotor_rotation(angle_rad: float) -> void:
	if rotor_node:
		rotor_node.rotation.y = angle_rad

## Sets the ball's position relative to bowl center in cylindrical coordinates
func set_ball_position(radius: float, angle_rad: float, y_offset: float) -> void:
	if ball_mesh:
		ball_mesh.position = Vector3(
			cos(angle_rad) * radius,
			y_offset,
			sin(angle_rad) * radius
		)

## Highlights the winning pocket on the rotor turntable
func highlight_pocket(pocket_idx: int) -> void:
	if not win_marker or not rotor_node:
		return
	if pocket_idx < 0 or pocket_idx >= WHEEL_NUMBERS.size():
		win_marker.visible = false
		return
	
	# Sector angle relative to rotor turntable: 0 is at -90 deg (-Z)
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
