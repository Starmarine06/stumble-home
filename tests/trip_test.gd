extends SceneTree

var fails := 0
var log_t: Array = []
var t := 0.0


func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func _on_warn(_left: float) -> void:
	log_t.append(["w", t])


func _on_trip() -> void:
	log_t.append(["t", t])


func _mk() -> Object:
	var d = Drunk.new(0.9)
	d.stumble_warning.connect(_on_warn)
	d.tripped.connect(_on_trip)
	log_t.clear()
	t = 0.0
	return d


func _init() -> void:
	var dt := 1.0 / 60.0
	var d = _mk()
	for i in int(120.0 / dt):
		t += dt
		d.tick(dt, true, 0.0)
	check("idle 120s never trips", log_t.is_empty())

	d = _mk()
	for i in int(60.0 / dt):
		t += dt
		d.tick(dt, true, 1.0)
		if not log_t.is_empty() and log_t[-1][0] == "t":
			break
	var w := -1.0
	var tr := -1.0
	for e in log_t:
		if e[0] == "w" and w < 0.0:
			w = e[1]
		if e[0] == "t" and tr < 0.0:
			tr = e[1]
	check("warning emitted", w >= 0.0)
	check("trip emitted", tr >= 0.0)
	check("gap >= warn_time-0.1", tr - w >= Tuning.stumble_warn_time - 0.1)

	d = _mk()
	var slowed := false
	for i in int(60.0 / dt):
		t += dt
		if d.is_warning() and not slowed:
			slowed = true
		d.tick(dt, true, 0.0 if slowed else 1.0)
	check("warning started", slowed)
	check("slowing cancels trip", not d.is_warning() and not _has("t"))
	quit(1 if fails > 0 else 0)


func _has(k: String) -> bool:
	for e in log_t:
		if e[0] == k:
			return true
	return false
