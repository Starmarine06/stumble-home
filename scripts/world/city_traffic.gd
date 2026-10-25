class_name CityTraffic
extends Node3D
## Cars that live on the city's streets. They drive on the right, keep a lane, follow the car in
## front at a safe distance, stop at the line on red (and on amber when they can), turn left or
## right at junctions (a left turn waits for a gap in oncoming traffic) and stop for anyone on foot
## or on a scooter in their path. They only exist near a viewer: spawned out of sight, freed once
## everyone has moved away. Each peer simulates its own cars; the signals use wall-clock time so they
## agree everywhere. A car that hits the local player knocks them flat.

const LANE := 3.4                  # lane centre, from the street centre line
const MAX_CARS := 24
const SPAWN_NEAR := 80.0           # never spawn closer than this to a viewer
const SPAWN_FAR := 200.0
const DESPAWN := 270.0
const ACCEL := 3.5
const BRAKE := 8.0                 # comfortable braking
const BRAKE_MAX := 14.0            # emergency braking
const CAR_LEN := 4.4
const GAP_MIN := 2.5
const TURN_SPEED := 6.0
const HIT_SPEED := 2.5             # a car slower than this just nudges, it does not knock you down
const HALF := CityLayout.ROAD * 0.5
const STOP_DIST := HALF + 6.7      # car centre to the middle of the junction when waiting at the line
const LOOKAHEAD := 24.0
const LEFT_PATIENCE := 7.0         # a left turn gives up waiting for a gap after this long

var city: CityBuilder
var cars: Array = []
var hits := 0                      # how many times a car has knocked the local player down (for tests)
var enabled := true

var _rng := RandomNumberGenerator.new()
var _spawn_t := 0.0
var _hit_cool := 0.0
var _body_mats: Dictionary = {}


class Car:
	extends RefCounted
	var node: AnimatableBody3D
	var tails: Array = []
	var axis := 0                  # 0 drives along x, 1 along z
	var line := 0                  # index of the street it is on
	var dir := 1
	var s := 0.0                   # coordinate along its axis
	var v := 0.0
	var cruise := 11.0
	var next_j := 0                # index of the next junction ahead on its street
	var maneuver := ""             # "", "straight", "left" or "right" once decided
	var turn := {}                 # active junction turn
	var wait := 0.0
	var braking := false
	var dead := false


func _ready() -> void:
	_rng.randomize()


# --- Geometry ----------------------------------------------------------------------------------------

static func dir_vec(axis: int, dir: int) -> Vector3:
	return Vector3(float(dir), 0.0, 0.0) if axis == 0 else Vector3(0.0, 0.0, float(dir))


## The lane point on street `line` at coordinate s, driving direction dir (drive on the right).
func lane_pos(axis: int, line: int, dir: int, s: float) -> Vector3:
	var c := city.layout.road_line(line)
	var base := Vector3(s, 0.0, c) if axis == 0 else Vector3(c, 0.0, s)
	return base + dir_vec(axis, dir).cross(Vector3.UP) * LANE


## Index of the first junction ahead of coordinate s going in dir.
func _next_junction(s: float, dir: int) -> int:
	var jf := s / CityLayout.PITCH + float(city.layout.blocks) * 0.5
	return ceili(jf) if dir > 0 else floori(jf)


func _in_grid(j: int) -> bool:
	return j >= 0 and j <= city.layout.blocks


# --- Frame ---------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if city == null or city.layout == null:
		return
	var game := get_node_or_null("/root/Game")
	if not enabled or (game != null and game.phase != game.Phase.SCAVENGE):
		if not cars.is_empty():
			clear()
		return
	var viewers := _viewers()
	if viewers.is_empty():
		return
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 0.3
		if cars.size() < MAX_CARS:
			_try_spawn(viewers)
	var blockers := _blockers()
	var sig := city.signal_state()
	for car: Car in cars:
		_step(car, delta, sig, blockers)
	_check_hits(blockers, delta)
	var keep: Array = []
	for car in cars:
		var far := true
		for v in viewers:
			if v.distance_to(car.node.position) < DESPAWN:
				far = false
				break
		if far or car.dead:
			car.node.queue_free()
		else:
			keep.append(car)
	cars = keep


func clear() -> void:
	for car in cars:
		car.node.queue_free()
	cars.clear()


func _viewers() -> Array:
	var out: Array = []
	for p in city.view_points:
		out.append(city.to_local(p))
	return out


## Everything a car must not hit: people on foot and scooters, in this node's coordinates.
func _blockers() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("player"):
		if n is Node3D and int(n.get("riding")) == 0:
			out.append({"pos": city.to_local(n.global_position), "node": n, "kind": "foot"})
	for n in get_tree().get_nodes_in_group("scooter"):
		if n is Node3D:
			out.append({"pos": city.to_local(n.global_position), "node": n, "kind": "scooter"})
	return out


# --- Spawning -------------------------------------------------------------------------------------------

func _try_spawn(viewers: Array) -> void:
	var lay := city.layout
	var v: Vector3 = viewers[_rng.randi() % viewers.size()]
	var axis := _rng.randi() % 2
	var across := v.z if axis == 0 else v.x
	var along := v.x if axis == 0 else v.z
	var line := clampi(roundi(across / CityLayout.PITCH + float(lay.blocks) * 0.5) + _rng.randi_range(-2, 2), 0, lay.blocks)
	var s := along + (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(SPAWN_NEAR, SPAWN_FAR)
	var limit := lay.half_extent() - 30.0
	if absf(s) > limit:
		return
	var dir := 1 if _rng.randf() < 0.5 else -1
	var nj := _next_junction(s, dir)
	if not _in_grid(nj):
		return
	# not inside a junction or right at its line, and not on top of another car or in view
	var cross := lay.road_line(nj)
	if absf(cross - s) < STOP_DIST + 6.0 or absf(lay.road_line(nj - dir) - s) < STOP_DIST:
		return
	var pos := lane_pos(axis, line, dir, s)
	for vw in viewers:
		if vw.distance_to(pos) < SPAWN_NEAR:
			return
	for o: Car in cars:
		if o.node.position.distance_to(pos) < 16.0:
			return
	var car := Car.new()
	car.axis = axis
	car.line = line
	car.dir = dir
	car.s = s
	car.next_j = nj
	car.cruise = _rng.randf_range(9.0, 13.0)
	car.v = car.cruise * 0.7
	_make_car(car)
	_place(car)
	add_child(car.node)
	cars.append(car)


# --- Driving ---------------------------------------------------------------------------------------------

func _place(car: Car) -> void:
	var d := dir_vec(car.axis, car.dir)
	car.node.position = lane_pos(car.axis, car.line, car.dir, car.s)
	car.node.rotation.y = atan2(-d.x, -d.z)


## Speed at which a car can still stop in `gap` metres, given the obstacle moves at `v_obstacle`.
static func _safe_speed(gap: float, v_obstacle: float) -> float:
	return sqrt(v_obstacle * v_obstacle + 2.0 * BRAKE * 0.7 * maxf(gap, 0.0))


func _step(car: Car, delta: float, sig: Dictionary, blockers: Array) -> void:
	var target := car.cruise
	if not car.turn.is_empty():
		target = TURN_SPEED
	else:
		target = minf(target, _junction_limit(car, delta, sig))
		target = minf(target, _leader_limit(car))
	target = minf(target, _blocker_limit(car, blockers))
	car.braking = target < car.v - 0.3
	if car.v < target:
		car.v = minf(target, car.v + ACCEL * delta)
	else:
		car.v = maxf(target, car.v - BRAKE_MAX * delta)
	_set_tail_lights(car)
	if not car.turn.is_empty():
		_advance_turn(car, delta)
		return
	car.s += float(car.dir) * car.v * delta
	var dist := (city.layout.road_line(car.next_j) - car.s) * float(car.dir)
	if car.maneuver != "straight" and car.maneuver != "" and dist <= HALF:
		_start_turn(car)
	elif dist <= 0.0:
		car.next_j += car.dir
		car.maneuver = ""
		if not _in_grid(car.next_j):
			car.dead = true
	_place(car)


## The speed this car may carry given the next junction: stop at the line for red, for amber it
## cannot beat, and for a left turn that has no gap yet.
func _junction_limit(car: Car, delta: float, sig: Dictionary) -> float:
	var dist := (city.layout.road_line(car.next_j) - car.s) * float(car.dir)
	if car.maneuver == "" and dist < STOP_DIST + 30.0:
		car.maneuver = _choose(car)
	var to_line := dist - STOP_DIST
	if to_line < -1.5:
		return car.cruise                                         # already through the line
	var state := int(sig["ew" if car.axis == 0 else "ns"])
	var need := car.v * car.v / (2.0 * BRAKE)
	var must_stop := state == 0 or (state == 1 and to_line >= need)
	if car.maneuver == "left" and to_line < need + 8.0:
		if _oncoming(car):
			car.wait += delta
			if car.wait < LEFT_PATIENCE:
				must_stop = true
		else:
			car.wait = 0.0
	if must_stop:
		if to_line <= 0.2:
			return 0.0
		return sqrt(2.0 * BRAKE * 0.8 * to_line)
	return car.cruise


func _leader_limit(car: Car) -> float:
	var best := car.cruise
	for o: Car in cars:
		if o == car or o.axis != car.axis or o.line != car.line or o.dir != car.dir:
			continue
		var ahead: float = (o.s - car.s) * float(car.dir)
		if ahead <= 0.0 or ahead > LOOKAHEAD + CAR_LEN:
			continue
		best = minf(best, 0.0 if ahead - CAR_LEN < GAP_MIN else _safe_speed(ahead - CAR_LEN - GAP_MIN, o.v))
	return best


## Slow for a person or scooter straight ahead in the car's path (also while turning).
func _blocker_limit(car: Car, blockers: Array) -> float:
	var best := car.cruise
	var fwd := -car.node.basis.z
	var right := fwd.cross(Vector3.UP)
	for b in blockers:
		var rel: Vector3 = b.pos - car.node.position
		var along := rel.dot(fwd)
		if along < 0.5 or along > LOOKAHEAD or absf(rel.dot(right)) > 2.3:
			continue
		best = minf(best, 0.0 if along - 2.6 < 1.0 else _safe_speed(along - 3.6, 0.0))
	return best


## Is something coming the other way that a left turn must wait for?
func _oncoming(car: Car) -> bool:
	for o: Car in cars:
		if o == car or o.axis != car.axis or o.line != car.line or o.dir == car.dir or o.next_j != car.next_j:
			continue
		var od: float = (city.layout.road_line(o.next_j) - o.s) * float(o.dir)
		if od > -HALF - 3.0 and od < 32.0 and (o.v > 1.5 or od < HALF + 2.0):
			return true
	return false


## Straight on mostly, with a turn now and then; never off the edge of the map.
func _choose(car: Car) -> String:
	var options: Array = []
	if _in_grid(car.next_j + car.dir):
		options.append(["straight", 6])
	var right_dir := car.dir if car.axis == 0 else -car.dir
	if _in_grid(car.line + right_dir):
		options.append(["right", 2])
	if _in_grid(car.line - right_dir):
		options.append(["left", 2])
	var total := 0
	for o in options:
		total += int(o[1])
	var roll := _rng.randi() % total
	for o in options:
		roll -= int(o[1])
		if roll < 0:
			return o[0]
	return options[0][0]


func _start_turn(car: Car) -> void:
	var lay := city.layout
	var right_dir := car.dir if car.axis == 0 else -car.dir
	var new_dir := right_dir if car.maneuver == "right" else -right_dir
	var new_axis := 1 - car.axis
	var c := lay.node_pos(car.next_j, car.line) if car.axis == 0 else lay.node_pos(car.line, car.next_j)
	var d_in := dir_vec(car.axis, car.dir)
	var d_out := dir_vec(new_axis, new_dir)
	var right_in := d_in.cross(Vector3.UP)
	var right_out := d_out.cross(Vector3.UP)
	var e := c - d_in * HALF + right_in * LANE
	var p := c + right_in * LANE + right_out * LANE
	var x := c + d_out * HALF + right_out * LANE
	var length := 0.0
	var prev := e
	for k in range(1, 9):
		var pt := _bezier(e, p, x, float(k) / 8.0)
		length += prev.distance_to(pt)
		prev = pt
	car.turn = {
		"e": e, "p": p, "x": x, "len": length, "u": 0.0,
		"axis": new_axis, "dir": new_dir, "line": car.next_j, "next": car.line + new_dir,
	}


static func _bezier(a: Vector3, b: Vector3, c: Vector3, u: float) -> Vector3:
	return a.lerp(b, u).lerp(b.lerp(c, u), u)


func _advance_turn(car: Car, delta: float) -> void:
	var t: Dictionary = car.turn
	t["u"] = minf(1.0, float(t["u"]) + car.v * delta / maxf(float(t["len"]), 0.1))
	var u := float(t["u"])
	var pos := _bezier(t["e"], t["p"], t["x"], u)
	var tangent: Vector3 = ((t["p"] - t["e"]).lerp(t["x"] - t["p"], u)).normalized()
	car.node.position = pos
	car.node.rotation.y = atan2(-tangent.x, -tangent.z)
	if u >= 1.0:
		car.axis = int(t["axis"])
		car.dir = int(t["dir"])
		car.line = int(t["line"])
		car.next_j = int(t["next"])
		car.s = pos.x if car.axis == 0 else pos.z
		car.maneuver = ""
		car.wait = 0.0
		car.turn = {}
		if not _in_grid(car.next_j):
			car.dead = true


# --- Hitting people ---------------------------------------------------------------------------------------

## A moving car that touches the local player throws them clear. Scooters need no help: the car
## is a solid body and the scooter's own collision already costs them speed and shakes the parcel.
func _check_hits(blockers: Array, delta: float) -> void:
	_hit_cool = maxf(0.0, _hit_cool - delta)
	if _hit_cool > 0.0:
		return
	for car: Car in cars:
		if car.v < HIT_SPEED:
			continue
		var inv: Basis = car.node.basis.inverse()
		for b in blockers:
			if b.kind != "foot" or not b.node.has_method("knock") or not b.node.is_local():
				continue
			var rel: Vector3 = inv * (b.pos - car.node.position)
			if absf(rel.x) < 1.5 and rel.z > -3.1 and rel.z < 2.6 and rel.y > -1.0 and rel.y < 2.2:
				b.node.knock(-car.node.basis.z, car.v)
				hits += 1
				_hit_cool = 2.0
				car.v = 0.0
				return


# --- Looks -------------------------------------------------------------------------------------------------

func _make_car(car: Car) -> void:
	var rng := _rng
	var body := AnimatableBody3D.new()
	body.sync_to_physics = true
	var kind := rng.randi() % 5       # 0..2 sedans, 3 van, 4 taxi
	var col: Color = CityBuilder.CAR_COLORS[rng.randi() % CityBuilder.CAR_COLORS.size()]
	var w := 1.9
	var len := CAR_LEN
	var h := 0.7
	if kind == 3:
		col = Color(0.9, 0.9, 0.92)
		w = 2.0
		len = 5.0
		h = 1.5
	elif kind == 4:
		col = Color(0.95, 0.75, 0.1)
	city.box(body, Vector3(w, h, len), Vector3(0, 0.65 + (h - 0.7) * 0.5, 0), col)
	if kind != 3:
		city.box(body, Vector3(w - 0.2, 0.6, 2.2), Vector3(0, 1.25, 0.1), col.darkened(0.2))
		city.box(body, Vector3(w - 0.15, 0.45, 2.0), Vector3(0, 1.27, 0.1), Color(0.1, 0.15, 0.2))
	else:
		city.box(body, Vector3(w - 0.1, 0.5, 0.1), Vector3(0, 1.6, -len * 0.5 + 0.9), Color(0.1, 0.15, 0.2))
	if kind == 4:
		city.lit_box(body, Vector3(0.7, 0.25, 0.3), Vector3(0, 1.7, 0.1), Color(1.0, 0.95, 0.6), 1.5)
	for sx in [-1.0, 1.0]:
		for sz in [-len * 0.3, len * 0.3]:
			city.box(body, Vector3(0.25, 0.6, 0.6), Vector3(sx * (w * 0.5 - 0.05), 0.3, sz), Color(0.05, 0.05, 0.06))
		city.lit_box(body, Vector3(0.4, 0.2, 0.1), Vector3(sx * (w * 0.5 - 0.4), 0.8, -len * 0.5 - 0.02), Color(1.0, 0.95, 0.75), 1.4)
		var tail := city.box(body, Vector3(0.4, 0.2, 0.1), Vector3(sx * (w * 0.5 - 0.4), 0.8, len * 0.5 + 0.02), Color(0.5, 0.05, 0.05))
		tail.material_override = city.mat(Color(0.6, 0.05, 0.05), 0.4)
		car.tails.append(tail)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, h + 0.8, len)
	cs.shape = bs
	cs.position.y = 0.75
	body.add_child(cs)
	body.add_to_group("traffic")
	car.node = body
	_set_tail_lights(car)


func _set_tail_lights(car: Car) -> void:
	var m := city.mat(Color(1.0, 0.05, 0.05), 3.0) if car.braking else city.mat(Color(0.6, 0.05, 0.05), 0.4)
	for t in car.tails:
		if t.material_override != m:
			t.material_override = m
