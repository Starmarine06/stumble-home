class_name CityLayout
extends RefCounted
## The city as data: a grid of blocks between streets, what each block is, every lot on it, where
## the casino and the crew's home are, and the route between them. Pure logic with no nodes, and
## fully deterministic from the seed, so every peer builds the same city.
##
## Layout space has the city centre at the origin. World places it so the car park lands on the
## world origin (see World.city_offset). Streets run along grid lines; block (i, j) sits between
## streets i and i + 1 along x, and j and j + 1 along z.

const BLOCKS := 16
const BLOCK := 120.0        # block side, kerb to kerb
const ROAD := 14.0          # street width
const PITCH := BLOCK + ROAD
const CELL := 30.0          # a lot is one cell of the 4 x 4 grid inside a block
const SETBACK := 10.0       # clear pavement between the kerb and a building front
const STREETS := ["Elm", "Oak", "Maple", "Cedar", "Pine", "Birch", "Willow", "Ash", "Poplar", "Hazel", "Alder", "Rowan", "Spruce", "Larch", "Yew", "Fir", "Linden", "Holly", "Juniper", "Sycamore"]
## Hand-made places that get a reserved lot near the casino, in the order they are placed.
const LANDMARKS := ["delivery", "garage", "pharmacy", "pawn", "pub", "kebab"]
const SIDE_DIR := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]   # N E S W

## The original map sits in the casino's block: the casino at the back of the 80 x 70 parking lot
## (they were 32 m apart), the van beside the car, and the car park out front. Offsets from the block centre.
const CASINO_OFFSET := Vector3(0.0, 0.0, -22.0)
const PARKING_OFFSET := Vector3(0.0, 0.0, 10.0)      # centre of the parking lot, 32 m in front of the casino
const CARPARK_OFFSET := Vector3(14.0, 0.0, 22.0)     # where the wrecked car and the crew start
## A route has at least this many points (start, corners, door).
const MIN_ROUTE_POINTS := 5

var seed_value := 0
var blocks := BLOCKS
var casino_block := Vector2i.ZERO
var home_block := Vector2i.ZERO
var home_lot: Dictionary = {}
var landmarks: Dictionary = {}       # name -> lot
var _kinds: Dictionary = {}          # Vector2i -> "casino" | "commercial" | "residential" | "park"
var _lots: Dictionary = {}           # Vector2i -> Array of lots
var _special: Dictionary = {}        # lot id -> name


func _init(p_seed: int, p_blocks := BLOCKS, home_min := 9, home_max := 14) -> void:
	seed_value = p_seed
	blocks = p_blocks
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var lo := 3 if blocks > 8 else 1
	casino_block = Vector2i(rng.randi_range(lo, blocks - 1 - lo), rng.randi_range(lo, blocks - 1 - lo))
	for i in blocks:
		for j in blocks:
			var b := Vector2i(i, j)
			var d := grid_dist(b, casino_block)
			var r := rng.randf()
			if b == casino_block:
				_kinds[b] = "casino"
			elif d <= 2:
				_kinds[b] = "commercial"
			elif r < 0.06:
				_kinds[b] = "park"
			elif r < 0.16:
				_kinds[b] = "commercial"
			else:
				_kinds[b] = "residential"
	_pick_home(rng, home_min, home_max)
	_place_landmarks(rng)


static func grid_dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


# --- Geometry -----------------------------------------------------------------------------

## Coordinate of street i (the same value for the streets running either way).
func road_line(i: int) -> float:
	return (float(i) - float(blocks) * 0.5) * PITCH


func block_center(b: Vector2i) -> Vector3:
	return Vector3((float(b.x) + 0.5 - float(blocks) * 0.5) * PITCH, 0.0, (float(b.y) + 0.5 - float(blocks) * 0.5) * PITCH)


func node_pos(i: int, j: int) -> Vector3:
	return Vector3(road_line(i), 0.0, road_line(j))


## Half the width of the whole city, edge of the outer streets included.
func half_extent() -> float:
	return float(blocks) * PITCH * 0.5 + ROAD * 0.5


func block_at(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x / PITCH + float(blocks) * 0.5)), 0, blocks - 1), clampi(int(floor(p.z / PITCH + float(blocks) * 0.5)), 0, blocks - 1))


func block_kind(b: Vector2i) -> String:
	return _kinds.get(b, "residential")


func casino_origin() -> Vector3:
	return block_center(casino_block) + CASINO_OFFSET


func carpark_center() -> Vector3:
	return block_center(casino_block) + CARPARK_OFFSET


## Centre of the parking lot the casino and the van stand on.
func parking_center() -> Vector3:
	return block_center(casino_block) + PARKING_OFFSET


# --- Lots ---------------------------------------------------------------------------------

## The 12 lots around the edge of a block (the middle 2 x 2 cells are back gardens).
func lots_of(b: Vector2i) -> Array:
	if _lots.has(b):
		return _lots[b]
	var out: Array = []
	if block_kind(b) != "casino":
		var c := block_center(b)
		var idx := 0
		for cz in 4:
			for cx in 4:
				if cx != 0 and cx != 3 and cz != 0 and cz != 3:
					continue
				var side: int
				if cz == 0:
					side = 0
				elif cz == 3:
					side = 2
				elif cx == 3:
					side = 1
				else:
					side = 3
				var off := Vector3((float(cx) - 1.5) * CELL, 0.0, (float(cz) - 1.5) * CELL)
				var along := cx if side == 0 or side == 2 else cz
				var road_idx := b.y if side == 0 else (b.y + 1 if side == 2 else (b.x + 1 if side == 1 else b.x))
				var along_block := b.x if side == 0 or side == 2 else b.y
				var lot_id := (b.y * blocks + b.x) * 16 + idx
				var center := c + off
				var dir: Vector3 = SIDE_DIR[side]
				out.append({
					"id": lot_id, "block": b, "side": side, "center": center, "facing": dir,
					"kind": _lot_kind(b, lot_id),
					"street": road_idx, "street_name": "%s %s" % [STREETS[road_idx % STREETS.size()], "St" if side == 0 or side == 2 else "Ave"],
					"number": 100 + 2 * (along_block * 4 + along) + (0 if side == 0 or side == 3 else 1),
					# Where the lot meets the road: the middle of the street in front of it.
					"street_point": Vector3(center.x, 0.0, center.z) + dir * (BLOCK * 0.5 + ROAD * 0.5 - (off.x * dir.x + off.z * dir.z)),
				})
				idx += 1
	_lots[b] = out
	return out


## The pavement in front of a lot's door, halfway between the kerb and the building: where you
## stand to ring the bell, and where a parked scooter goes.
func front_point(lot: Dictionary) -> Vector3:
	var c := block_center(lot.block)
	var f: Vector3 = lot.facing
	var local: Vector3 = lot.center - c
	var perp: Vector3 = local - f * local.dot(f)
	return c + perp + f * (BLOCK * 0.5 - SETBACK * 0.5)


func _lot_kind(b: Vector2i, lot_id: int) -> String:
	if _special.has(lot_id):
		return "special"
	if not home_lot.is_empty() and home_lot.id == lot_id:
		return "home"
	match block_kind(b):
		"commercial":
			return "shop"
		"park":
			return "park"
	return "house"


func address(lot: Dictionary) -> String:
	return "%d %s" % [lot.number, lot.street_name]


## Every lot in the city, for tests and for picking delivery addresses.
func all_lots() -> Array:
	var out: Array = []
	for i in blocks:
		for j in blocks:
			out.append_array(lots_of(Vector2i(i, j)))
	return out


func lot_by_id(lot_id: int) -> Dictionary:
	var per_block := 16
	var b_index := lot_id / per_block
	var b := Vector2i(b_index % blocks, b_index / blocks)
	for l in lots_of(b):
		if l.id == lot_id:
			return l
	return {}


func _pick_home(rng: RandomNumberGenerator, home_min: int, home_max: int) -> void:
	var cands: Array = []
	var far: Array = []
	var far_d := -1
	for i in blocks:
		for j in blocks:
			var b := Vector2i(i, j)
			if block_kind(b) != "residential":
				continue
			var d := grid_dist(b, casino_block)
			# Not in line with the casino, or the way home would be one dull straight road.
			if d >= home_min and d <= home_max and absi(b.x - casino_block.x) >= 2 and absi(b.y - casino_block.y) >= 2:
				cands.append(b)
			if d > far_d:
				far_d = d
				far = [b]
			elif d == far_d:
				far.append(b)
	var pool: Array = cands if not cands.is_empty() else far
	home_block = pool[rng.randi_range(0, pool.size() - 1)]
	var lots := lots_of(home_block)
	home_lot = lots[rng.randi_range(0, lots.size() - 1)]


func _place_landmarks(rng: RandomNumberGenerator) -> void:
	var cands: Array = []
	for i in blocks:
		for j in blocks:
			var b := Vector2i(i, j)
			if block_kind(b) == "commercial" and grid_dist(b, casino_block) <= 2:
				for l in lots_of(b):
					cands.append(l)
	# Fisher-Yates with the layout's own stream.
	for k in range(cands.size() - 1, 0, -1):
		var r := rng.randi_range(0, k)
		var tmp = cands[k]
		cands[k] = cands[r]
		cands[r] = tmp
	for n in mini(LANDMARKS.size(), cands.size()):
		_special[cands[n].id] = LANDMARKS[n]
	_lots.clear()
	for l in all_lots():
		if _special.has(l.id):
			l.special = _special[l.id]
			landmarks[l.special] = l
	# Home block lots were rebuilt above; re-point home_lot at the fresh dictionary.
	for l in lots_of(home_block):
		if l.id == home_lot.id:
			home_lot = l


# --- Route ----------------------------------------------------------------------------------

## The point on the street in front of the home door: where the drive ends.
func home_door() -> Vector3:
	return home_lot.street_point


## The way home as corner points in layout space, from the car park to the door.
## Returns {"pts": Array[Vector3], "turns": Array[int]} where turns[i] is +1 for a right turn at pts[i + 1].
func route_points() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 77
	var door := home_door()
	var start := carpark_center()
	var jS := casino_block.y + 1
	var s_pt := Vector3(start.x, 0.0, road_line(jS))
	# Start street segment is between streets casino_block.x and casino_block.x + 1.
	var s_a := Vector2i(casino_block.x, jS)
	var s_b := Vector2i(casino_block.x + 1, jS)
	var d_a: Vector2i
	var d_b: Vector2i
	if home_lot.side == 0 or home_lot.side == 2:
		var jd: int = home_lot.street
		d_a = Vector2i(home_lot.block.x, jd)
		d_b = Vector2i(home_lot.block.x + 1, jd)
	else:
		var idn: int = home_lot.street
		d_a = Vector2i(idn, home_lot.block.y)
		d_b = Vector2i(idn, home_lot.block.y + 1)
	var d_ref := Vector2i((d_a.x + d_b.x) / 2, (d_a.y + d_b.y) / 2)
	var start_int := s_a if grid_dist(s_a, d_ref) <= grid_dist(s_b, d_ref) else s_b
	var end_int := d_a if grid_dist(d_a, start_int) <= grid_dist(d_b, start_int) else d_b

	# Re-roll the walk until it has enough corners to keep the Navigator busy.
	var best := {}
	for _try in 20:
		var raw: Array[Vector3] = [start, s_pt]
		for n in _staircase(start_int, end_int, rng):
			raw.append(node_pos(n.x, n.y))
		raw.append(door)
		var r := _corners(raw)
		if best.is_empty() or r.pts.size() > best.pts.size():
			best = r
		if r.pts.size() >= MIN_ROUTE_POINTS:
			break
	return best


## A random monotone walk along the street grid from a to b, favouring runs of 1 or 2 blocks.
func _staircase(a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> Array:
	var out: Array = [a]
	var cur := a
	var axis := rng.randi_range(0, 1)
	var run_left := rng.randi_range(1, 2)
	while cur != b:
		var dx := signi(b.x - cur.x)
		var dz := signi(b.y - cur.y)
		if dx == 0:
			axis = 1
		elif dz == 0:
			axis = 0
		elif run_left <= 0:
			axis = 1 - axis
			run_left = rng.randi_range(1, 2)
		if axis == 0:
			cur = Vector2i(cur.x + dx, cur.y)
		else:
			cur = Vector2i(cur.x, cur.y + dz)
		run_left -= 1
		out.append(cur)
	return out


static func _corners(raw: Array[Vector3]) -> Dictionary:
	var pts: Array[Vector3] = []
	for p in raw:
		if pts.is_empty() or Vector2(p.x - pts[-1].x, p.z - pts[-1].z).length() > 0.5:
			pts.append(p)
	# Drop points in the middle of a straight run.
	var i := 1
	while i < pts.size() - 1:
		var a := Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).normalized()
		var b := Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z).normalized()
		if absf(a.cross(b)) < 0.01 and a.dot(b) > 0.0:
			pts.remove_at(i)
		else:
			i += 1
	var turns: Array[int] = []
	for k in range(1, pts.size() - 1):
		var a2 := Vector2(pts[k].x - pts[k - 1].x, pts[k].z - pts[k - 1].z)
		var b2 := Vector2(pts[k + 1].x - pts[k].x, pts[k + 1].z - pts[k].z)
		turns.append(1 if (a2.x * b2.y - a2.y * b2.x) > 0.0 else -1)
	return {"pts": pts, "turns": turns}


static func route_length(pts: Array) -> float:
	var t := 0.0
	for i in pts.size() - 1:
		t += Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z).length()
	return t
