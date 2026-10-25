class_name Hazards
extends Node3D
## Street hazards along the drive home: oncoming cars, dashing dogs, muggers and police checkpoints.
## plan() is pure and deterministic from the seed and route. check() is called with
## the car's position and speed, and returns hits. Has no autoload dependencies.

const DEFAULTS := {
	"road_w": 10.0,          # matches Drive.ROAD_W
	"avg_speed": 12.0,       # expected car speed, spreads event times along the route
	"start_delay": 8.0,      # no events before this many seconds
	"tele_lead": 2.5,        # seconds of warning before an event is dangerous (min 2.0)
	"traffic_count": 3,
	"dog_count": 4,
	"mugger_count": 2,
	"traffic_speed": 16.0,
	"traffic_hit_r": 2.4,
	"traffic_dmg": 20.0,
	"traffic_wanted": 6.0,
	"dog_speed": 7.0,
	"dog_hit_r": 1.6,
	"dog_dmg": 6.0,
	"dog_wanted": 5.0,
	"mugger_life": 60.0,
	"mugger_range": 7.0,
	"mugger_speed": 4.0,     # jumps the car when slower than this
	"mugger_dmg": 4.0,
	"mugger_wanted": 10.0,
	"kerb_margin": 1.5,
	"min_edge": 20.0,        # keep events away from corners
	"checkpoint_count": 0,   # roadblocks: slow right down before the cones or the cops take notice
	"checkpoint_hit_r": 9.0, # how close to the barrier you must be stopped by
	"checkpoint_slow": 3.0,  # m/s: slower than this inside the ring counts as stopped
	"checkpoint_dmg": 0.0,
	"checkpoint_wanted": 25.0,
	"checkpoint_pass_dmg": 0.0,
	"checkpoint_pass_wanted": -8.0,   # the officer waves you through, a bit less keen on you
	"checkpoint_lead": 6.0,           # seconds of warning: the cones show from further off
}
const MIN_TELE := 2.0

var events: Array = []
var time := 0.0
var _nodes := {}


static func plan(p_seed: int, pts: Array, params: Dictionary = {}) -> Array:
	var P := DEFAULTS.duplicate()
	P.merge(params, true)
	var out: Array = []
	if pts.size() < 2:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var cum: Array = [0.0]
	for i in pts.size() - 1:
		cum.append(cum[i] + _flat(pts[i + 1] - pts[i]).length())
	var lead := maxf(float(P.tele_lead), MIN_TELE)
	var half := float(P.road_w) * 0.5
	var edge := float(P.min_edge)
	var kinds := [["traffic", int(P.traffic_count)], ["dog", int(P.dog_count)], ["mugger", int(P.mugger_count)], ["checkpoint", int(P.checkpoint_count)]]
	var id := 0
	for k in kinds:
		for _n in k[1]:
			# a short leg (the last step to the door, say) has no room for a hazard: pick another
			var leg := rng.randi_range(0, pts.size() - 2)
			for _try in 8:
				if cum[leg + 1] - cum[leg] >= edge * 2.0 + 10.0:
					break
				leg = rng.randi_range(0, pts.size() - 2)
			var a: Vector3 = pts[leg]
			var len: float = cum[leg + 1] - cum[leg]
			if len < edge * 2.0 + 10.0:
				continue
			var dir := _flat(pts[leg + 1] - a).normalized()
			var right := dir.cross(Vector3.UP)
			var s := rng.randf_range(edge, len - edge)
			var t_here: float = (cum[leg] + s) / float(P.avg_speed) + float(P.start_delay)
			var ev := {"id": id, "kind": k[0], "leg": leg}
			match k[0]:
				"traffic":
					# Starts ahead in the opposite lane and drives toward the car.
					var s0 := minf(s + 40.0, len - 5.0)
					ev.pos = a + dir * s0 - right * half * 0.5
					ev.dir = -dir
					ev.speed = float(P.traffic_speed)
					ev.dur = s0 / ev.speed
					ev.active = t_here
				"dog":
					var side := 1.0 if rng.randf() < 0.5 else -1.0
					ev.pos = a + dir * s + right * side * (half + 1.0)
					ev.dir = -right * side
					ev.speed = float(P.dog_speed)
					ev.dur = (half * 2.0 + 2.0) / ev.speed
					ev.active = t_here
				"checkpoint":
					ev.pos = a + dir * s
					ev.dir = Vector3.ZERO
					ev.speed = 0.0
					ev.dur = 30.0
					ev.active = t_here
					ev.leg_dir = dir
				_:
					var side2 := 1.0 if rng.randf() < 0.5 else -1.0
					ev.pos = a + dir * s + right * side2 * (half + float(P.kerb_margin))
					ev.dir = Vector3.ZERO
					ev.speed = 0.0
					ev.dur = float(P.mugger_life)
					ev.active = t_here
			ev.tele = ev.active - lead
			ev.end = ev.pos + ev.dir * ev.speed * ev.dur
			ev.dmg = float(P[k[0] + "_dmg"])
			ev.wanted = float(P[k[0] + "_wanted"])
			ev.hit_r = float(P.get(k[0] + "_hit_r", P.mugger_range))
			ev.slow = float(P.mugger_speed)
			if k[0] == "checkpoint":
				ev.tele = ev.active - maxf(float(P.checkpoint_lead), MIN_TELE)
				ev.slow = float(P.checkpoint_slow)
			out.append(ev)
			id += 1
	out.sort_custom(func(x, y): return x.active < y.active)
	return out


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func event_pos(ev: Dictionary, t: float) -> Vector3:
	var el := clampf(t - float(ev.active), 0.0, float(ev.dur))
	return ev.pos + ev.dir * float(ev.speed) * el


func load_plan(p_plan: Array) -> void:
	events = p_plan.duplicate(true)
	time = 0.0
	for e in events:
		e.used = false


func build(p_plan: Array) -> void:
	for n in _nodes.values():
		n.queue_free()
	_nodes.clear()
	load_plan(p_plan)
	for e in events:
		var root := Node3D.new()
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var col := Color(0.8, 0.2, 0.2)
		match e.kind:
			"traffic":
				bm.size = Vector3(2.0, 1.4, 4.4)
				col = Color(0.3, 0.4, 0.8)
				mi.position.y = 0.8
			"dog":
				bm.size = Vector3(0.5, 0.6, 1.1)
				col = Color(0.6, 0.4, 0.2)
				mi.position.y = 0.3
			"checkpoint":
				bm.size = Vector3(float(DEFAULTS.road_w) * 0.8, 1.0, 0.5)
				col = Color(0.95, 0.95, 1.0)
				mi.position.y = 0.6
			_:
				bm.size = Vector3(0.7, 1.8, 0.5)
				col = Color(0.15, 0.15, 0.15)
				mi.position.y = 0.9
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		mi.material_override = m
		root.add_child(mi)
		var lbl := Label3D.new()
		lbl.text = "!"
		lbl.font_size = 160
		lbl.pixel_size = 0.01
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.modulate = Color(1, 0.8, 0.1)
		lbl.position.y = 3.0
		root.add_child(lbl)
		root.visible = false
		if e.dir != Vector3.ZERO:
			root.rotation.y = atan2(-e.dir.x, -e.dir.z)
		if e.kind == "checkpoint":
			root.rotation.y = atan2(-e.leg_dir.x, -e.leg_dir.z)
			_build_checkpoint(root)
		root.position = e.pos
		add_child(root)
		_nodes[e.id] = root


## Cones either side of the barrier, a police car parked on the verge and a flashing blue light.
func _build_checkpoint(root: Node3D) -> void:
	var half := float(DEFAULTS.road_w) * 0.5
	for sx in [-1.0, 1.0]:
		for k in 3:
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = 0.28
			cm.height = 0.7
			cone.mesh = cm
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(1.0, 0.45, 0.1)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.45, 0.1)
			m.emission_energy_multiplier = 0.8
			cone.material_override = m
			cone.position = Vector3(sx * (half * 0.8 + 0.6), 0.35, 2.0 + k * 2.5)
			root.add_child(cone)
	var car := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 1.4, 4.6)
	car.mesh = bm
	var cm2 := StandardMaterial3D.new()
	cm2.albedo_color = Color(0.9, 0.9, 0.95)
	car.material_override = cm2
	car.position = Vector3(half + 2.5, 0.8, -1.0)
	root.add_child(car)
	var light := OmniLight3D.new()
	light.light_color = Color(0.1, 0.3, 1.0)
	light.light_energy = 3.0
	light.omni_range = 25.0
	light.position = Vector3(half + 2.5, 2.4, -1.0)
	root.add_child(light)


func check(car_pos: Vector3, car_speed: float, delta: float) -> Array:
	time += delta
	var hits: Array = []
	for e in events:
		if e.used:
			continue
		var expired: bool = time > float(e.active) + float(e.dur)
		var p := event_pos(e, time)
		var live: bool = time >= float(e.active) and not expired
		if live:
			var d := Vector2(car_pos.x - p.x, car_pos.z - p.z).length()
			var hit := false
			match e.kind:
				"mugger":
					hit = d <= float(e.hit_r) and absf(car_speed) < float(e.slow)
				"checkpoint":
					if d <= float(e.hit_r):
						if absf(car_speed) < float(e.slow):
							e.used = true
							hits.append({"kind": "checkpoint_pass", "dmg": float(DEFAULTS.checkpoint_pass_dmg), "wanted": float(DEFAULTS.checkpoint_pass_wanted), "text": _text("checkpoint_pass")})
						else:
							hit = true
				_:
					hit = d <= float(e.hit_r)
			if hit:
				e.used = true
				hits.append({"kind": e.kind, "dmg": e.dmg, "wanted": e.wanted, "text": _text(e.kind)})
		elif expired:
			e.used = true
		_sync(e, p, live)
	return hits


func _sync(e: Dictionary, p: Vector3, live: bool) -> void:
	var n: Node3D = _nodes.get(e.id)
	if n == null:
		return
	if e.used and not live:
		n.visible = false
		return
	n.visible = time >= float(e.tele) and not e.used
	n.position = p
	n.get_child(1).visible = not live


static func _text(kind: String) -> String:
	match kind:
		"traffic":
			return "HEAD-ON! Wrong lane, mate!"
		"dog":
			return "DOG! Poor lad."
		"checkpoint":
			return "You ran the checkpoint! Sirens."
		"checkpoint_pass":
			return "The officer squints, sniffs, and waves you through."
		_:
			return "MUGGED! They took the snacks."
