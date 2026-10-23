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
	car.position = Vector3(3, 1, 2)
	var mesh := Node3D.new()
	mesh.name = "Body"
	mesh.position = Vector3(0, 0.5, 0)
	car.add_child(mesh)
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
	l.light_energy = 2.0
	car.add_child(l)
	fx.flicker_lights([l])
	l.light_energy = 2.0
	fx.flicker_lights([l])
	await process_frame
	fx.flicker_lights([l])
	fx.engine_start()
	fx.engine_start()
	var moved := false
	for i in 8:
		await create_timer(0.03).timeout
		check(car.position == Vector3(3, 1, 2), "car root untouched during shake")
		if mesh.position != Vector3(0, 0.5, 0):
			moved = true
	check(moved, "child mesh shook")
	await create_timer(0.5).timeout
	check(car.position == Vector3(3, 1, 2), "car root unchanged after shake")
	check(mesh.position == Vector3(0, 0.5, 0), "mesh restored after shake")
	check(is_equal_approx(l.light_energy, 2.0), "flicker restores energy")
	check(fx.engine_bay == car.get_node("EngineBay") and fx.exhaust == car.get_node("Exhaust"), "markers found")
	fx.set_repair(0.0)
	var a0: int = fx.smoke.amount
	fx.set_repair(0.8)
	check(fx.smoke.amount < a0 and fx.smoke.emitting, "smoke scales with damage")

	var bare := Node3D.new()
	root.add_child(bare)
	var fx2 = load("res://scripts/world/car_fx.gd").new()
	fx2.setup(bare)
	fx2.set_repair(0.5)
	fx2.engine_start()
	check(fx2.smoke != null, "setup without markers ok")

	print("failures: ", fails)
	quit(fails)
