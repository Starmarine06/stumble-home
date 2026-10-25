class_name Scooter
extends CharacterBody3D
## The delivery scooter. Whoever the host seats as driver simulates it and streams its state;
## every other peer just follows. It collides with the city (building boxes, the ground) so a
## drunk driver can find walls the hard way, and every bump shakes the parcel.

const MAX_SPEED := 15.0
const ACCEL := 7.0
const BRAKE := 14.0
const REVERSE_MAX := 3.0
const TURN_RATE := 2.3
const GRAVITY := 20.0
const SEAT_DRIVER := Vector3(0.0, 0.1, 0.15)    # origin of a seated player, scooter-local; it faces -Z
const SEAT_PILLION := Vector3(0.0, 0.1, 0.85)
const SEAT_RANGE := 2.2
const STOP_SPEED := 4.0                         # you can only hop off below this

var speed := 0.0
var yaw := 0.0
var yaw_rate := 0.0             # rad/s; the parcel carrier feels this in the corners
var drunk: Drunk
var drive_seat: Interactable
var pillion_seat: Interactable

var _jolt := 0.0                # strength of the last wall hit, taken once by the parcel carrier
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _send_t := 0.0
var _hiccup_in := 5.0
var _kick := 0.0


func _ready() -> void:
	add_to_group("scooter")
	_target_pos = position
	_target_yaw = rotation.y
	yaw = rotation.y
	drunk = Drunk.new(Roles.role_drunk(Roles.Id.DRIVER))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.7, 1.0, 1.9)
	cs.shape = bs
	cs.position.y = 0.5
	add_child(cs)
	_build_model()
	drive_seat = _seat("DriveSeat", Vector3(0.0, 0.5, 0.15), "[E] hop on and drive the scooter", 1)
	pillion_seat = _seat("PillionSeat", Vector3(0.0, 0.5, 0.85), "[E] hop on behind, holding the parcel", 2)
	Game.scooter_state.connect(_on_state)


func _exit_tree() -> void:
	if Game.scooter_state.is_connected(_on_state):
		Game.scooter_state.disconnect(_on_state)


func _seat(node_name: String, pos: Vector3, prompt: String, seat: int) -> Interactable:
	var it := Interactable.new()
	it.name = node_name
	it.position = pos
	it.prompt = prompt
	it.range_m = SEAT_RANGE
	add_child(it)
	it.activated.connect(func(_p): Game.request_seat(seat))
	return it


func _build_model() -> void:
	var body := Color(0.95, 0.5, 0.1)
	var dark := Color(0.12, 0.12, 0.14)
	_part(Vector3(0.45, 0.35, 1.5), Vector3(0, 0.45, 0.0), body)           # deck and body
	_part(Vector3(0.4, 0.5, 0.35), Vector3(0, 0.85, -0.6), body)           # front column
	_part(Vector3(0.9, 0.08, 0.08), Vector3(0, 1.12, -0.62), dark)         # handlebars
	_part(Vector3(0.42, 0.14, 0.7), Vector3(0, 0.72, 0.5), dark)           # saddle
	_part(Vector3(0.25, 0.2, 0.25), Vector3(0, 0.95, -0.82), Color(1.0, 0.95, 0.7), 1.5)   # headlamp
	for z in [-0.65, 0.7]:
		var w := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.28
		cm.bottom_radius = 0.28
		cm.height = 0.16
		w.mesh = cm
		w.rotation_degrees.z = 90.0
		w.position = Vector3(0, 0.28, z)
		w.material_override = _mat(dark)
		add_child(w)


func _part(size: Vector3, pos: Vector3, c: Color, emit := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c, emit)
	mi.position = pos
	add_child(mi)


func _mat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


## The garage's tune-up makes it a quarter faster.
func top_speed() -> float:
	return MAX_SPEED * (1.25 if Game.bought.has("garage/tuneup") else 1.0)


## World position of a seat for the rider.
func seat_global(seat: int) -> Vector3:
	return global_transform * (SEAT_DRIVER if seat == 1 else SEAT_PILLION)


## Park it facing along a direction (for the first frame).
func place(pos: Vector3, p_yaw: float) -> void:
	position = pos
	yaw = p_yaw
	rotation.y = p_yaw
	_target_pos = pos
	_target_yaw = p_yaw


## The strength of the last wall hit, once. Zero when nothing has hit since last asked.
func take_jolt() -> float:
	var j := _jolt
	_jolt = 0.0
	return j


func _process(_delta: float) -> void:
	var me := Game.my_id()
	var seated := Game.seat_driver == me or Game.seat_pillion == me
	drive_seat.enabled = Game.seat_driver == 0 and not seated and Game.phase == Game.Phase.SCAVENGE
	pillion_seat.enabled = Game.seat_pillion == 0 and not seated and Game.phase == Game.Phase.SCAVENGE


func _physics_process(delta: float) -> void:
	if Game.phase != Game.Phase.SCAVENGE:
		return
	if Game.seat_driver == Game.my_id():
		_drive_step(delta)
	else:
		var prev := yaw
		global_position = global_position.lerp(_target_pos, clampf(12.0 * delta, 0.0, 1.0))
		yaw = lerp_angle(yaw, _target_yaw, clampf(12.0 * delta, 0.0, 1.0))
		rotation.y = yaw
		yaw_rate = angle_difference(prev, yaw) / maxf(delta, 0.0001)
		if Game.seat_driver == 0:
			speed = 0.0


func _drive_step(delta: float) -> void:
	drunk.tick(delta, false)
	var steer_raw := Input.get_axis("left", "right")
	var thr := Input.get_axis("back", "forward")
	_hiccup_in -= delta
	if _hiccup_in <= 0.0:
		_hiccup_in = randf_range(Tuning.hiccup_min, Tuning.hiccup_max)
		_kick = randf_range(-1.0, 1.0) * 0.8 * drunk.level
	_kick = move_toward(_kick, 0.0, 2.5 * delta)
	var steer := clampf(drunk.steer1(steer_raw) + _kick, -1.0, 1.0)
	if thr > 0.0:
		speed += ACCEL * delta * thr
	elif thr < 0.0:
		speed += BRAKE * delta * thr
	else:
		speed = move_toward(speed, 0.0, 3.0 * delta)
	speed = clampf(speed, -REVERSE_MAX, top_speed())
	var prev := yaw
	yaw -= steer * TURN_RATE * clampf(absf(speed) / 5.0, 0.0, 1.0) * delta * signf(speed)
	yaw_rate = angle_difference(prev, yaw) / maxf(delta, 0.0001)
	rotation.y = yaw
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	velocity = fwd * speed + Vector3(0, velocity.y - GRAVITY * delta if not is_on_floor() else -1.0, 0)
	move_and_slide()
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		if n.y < 0.5:
			var into := -fwd.dot(n)
			if into > 0.25 and speed > 2.0:
				_jolt = maxf(_jolt, speed * into)
				speed *= 1.0 - into * 0.85
	_send_t += delta
	if _send_t >= 0.05:
		_send_t = 0.0
		Game.send_scooter_state(global_position, yaw, speed)


func _on_state(pos: Vector3, p_yaw: float, p_speed: float) -> void:
	if Game.seat_driver == Game.my_id():
		return
	_target_pos = pos
	_target_yaw = p_yaw
	if speed - p_speed > 4.0:
		_jolt = maxf(_jolt, speed - p_speed)    # the driver hit something; the passenger feels it as a sudden stop
	speed = p_speed
