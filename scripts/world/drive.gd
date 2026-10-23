class_name Drive
extends Node3D
## The drive home. The Driver's peer simulates the car and streams its state;
## everyone else follows. The route is built from the shared seed, but only the
## Navigator's HUD shows it.

const ROAD_W := 10.0
const MAX_SPEED := 24.0
const HOT_SPEED := 8.0
const LEGS := 7

var pts: Array[Vector3] = []
var turns: Array[int] = []      # +1 right, -1 left; turns[i] is the corner at pts[i + 1]
var car: Node3D
var speed := 0.0
var yaw := 0.0
var leg := 0
var is_driver := false
var drunk: Drunk
var blackout := 0.0             # 0..1, only meaningful on the Driver's peer

var _seed := 0
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _blackout_left := 0.0
var _nod_in := 14.0
var _hiccup_in := 6.0
var _kick := 0.0
var _dmg_acc := 0.0
var _dmg_timer := 0.0
var _crash_cd := 0.0
var _send_t := 0.0
var _arrived_sent := false
var _cop: Node3D
var _cop_time := 0.0


func setup(drive_seed: int, p_car: Node3D) -> void:
	_seed = drive_seed
	car = p_car
	_generate()
	_build_scenery()
	car.position = pts[0]
	car.rotation = Vector3.ZERO
	_target_pos = car.position
	is_driver = Game.has_role(Roles.Id.DRIVER)
	drunk = Drunk.new(Roles.role_drunk(Roles.Id.DRIVER))
	_nod_in = randf_range(10.0, 16.0)
	Game.car_state.connect(_on_car_state)
	Game.cop_warning.connect(_on_cop_warning)


func _exit_tree() -> void:
	if Game.car_state.is_connected(_on_car_state):
		Game.car_state.disconnect(_on_car_state)
	if Game.cop_warning.is_connected(_on_cop_warning):
		Game.cop_warning.disconnect(_on_cop_warning)


# --- Route ---------------------------------------------------------------------------

func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var p := Vector3.ZERO
	var dir := Vector3(0, 0, -1)
	pts = [p]
	turns = []
	for i in LEGS:
		p += dir * rng.randf_range(70.0, 120.0)
		pts.append(p)
		if i < LEGS - 1:
			var t := 1 if rng.randf() < 0.5 else -1
			var n := turns.size()
			if n >= 2 and turns[n - 1] == turns[n - 2]:
				t = -turns[n - 1]
			turns.append(t)
			dir = dir.rotated(Vector3.UP, -t * PI * 0.5)


func _seg_query(p: Vector3, a: Vector3, b: Vector3) -> Dictionary:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	var c := Vector2(a.x, a.z) + ab * t
	return {"d": Vector2(p.x, p.z).distance_to(c), "pt": Vector3(c.x, 0.0, c.y)}


func path_query(p: Vector3) -> Dictionary:
	var best := {"d": INF, "pt": Vector3.ZERO}
	for i in pts.size() - 1:
		var q := _seg_query(p, pts[i], pts[i + 1])
		if q.d < best.d:
			best = q
	return best


func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 1
	_mesh_box(Vector3(4000, 1, 4000), Vector3(0, -0.55, 0), Color(0.08, 0.1, 0.08))
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var mid := (a + b) * 0.5
		var len := a.distance_to(b)
		var yaw_s := atan2(-(b.x - a.x), -(b.z - a.z))
		var road := _mesh_box(Vector3(ROAD_W, 0.1, len + ROAD_W), mid + Vector3(0, -0.02, 0), Color(0.12, 0.12, 0.14))
		road.rotation.y = yaw_s
		var line := _mesh_box(Vector3(0.3, 0.12, len + ROAD_W), mid + Vector3(0, 0.0, 0), Color(0.9, 0.8, 0.2))
		line.rotation.y = yaw_s
	for _i in 220:
		var seg := rng.randi_range(0, pts.size() - 2)
		var t := rng.randf()
		var base := pts[seg].lerp(pts[seg + 1], t)
		var off := Vector3(rng.randf_range(-70, 70), 0, rng.randf_range(-70, 70))
		var pos := base + off
		if path_query(pos).d < ROAD_W * 0.5 + 12.0:
			continue
		var h := rng.randf_range(6.0, 34.0)
		var w := rng.randf_range(8.0, 18.0)
		var shade := rng.randf_range(0.15, 0.4)
		_mesh_box(Vector3(w, h, w), pos + Vector3(0, h * 0.5, 0), Color(shade, shade * 0.9, shade * 1.2))
	# Home
	var end := pts[pts.size() - 1]
	var last_dir := (end - pts[pts.size() - 2]).normalized()
	var home_pos := end + last_dir * 14.0
	_mesh_box(Vector3(14, 8, 10), home_pos + Vector3(0, 4, 0), Color(0.9, 0.75, 0.5))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.5)
	light.light_energy = 3.0
	light.omni_range = 40.0
	light.position = end + Vector3(0, 6, 0)
	add_child(light)
	var sign := Label3D.new()
	sign.text = "HOME"
	sign.font_size = 200
	sign.pixel_size = 0.02
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color(1, 0.9, 0.5)
	sign.position = home_pos + Vector3(0, 12, 0)
	add_child(sign)


func _mesh_box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


# --- Navigation (what the Navigator reads) ---------------------------------------------

func nav() -> Dictionary:
	var corner := pts[mini(leg + 1, pts.size() - 1)]
	var dist := Vector2(car.position.x - corner.x, car.position.z - corner.z).length()
	var final := leg + 1 >= pts.size() - 1
	return {"dist": dist, "dir": 0 if final else turns[leg], "final": final}


func _update_leg() -> void:
	while leg < pts.size() - 2:
		var a := pts[leg + 1]
		var b := pts[leg + 2]
		var q := _seg_query(car.position, a, b)
		var proj := (car.position - a).dot((b - a).normalized())
		if q.d < ROAD_W * 0.5 and proj > 0.0:
			leg += 1
		else:
			break


# --- Simulation --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if car == null:
		return
	if is_driver:
		_drive_step(delta)
	else:
		car.position = car.position.lerp(_target_pos, clampf(12.0 * delta, 0.0, 1.0))
		car.rotation.y = lerp_angle(car.rotation.y, _target_yaw, clampf(12.0 * delta, 0.0, 1.0))
	_update_leg()
	if _cop:
		_cop_time -= delta
		_cop.visible = Game.has_role(Roles.Id.LOOKOUT)
		if _cop_time <= 0.0:
			_cop.queue_free()
			_cop = null


func _drive_step(delta: float) -> void:
	drunk.tick(delta, false)
	_nod_in -= delta
	if _nod_in <= 0.0 and _blackout_left <= 0.0:
		_blackout_left = 0.9
		_nod_in = randf_range(14.0, 22.0)
	var steer_raw := Input.get_axis("left", "right")
	var thr := Input.get_axis("back", "forward")
	blackout = 0.0
	if _blackout_left > 0.0:
		_blackout_left -= delta
		steer_raw = 0.0
		blackout = clampf(_blackout_left / 0.3, 0.0, 1.0) * clampf((0.9 - _blackout_left) / 0.2, 0.0, 1.0)
	_hiccup_in -= delta
	if _hiccup_in <= 0.0:
		_hiccup_in = randf_range(5.0, 9.0)
		_kick = randf_range(-1.0, 1.0) * 0.9 * drunk.level
	_kick = move_toward(_kick, 0.0, 2.5 * delta)
	var steer := clampf(drunk.steer1(steer_raw) + _kick, -1.0, 1.0)

	var max_speed := HOT_SPEED if Game.engine_hot else MAX_SPEED
	if thr > 0.0:
		speed += 9.0 * delta * thr
	elif thr < 0.0:
		speed += 18.0 * delta * thr
	else:
		speed = move_toward(speed, 0.0, 3.0 * delta)
	speed = clampf(speed, -6.0, max_speed)
	var turn_rate := 1.7 * clampf(absf(speed) / 8.0, 0.0, 1.0)
	yaw -= steer * turn_rate * delta * signf(speed)
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	car.position += fwd * speed * delta
	car.rotation.y = yaw

	var q := path_query(car.position)
	_crash_cd = maxf(0.0, _crash_cd - delta)
	if q.d > 8.0:
		speed = -2.0
		car.position += (q.pt - car.position).normalized() * 3.0
		if _crash_cd <= 0.0:
			_crash_cd = 1.5
			_dmg_acc += 10.0
			Game.request_car_damage(10.0, 6.0)
			Game.toast_msg.emit("CRASH!")
	elif q.d > ROAD_W * 0.5:
		speed = minf(speed, 7.0)
		_dmg_acc += 3.0 * delta
	_dmg_timer += delta
	if _dmg_timer >= 0.5:
		_dmg_timer = 0.0
		if _dmg_acc > 0.01:
			Game.request_car_damage(_dmg_acc, 0.0)
			_dmg_acc = 0.0

	_send_t += delta
	if _send_t >= 0.05:
		_send_t = 0.0
		Game.send_car_state(car.position, yaw, speed)
	if not _arrived_sent and Vector2(car.position.x - pts[-1].x, car.position.z - pts[-1].z).length() < 10.0:
		_arrived_sent = true
		Game.request_arrived()


func _on_car_state(pos: Vector3, p_yaw: float, p_speed: float) -> void:
	if is_driver:
		return
	_target_pos = pos
	_target_yaw = p_yaw
	speed = p_speed


func _on_cop_warning(side: String, seconds: float) -> void:
	if _cop:
		_cop.queue_free()
	_cop = Node3D.new()
	var s := -1.0 if side == "LEFT" else 1.0
	var fwd := Vector3(-sin(car.rotation.y), 0.0, -cos(car.rotation.y))
	var right := fwd.cross(Vector3.UP)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 1.4, 4.6)
	body.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.9, 0.95)
	body.material_override = m
	body.position.y = 0.8
	_cop.add_child(body)
	for c in [Color(1, 0.1, 0.1), Color(0.1, 0.2, 1)]:
		var l := OmniLight3D.new()
		l.light_color = c
		l.light_energy = 4.0
		l.omni_range = 30.0
		l.position = Vector3(0 if c.r > 0.5 else 0.8, 2.0, 0)
		_cop.add_child(l)
	_cop.position = car.position + fwd * 45.0 + right * s * 14.0
	_cop.rotation.y = car.rotation.y
	_cop_time = seconds
	add_child(_cop)
