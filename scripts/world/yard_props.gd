class_name YardProps
extends RefCounted
## Junkyard dressing. Static, deterministic from seed, no per-frame cost.

const CLEAR := 6.0
const FENCE_R := 40.0


static func _ok(p: Vector3, keep: Array, extra: float = 0.0) -> bool:
	for k in keep:
		var d := Vector2(p.x - k.x, p.z - k.z).length()
		if d < CLEAR + extra:
			return false
	return true


static func _mat(c: Color, metal: float = 0.0, emit: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.9
	if emit:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.5
	return m


static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot_y: float = 0.0, body: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	if body:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


static func _cyl(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, body: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if body:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = r
		cy.height = h
		cs.shape = cy
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


static func _spot(rng: RandomNumberGenerator, keep: Array, extra: float = 0.0) -> Vector3:
	# Always consumes a fixed number of rng calls per attempt for determinism.
	for i in 30:
		var a := rng.randf() * TAU
		var r := 8.0 + rng.randf() * 28.0
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		if _ok(p, keep, extra):
			return p
	return Vector3.INF


static func build(seed: int, keep_clear: Array) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var root := Node3D.new()
	root.name = "YardProps"

	var rubber := _mat(Color(0.08, 0.08, 0.09))
	var rust := [_mat(Color(0.45, 0.22, 0.12), 0.4), _mat(Color(0.35, 0.3, 0.25), 0.4), _mat(Color(0.3, 0.38, 0.4), 0.4)]
	var glass := _mat(Color(0.1, 0.12, 0.13))
	var wood := _mat(Color(0.5, 0.36, 0.2))
	var scrap := _mat(Color(0.4, 0.38, 0.36), 0.6)
	var barrel := [_mat(Color(0.7, 0.2, 0.15), 0.3), _mat(Color(0.2, 0.35, 0.6), 0.3)]
	var steel := _mat(Color(0.5, 0.52, 0.55), 0.7)

	# Fence ring
	var segs := 48
	var seg_len := TAU * FENCE_R / segs + 0.3
	for i in segs:
		var a := TAU * float(i) / segs
		var p := Vector3(cos(a) * FENCE_R, 1.25, sin(a) * FENCE_R)
		if not _ok(p, keep_clear):
			continue
		_box(root, p, Vector3(seg_len, 2.5, 0.08), steel, -a + PI * 0.5, true)

	# Tyre stacks
	for i in 14:
		var p := _spot(rng, keep_clear, 1.0)
		var n := 2 + rng.randi() % 4
		if p == Vector3.INF:
			continue
		for j in n:
			_cyl(root, p + Vector3(0, 0.15 + j * 0.3, 0), 0.45, 0.3, rubber, j == 0)

	# Wrecked car shells
	for i in 7:
		var p := _spot(rng, keep_clear, 3.0)
		var yaw := rng.randf() * TAU
		var m = rust[rng.randi() % rust.size()]
		if p == Vector3.INF:
			continue
		var shell := Node3D.new()
		shell.position = p
		shell.rotation.y = yaw
		root.add_child(shell)
		_box(shell, Vector3(0, 0.6, 0), Vector3(4.2, 0.8, 1.9), m, 0.0, true)
		_box(shell, Vector3(-0.2, 1.2, 0), Vector3(2.2, 0.6, 1.7), m)
		_box(shell, Vector3(-0.2, 1.25, 0), Vector3(2.0, 0.35, 1.75), glass)
		_box(shell, Vector3(0.9, 1.2, 0.6), Vector3(0.05, 0.4, 0.6), glass)

	# Barrels
	for i in 16:
		var p := _spot(rng, keep_clear, 1.0)
		var m = barrel[rng.randi() % 2]
		if p == Vector3.INF:
			continue
		_cyl(root, p + Vector3(0, 0.45, 0), 0.3, 0.9, m, true)

	# Scrap piles
	for i in 10:
		var p := _spot(rng, keep_clear, 2.0)
		if p == Vector3.INF:
			continue
		for j in 5:
			var s := Vector3(0.5 + rng.randf() * 1.2, 0.3 + rng.randf() * 0.8, 0.5 + rng.randf() * 1.2)
			var o := Vector3(rng.randf_range(-1, 1), s.y * 0.5 + j * 0.15, rng.randf_range(-1, 1))
			_box(root, p + o, s, scrap, rng.randf() * TAU)

	# Pallets
	for i in 10:
		var p := _spot(rng, keep_clear, 1.0)
		var yaw := rng.randf() * TAU
		if p == Vector3.INF:
			continue
		_box(root, p + Vector3(0, 0.08, 0), Vector3(1.2, 0.16, 1.0), wood, yaw, true)

	# Lamp posts
	for i in 5:
		var p := _spot(rng, keep_clear, 1.0)
		if p == Vector3.INF:
			continue
		_cyl(root, p + Vector3(0, 2.5, 0), 0.07, 5.0, steel)
		_box(root, p + Vector3(0, 5.05, 0), Vector3(0.5, 0.15, 0.3), _mat(Color(1.0, 0.85, 0.5), 0.0, true))

	# Portacabin office
	var op := _spot(rng, keep_clear, 4.0)
	if op != Vector3.INF:
		var oy := rng.randf() * TAU
		var cab := Node3D.new()
		cab.position = op
		cab.rotation.y = oy
		root.add_child(cab)
		_box(cab, Vector3(0, 1.35, 0), Vector3(5.0, 2.7, 2.5), _mat(Color(0.75, 0.72, 0.62)), 0.0, true)
		_box(cab, Vector3(0, 2.75, 0), Vector3(5.2, 0.15, 2.7), _mat(Color(0.3, 0.3, 0.32)))
		_box(cab, Vector3(0.8, 1.5, 1.26), Vector3(1.2, 0.8, 0.05), _mat(Color(1.0, 0.9, 0.5), 0.0, true))
		_box(cab, Vector3(-1.5, 1.0, 1.26), Vector3(0.9, 2.0, 0.05), wood)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0.8, 1.5, 2.2)
		lamp.omni_range = 7.0
		lamp.light_color = Color(1.0, 0.85, 0.5)
		cab.add_child(lamp)

	return root
