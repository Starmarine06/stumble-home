class_name CarModel
extends RefCounted
## Low-poly cartoon banger built from primitives. Front is -Z, rear is +Z.
## build() returns a Node3D "Car"; set_repair(car, t) goes from wrecked (0) to clean (1).

const RUST := Color(0.38, 0.2, 0.1)
const PAINT := Color(0.95, 0.18, 0.15)
const HOOD_OPEN_WRECK := 0.55
const HOOD_OPEN_CLEAN := 0.4


static func _mat(c: Color, rough := 0.8, alpha := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _box(parent: Node3D, nm: String, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, nm: String, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(0, 0, PI * 0.5)  # axle along X
	parent.add_child(mi)
	return mi


static func _marker(parent: Node3D, nm: String, pos: Vector3) -> void:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	parent.add_child(n)


static func build() -> Node3D:
	var car := Node3D.new()
	car.name = "Car"
	var body := _mat(RUST, 0.7)
	var dark := _mat(Color(0.08, 0.08, 0.09), 0.9)
	var glass := _mat(Color(0.1, 0.15, 0.2, 0.55), 0.1, true)
	var chrome := _mat(Color(0.75, 0.77, 0.8), 0.3)
	var rubber := _mat(Color(0.07, 0.07, 0.07), 0.95)
	var head := _mat(Color(1.0, 0.95, 0.6), 0.2)
	head.emission_enabled = true
	head.emission = Color(1.0, 0.9, 0.4)
	head.emission_energy_multiplier = 0.4
	var tail := _mat(Color(0.8, 0.05, 0.05), 0.2)
	tail.emission_enabled = true
	tail.emission = Color(0.8, 0.0, 0.0)
	tail.emission_energy_multiplier = 0.3
	var plate := _mat(Color(0.95, 0.92, 0.7), 0.6)
	var engine := _mat(Color(0.25, 0.27, 0.3), 0.5)
	car.set_meta("body_mat", body)

	# Lower body, tapered: wide sill slab plus slightly narrower upper belt.
	_box(car, "BodyLower", Vector3(2.1, 0.55, 4.2), Vector3(0, 0.6, 0), body)
	_box(car, "BodyUpper", Vector3(1.95, 0.3, 4.0), Vector3(0, 0.98, 0.1), body)
	_box(car, "Trunk", Vector3(1.9, 0.18, 1.1), Vector3(0, 1.2, 1.5), body, Vector3(-0.04, 0, 0))
	_box(car, "Floor", Vector3(1.9, 0.1, 3.4), Vector3(0, 0.3, 0), dark)
	# Cabin
	_box(car, "Roof", Vector3(1.7, 0.1, 1.5), Vector3(0, 1.85, 0.5), body)
	for p in [[-1, -0.25], [1, -0.25], [-1, 1.25], [1, 1.25]]:
		var s: float = p[0]
		var z: float = p[1]
		_box(car, "Pillar", Vector3(0.1, 0.65, 0.1), Vector3(s * 0.8, 1.5, z), body)
	_box(car, "WindscreenGlass", Vector3(1.6, 0.6, 0.06), Vector3(0, 1.52, -0.3), glass, Vector3(-0.45, 0, 0))
	_box(car, "RearGlass", Vector3(1.6, 0.55, 0.06), Vector3(0, 1.52, 1.3), glass, Vector3(0.4, 0, 0))
	for sx in [-1, 1]:
		_box(car, "SideGlass", Vector3(0.05, 0.5, 1.3), Vector3(sx * 0.86, 1.52, 0.5), glass)
		# door seams
		_box(car, "DoorSeamF", Vector3(0.03, 0.5, 0.03), Vector3(sx * 1.06, 0.75, -0.2), dark)
		_box(car, "DoorSeamR", Vector3(0.03, 0.5, 0.03), Vector3(sx * 1.06, 0.75, 0.55), dark)
		_box(car, "DoorHandle", Vector3(0.05, 0.05, 0.2), Vector3(sx * 1.07, 0.95, 0.3), chrome)
		# mirrors
		_box(car, "MirrorArm", Vector3(0.12, 0.05, 0.05), Vector3(sx * 1.1, 1.2, -0.3), dark)
		_box(car, "Mirror", Vector3(0.08, 0.14, 0.2), Vector3(sx * 1.12, 1.22, -0.3), body)

	# Bumpers, lights, plate
	_box(car, "BumperF", Vector3(2.2, 0.22, 0.2), Vector3(0, 0.4, -2.2), chrome)
	_box(car, "BumperR", Vector3(2.2, 0.22, 0.2), Vector3(0, 0.4, 2.2), chrome)
	_box(car, "Grille", Vector3(1.0, 0.25, 0.05), Vector3(0, 0.65, -2.12), dark)
	for sx in [-1, 1]:
		_box(car, "HeadlightLens", Vector3(0.4, 0.2, 0.08), Vector3(sx * 0.7, 0.75, -2.1), head)
		_box(car, "TailLightLens", Vector3(0.4, 0.2, 0.08), Vector3(sx * 0.7, 0.85, 2.1), tail)
	_box(car, "LicencePlate", Vector3(0.5, 0.14, 0.03), Vector3(0, 0.62, 2.12), plate)

	# Engine bay (open hood)
	_box(car, "EngineBayFloor", Vector3(1.6, 0.1, 1.5), Vector3(0, 0.9, -1.4), dark)
	_box(car, "EngineBlock", Vector3(0.8, 0.4, 0.8), Vector3(0, 1.1, -1.4), engine)
	_box(car, "EngineCover", Vector3(0.5, 0.1, 0.5), Vector3(0, 1.35, -1.4), chrome)
	var hinge := Node3D.new()
	hinge.name = "HoodHinge"
	hinge.position = Vector3(0, 1.22, -0.65)
	hinge.rotation.x = HOOD_OPEN_WRECK
	car.add_child(hinge)
	_box(hinge, "Hood", Vector3(1.9, 0.1, 1.5), Vector3(0, 0, -0.75), body)

	# Wheels, arches
	var wheels: Array = []
	for i in 4:
		var sx := -1.0 if i % 2 == 0 else 1.0
		var z := -1.35 if i < 2 else 1.35
		var w := Node3D.new()
		w.name = "Wheel%d" % i
		w.position = Vector3(sx * 0.98, 0.4, z)
		car.add_child(w)
		_cyl(w, "Tyre", 0.4, 0.3, Vector3.ZERO, rubber)
		_cyl(w, "Rim", 0.26, 0.32, Vector3.ZERO, chrome)
		_cyl(w, "Hubcap", 0.12, 0.36, Vector3.ZERO, engine)
		wheels.append(w)
		_box(car, "WheelArch", Vector3(0.12, 0.12, 1.0), Vector3(sx * 1.04, 0.84, z), dark)
	car.set_meta("wheels", wheels)
	car.set_meta("hood", hinge)

	# Markers
	_marker(car, "EngineBay", Vector3(0, 1.1, -1.5))
	_marker(car, "Exhaust", Vector3(0.6, 0.35, 2.3))
	_marker(car, "HeadlightL", Vector3(-0.7, 0.75, -2.15))
	_marker(car, "HeadlightR", Vector3(0.7, 0.75, -2.15))

	# Collider
	var sb := StaticBody3D.new()
	sb.name = "Body"
	sb.position = Vector3(0, 0.8, 0)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.2, 1.6, 4.4)
	cs.shape = bs
	sb.add_child(cs)
	car.add_child(sb)

	set_repair(car, 0.0)
	return car


static func set_repair(car: Node3D, t: float) -> void:
	t = clampf(t, 0.0, 1.0)
	var body: StandardMaterial3D = car.get_meta("body_mat")
	body.albedo_color = RUST.lerp(PAINT, t)
	body.roughness = lerpf(0.9, 0.35, t)
	body.metallic = lerpf(0.0, 0.3, t)
	var hinge: Node3D = car.get_meta("hood")
	hinge.rotation = Vector3(lerpf(HOOD_OPEN_WRECK, HOOD_OPEN_CLEAN, t), 0.0, lerpf(0.12, 0.0, t))
	var wheels: Array = car.get_meta("wheels")
	for i in wheels.size():
		var w: Node3D = wheels[i]
		var s := 1.0
		if i == 0:
			s = lerpf(0.7, 1.0, t)  # flat tyre until repaired
		w.scale = Vector3(1, s, s)
		w.position.y = 0.4 * s
