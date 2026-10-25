extends SceneTree
## CityBuilder streams blocks in around the viewers a couple per frame and frees the rest.
##   godot --headless --path . -s res://tests/city_builder_test.gd

var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1


func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var layout := CityLayout.new(4242)
	var city := CityBuilder.new()
	var specials := []
	city.special_hook = func(lot, _parent, _pos, _size): specials.append(lot.special)
	root.add_child(city)
	city.setup(layout)
	var center := layout.block_center(layout.casino_block)
	var t0 := Time.get_ticks_msec()
	city.build_around([center])
	var ms := Time.get_ticks_msec() - t0
	var side := 2 * CityBuilder.LOAD_R + 1
	_check(city.loaded_blocks().size() == side * side, "builds the %d x %d blocks around the viewer" % [side, side])
	print("INFO  built %d blocks in %d ms" % [city.loaded_blocks().size(), ms])
	_check(ms < 3000, "initial build is quick")
	var worst := 0
	for b in city.loaded_blocks():
		worst = maxi(worst, _count(city.chunk(b)))
	print("INFO  heaviest block has %d nodes" % worst)
	_check(worst < 650, "a block stays under 650 nodes")
	var home_kind: String = layout.block_kind(layout.casino_block)
	_check(home_kind == "casino" and city.chunk(layout.casino_block) != null, "the casino block is built")
	var statics := 0
	for ch in city.chunk(layout.casino_block).get_children():
		if ch.get_child_count() > 0 and ch.get_child(0) is StaticBody3D:
			statics += 1
	_check(statics >= 1, "block pavement is solid underfoot")

	# Landmarks fire the hook when their block is built
	var near_delivery: Vector2i = layout.landmarks.delivery.block
	city.build_around([layout.block_center(near_delivery)])
	_check(specials.has("delivery"), "the delivery shop's lot calls the landmark hook")

	# Moving away frees old blocks and queues new ones; builds are paced
	var far := layout.block_center(Vector2i(0, 0))
	city.view_points = [far]
	city.refresh()
	await process_frame
	var loaded_far := 0
	for b in city.loaded_blocks():
		if CityLayout.grid_dist(b, layout.block_at(far)) > CityBuilder.KEEP_R * 2:
			loaded_far += 1
	_check(loaded_far == 0, "blocks far from every viewer are freed")
	var before: int = city.loaded_blocks().size()
	await process_frame
	var after: int = city.loaded_blocks().size()
	_check(after - before <= CityBuilder.BUILDS_PER_FRAME, "at most %d blocks are built per frame" % CityBuilder.BUILDS_PER_FRAME)
	for _i in 30:
		await process_frame
	_check(city.loaded_blocks().has(layout.block_at(far)), "the new area fills in over a few frames")

	# Two viewers keep two areas alive
	city.build_around([layout.block_center(Vector2i(2, 2)), layout.block_center(Vector2i(13, 13))])
	_check(city.loaded_blocks().has(Vector2i(2, 2)) and city.loaded_blocks().has(Vector2i(13, 13)), "every viewer gets its own surroundings")

	# One house in four is hollow, with a doorway you can walk through
	city.build_around([center])
	var open_ids := []
	var solid_ids := []
	for b in city.loaded_blocks():
		for lot in layout.lots_of(b):
			if CityBuilder.is_open_house(lot):
				open_ids.append(lot)
			elif CityBuildings.style_of(lot) == "house":
				solid_ids.append(lot)
	var ratio := float(open_ids.size()) / maxf(float(open_ids.size() + solid_ids.size()), 1.0)
	_check(open_ids.size() > 0 and ratio > 0.15 and ratio < 0.35, "about a quarter of houses are open (%d of %d)" % [open_ids.size(), open_ids.size() + solid_ids.size()])
	var lot: Dictionary = open_ids[0]
	var house: Node3D = city.chunk(lot.block).get_node_or_null("OpenHouse_%d" % lot.id)
	_check(house != null and house.get_child_count() >= 8, "an open house is built from walls, a ceiling and furniture")
	await physics_frame
	await physics_frame
	var space := city.get_world_3d().direct_space_state
	var f: Vector3 = lot.facing
	var door: Vector3 = (house.get_node("Wall3").global_position + house.get_node("Wall4").global_position) * 0.5
	var from := Vector3(door.x, 1.0, door.z) + f * 6.0
	var through := PhysicsRayQueryParameters3D.create(from, from - f * 30.0)
	var hit_in := space.intersect_ray(through)
	_check(not hit_in.is_empty() and from.distance_to(hit_in.position) > 6.0 + 8.0, "a ray through the doorway gets inside (stops at %.1f m, the back wall)" % (from.distance_to(hit_in.position) if not hit_in.is_empty() else -1.0))
	var beside := from + Vector3(f.z, 0.0, -f.x) * 4.0
	var wall_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(beside, beside - f * 30.0))
	_check(not wall_hit.is_empty() and beside.distance_to(wall_hit.position) < 8.0, "beside the door the front wall is solid")
	var solid_lot: Dictionary = solid_ids[0]
	_check(city.chunk(solid_lot.block).get_node_or_null("OpenHouse_%d" % solid_lot.id) == null, "the other houses are plain solid boxes")

	# Real-world variety: every kind of building turns up, and the signals behave
	var styles := {}
	for l in layout.all_lots():
		styles[CityBuildings.style_of(l)] = true
	for s in ["house", "villa", "apartment", "office", "shop", "special", "home"]:
		_check(styles.has(s), "the city has %s buildings" % s)
	var first_block: Vector2i = city.loaded_blocks()[0]
	_check(city.chunk(first_block).get_node_or_null("Crosswalks") != null, "intersections have zebra crossings")
	var both_green := false
	var seen := {}
	for i in 480:
		var st: Dictionary = city.signal_state(float(i) * 0.1)
		if st.ns == 2 and st.ew == 2:
			both_green = true
		seen["%d%d" % [st.ns, st.ew]] = true
	_check(not both_green, "the signals never show green both ways")
	_check(seen.has("20") and seen.has("10") and seen.has("02") and seen.has("01"), "the signals run green, amber, then the other way")

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(_fails)
