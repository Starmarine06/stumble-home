extends SceneTree
## Headless: the traffic on the city streets (lanes, signals, following, turning, hitting people) and
## the collision of street furniture.
##   godot --headless --path . -s res://tests/traffic_test.gd

var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	game.start_hosting()
	game.start_game()
	await create_timer(1.0).timeout
	var world := root.get_node_or_null("Main/World")
	var me = world.local_player()
	var city = world.city
	var traffic = city.traffic
	var layout = game.city

	# park the viewer on a street junction a few blocks from the casino and let cars appear
	var cb: Vector2i = layout.casino_block
	var spot: Vector3 = layout.node_pos(clampi(cb.x + 2, 1, 14), clampi(cb.y + 2, 1, 14))
	world.city.view_points = [city.to_global(spot)]
	me.global_position = city.to_global(spot) + Vector3(0, 1.0, 0)
	me.set_physics_process(false)
	city.build_around(city.view_points)
	await create_timer(1.0).timeout
	Engine.time_scale = 4.0

	var violations := 0
	var overlaps := 0
	var turned := 0
	var peak := 0
	var inside := {}      # car -> true while within a junction square
	var starts := {}      # car -> first line index, to notice turns
	for _f in 2400:
		await physics_frame
		peak = maxi(peak, traffic.cars.size())
		var sig: Dictionary = city.signal_state()
		for car in traffic.cars:
			if not starts.has(car):
				starts[car] = [car.axis, car.line]
			elif starts[car] != [car.axis, car.line]:
				turned += 1
				starts[car] = [car.axis, car.line]
			# junction square test
			var in_sq := false
			var c := Vector3.ZERO
			var p: Vector3 = car.node.position
			var ix := roundi(p.x / CityLayout.PITCH + float(layout.blocks) * 0.5)
			var iz := roundi(p.z / CityLayout.PITCH + float(layout.blocks) * 0.5)
			c = layout.node_pos(ix, iz)
			if absf(p.x - c.x) < CityTraffic.HALF and absf(p.z - c.z) < CityTraffic.HALF:
				in_sq = true
			if in_sq and not inside.has(car):
				inside[car] = true
				if int(sig["ew" if car.axis == 0 else "ns"]) == 0 and car.turn.is_empty():
					violations += 1
			elif not in_sq:
				inside.erase(car)
		for i in traffic.cars.size():
			for j in range(i + 1, traffic.cars.size()):
				var a = traffic.cars[i]
				var b = traffic.cars[j]
				if a.node.position.distance_to(b.node.position) < 2.0:
					overlaps += 1
	Engine.time_scale = 1.0
	_check(peak >= 8, "cars appear near the viewer (peak %d)" % peak)
	_check(violations == 0, "no car enters a junction on red (%d did)" % violations)
	_check(overlaps == 0, "cars never drive through each other (%d overlap frames)" % overlaps)
	_check(turned >= 1, "cars turn at junctions (%d turns seen)" % turned)

	# a moving car that meets the local player knocks them down
	me.set_physics_process(true)
	traffic.enabled = true
	await physics_frame
	if traffic.cars.is_empty():
		_check(false, "there is a car to test with")
	else:
		var car = traffic.cars[0]
		car.v = 8.0
		var fwd: Vector3 = -car.node.basis.z
		me.global_position = city.to_global(car.node.position + fwd * 1.5) + Vector3(0, 0.2, 0)
		traffic._hit_cool = 0.0
		var before: int = traffic.hits
		traffic._check_hits(traffic._blockers(), 0.0)
		_check(traffic.hits == before + 1 and me.drunk.is_stunned(), "a car at speed knocks the player down")

	# people in the road make cars stop
	traffic.clear()
	await physics_frame
	var lane: Vector3 = traffic.lane_pos(0, 3, 1, spot.x - 80.0)
	var probe = traffic.Car.new()
	probe.axis = 0
	probe.line = 3
	probe.dir = 1
	probe.s = spot.x - 80.0
	probe.next_j = traffic._next_junction(probe.s, 1)
	probe.cruise = 12.0
	probe.v = 12.0
	traffic._make_car(probe)
	traffic._place(probe)
	traffic.add_child(probe.node)
	var limit: float = traffic._blocker_limit(probe, [{"pos": lane + Vector3(9.0, 0, 0), "node": me, "kind": "foot"}])
	_check(limit < 9.0, "a car slows for someone standing 9 m ahead in its lane (limit %.1f)" % limit)
	limit = traffic._blocker_limit(probe, [{"pos": lane + Vector3(9.0, 0, 6.0), "node": me, "kind": "foot"}])
	_check(limit >= 12.0, "a car ignores someone on the pavement")
	probe.node.queue_free()

	# street furniture is solid
	var space: PhysicsDirectSpaceState3D = city.get_world_3d().direct_space_state
	var chunk = city.chunk(city.loaded_blocks()[0])
	var solids := 0
	for n in chunk.find_children("*", "StaticBody3D", true, false):
		solids += 1
	_check(solids > 15, "a block has plenty of solid bodies, trees, poles and parked cars included (%d)" % solids)
	var probe_pos: Vector3 = city.to_global(Vector3(1000, 5, 1000))
	var ray_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(probe_pos, probe_pos + Vector3(0, -50, 0)))
	_check(not ray_hit.is_empty(), "the ground reaches the horizon")

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(_fails)
