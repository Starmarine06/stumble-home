extends SceneTree
## Headless checks for Hazards. Run: godot --headless --path . -s res://tests/hazards_test.gd

var fails := 0
var H


func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func route(seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var p := Vector3.ZERO
	var dir := Vector3(0, 0, -1)
	var pts: Array = [p]
	for i in 7:
		p += dir * rng.randf_range(70.0, 120.0)
		pts.append(p)
		dir = dir.rotated(Vector3.UP, (1 if rng.randf() < 0.5 else -1) * PI * 0.5)
	return pts


func dist_to_route(p: Vector3, pts: Array) -> float:
	var best := INF
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ap := Vector2(p.x - a.x, p.z - a.z)
		var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, (Vector2(a.x, a.z) + ab * t).distance_to(Vector2(p.x, p.z)))
	return best


func _initialize() -> void:
	H = load("res://scripts/world/hazards.gd")
	var pts := route(1234)
	var a: Array = H.plan(42, pts, {})
	var b: Array = H.plan(42, pts, {})
	var c: Array = H.plan(43, pts, {})
	check("plan not empty", a.size() > 0)
	check("same seed identical", a == b)
	check("different seed differs", a != c)

	var margin := 3.0
	var in_road := true
	var tele_ok := true
	for e in a:
		for p in [e.pos, e.end]:
			if dist_to_route(p, pts) > 5.0 + margin:
				in_road = false
		if e.active - e.tele < 2.0:
			tele_ok = false
	check("events within road width + margin", in_road)
	check("telegraph >= 2.0 s", tele_ok)

	var empty: Array = H.plan(42, pts, {"traffic_count": 0, "dog_count": 0, "mugger_count": 0})
	check("zero counts -> empty plan", empty.is_empty())

	# Dog: drive through the crossing point at its active time.
	var dogs := a.filter(func(e): return e.kind == "dog")
	check("has dogs", dogs.size() > 0)
	var dog: Dictionary = dogs[0]
	var h = H.new()
	h.load_plan([dog])
	var t_mid: float = dog.active + dog.dur * 0.5
	var cross: Vector3 = H.event_pos(dog, t_mid)
	check("nothing before active", h.check(cross, 10.0, t_mid - 0.5).size() == 0)
	var hits: Array = h.check(cross, 10.0, 0.5)
	check("exactly one dog hit", hits.size() == 1 and hits[0].kind == "dog")
	check("hit has fields", hits.size() == 1 and hits[0].has("dmg") and hits[0].has("wanted") and hits[0].has("text"))
	check("passing again yields none", h.check(cross, 10.0, 0.1).size() == 0)
	h.free()

	# Dodge: car far from the dog yields nothing.
	var h2 = H.new()
	h2.load_plan([dog])
	check("dodge yields nothing", h2.check(cross + Vector3(30, 0, 0), 10.0, t_mid).size() == 0
		and h2.check(cross + Vector3(30, 0, 0), 10.0, 20.0).size() == 0)
	h2.free()

	# Mugger: only below the speed threshold and within range.
	var mugs := a.filter(func(e): return e.kind == "mugger")
	check("has muggers", mugs.size() > 0)
	var mug: Dictionary = mugs[0]
	var near: Vector3 = mug.pos + Vector3(2, 0, 0)
	var fast = H.new()
	fast.load_plan([mug])
	check("mugger ignores fast car", fast.check(near, 15.0, mug.active + 1.0).size() == 0)
	var slow_far = H.new()
	slow_far.load_plan([mug])
	check("mugger ignores far slow car", slow_far.check(mug.pos + Vector3(40, 0, 0), 1.0, mug.active + 1.0).size() == 0)
	var slow = H.new()
	slow.load_plan([mug])
	var mh: Array = slow.check(near, 1.0, mug.active + 1.0)
	check("mugger hits slow near car once", mh.size() == 1 and mh[0].kind == "mugger" and slow.check(near, 1.0, 0.1).size() == 0)
	for n in [fast, slow_far, slow]:
		n.free()

	# build() works and check() drives visuals without error.
	var hb = H.new()
	hb.build(a)
	hb.check(Vector3.ZERO, 5.0, 1.0)
	check("build makes nodes", hb.get_child_count() == a.size())
	hb.free()

	var src := FileAccess.get_file_as_string("res://scripts/world/hazards.gd")
	check("no Game/Net references", not (src.contains("Game.") or src.contains("Net.")))

	print("fails: ", fails)
	quit(1 if fails > 0 else 0)
