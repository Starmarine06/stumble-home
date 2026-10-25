class_name CityBuilder
extends Node3D
## Turns a CityLayout into nodes. The ground and streets exist from the start (a few long boxes);
## each block's buildings, intersection and street furniture are built only when someone is close,
## a couple of blocks per frame, and freed again when everyone has moved on. Building styles live
## in CityBuildings. Everything is low-poly boxes: only a handful of blocks are ever live.

signal chunk_built(block: Vector2i, chunk: Node3D)

const PARKING_LOT := preload("res://scenes/parking_lot.tscn")
const VAN := preload("res://scenes/van.tscn")
const CURB := 0.1              # low enough that a capsule rides up it without a step-climb
const LOAD_R := 2              # blocks around a viewer that get built
const KEEP_R := 3              # blocks beyond this are freed
const BUILDS_PER_FRAME := 2
const UPDATE_EVERY := 0.25

## Traffic signals run one shared cycle (seconds): north-south green, amber, east-west green, amber.
const SIGNAL_NS_GREEN := 10.0
const SIGNAL_AMBER := 2.0
const SIGNAL_EW_GREEN := 10.0
const SIGNAL_ALL_RED := 1.5     # both ways red between phases, so nobody is still crossing when the other side goes
const SIGNAL_CYCLE := SIGNAL_NS_GREEN + SIGNAL_AMBER + SIGNAL_EW_GREEN + SIGNAL_AMBER + SIGNAL_ALL_RED * 2.0
const CAR_COLORS := [Color(0.7, 0.1, 0.1), Color(0.1, 0.25, 0.6), Color(0.85, 0.85, 0.85), Color(0.12, 0.12, 0.14), Color(0.2, 0.5, 0.3), Color(0.75, 0.65, 0.2)]

var layout: CityLayout
## World-space points the city should exist around (cameras, players, the car).
var view_points: Array = []
## Called as hook(lot, parent_node, lot_centre_in_parent, building_size) for every reserved lot as its block is built.
var special_hook := Callable()

var buildings: CityBuildings
var traffic: CityTraffic
var _chunks: Dictionary = {}     # Vector2i -> Node3D
var _queue: Array = []
var _t := 0.0
var _clock := 0.0
var _mats: Dictionary = {}
var _signal_mats: Dictionary = {}   # "ns" / "ew" -> [red, amber, green] lamp materials, shared by every head
var _crosswalk_mesh: BoxMesh


func setup(p_layout: CityLayout) -> void:
	layout = p_layout
	buildings = CityBuildings.new(self)
	_crosswalk_mesh = BoxMesh.new()
	_crosswalk_mesh.size = Vector3(3.2, 0.03, 0.55)
	for axis in ["ns", "ew"]:
		var lamps: Array = []
		for c in [Color(1, 0.1, 0.1), Color(1, 0.7, 0.1), Color(0.1, 1, 0.3)]:
			var m := StandardMaterial3D.new()
			m.albedo_color = c
			m.emission_enabled = true
			m.emission = c
			lamps.append(m)
		_signal_mats[axis] = lamps
	_tick_signals()
	_build_ground()
	_build_streets()
	traffic = CityTraffic.new()
	traffic.name = "Traffic"
	traffic.city = self
	add_child(traffic)


# --- Always-on: ground and streets ---------------------------------------------------------------

func _build_ground() -> void:
	var size := layout.half_extent() * 2.0 + 800.0
	var body := StaticBody3D.new()
	body.name = "Ground"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size, 1.0, size)
	cs.shape = bs
	body.add_child(cs)
	body.position = Vector3(0, -0.5, 0)
	add_child(body)
	var grass := box(self, Vector3(size, 0.1, size), Vector3(0, -0.07, 0), Color(0.07, 0.09, 0.07))
	grass.name = "GroundMesh"


func _build_streets() -> void:
	var len := layout.half_extent() * 2.0
	var asphalt := Color(0.11, 0.11, 0.13)
	var line := Color(0.85, 0.75, 0.2)
	for i in layout.blocks + 1:
		var c := layout.road_line(i)
		box(self, Vector3(CityLayout.ROAD, 0.04, len), Vector3(c, 0.01, 0), asphalt)
		box(self, Vector3(len, 0.04, CityLayout.ROAD), Vector3(0, 0.012, c), asphalt)
	_street_markings(line)


## Dashed centre lines, one MultiMesh for the whole city: dashes only on the straight stretch of each block,
## never inside an intersection.
func _street_markings(line: Color) -> void:
	var dash := BoxMesh.new()
	dash.size = Vector3(0.2, 0.03, 3.0)
	var xforms: Array[Transform3D] = []
	var span := CityLayout.BLOCK * 0.5 - 6.0
	for i in layout.blocks + 1:
		var c := layout.road_line(i)
		for k in layout.blocks:
			var mid := (float(k) + 0.5 - float(layout.blocks) * 0.5) * CityLayout.PITCH
			var d := -span
			while d < span:
				xforms.append(Transform3D(Basis(), Vector3(c, 0.045, mid + d)))
				xforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(mid + d, 0.047, c)))
				d += 8.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dash
	mm.instance_count = xforms.size()
	for n in xforms.size():
		mm.set_instance_transform(n, xforms[n])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "LaneDashes"
	mmi.multimesh = mm
	mmi.material_override = mat(line)
	add_child(mmi)


# --- Streaming and signals -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if layout == null:
		return
	# wall-clock time, so every peer's lights agree without any messages
	_clock = Time.get_unix_time_from_system()
	_tick_signals()
	_t -= delta
	if _t <= 0.0:
		_t = UPDATE_EVERY
		refresh()
	for _n in BUILDS_PER_FRAME:
		if _queue.is_empty():
			break
		var b: Vector2i = _queue.pop_front()
		if not _chunks.has(b):
			_make_chunk(b)


## The lamp each axis shows right now: 0 red, 1 amber, 2 green. Never green both ways.
func signal_state(at := -1.0) -> Dictionary:
	var t := fmod(_clock if at < 0.0 else at, SIGNAL_CYCLE)
	var ns := 0
	var ew := 0
	if t < SIGNAL_NS_GREEN:
		ns = 2
	elif t < SIGNAL_NS_GREEN + SIGNAL_AMBER:
		ns = 1
	elif t < SIGNAL_NS_GREEN + SIGNAL_AMBER + SIGNAL_ALL_RED:
		pass
	elif t < SIGNAL_NS_GREEN + SIGNAL_AMBER + SIGNAL_ALL_RED + SIGNAL_EW_GREEN:
		ew = 2
	elif t < SIGNAL_NS_GREEN + SIGNAL_AMBER + SIGNAL_ALL_RED + SIGNAL_EW_GREEN + SIGNAL_AMBER:
		ew = 1
	return {"ns": ns, "ew": ew}


## Every signal head shares six lamp materials, so the whole city cycles with no per-node work.
func _tick_signals() -> void:
	var s := signal_state()
	for axis in ["ns", "ew"]:
		var lit := int(s[axis])
		var lamps: Array = _signal_mats[axis]
		for i in 3:
			lamps[i].emission_energy_multiplier = 3.0 if lit == i else 0.05


## Work out which blocks should exist and queue the missing ones, nearest first.
func refresh() -> void:
	var want: Dictionary = {}    # block -> distance to the nearest viewer, in blocks
	var keep: Dictionary = {}
	for p in view_points:
		var home := layout.block_at(to_local(p))
		for dx in range(-KEEP_R, KEEP_R + 1):
			for dz in range(-KEEP_R, KEEP_R + 1):
				var b := home + Vector2i(dx, dz)
				if b.x < 0 or b.y < 0 or b.x >= layout.blocks or b.y >= layout.blocks:
					continue
				keep[b] = true
				var d := maxi(absi(dx), absi(dz))
				if d <= LOAD_R and (not want.has(b) or want[b] > d):
					want[b] = d
	for b in _chunks.keys():
		if not keep.has(b):
			_chunks[b].queue_free()
			_chunks.erase(b)
	var missing: Array = []
	for b in want:
		if not _chunks.has(b):
			missing.append(b)
	missing.sort_custom(func(a, c): return want[a] < want[c])
	_queue = missing


## Build everything around these points right now (the first frame, and tests).
func build_around(points: Array) -> void:
	view_points = points
	refresh()
	for b in _queue:
		if not _chunks.has(b):
			_make_chunk(b)
	_queue.clear()


func loaded_blocks() -> Array:
	return _chunks.keys()


func chunk(b: Vector2i) -> Node3D:
	return _chunks.get(b)


func _make_chunk(b: Vector2i) -> void:
	var root := Node3D.new()
	root.name = "Block_%d_%d" % [b.x, b.y]
	root.position = layout.block_center(b)
	add_child(root)
	_chunks[b] = root
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed_value * 31 + b.x * 97 + b.y * 1013
	solid_box(root, Vector3(CityLayout.BLOCK, CURB, CityLayout.BLOCK), Vector3(0, CURB * 0.5, 0), Color(0.3, 0.3, 0.32))
	match layout.block_kind(b):
		"casino":
			_build_carpark(root)
		"park":
			box(root, Vector3(CityLayout.BLOCK - 14.0, 0.05, CityLayout.BLOCK - 14.0), Vector3(0, CURB + 0.02, 0), Color(0.12, 0.28, 0.12))
			for _k in 14:
				tree(root, Vector3(rng.randf_range(-48, 48), CURB, rng.randf_range(-48, 48)), rng)
		_:
			for lot in layout.lots_of(b):
				_build_lot(root, lot)
			for _k in 3:
				tree(root, Vector3(rng.randf_range(-22, 22), CURB, rng.randf_range(-22, 22)), rng)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_lamp(root, Vector3(sx * (CityLayout.BLOCK * 0.5 - 1.0), CURB, sz * (CityLayout.BLOCK * 0.5 - 1.0)))
	_build_intersection(root, b)
	_street_furniture(root, rng)
	chunk_built.emit(b, root)


## The original map: its parking lot and the van, laid out as they were around the casino.
func _build_carpark(root: Node3D) -> void:
	var local: Vector3 = layout.parking_center() - layout.block_center(layout.casino_block)
	var lot := PARKING_LOT.instantiate() as Node3D
	lot.name = "ParkingLot"
	lot.position = local + Vector3(0, CURB, 0)
	root.add_child(lot)
	var van := VAN.instantiate() as Node3D
	van.name = "ParkedVan"
	van.position = local + Vector3(-15.5, CURB, 2.0)
	van.rotation_degrees.y = 90.0
	root.add_child(van)


func _build_lot(root: Node3D, lot: Dictionary) -> void:
	var style := CityBuildings.style_of(lot)
	if style == "park":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed_value * 131 + int(lot.id)
	var f: Vector3 = lot.facing
	var local_c: Vector3 = lot.center - layout.block_center(lot.block)
	var ctx := {
		"root": root, "lot": lot, "f": f, "across": Vector3(f.z, 0.0, -f.x),
		"perp": local_c - f * local_c.dot(f), "rng": rng,
	}
	match style:
		"house":
			buildings.house(ctx)
		"villa":
			buildings.villa(ctx)
		"apartment":
			buildings.apartment(ctx)
		"office":
			buildings.office(ctx)
		"shop":
			buildings.shop(ctx)
		"home":
			buildings.home(ctx)
		"special":
			buildings.special(ctx)
			if special_hook.is_valid():
				special_hook.call(lot, root, ctx.pos, ctx.size)


static func is_open_house(lot: Dictionary) -> bool:
	return CityBuildings.is_open_house(lot)


# --- Intersections ---------------------------------------------------------------------------------

## The crossing at this block's north-west corner: zebra crossings on all four arms, stop lines, two
## signal poles with a head for each approach, and the street-name plates.
func _build_intersection(root: Node3D, b: Vector2i) -> void:
	var c := Vector3(-(CityLayout.BLOCK * 0.5 + CityLayout.ROAD * 0.5), 0.0, -(CityLayout.BLOCK * 0.5 + CityLayout.ROAD * 0.5))
	var half := CityLayout.ROAD * 0.5
	var white := Color(0.9, 0.9, 0.9)
	var xforms: Array[Transform3D] = []
	for arm in 4:
		var dir := Vector3(1, 0, 0).rotated(Vector3.UP, arm * PI * 0.5)
		var side := Vector3(-dir.z, 0, dir.x)
		# zebra stripes run along the road, spaced across it
		var stripe_basis := Basis(Vector3.UP, atan2(-dir.z, dir.x))
		for k in range(-5, 6):
			xforms.append(Transform3D(stripe_basis, c + dir * (half + 2.2) + side * (float(k) * 1.15) + Vector3(0, 0.045, 0)))
		var line_size := Vector3(0.4, 0.035, half) if absf(dir.x) > 0.5 else Vector3(half, 0.035, 0.4)
		box(root, line_size, c + dir * (half + 5.0) - side * half * 0.5 + Vector3(0, 0.048, 0), white)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _crosswalk_mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Crosswalks"
	mmi.multimesh = mm
	mmi.material_override = mat(white)
	root.add_child(mmi)
	# two opposite corners carry a pole; each pole has a head for each road
	var p1 := c + Vector3(half + 1.5, CURB, half + 1.5)
	var p2 := c + Vector3(-half - 1.5, CURB, -half - 1.5)
	_signal_pole(root, p1, Vector3(0, 0, 1), Vector3(1, 0, 0))
	_signal_pole(root, p2, Vector3(0, 0, -1), Vector3(-1, 0, 0))
	_street_plates(root, p1, b)


## One pole with two heads: "ns" faces along z (traffic on the vertical street), "ew" along x.
func _signal_pole(root: Node3D, p: Vector3, ns_dir: Vector3, ew_dir: Vector3) -> void:
	box(root, Vector3(0.25, 5.6, 0.25), p + Vector3(0, 2.8, 0), Color(0.18, 0.18, 0.2))
	collider(root, Vector3(0.5, 5.6, 0.5), p + Vector3(0, 2.8, 0))
	_head(root, p + Vector3(0, 5.0, 0) + ns_dir * 0.35, ns_dir, "ns")
	_head(root, p + Vector3(0, 3.9, 0) + ew_dir * 0.35, ew_dir, "ew")


func _head(root: Node3D, p: Vector3, face: Vector3, axis: String) -> void:
	box(root, Vector3(0.4, 1.3, 0.4), p, Color(0.08, 0.08, 0.09))
	var lamps: Array = _signal_mats[axis]
	for i in 3:
		var lamp := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.26, 0.26, 0.26)
		lamp.mesh = bm
		lamp.material_override = lamps[i]
		lamp.position = p + Vector3(0, 0.4 - 0.4 * float(i), 0) + face * 0.2
		root.add_child(lamp)


## Green street-name plates on a pole, one per street, readable from both sides.
func _street_plates(root: Node3D, p: Vector3, b: Vector2i) -> void:
	var st := "%s St" % CityLayout.STREETS[b.y % CityLayout.STREETS.size()]
	var ave := "%s Ave" % CityLayout.STREETS[b.x % CityLayout.STREETS.size()]
	for pl in [[st, 0.0, 6.7], [ave, 90.0, 6.0]]:
		var node := Node3D.new()
		node.position = p + Vector3(0, pl[2], 0)
		node.rotation_degrees.y = pl[1]
		root.add_child(node)
		box(node, Vector3(3.4, 0.55, 0.08), Vector3.ZERO, Color(0.05, 0.4, 0.2))
		for side in [1.0, -1.0]:
			var l := Label3D.new()
			l.text = pl[0]
			l.font_size = 64
			l.pixel_size = 0.0085
			l.double_sided = false
			l.position = Vector3(0, 0, 0.05 * side)
			if side < 0.0:
				l.rotation_degrees.y = 180.0
			node.add_child(l)


## Street trees along the pavement and a few cars parked at the kerb.
func _street_furniture(root: Node3D, rng: RandomNumberGenerator) -> void:
	var edge := CityLayout.BLOCK * 0.5 - 2.5
	for side in 4:
		var dir: Vector3 = CityLayout.SIDE_DIR[side]
		var along := Vector3(dir.z, 0, -dir.x)
		for k in [-30.0, 0.0, 30.0]:
			if rng.randf() < 0.6:
				tree(root, dir * edge + along * (k + rng.randf_range(-4.0, 4.0)) + Vector3(0, CURB, 0), rng)
		for _c in 2:
			if rng.randf() < 0.6:
				_parked_car(root, dir * (CityLayout.BLOCK * 0.5 + 3.4) + along * rng.randf_range(-45.0, 45.0), along, rng)


func _parked_car(root: Node3D, p: Vector3, along: Vector3, rng: RandomNumberGenerator) -> void:
	var col: Color = CAR_COLORS[rng.randi() % CAR_COLORS.size()]
	var car := Node3D.new()
	car.position = p
	car.rotation.y = atan2(-along.x, -along.z)
	root.add_child(car)
	box(car, Vector3(1.9, 0.7, 4.3), Vector3(0, 0.65, 0), col)
	box(car, Vector3(1.7, 0.6, 2.2), Vector3(0, 1.25, 0.1), col.darkened(0.2))
	box(car, Vector3(1.75, 0.45, 2.0), Vector3(0, 1.27, 0.1), Color(0.1, 0.15, 0.2))
	for sx in [-1.0, 1.0]:
		for sz in [-1.4, 1.4]:
			box(car, Vector3(0.25, 0.6, 0.6), Vector3(sx * 0.95, 0.3, sz), Color(0.05, 0.05, 0.06))
	collider(car, Vector3(1.9, 1.5, 4.3), Vector3(0, 0.75, 0))


func tree(parent: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.25
	tm.bottom_radius = 0.3
	tm.height = 2.2
	trunk.mesh = tm
	trunk.material_override = mat(Color(0.28, 0.18, 0.1))
	trunk.position = p + Vector3(0, 1.1, 0)
	parent.add_child(trunk)
	collider(parent, Vector3(0.7, 3.0, 0.7), p + Vector3(0, 1.5, 0))
	var crown := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = rng.randf_range(1.6, 2.4)
	cm.height = rng.randf_range(3.5, 5.0)
	crown.mesh = cm
	crown.material_override = mat(Color(0.1, rng.randf_range(0.3, 0.45), 0.12))
	crown.position = p + Vector3(0, 2.2 + cm.height * 0.5, 0)
	parent.add_child(crown)


func _lamp(parent: Node3D, p: Vector3) -> void:
	box(parent, Vector3(0.25, 5.0, 0.25), p + Vector3(0, 2.5, 0), Color(0.15, 0.15, 0.17))
	collider(parent, Vector3(0.5, 5.0, 0.5), p + Vector3(0, 2.5, 0))
	lit_box(parent, Vector3(0.7, 0.35, 0.7), p + Vector3(0, 5.1, 0), Color(1.0, 0.85, 0.55), 2.0)


# --- Mesh helpers ---------------------------------------------------------------------------------

func mat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


func box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func lit_box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, energy: float) -> MeshInstance3D:
	var mi := box(parent, size, pos, c)
	mi.material_override = mat(c, energy)
	return mi


func solid_box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	return solid_box_mat(parent, size, pos, mat(c))


## An invisible solid box: the collision for things that are drawn as several small pieces.
func collider(parent: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = pos
	parent.add_child(body)
	return body


## A solid box with its own material (the building facades).
func solid_box_mat(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	mi.add_child(body)
	return mi
