class_name World
extends Node3D
## One night: the junkyard where the crew finds and fits car parts, then the
## drive home (see Drive). Visuals are built in code from the shared seed so
## every peer sees the same layout.

const CarFxClass = preload("res://scripts/world/car_fx.gd")
const CarModelClass = preload("res://scripts/world/car_model.gd")
const YardPropsClass = preload("res://scripts/world/yard_props.gd")

var players: Node3D
var spawner: MultiplayerSpawner
var car: Node3D
var cam: Camera3D
var hud: Hud
var drive: Drive
var kebab_panel: KebabPanel

var _yard: Node3D
var _part_nodes: Array = []
var car_fx: Node = null
var _last_repair := -1.0
var _was_installed := {}
var _engine_started := false
var _headlights: Array[SpotLight3D] = []
var _ghost: MeshInstance3D
var _ghost_part := -1
var _ghost_mat := StandardMaterial3D.new()
var _look := Vector2.ZERO  # cab view: x = yaw, y = pitch


func _ready() -> void:
	add_to_group("world")
	_build_environment()
	_yard = Node3D.new()
	_yard.name = "Yard"
	add_child(_yard)
	_build_yard()
	car = _make_car()
	car.position = Game.CAR_POS
	add_child(car)
	car_fx = CarFxClass.new()
	car_fx.name = "CarFx"
	car.add_child(car_fx)
	car_fx.setup(car)
	var keep: Array = [Game.CAR_POS]
	for p in Game.parts:
		keep.append(p.pos)
	for cp in Game.coolers:
		keep.append(cp)
	_yard.add_child(YardPropsClass.build(Game.world_seed, keep))
	for i in Game.parts.size():
		var n := _make_part(i)
		_part_nodes.append(n)
		add_child(n)

	players = Node3D.new()
	players.name = "Players"
	add_child(players)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(players)
	spawner.spawn_function = _spawn_player

	cam = Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.position = Vector3(0, 12, 12)
	cam.look_at(Vector3.ZERO)
	cam.current = true  # overview until your own player spawns and takes over

	_ghost = MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 0.3
	gm.height = 0.6
	_ghost.mesh = gm
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost.material_override = _ghost_mat
	_ghost.visible = false
	add_child(_ghost)

	hud = Hud.new()
	hud.world = self
	add_child(hud)

	Game.spawn_players.connect(_spawn_all)
	Game.drive_started.connect(_start_drive)
	Game.kebab_opened.connect(_on_kebab_opened)
	Game.kebab_state.connect(_on_kebab_state)
	Game.kebab_closed.connect(_close_kebab)
	Game.kebab_reward.connect(_on_kebab_reward)
	Game.world_ready()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.spawn_players.is_connected(_spawn_all):
		Game.spawn_players.disconnect(_spawn_all)
	if Game.drive_started.is_connected(_start_drive):
		Game.drive_started.disconnect(_start_drive)
	for pair in [[Game.kebab_opened, _on_kebab_opened], [Game.kebab_state, _on_kebab_state], [Game.kebab_closed, _close_kebab], [Game.kebab_reward, _on_kebab_reward]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func _unhandled_input(event: InputEvent) -> void:
	# In the car you stay in your seat but can look around.
	if drive and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look.x = clampf(_look.x - event.relative.x * Player.MOUSE_SENS, -2.2, 2.2)
		_look.y = clampf(_look.y - event.relative.y * Player.MOUSE_SENS, -0.8, 0.8)


func local_player() -> Player:
	return players.get_node_or_null(str(Game.my_id())) as Player


# --- Players ---------------------------------------------------------------------

func _spawn_all() -> void:
	var ids := Game.names.keys()
	ids.sort()
	for k in ids.size():
		var ang := TAU * float(k) / maxf(ids.size(), 1.0) + 0.6
		var pos := Game.CAR_POS + Vector3(cos(ang) * 7.0, 1.0, sin(ang) * 7.0)
		spawner.spawn({"peer": ids[k], "pos": pos})


func _spawn_player(data: Dictionary) -> Node:
	var p := Player.new()
	p.name = str(data.peer)
	p.position = data.pos
	return p


# --- Scenery -----------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.6)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.09, 0.16)
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.7
	moon.rotation_degrees = Vector3(-55, 30, 0)
	add_child(moon)


func _box(parent: Node, size: Vector3, pos: Vector3, color: Color, solid := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		mi.add_child(body)
	return mi


func _build_yard() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.world_seed
	_box(_yard, Vector3(110, 1, 110), Vector3(0, -0.5, 0), Color(0.16, 0.15, 0.13))
	var half := 52.0
	for side in [-1, 1]:
		_box(_yard, Vector3(110, 4, 1), Vector3(0, 2, side * half), Color(0.25, 0.25, 0.28))
		_box(_yard, Vector3(1, 4, 110), Vector3(side * half, 2, 0), Color(0.25, 0.25, 0.28))
	for i in 40:
		var pos := Vector3(rng.randf_range(-46, 46), 0, rng.randf_range(-46, 46))
		if pos.length() < 9.0 or _near_special(pos):
			continue
		var h := rng.randf_range(1.0, 3.2)
		var c := Color(rng.randf_range(0.2, 0.5), rng.randf_range(0.2, 0.4), rng.randf_range(0.2, 0.35))
		_box(_yard, Vector3(rng.randf_range(1.5, 4.0), h, rng.randf_range(1.5, 4.0)), pos + Vector3(0, h * 0.5, 0), c)
	for pos in Game.coolers:
		_box(_yard, Vector3(0.9, 1.4, 0.9), pos + Vector3(0, 0.7, 0), Color(0.3, 0.6, 0.95), false)
		var l := OmniLight3D.new()
		l.light_color = Color(0.5, 0.8, 1.0)
		l.omni_range = 7.0
		l.position = pos + Vector3(0, 2.0, 0)
		_yard.add_child(l)
	for pos in [Vector3(-20, 5, -20), Vector3(20, 5, -20), Vector3(-20, 5, 20), Vector3(20, 5, 20)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.85, 0.55)
		lamp.light_energy = 1.4
		lamp.omni_range = 26.0
		lamp.position = pos
		_yard.add_child(lamp)


func _near_special(pos: Vector3) -> bool:
	for p in Game.parts:
		if pos.distance_to(p.pos) < 4.0:
			return true
	for c in Game.coolers:
		if pos.distance_to(c) < 4.0:
			return true
	return false


func _make_car() -> Node3D:
	var c: Node3D = CarModelClass.build()
	for nm in ["HeadlightL", "HeadlightR"]:
		var s := SpotLight3D.new()
		s.spot_range = 40.0
		s.spot_angle = 35.0
		s.light_energy = 3.0
		s.visible = false
		c.get_node(nm).add_child(s)
		_headlights.append(s)
	return c


func _make_part(i: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Part%d" % i
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	match i:
		0:
			var b := BoxMesh.new()
			b.size = Vector3(0.7, 0.45, 0.45)
			mi.mesh = b
			m.albedo_color = Color(0.9, 0.2, 0.2)
		1:
			var c := CylinderMesh.new()
			c.top_radius = 0.25
			c.bottom_radius = 0.25
			c.height = 0.7
			mi.mesh = c
			m.albedo_color = Color(0.9, 0.7, 0.2)
		2:
			var s := CapsuleMesh.new()
			s.radius = 0.12
			s.height = 0.6
			mi.mesh = s
			m.albedo_color = Color(0.3, 0.9, 0.9)
		_:
			var t := TorusMesh.new()
			t.inner_radius = 0.22
			t.outer_radius = 0.5
			mi.mesh = t
			m.albedo_color = Color(0.15, 0.15, 0.15)
	m.emission = m.albedo_color
	m.emission_energy_multiplier = 0.6
	mi.material_override = m
	mi.position.y = 0.4
	n.add_child(mi)
	var l := OmniLight3D.new()
	l.name = "Glow"
	l.light_color = m.albedo_color
	l.omni_range = 4.0
	l.light_energy = 1.0
	l.position.y = 1.0
	n.add_child(l)
	return n


# --- Per-frame ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_parts(delta)
	var installed := 0
	for p in Game.parts:
		if p.state == Game.PS.INSTALLED:
			installed += 1
	var t := float(installed) / maxf(Game.parts.size(), 1.0)
	if not is_equal_approx(t, _last_repair):
		_last_repair = t
		CarModelClass.set_repair(car, t)
		car_fx.set_repair(t)
	for i in Game.parts.size():
		var inst: bool = Game.parts[i].state == Game.PS.INSTALLED
		if inst and not _was_installed.get(i, false):
			car_fx.spark_burst(Vector3(0, 1.2, -1.5))
		_was_installed[i] = inst
	var all_in := installed == Game.parts.size()
	if all_in and not _engine_started:
		car_fx.engine_start()
	_engine_started = all_in
	for s in _headlights:
		s.visible = all_in
	_update_camera(delta)


func _update_parts(delta: float) -> void:
	var me := local_player()
	var lookout := Game.has_role(Roles.Id.LOOKOUT)
	for i in _part_nodes.size():
		var n: Node3D = _part_nodes[i]
		var p: Dictionary = Game.parts[i]
		var glow := n.get_node("Glow") as OmniLight3D
		n.visible = true
		match p.state:
			Game.PS.WORLD:
				n.position = p.pos
				n.rotation.y = p.yaw
				n.rotation.z = 0.0
				var d := me.global_position.distance_to(p.pos) if me else 999.0
				glow.visible = d < (25.0 if lookout else 8.0)
			Game.PS.CARRIED:
				var holder := players.get_node_or_null(str(p.holder)) as Node3D
				n.visible = holder != null
				n.rotation.z = 0.0
				# Your own hands are exact; everyone else's part is smoothed between pose updates.
				if holder == me:
					n.position = p.pos
					n.rotation.y = p.yaw
				else:
					n.position = n.position.lerp(p.pos, clampf(15.0 * delta, 0.0, 1.0))
					n.rotation.y = lerp_angle(n.rotation.y, p.yaw, clampf(15.0 * delta, 0.0, 1.0))
				glow.visible = false
			Game.PS.INSTALLED:
				var slot: Vector3 = car.global_transform * Game.SLOTS[i]
				n.position = slot - Vector3(0, Player.PART_HALF, 0)
				n.rotation.y = Game.SLOT_YAW[i]
				if p.q < Game.SOLID_Q:
					# Crooked fit: sits askew, and rattles hard just before it drops.
					var t := Time.get_ticks_msec() * 0.001
					var amp := 0.12 if p.warned else 0.03
					n.position += Vector3(sin(t * 31.0), 0.0, cos(t * 27.0)) * amp
					n.rotation.z = 0.5 * (1.0 - p.q)
				else:
					n.rotation.z = 0.0
				glow.visible = false
			_:
				n.visible = false
	if Game.phase == Game.Phase.DRIVE:
		for n in _part_nodes:
			n.visible = false
	_update_ghost(me)


## The glowing target for whatever part you are holding; green when lined up.
func _update_ghost(me: Player) -> void:
	var held := Game.carried_by(Game.my_id())
	_ghost.visible = me != null and held != -1 and me.holding and Game.phase == Game.Phase.SCAVENGE
	if not _ghost.visible:
		return
	if _ghost_part != held:
		_ghost_part = held
		_ghost.mesh = (_part_nodes[held].get_child(0) as MeshInstance3D).mesh
	_ghost.global_position = me.slot_pos(held)
	_ghost.rotation.y = Game.SLOT_YAW[held]
	var q := me.fit_q
	var col := Color(0.9, 0.2, 0.2).lerp(Color(0.2, 0.95, 0.3), clampf((q - 0.3) / 0.6, 0.0, 1.0)) if q >= 0.0 else Color(1, 1, 1)
	col.a = 0.55 if q >= 0.0 else 0.28
	_ghost_mat.albedo_color = col


func _update_camera(delta: float) -> void:
	if drive:
		# Cab view from the driver's side: every seat looks out the windscreen.
		var rig := Transform3D(Basis.from_euler(Vector3(_look.y, _look.x, 0.0)), Vector3.ZERO)
		cam.global_transform = drive.car.global_transform * Transform3D(Basis.IDENTITY, Vector3(-0.45, 1.55, 0.2)) * rig


# --- Drive ---------------------------------------------------------------------------

func _start_drive(drive_seed: int) -> void:
	players.process_mode = Node.PROCESS_MODE_DISABLED
	players.visible = false
	cam.fov = 75.0
	cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_yard.queue_free()
	car.position = Vector3.ZERO
	drive = Drive.new()
	drive.name = "Drive"
	var nd := Nights.get_night(Game.night)
	drive.setup(drive_seed, car, nd.hazards, Game.kebab_shop_enabled, int(nd.legs), nd.leg_len)
	add_child(drive)


# --- Kebab shop ------------------------------------------------------------------------

func _on_kebab_opened(order_seed: int, reader_peer: int) -> void:
	_close_kebab()
	kebab_panel = KebabPanel.new()
	kebab_panel.name = "KebabPanel"
	var is_reader := Game.my_id() == reader_peer
	kebab_panel.reader = is_reader
	if is_reader:
		var k := Kebab.new()
		k.new_order(order_seed)
		kebab_panel.order_text = k.describe(0, 0)
	kebab_panel.picked.connect(Game.request_kebab_pick)
	kebab_panel.undo_pressed.connect(Game.request_kebab_undo)
	kebab_panel.closed.connect(Game.request_kebab_close)
	var layer := CanvasLayer.new()
	layer.name = "KebabLayer"
	add_child(layer)
	layer.add_child(kebab_panel)
	var vp := get_viewport().get_visible_rect().size
	kebab_panel.position = (vp - kebab_panel.size) * 0.5
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_kebab_state(items: Array, time_left: float) -> void:
	if kebab_panel:
		var typed: Array[String] = []
		for it in items:
			typed.append(str(it))
		kebab_panel.set_state(typed, time_left)


func _close_kebab() -> void:
	if kebab_panel == null:
		return
	var layer := kebab_panel.get_parent()
	kebab_panel = null
	layer.free()
	if drive:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_kebab_reward(sober: float) -> void:
	var me := local_player()
	if me and me.drunk:
		me.drunk.sober(sober)
	if drive and drive.drunk:
		drive.drunk.sober(sober)
