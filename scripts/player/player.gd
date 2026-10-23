class_name Player
extends CharacterBody3D
## One drunk on foot, seen in first person. The owning peer simulates movement
## and its own hands; everyone else just receives position/rotation/stunned
## through a MultiplayerSynchronizer, and the held part's pose through Game.
##
## Hands: hold the left mouse button to lift a part, let go to put it down.
## A held part is a heavy thing on a spring: it lags behind your aim, sags and
## shakes as your arms tire, and slips out of your grip when they give up.
## Let go over the glowing slot to seat it; how well it fits depends on how
## close, how square and how slow you were.

const WALK_SPEED := 5.2
const SPRINT_SPEED := 9.2
const JUMP_VELOCITY := 4.8
const ACCELERATION := 12.0
const FRICTION := 9.0
const WATER_RANGE := 3.0
const MOUSE_SENS := 0.003
const EYE_HEIGHT := 1.65
const BOB_FREQ := 2.4
const BOB_AMP := 0.05
const BASE_FOV := 75.0

const GRAB_RANGE := 2.8
const GRAB_CONE := 0.85          # cos of the aim cone for picking something up
const PART_HALF := 0.4           # part origin sits this far below its centre
const PART_GRAVITY := 20.0
const POSE_RATE := 0.05

var peer_id := 1
var stunned := false
var drunk: Drunk

# Read by the HUD.
var strain := 0.0                # 0 fresh .. 1 arms give out
var aim_part := -1               # part under the crosshair, if you could grab it
var holding := false             # a part is in your hands right now
var fit_q := -1.0                # live fit quality over a slot, -1 when not near one

var _body: Node3D
var _label: Label3D
var _head: Node3D
var _cam: Camera3D
var _flash: SpotLight3D
var _bob := 0.0
var _mouse_free := false
var _cooler_cd := {}
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var _held := -1
var _sim := false                # we are simulating the carried part's physics
var _free := false               # let go: the part is falling
var _pending := false            # told the host what happened, waiting for its reply
var _armed := true               # button must be released before the next grab
var _hp := Vector3.ZERO          # carried part centre
var _hv := Vector3.ZERO
var _hrel := 0.0                 # part yaw relative to your body
var _reach := 1.0
var _pose_t := 0.0
var _grab_cd := 0.0


func _enter_tree() -> void:
	peer_id = int(str(name))
	set_multiplayer_authority(peer_id)
	# Must be built here (not in _ready) so the spawner can register it.
	var sync := MultiplayerSynchronizer.new()
	var cfg := SceneReplicationConfig.new()
	for prop in [^":position", ^":rotation", ^":stunned"]:
		cfg.add_property(prop)
		cfg.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	sync.set_multiplayer_authority(peer_id)
	add_child(sync)


func _ready() -> void:
	add_to_group("player")
	var roles := Game.roles_of(peer_id)
	var base := 0.0
	for r in roles:
		base = maxf(base, Roles.role_drunk(r))
	drunk = Drunk.new(base if base > 0.0 else 0.9)

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 1.8
	cap.radius = 0.4
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	_body = Node3D.new()
	add_child(_body)
	var color := Roles.role_color(roles[0]) if not roles.is_empty() else Color.WHITE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var torso := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.height = 1.5
	cm.radius = 0.4
	torso.mesh = cm
	torso.material_override = mat
	torso.position.y = 0.85
	_body.add_child(torso)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	head.mesh = sm
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.95, 0.8, 0.65)
	head.material_override = skin
	head.position = Vector3(0, 1.8, 0)
	_body.add_child(head)
	var nose := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(0.1, 0.1, 0.2)
	nose.mesh = nm
	nose.material_override = skin
	nose.position = Vector3(0, 1.78, -0.3)
	_body.add_child(nose)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.008
	_label.position.y = 2.5
	_label.font_size = 40
	var rn := ", ".join(roles.map(func(r): return Roles.role_name(r)))
	_label.text = "%s\n%s" % [Game.names.get(peer_id, "?"), rn]
	add_child(_label)

	_head = Node3D.new()
	_head.position.y = EYE_HEIGHT
	add_child(_head)
	if is_local():
		# First person: you see through your own eyes, not your own body.
		_body.visible = false
		_label.visible = false
		_cam = Camera3D.new()
		_cam.fov = BASE_FOV
		_head.add_child(_cam)
		_cam.current = true
		_head.rotation.x = deg_to_rad(6.0)
		_flash = SpotLight3D.new()
		_flash.light_color = Color(1, 0.98, 0.92)
		_flash.light_energy = 3.0
		_flash.spot_range = 28.0
		_flash.spot_angle = 38.0
		_cam.add_child(_flash)
		_capture_mouse(true)


func is_local() -> bool:
	return is_multiplayer_authority()


func _exit_tree() -> void:
	if is_local() and _cam:
		_capture_mouse(false)


func _capture_mouse(on: bool) -> void:
	_mouse_free = not on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or _cam == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_capture_mouse(_mouse_free)
	elif event is InputEventMouseButton and event.pressed:
		if _mouse_free:
			_capture_mouse(true)
			_armed = false  # that click was for the window, not for grabbing
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_reach = minf(1.5, _reach + 0.08)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_reach = maxf(0.6, _reach - 0.08)
	elif event is InputEventMouseMotion and not _mouse_free:
		rotate_y(-event.relative.x * MOUSE_SENS)
		_head.rotation.x = clampf(_head.rotation.x - event.relative.y * MOUSE_SENS, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event is InputEventKey and event.pressed and not event.echo and event.is_action("flashlight") and _flash:
		_flash.visible = not _flash.visible


func _physics_process(delta: float) -> void:
	var tilt := 80.0 if stunned else 0.0
	_body.rotation_degrees.x = lerpf(_body.rotation_degrees.x, -tilt, 10.0 * delta)
	if not is_local():
		return

	var hud := _hud()
	var busy: bool = hud != null and hud.minigame_active
	drunk.tick(delta)
	stunned = drunk.is_stunned() or Game.is_out(peer_id)

	_move(delta, busy)
	_hands(delta, busy)
	_drink(hud, busy, delta)
	if hud:
		hud.drunk_level = drunk.level


# --- Walking ---------------------------------------------------------------------------

## Same feel as the first-person prototype: smooth acceleration, friction, jump,
## sprint, head bob. The drunk model still wobbles and lags what you press.
func _move(delta: float, busy: bool) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var mass := _held_mass()
	if Input.is_action_just_pressed("jump") and is_on_floor() and not stunned and not busy and mass < 6.0:
		velocity.y = JUMP_VELOCITY

	var raw := Vector2.ZERO if busy else Input.get_vector("left", "right", "forward", "back")
	var mv := Vector2.ZERO if stunned else drunk.steer(raw)
	var sprinting := Input.is_action_pressed("sprint") and mass < 3.0 and not stunned and raw.y < 0.0
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	speed *= clampf(1.0 - 0.03 * mass / _strength(), 0.45, 1.0)

	var dir := global_transform.basis * Vector3(mv.x, 0.0, mv.y)
	if mv.length() > 0.05:
		velocity.x = lerpf(velocity.x, dir.x * speed, ACCELERATION * delta)
		velocity.z = lerpf(velocity.z, dir.z * speed, ACCELERATION * delta)
	else:
		velocity.x = lerpf(velocity.x, 0.0, FRICTION * delta)
		velocity.z = lerpf(velocity.z, 0.0, FRICTION * delta)
	move_and_slide()
	_update_view(delta, mv.length() > 0.05, sprinting)


## Head bob while walking, FOV kick when sprinting, and the world sways and
## drops when the drunk gets tripped.
func _update_view(delta: float, walking: bool, sprinting: bool) -> void:
	var y := EYE_HEIGHT
	if walking and is_on_floor():
		_bob += delta * BOB_FREQ * (SPRINT_SPEED / WALK_SPEED if sprinting else 1.0)
		y += sin(_bob * TAU) * BOB_AMP
	else:
		_bob = 0.0
	if stunned:
		y = 0.5
	_head.position.y = lerpf(_head.position.y, y, 10.0 * delta)
	var roll := sin(Time.get_ticks_msec() * 0.0028) * 0.1 * drunk.level
	if stunned:
		roll = 0.5
	_cam.rotation.z = lerpf(_cam.rotation.z, roll, 6.0 * delta)
	_cam.fov = lerpf(_cam.fov, BASE_FOV + (8.0 if sprinting else 0.0), 6.0 * delta)


# --- Hands -------------------------------------------------------------------------------

func _strength() -> float:
	var s := 1.0
	if Game.has_role(Roles.Id.MECHANIC):
		s = 1.6
	elif Game.has_role(Roles.Id.DRIVER):
		s = 1.3
	return s * (1.0 - 0.4 * Game.fatigue_of(peer_id))


func _held_mass() -> float:
	var h := Game.carried_by(peer_id)
	return Game.PART_MASS[h] if h != -1 else 0.0


func _hands(delta: float, busy: bool) -> void:
	_grab_cd = maxf(0.0, _grab_cd - delta)
	var btn := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _mouse_free and not busy
	if not btn:
		_armed = true
	var held := Game.carried_by(peer_id)
	holding = held != -1 and _sim and not _free
	fit_q = -1.0
	aim_part = -1

	if held == -1:
		_held = -1
		_sim = false
		_free = false
		_pending = false
		strain = maxf(0.0, strain - 0.15 * delta)
		if Game.phase != Game.Phase.SCAVENGE or stunned:
			return
		aim_part = _aimed_part()
		if btn and _armed and aim_part != -1 and _grab_cd <= 0.0:
			_grab_cd = Tuning.grab_cooldown
			Game.request_pickup(aim_part)
		return

	if _pending:
		return
	if not _sim:
		_held = held
		_sim = true
		_free = not (btn and _armed)  # a tap picks it up and drops it again
		_hp = Game.parts[held].pos + Vector3(0, PART_HALF, 0)
		_hv = Vector3.ZERO
		_hrel = wrapf(Game.parts[held].yaw - rotation.y, -PI, PI)
		strain = minf(1.0, strain + Tuning.pickup_strain * Game.PART_MASS[held] / 12.0)  # the heave off the floor
		return

	if _free:
		_fall(delta)
		return

	if not btn or stunned or strain >= 1.0:
		if strain >= 1.0:
			Game.toast_msg.emit("Your arms give out!")
		_release(held)
		return
	_hold(delta, held)


func _hold(delta: float, held: int) -> void:
	var mass: float = Game.PART_MASS[held]
	var steady := 0.5 if Game.has_role(Roles.Id.MECHANIC) else 1.0
	var ext := _reach - 0.6
	strain = minf(1.0, strain + mass * (0.007 + 0.010 * ext) / _strength() * delta)

	# Where your hands want the part: in front of you, sagging as you tire, shaking when
	# drunk or strained.
	var t := Time.get_ticks_msec() * 0.001
	var tremor := 0.015 + 0.07 * drunk.level * steady + 0.1 * strain * strain
	var shake := Vector3(sin(t * 7.3), sin(t * 9.1 + 1.0), sin(t * 8.2 + 2.0)) * tremor
	var target := _cam.global_transform * Vector3(0.1, -0.2, -_reach) + shake
	target.y -= strain * 0.35

	# Spring on a heavy mass: heavier parts trail your aim and overshoot.
	var m_eff := 1.0 + 0.2 * mass
	var k := 70.0 / m_eff
	var accel := (target - _hp) * k - _hv * (2.0 * sqrt(k) * 0.8)
	_hv = (_hv + accel * delta).limit_length(9.0)
	_hp += _hv * delta
	_hp.y = maxf(_hp.y, PART_HALF)

	var turn := Input.get_axis("turn_l", "turn_r")
	_hrel = wrapf(_hrel + turn * 1.8 * delta + sin(t * 5.1) * tremor * 0.4 * delta, -PI, PI)

	var near := _hp.distance_to(slot_pos(held)) < Game.PLACE_R * 2.0
	fit_q = placement_quality(held) if near else -1.0
	_publish(held, delta)


func _release(held: int) -> void:
	if Game.phase == Game.Phase.SCAVENGE and _hp.distance_to(slot_pos(held)) < Game.PLACE_R:
		Game.request_place(placement_quality(held))
		_pending = true
		return
	_free = true
	_hv *= 0.6


func _fall(delta: float) -> void:
	_hv.y -= PART_GRAVITY * delta
	_hv.x *= 0.98
	_hv.z *= 0.98
	_hp += _hv * delta
	if _hp.y <= PART_HALF:
		_hp.y = PART_HALF
		var rest := _hp - Vector3(0, PART_HALF, 0)
		Game.parts[_held].pos = rest
		Game.request_drop(rest, rotation.y + _hrel, -_hv.y)
		_pending = true
		return
	_publish(_held, delta)


func _publish(held: int, delta: float) -> void:
	var pos := _hp - Vector3(0, PART_HALF, 0)
	Game.parts[held].pos = pos
	Game.parts[held].yaw = rotation.y + _hrel
	_pose_t -= delta
	if _pose_t <= 0.0:
		_pose_t = POSE_RATE
		Game.send_pose(held, pos, rotation.y + _hrel)


## What the crosshair is on: the part most in line with where you look, in reach.
func _aimed_part() -> int:
	var best := -1
	var best_dot := GRAB_CONE
	var eye := _cam.global_position
	var fwd := -_cam.global_transform.basis.z
	for i in Game.parts.size():
		var p: Dictionary = Game.parts[i]
		if p.state != Game.PS.WORLD:
			continue
		var to: Vector3 = p.pos + Vector3(0, PART_HALF, 0) - eye
		if to.length() > GRAB_RANGE:
			continue
		var d := fwd.dot(to.normalized())
		if d > best_dot:
			best_dot = d
			best = i
	return best


func slot_pos(i: int) -> Vector3:
	var world := get_tree().get_first_node_in_group("world") as World
	var car: Node3D = world.car if world else null
	return car.global_transform * Game.SLOTS[i] if car else Game.SLOTS[i]


## 1.0 = seated dead on, slowly, squared up. Position matters most, then speed and angle.
func placement_quality(i: int) -> float:
	var yaw_err := 0.0
	if not Game.SLOT_SYMMETRIC[i]:
		var d := wrapf(rotation.y + _hrel - Game.SLOT_YAW[i], 0.0, PI)
		yaw_err = minf(d, PI - d)
	return quality_for(_hp.distance_to(slot_pos(i)), yaw_err, _hv.length())


static func quality_for(dist: float, yaw_err: float, speed: float) -> float:
	var pos_q := 1.0 - clampf(dist / Game.PLACE_R, 0.0, 1.0)
	var yaw_q := 1.0 - clampf(yaw_err / 0.6, 0.0, 1.0)
	var speed_q := 1.0 - clampf((speed - 0.4) / 2.0, 0.0, 1.0)
	return pos_q * 0.55 + yaw_q * 0.25 + speed_q * 0.2


# --- Water cooler --------------------------------------------------------------------

func _drink(hud: Node, busy: bool, delta: float) -> void:
	var prompt := ""
	var water := _nearest_cooler()
	for k in _cooler_cd.keys():
		_cooler_cd[k] = maxf(0.0, _cooler_cd[k] - delta)

	if Game.phase == Game.Phase.SCAVENGE:
		if holding:
			prompt = "Wheel: reach    Q / E: turn    let go over the glow to fit"
		elif aim_part != -1:
			prompt = "Hold LEFT MOUSE to lift the %s  (%d kg)" % [Game.parts[aim_part].name, int(Game.PART_MASS[aim_part])]
		elif water != -1 and _held_mass() == 0.0:
			prompt = "[E] drink water (sober up, less tired)"
			if Input.is_action_just_pressed("act") and not busy and not stunned and _cooler_cd.get(water, 0.0) <= 0.0:
				_cooler_cd[water] = 20.0
				drunk.sober(0.25)
				Game.request_rest()
				Game.toast_msg.emit("Glug. Slightly less drunk. For now.")
	if hud:
		hud.set_prompt(prompt)


func _nearest_cooler() -> int:
	for i in Game.coolers.size():
		if global_position.distance_to(Game.coolers[i]) < WATER_RANGE:
			return i
	return -1


func _hud() -> Node:
	return get_tree().get_first_node_in_group("hud")
