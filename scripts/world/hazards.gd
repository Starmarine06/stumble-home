class_name Hazards
extends Node3D
## Street hazards along the drive home: oncoming cars, dashing dogs and muggers.
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
	var kinds := [["traffic", int(P.traffic_count)], ["dog", int(P.dog_count)], ["mugger", int(P.mugger_count)]]
	var id := 0
	for k in kinds:
		for _n in k[1]:
			var leg := rng.randi_range(0, pts.size() - 2)
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
		root.position = e.pos
		add_child(root)
		_nodes[e.id] = root


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
		_:
			return "MUGGED! They took the snacks."
