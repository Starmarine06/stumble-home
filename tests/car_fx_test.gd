extends SceneTree

var fails := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", msg)
	else:
		print("ok: ", msg)


func _initialize() -> void:
	await process_frame
	_run()


func _run() -> void:
	var car := Node3D.new()
	for n in ["EngineBay", "Exhaust"]:
		var m := Node3D.new()
		m.name = n
		car.add_child(m)
	root.add_child(car)
	var fx = load("res://scripts/world/car_fx.gd").new()
	fx.setup(car)
	fx.set_repair(0.0)
	check(fx.smoke.emitting, "smoke emitting at 0")
	fx.set_repair(1.0)
	check(not fx.smoke.emitting, "smoke off at 1")
	fx.spark_burst(Vector3(0, 1, 0))
	fx.engine_start()
	var l := OmniLight3D.new()
	car.add_child(l)
	fx.flicker_lights([l])
	check(true, "effects ran")

	var bare := Node3D.new()
	root.add_child(bare)
	var fx2 = load("res://scripts/world/car_fx.gd").new()
	fx2.setup(bare)
	fx2.set_repair(0.5)
	fx2.engine_start()
	check(fx2.smoke != null, "setup without markers ok")

	print("failures: ", fails)
	quit(fails)
