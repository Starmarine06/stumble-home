class_name DartBoard3D
extends Node3D

## 3D Official Tournament Dartboard mounted on a Pub Wall
## Handles procedural board texture, ring hit detection, strict score calculation,
## physical 3D darts sticking into the board, and floating 3D score popups.

const WEDGES: Array[int] = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]

# Board radius in meters (official tournament size: 451mm diameter / 2 = 0.2255m play area + outer rim = 0.42m visual)
const BOARD_RADIUS: float = 0.42

# Ring radii (meters) relative to board center (0.0):
const R_INNER_BULL: float = 0.016   # 50 pts (Double Bull)
const R_OUTER_BULL: float = 0.038   # 25 pts (Single Bull)
const R_TRIPLE_IN: float = 0.190    # Triple ring inner (3x score)
const R_TRIPLE_OUT: float = 0.235   # Triple ring outer (3x score)
const R_DOUBLE_IN: float = 0.345    # Double ring inner (2x score)
const R_DOUBLE_OUT: float = 0.390   # Double ring outer (2x score)
const R_OUTER_RIM: float = 0.420    # Outer wire rim / board limit

var board_mesh: MeshInstance3D = null
var cabinet_mesh: MeshInstance3D = null
var trim_mesh: MeshInstance3D = null
var board_spotlight: SpotLight3D = null
var throw_line: MeshInstance3D = null
var stuck_darts_root: Node3D = null
var number_labels: Array[Label3D] = []

func _ready() -> void:
	setup_dartboard()

func setup_dartboard() -> void:
	# 1. Backboard / Wooden Cabinet on Wall
	if not cabinet_mesh:
		cabinet_mesh = MeshInstance3D.new()
		cabinet_mesh.name = "CabinetBackboard"
		var box_c = BoxMesh.new()
		box_c.size = Vector3(1.6, 1.9, 0.08)
		var wood_mat = StandardMaterial3D.new()
		wood_mat.albedo_color = Color(0.20, 0.09, 0.04) # Deep pub mahogany
		wood_mat.roughness = 0.55
		cabinet_mesh.mesh = box_c
		cabinet_mesh.material_override = wood_mat
		cabinet_mesh.position = Vector3(0, 0, -0.04)
		add_child(cabinet_mesh)

		# Gold outer trim on cabinet
		trim_mesh = MeshInstance3D.new()
		trim_mesh.name = "CabinetGoldTrim"
		var box_t = BoxMesh.new()
		box_t.size = Vector3(1.66, 1.96, 0.04)
		var trim_mat = StandardMaterial3D.new()
		trim_mat.albedo_color = Color(0.85, 0.68, 0.22)
		trim_mat.metallic = 0.85
		trim_mat.roughness = 0.30
		trim_mesh.mesh = box_t
		trim_mesh.material_override = trim_mat
		trim_mesh.position = Vector3(0, 0, -0.07)
		add_child(trim_mesh)

	# 2. 3D Dartboard Face & Cylinder Rim
	if not board_mesh:
		# Outer black sisal cylinder rim
		var rim = MeshInstance3D.new()
		rim.name = "BoardRimCylinder"
		var cyl = CylinderMesh.new()
		cyl.top_radius = BOARD_RADIUS
		cyl.bottom_radius = BOARD_RADIUS
		cyl.height = 0.05
		cyl.radial_segments = 48
		rim.mesh = cyl
		rim.rotation.x = deg_to_rad(90.0)
		rim.position = Vector3(0, 0, 0.01)
		var rim_mat = StandardMaterial3D.new()
		rim_mat.albedo_color = Color(0.08, 0.08, 0.09)
		rim_mat.roughness = 0.8
		rim.material_override = rim_mat
		add_child(rim)

		# Front circular face with high-res dartboard texture
		board_mesh = MeshInstance3D.new()
		board_mesh.name = "DartboardFace"
		var quad = QuadMesh.new()
		quad.size = Vector2(BOARD_RADIUS * 2.0, BOARD_RADIUS * 2.0)
		board_mesh.mesh = quad
		# Quad naturally faces +Z (into the casino room)
		board_mesh.position = Vector3(0, 0, 0.038)
		
		var b_mat = StandardMaterial3D.new()
		var tex = load("res://assets/textures/dartboard_face.png")
		if tex:
			b_mat.albedo_texture = tex
		b_mat.roughness = 0.65
		b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		board_mesh.material_override = b_mat
		add_child(board_mesh)

	# 3. Dedicated Overhead Warm Pub Spotlight
	if not board_spotlight:
		board_spotlight = SpotLight3D.new()
		board_spotlight.name = "DartBoardSpotlight"
		board_spotlight.position = Vector3(0, 1.25, 0.85)
		board_spotlight.rotation.x = deg_to_rad(-52.0)
		board_spotlight.light_color = Color(1.0, 0.92, 0.78)
		board_spotlight.light_energy = 6.0
		board_spotlight.spot_range = 4.2
		board_spotlight.spot_angle = 55.0
		board_spotlight.shadow_enabled = true
		add_child(board_spotlight)

	# 4. Container for stuck physical 3D darts
	if not stuck_darts_root:
		stuck_darts_root = Node3D.new()
		stuck_darts_root.name = "StuckDarts"
		add_child(stuck_darts_root)

## Evaluates a hit coordinate on the 3D board plane.
## local_pos: Vector2 relative to board center where X is right (+X) and Y is up (+Y).
## Strictly enforces that points are ONLY awarded if the dart lands on the board face!
func evaluate_hit(local_pos: Vector2) -> Dictionary:
	var dist = local_pos.length()
	
	# Strict Board Boundary: If hit is outside outer rim, 0 points!
	if dist > R_OUTER_RIM:
		return {
			"is_hit": false,
			"score": 0,
			"name": "MISS (0 PTS)",
			"color": Color(0.95, 0.25, 0.25),
			"multiplier": 0
		}
	
	# Inner Bullseye (Double Bull) - 50 pts
	if dist <= R_INNER_BULL:
		return {
			"is_hit": true,
			"score": 50,
			"name": "🎯 DOUBLE BULLSEYE! (50 pts)",
			"color": Color(1.0, 0.2, 0.25),
			"multiplier": 2
		}
	
	# Outer Bullseye (Single Bull) - 25 pts
	if dist <= R_OUTER_BULL:
		return {
			"is_hit": true,
			"score": 25,
			"name": "BULLSEYE (25 pts)",
			"color": Color(0.2, 0.9, 0.35),
			"multiplier": 1
		}
	
	# Determine wedge number from angle (+X right, +Y up)
	# Clockwise from top (+Y = 0 deg, +X = 90 deg, -Y = 180 deg, -X = 270 deg)
	var ang_rad = atan2(local_pos.x, local_pos.y)
	if ang_rad < 0:
		ang_rad += TAU
	var ang_deg = rad_to_deg(ang_rad)
	var wedge_idx = int((ang_deg + 9.0) / 18.0) % 20
	var wedge_num = WEDGES[wedge_idx]
	
	# Triple Ring (3x multiplier)
	if dist >= R_TRIPLE_IN and dist <= R_TRIPLE_OUT:
		var pts = wedge_num * 3
		return {
			"is_hit": true,
			"score": pts,
			"name": "TRIPLE %d! (%d pts)" % [wedge_num, pts],
			"color": Color(1.0, 0.85, 0.2),
			"multiplier": 3
		}
	
	# Double Ring (2x multiplier)
	if dist >= R_DOUBLE_IN and dist <= R_DOUBLE_OUT:
		var pts = wedge_num * 2
		return {
			"is_hit": true,
			"score": pts,
			"name": "DOUBLE %d! (%d pts)" % [wedge_num, pts],
			"color": Color(0.3, 0.85, 1.0),
			"multiplier": 2
		}
	
	# Single Bed
	return {
		"is_hit": true,
		"score": wedge_num,
		"name": "SINGLE %d (%d pts)" % [wedge_num, wedge_num],
		"color": Color(0.92, 0.92, 0.96),
		"multiplier": 1
	}

## Spawns a physical 3D dart stuck into the board at local coordinates (x, y)
func spawn_stuck_dart(local_pos: Vector2) -> Node3D:
	if not stuck_darts_root:
		stuck_darts_root = Node3D.new()
		stuck_darts_root.name = "StuckDarts"
		add_child(stuck_darts_root)

	var dart = Node3D.new()
	dart.name = "StuckDart"
	# Position on the front face of the board (Z = 0.04m)
	dart.position = Vector3(local_pos.x, local_pos.y, 0.04)
	# Slight natural angle tilt as darts stick into sisal
	dart.rotation.x = deg_to_rad(randf_range(-6.0, 3.0))
	dart.rotation.y = deg_to_rad(randf_range(-4.0, 4.0))

	# 1. Steel needle tip
	var tip = MeshInstance3D.new()
	var cyl_tip = CylinderMesh.new()
	cyl_tip.top_radius = 0.003
	cyl_tip.bottom_radius = 0.001
	cyl_tip.height = 0.035
	tip.mesh = cyl_tip
	tip.rotation.x = deg_to_rad(-90.0)
	tip.position = Vector3(0, 0, 0.01)
	var tip_mat = StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.85, 0.88, 0.92)
	tip_mat.metallic = 0.95
	tip_mat.roughness = 0.2
	tip.material_override = tip_mat
	dart.add_child(tip)

	# 2. Dark Matte Tungsten Barrel (High-contrast obsidian black)
	var barrel = MeshInstance3D.new()
	var cyl_bar = CylinderMesh.new()
	cyl_bar.top_radius = 0.009
	cyl_bar.bottom_radius = 0.007
	cyl_bar.height = 0.055
	barrel.mesh = cyl_bar
	barrel.rotation.x = deg_to_rad(-90.0)
	barrel.position = Vector3(0, 0, 0.05)
	var bar_mat = StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.08, 0.08, 0.10) # Dark obsidian black
	bar_mat.metallic = 0.95
	bar_mat.roughness = 0.35
	barrel.material_override = bar_mat
	dart.add_child(barrel)

	# 3. Carbon Shaft (Pitch black)
	var shaft = MeshInstance3D.new()
	var cyl_sh = CylinderMesh.new()
	cyl_sh.top_radius = 0.004
	cyl_sh.bottom_radius = 0.004
	cyl_sh.height = 0.075
	shaft.mesh = cyl_sh
	shaft.rotation.x = deg_to_rad(-90.0)
	shaft.position = Vector3(0, 0, 0.11)
	var sh_mat = StandardMaterial3D.new()
	sh_mat.albedo_color = Color(0.03, 0.03, 0.04) # Pitch black
	shaft.material_override = sh_mat
	dart.add_child(shaft)

	# 4 Cross Flights (Dark Charcoal with Deep Crimson Trim)
	for f_rot in [0.0, 90.0]:
		var flight = MeshInstance3D.new()
		var box_fl = BoxMesh.new()
		box_fl.size = Vector3(0.038, 0.002, 0.048)
		flight.mesh = box_fl
		flight.rotation.z = deg_to_rad(f_rot)
		flight.position = Vector3(0, 0, 0.14)
		var fl_mat = StandardMaterial3D.new()
		fl_mat.albedo_color = Color(0.06, 0.06, 0.08) # Jet black flight
		flight.material_override = fl_mat
		dart.add_child(flight)

	stuck_darts_root.add_child(dart)
	return dart

## Spawns a floating 3D score popup that drifts up and fades
func spawn_score_popup(local_pos: Vector2, text: String, col: Color) -> void:
	var popup = Label3D.new()
	popup.text = text
	popup.font_size = 42
	popup.modulate = col
	popup.outline_size = 8
	popup.outline_modulate = Color(0.05, 0.05, 0.05)
	popup.position = Vector3(local_pos.x, local_pos.y + 0.12, 0.10)
	add_child(popup)

	# Animate float and fade
	var tween = create_tween()
	tween.tween_property(popup, "position:y", popup.position.y + 0.30, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tween.tween_callback(popup.queue_free)

func clear_darts() -> void:
	if stuck_darts_root:
		for c in stuck_darts_root.get_children():
			c.queue_free()
