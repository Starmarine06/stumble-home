class_name Player
extends CharacterBody3D
## One drunk on foot. The owning peer simulates movement; everyone else just
## receives position/rotation/stunned through a MultiplayerSynchronizer.

const SPEED := 4.6
const GRAVITY := 20.0
const GRAB_RANGE := 2.6
const CAR_RANGE := 5.0
const WATER_RANGE := 3.0

var peer_id := 1
var stunned := false
var drunk: Drunk

var _body: Node3D
var _label: Label3D
var _grab_cooldown := 0.0
var _cooler_cd := {}


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



func is_local() -> bool:
	return is_multiplayer_authority()


func _physics_process(delta: float) -> void:
	var tilt := 80.0 if stunned else 0.0
	_body.rotation_degrees.x = lerpf(_body.rotation_degrees.x, -tilt, 10.0 * delta)
	if not is_local():
		return

	var hud := _hud()
	var busy: bool = hud != null and hud.minigame_active
	drunk.tick(delta)
	stunned = drunk.is_stunned()

	var raw := Vector2.ZERO if busy else Input.get_vector("left", "right", "forward", "back")
	var mv := Vector2.ZERO if stunned else drunk.steer(raw)
	var speed := SPEED
	if Game.carried_by(peer_id) != -1 and not Game.has_role(Roles.Id.DRIVER):
		speed *= 0.8
	velocity.x = mv.x * speed
	velocity.z = mv.y * speed
	velocity.y = -1.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if mv.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-mv.x, -mv.y), 10.0 * delta)

	_grab_cooldown = maxf(0.0, _grab_cooldown - delta)
	for k in _cooler_cd.keys():
		_cooler_cd[k] = maxf(0.0, _cooler_cd[k] - delta)
	_interact(hud, busy)
	if hud:
		hud.drunk_level = drunk.level


func _interact(hud: Node, busy: bool) -> void:
	var prompt := ""
	var act := Input.is_action_just_pressed("act") and not busy and not stunned
	var held := Game.carried_by(peer_id)
	var pos2 := Vector2(global_position.x, global_position.z)
	var near_car := pos2.distance_to(Vector2(Game.CAR_POS.x, Game.CAR_POS.z)) < CAR_RANGE
	var water := _nearest_cooler()

	if held != -1:
		prompt = "[Q] drop  (it will clang)"
		if near_car:
			prompt = "[E] hand over the %s" % Game.parts[held].name
			if act:
				Game.request_deliver()
		elif Input.is_action_just_pressed("drop") and not busy:
			Game.request_drop()
	else:
		var near_part := _nearest_part()
		var delivered := Game.delivered_part()
		if near_part != -1:
			prompt = "[E] grab the %s" % Game.parts[near_part].name
			if act and _grab_cooldown <= 0.0:
				_grab_cooldown = 0.8
				Game.request_pickup(near_part)
		elif near_car and delivered != -1 and Game.has_role(Roles.Id.MECHANIC):
			prompt = "[E] fit the %s (steady hands!)" % Game.parts[delivered].name
			if act and hud:
				hud.start_minigame(3, 4, "FIT THE %s" % Game.parts[delivered].name.to_upper(), 0.0,
					func(ok: bool): Game.request_install(delivered, ok), drunk.level)
		elif near_car and delivered != -1:
			prompt = "Only the Mechanic can fit parts."
		elif water != -1:
			prompt = "[E] drink water (sober up a bit)"
			if act and _cooler_cd.get(water, 0.0) <= 0.0:
				_cooler_cd[water] = 20.0
				drunk.sober(0.25)
				Game.toast_msg.emit("Glug. Slightly less drunk. For now.")
	if hud:
		hud.set_prompt(prompt)


func _nearest_part() -> int:
	var best := -1
	var bd := GRAB_RANGE
	for i in Game.parts.size():
		var p: Dictionary = Game.parts[i]
		if p.state == Game.PS.WORLD:
			var d := global_position.distance_to(p.pos)
			if d < bd:
				bd = d
				best = i
	return best


func _nearest_cooler() -> int:
	for i in Game.coolers.size():
		if global_position.distance_to(Game.coolers[i]) < WATER_RANGE:
			return i
	return -1


func _hud() -> Node:
	return get_tree().get_first_node_in_group("hud")
