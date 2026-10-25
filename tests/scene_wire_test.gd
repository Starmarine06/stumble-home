extends SceneTree
## Checks the car model, car fx and the city are wired into the world.

var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	game.start_hosting()
	game.start_game()
	await create_timer(1.0).timeout
	var world := root.get_node_or_null("Main/World")
	_check(world != null, "world built")
	var car: Node = world.get("car")
	_check(car != null and car.get_node_or_null("EngineBay") != null, "car has EngineBay")
	_check(car.get_node_or_null("CarFx") != null, "car has CarFx child")
	_check(car.get_node_or_null("Body") is StaticBody3D, "car has single Body collider")
	var city: Node = world.get_node_or_null("City")
	_check(city != null and city.get_child_count() > 20, "city has streets and built blocks")
	_check(world.get_node_or_null("CarPark") != null, "car park props exist")
	var lights := 0
	for nm in ["HeadlightL", "HeadlightR"]:
		for ch in car.get_node(nm).get_children():
			if ch is SpotLight3D:
				lights += 1
	_check(lights == 2, "headlight spots under markers")
	var me: Node = world.local_player()
	_check(me != null and "stumble_warn" in me, "player exposes stumble_warn")
	print("scene_wire failures: %d" % _fails)
	quit(1 if _fails else 0)
