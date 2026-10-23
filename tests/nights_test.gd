extends SceneTree
## Night definitions. Run:
##   godot --headless --path . -s res://tests/nights_test.gd

var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1


func _tuning_is_default() -> bool:
	var d := Tuning.defaults()
	for k in d:
		if not is_equal_approx(Tuning.get_value(k), float(d[k])):
			return false
	return true


func _init() -> void:
	_check(Nights.count() >= 2, "at least two nights")
	var n1 := Nights.get_night(0)
	_check(n1.legs == 7, "night 1 legs = 7")
	_check(n1.leg_len == [70.0, 120.0], "night 1 leg length 70-120")
	_check(n1.part_radius == [14.0, 34.0], "night 1 part radius 14-34")
	_check(not n1.kebab_shop, "night 1 no kebab shop")
	_check(n1.tuning.is_empty(), "night 1 no overrides")
	var h1: Dictionary = n1.hazards
	_check(int(h1.traffic_count) == 0 and int(h1.dog_count) == 0 and int(h1.mugger_count) == 0, "night 1 hazard counts 0")
	Tuning.apply({"cop_window": 3.0})
	Nights.apply_tuning(0)
	_check(_tuning_is_default(), "apply_tuning(0) leaves defaults")

	var n2 := Nights.get_night(1)
	var h2: Dictionary = n2.hazards
	_check(int(h2.traffic_count) + int(h2.dog_count) + int(h2.mugger_count) > 0, "night 2 hazards on")
	_check(n2.kebab_shop, "night 2 kebab shop")
	_check(int(n2.legs) > int(n1.legs), "night 2 more legs")
	Nights.apply_tuning(1)
	var d := Tuning.defaults()
	var changed := 0
	for k in d:
		if not is_equal_approx(Tuning.get_value(k), float(d[k])):
			changed += 1
	_check(changed >= 2, "apply_tuning(1) changes %d values" % changed)

	for i in Nights.count():
		for k in Nights.get_night(i).tuning:
			_check(d.has(k), "night %d override key '%s' exists" % [i + 1, k])
		var hz: Dictionary = Nights.get_night(i).hazards
		for k in hz:
			_check(Hazards.DEFAULTS.has(k), "night %d hazard key '%s' exists" % [i + 1, k])

	Tuning.reset()
	print("FAILED %d" % _fails if _fails else "ALL PASS")
	quit(1 if _fails else 0)
