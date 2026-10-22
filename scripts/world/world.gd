class_name World
extends Node3D
## One night: the junkyard where the crew finds and fits car parts, then the
## drive home (see Drive). Visuals are built in code from the shared seed so
## every peer sees the same layout.

var players: Node3D
var spawner: MultiplayerSpawner
var car: Node3D
var cam: Camera3D
var hud: Hud
var drive: Drive

var _yard: Node3D
var _part_nodes: Array = []
var _car_mat := StandardMaterial3D.new()
var _headlights: Array[SpotLight3D] = []


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
	cam.current = true

	hud = Hud.new()
	hud.world = self
	add_child(hud)

	Game.spawn_players.connect(_spawn_all)
	Game.drive_started.connect(_start_drive)
	Game.world_ready()


func _exit_tree() -> void:
	if Game.spawn_players.is_connected(_spawn_all):
		Game.spawn_players.disconnect(_spawn_all)
	if Game.drive_started.is_connected(_start_drive):
		Game.drive_started.disconnect(_start_drive)


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
	var c := Node3D.new()
	c.name = "Car"
	_car_mat.albedo_color = Color(0.35, 0.2, 0.1)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 0.8, 4.4)
	body.mesh = bm
	body.material_override = _car_mat
	body.position.y = 0.8
	c.add_child(body)
	var cabin := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.9, 0.7, 2.0)
	cabin.mesh = cm
	cabin.material_override = _car_mat
	cabin.position = Vector3(0, 1.5, 0.3)
	c.add_child(cabin)
	var tyre_mat := StandardMaterial3D.new()
	tyre_mat.albedo_color = Color(0.05, 0.05, 0.05)
	for x in [-1.15, 1.15]:
		for z in [-1.4, 1.4]:
			var w := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.45
			cyl.bottom_radius = 0.45
			cyl.height = 0.35
			w.mesh = cyl
			w.material_override = tyre_mat
			w.rotation_degrees.z = 90
			w.position = Vector3(x, 0.45, z)
			c.add_child(w)
	for x in [-0.7, 0.7]:
		var s := SpotLight3D.new()
		s.position = Vector3(x, 0.9, -2.2)
		s.spot_range = 40.0
		s.spot_angle = 35.0
		s.light_energy = 3.0
		s.visible = false
		c.add_child(s)
		_headlights.append(s)
	var body_static := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.2, 1.6, 4.4)
	cs.shape = bs
	cs.position.y = 0.8
	body_static.add_child(cs)
	c.add_child(body_static)
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
	_update_parts()
	var installed := 0
	for p in Game.parts:
		if p.state == Game.PS.INSTALLED:
			installed += 1
	var t := float(installed) / maxf(Game.parts.size(), 1.0)
	_car_mat.albedo_color = Color(0.35, 0.2, 0.1).lerp(Color(0.85, 0.12, 0.12), t)
	for s in _headlights:
		s.visible = installed == Game.parts.size()
	_update_camera(delta)


func _update_parts() -> void:
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
				var d := me.global_position.distance_to(p.pos) if me else 999.0
				glow.visible = d < (25.0 if lookout else 8.0)
			Game.PS.CARRIED:
				var holder := players.get_node_or_null(str(p.holder)) as Node3D
				n.visible = holder != null
				if holder:
					n.position = holder.global_position + Vector3(0, 1.9, 0)
				glow.visible = false
			Game.PS.DELIVERED:
				n.position = Game.CAR_POS + Vector3(3.0, 0.0, -1.5 + i * 1.0)
				glow.visible = true
			_:
				n.visible = false
	if Game.phase == Game.Phase.DRIVE:
		for n in _part_nodes:
			n.visible = false


func _update_camera(delta: float) -> void:
	var target := Transform3D()
	if drive:
		target = drive.camera_transform()
	else:
		var me := local_player()
		var focus := me.global_position if me else Game.CAR_POS
		target.origin = focus + Vector3(0, 11, 10)
		target = target.looking_at(focus, Vector3.UP)
		target.origin = focus + Vector3(0, 11, 10)
	cam.global_transform = cam.global_transform.interpolate_with(target, clampf(6.0 * delta, 0.0, 1.0))


# --- Drive ---------------------------------------------------------------------------

func _start_drive(drive_seed: int) -> void:
	players.process_mode = Node.PROCESS_MODE_DISABLED
	players.visible = false
	_yard.queue_free()
	car.position = Vector3.ZERO
	drive = Drive.new()
	drive.name = "Drive"
	drive.setup(drive_seed, car)
	add_child(drive)
