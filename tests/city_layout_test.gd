extends SceneTree
## CityLayout is pure logic: same seed, same city; the casino lands somewhere random but never at the
## edge; the way home is a connected walk of the street grid with only right-angle turns.
##   godot --headless --path . -s res://tests/city_layout_test.gd

var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1


func _on_road(l: CityLayout, p: Vector3) -> bool:
	for i in l.blocks + 1:
		if absf(p.x - l.road_line(i)) < 0.01 or absf(p.z - l.road_line(i)) < 0.01:
			return true
	return false


func _initialize() -> void:
	var a := CityLayout.new(1234)
	var b := CityLayout.new(1234)
	_check(a.casino_block == b.casino_block and a.home_block == b.home_block, "same seed gives the same casino and home")
	var ra := a.route_points()
	var rb := b.route_points()
	_check(ra.pts == rb.pts and ra.turns == rb.turns, "same seed gives the same route")

	var casinos := {}
	var bad_edge := 0
	var bad_home := 0
	var bad_landmarks := 0
	var bad_route := 0
	var bad_turn := 0
	var bad_roads := 0
	var bad_streetpt := 0
	var lens: Array[float] = []
	var min_corners := 99
	for s in 300:
		var l := CityLayout.new(s * 7919 + 13)
		casinos[l.casino_block] = true
		var cb := l.casino_block
		if cb.x < 3 or cb.y < 3 or cb.x > l.blocks - 4 or cb.y > l.blocks - 4:
			bad_edge += 1
		var d := CityLayout.grid_dist(l.home_block, cb)
		if l.block_kind(l.home_block) != "residential" or d < 9 or d > 14 or l.home_lot.kind != "home":
			bad_home += 1
		var names := {}
		for nm in l.landmarks:
			names[l.landmarks[nm].id] = true
		if l.landmarks.size() != CityLayout.LANDMARKS.size() or names.size() != l.landmarks.size():
			bad_landmarks += 1
		var r := l.route_points()
		var pts: Array = r.pts
		var length := CityLayout.route_length(pts)
		lens.append(length)
		min_corners = mini(min_corners, pts.size())
		if pts[0] != l.carpark_center() or pts[-1] != l.home_door() or r.turns.size() != pts.size() - 2:
			bad_route += 1
		for k in range(1, pts.size() - 1):
			var v1 := Vector2(pts[k].x - pts[k - 1].x, pts[k].z - pts[k - 1].z).normalized()
			var v2 := Vector2(pts[k + 1].x - pts[k].x, pts[k + 1].z - pts[k].z).normalized()
			if absf(v1.dot(v2)) > 0.01:
				bad_turn += 1
			if not _on_road(l, pts[k]):
				bad_roads += 1
		if not _on_road(l, l.home_door()):
			bad_streetpt += 1
		if length < 900.0 or length > 2600.0:
			bad_route += 1
	_check(casinos.size() >= 40, "casino placement varies with the seed (%d distinct blocks in 300 seeds)" % casinos.size())
	_check(bad_edge == 0, "casino is never in the outer ring")
	_check(bad_home == 0, "home is a residential lot 9 to 14 blocks from the casino")
	_check(bad_landmarks == 0, "all landmark lots are reserved and distinct")
	_check(bad_route == 0, "route runs from the car park to the door, 0.9 to 2.6 km long")
	_check(bad_turn == 0, "every corner is a right angle, never a U-turn")
	_check(bad_roads == 0, "every corner sits on a street")
	_check(bad_streetpt == 0, "the home door meets the street")
	_check(min_corners >= CityLayout.MIN_ROUTE_POINTS, "even the shortest route has corners to navigate (min %d points)" % min_corners)
	var avg := 0.0
	for x in lens:
		avg += x
	avg /= lens.size()
	print("INFO  average route %.0f m, range %.0f to %.0f m" % [avg, lens.min(), lens.max()])

	# Lots and addresses
	var l0 := CityLayout.new(99)
	var lots := l0.all_lots()
	var ids := {}
	var addrs := {}
	for lot in lots:
		ids[lot.id] = true
		addrs[l0.address(lot)] = true
	_check(ids.size() == lots.size(), "lot ids are unique (%d lots)" % lots.size())
	_check(addrs.size() == lots.size(), "addresses are unique")
	_check(lots.size() == (l0.blocks * l0.blocks - 1) * 12, "12 lots on every block except the casino's")
	var lot_ok := true
	for lot in lots:
		if not _on_road(l0, lot.street_point):
			lot_ok = false
		if l0.lot_by_id(lot.id).get("id", -1) != lot.id:
			lot_ok = false
	_check(lot_ok, "every lot reaches a street and can be looked up by id")
	_check(l0.landmarks.has("delivery"), "the delivery shop has a lot")
	var near := CityLayout.grid_dist(l0.landmarks.delivery.block, l0.casino_block)
	_check(near >= 1 and near <= 2, "the delivery shop is a block or two from the casino")

	# Car park and casino sit in the same block, clear of each other
	var o := l0.casino_origin()
	var c := l0.carpark_center()
	_check(l0.block_at(o) == l0.casino_block and l0.block_at(c) == l0.casino_block, "casino and car park share a block")
	_check(c.z - o.z > 14.5 + 20.0, "the car starts well out in front of the casino (%.0f m)" % (c.z - o.z))

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(_fails)
