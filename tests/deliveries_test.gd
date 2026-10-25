extends SceneTree
## The job board is pure logic: deterministic, sensible distances and pay, honest payout maths.
##   godot --headless --path . -s res://tests/deliveries_test.gd

var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1


func _initialize() -> void:
	var city := CityLayout.new(777)
	var a := Deliveries.board(city, 777)
	var b := Deliveries.board(city, 777)
	_check(a == b and a.size() == Deliveries.BOARD_SIZE, "the same seed makes the same board")
	_check(Deliveries.board(city, 778) != a, "a different seed makes a different board")
	var ids := {}
	for o in a:
		ids[o.id] = true
	_check(ids.size() == a.size(), "order ids are unique")

	var dists: Array[float] = []
	var pays: Array[float] = []
	var bad := 0
	var shop: Dictionary = city.landmarks.delivery
	for i in 400:
		var rng := RandomNumberGenerator.new()
		rng.seed = i * 31 + 5
		var o := Deliveries.make_order(city, rng, i)
		var lot := city.lot_by_id(o.lot)
		if lot.is_empty() or lot.kind == "park" or lot.kind == "special":
			bad += 1
		if o.dist < Deliveries.MIN_TRIP or o.dist > Deliveries.MAX_TRIP or o.pay <= 0 or o.time <= 0:
			bad += 1
		if o.addr != city.address(lot):
			bad += 1
		dists.append(o.dist)
		pays.append(o.pay)
	_check(bad == 0, "every order has a real door, a sane trip, pay and deadline")
	var avg := 0.0
	var avg_pay := 0.0
	for i in dists.size():
		avg += dists[i]
		avg_pay += pays[i]
	avg /= dists.size()
	avg_pay /= pays.size()
	print("INFO  average trip %.0f m, pay $%.0f, tightest deadline %d s" % [avg, avg_pay, Deliveries.time_limit(avg)])
	_check(avg > 900.0 and avg < 1900.0, "a delivery is a long ride (avg %d m)" % avg)
	var secs := Deliveries.time_limit(avg)
	_check(secs >= 120 and secs <= 330, "the deadline allows a few minutes (%d s)" % secs)
	var runs := PartsShop.total() / avg_pay
	print("INFO  perfect deliveries to pay for all parts: %.1f" % runs)
	_check(runs >= 8.0, "parts cost many deliveries, so the casino cannot replace the work")

	_check(Deliveries.payout(300, 100.0, false) == 300, "a clean, on-time parcel pays in full")
	_check(Deliveries.payout(300, 100.0, true) == 150, "late pays half")
	_check(Deliveries.payout(300, 0.0, false) == 120, "a wrecked parcel still pays something")
	_check(Deliveries.payout(300, 50.0, false) < 300 and Deliveries.payout(300, 50.0, false) > 120, "damage scales the fee")
	_check(Deliveries.compass(Vector3.ZERO, Vector3(100, 0, 0)) == "E", "compass: east")
	_check(Deliveries.compass(Vector3.ZERO, Vector3(0, 0, -100)) == "N", "compass: north is -z")
	_check(Deliveries.compass(Vector3.ZERO, Vector3(-70, 0, 70)) == "SW", "compass: south-west")
	_check(Deliveries.compass(Vector3.ZERO, Vector3(2, 0, 2)) == "HERE", "compass: arrived")

	var fp := city.front_point(shop)
	var sp: Vector3 = shop.street_point
	_check(fp.distance_to(sp) > 3.0 and fp.distance_to(sp) < 30.0, "the shop front is near its street (%.1f m)" % fp.distance_to(sp))

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(_fails)
