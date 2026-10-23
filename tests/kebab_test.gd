extends SceneTree
## Run: godot --headless --path . -s res://tests/kebab_test.gd

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	var k = Kebab.new()
	var a: Array = k.new_order(42).duplicate()
	var k2 = Kebab.new()
	var b: Array = k2.new_order(42)
	check("deterministic", a == b)
	var sizes_ok := true
	for s in 60:
		var n: int = Kebab.new().new_order(s).size()
		if n < 4 or n > 6:
			sizes_ok = false
	check("4-6 ingredients", sizes_ok)

	k.new_order(7)
	for ing in k.order:
		k.pick(ing, 0.0)
	check("perfect scores 1.0", is_equal_approx(k.score(), 1.0))

	k.new_order(7)
	k.pick(k.neighbour(k.order[0]), 0.0)
	check("wrong pick scores less", k.score() < 1.0)
	k.undo()
	for ing in k.order:
		k.pick(ing, 0.0)
	check("undo then right scores 1.0", is_equal_approx(k.score(), 1.0))

	k.new_order(9)
	k.misgrab_rate = 0.4
	var miss := 0
	for i in 200:
		k.items.clear()
		if k.pick("Lamb", 1.0) != "Lamb":
			miss += 1
	var rate := miss / 200.0
	check("misgrab rate near config (%.3f)" % rate, absf(rate - 0.4) <= 0.10)

	var hi: Dictionary = k.reward(1.0)
	var lo: Dictionary = k.reward(0.0)
	var all_better := true
	for key in ["sober", "hp", "wanted_delta"]:
		if not (hi[key] > lo[key]):
			all_better = false
	check("reward(1) beats reward(0)", all_better)

	k.new_order(11)
	k.pick(k.order[0], 0.0)
	k.tick(k.time_limit + 1.0)
	check("timeout incomplete <= 0.5", k.score() <= 0.5)

	check("describe hidden for others", k.describe(0, 1) == "" and k.describe(1, 1) != "")

	var p = KebabPanel.new()
	root.add_child(p)
	p.order_text = "1. Lamb"
	p.reader = false
	check("panel hides order", not p.order_visible())
	p.reader = true
	check("panel shows order", p.order_visible())
	p.reader = false
	var got := []
	p.picked.connect(func(i): got.append(i))
	p.find_child("btn_Lamb", true, false).pressed.emit()
	check("panel emits picked", got == ["Lamb"])

	print("fails: ", fails)
	quit(1 if fails > 0 else 0)
