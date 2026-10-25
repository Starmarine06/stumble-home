extends SceneTree
## Headless: the delivery loop on the host (solo): job board, parcel, scooter seats, the parcel
## balance, drops, deliveries and what they pay.
##   godot --headless --path . -s res://tests/delivery_test.gd

var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	_run.call_deferred()


func _find(n: Node, node_name: String) -> Node:
	return n.find_child(node_name, true, false)


func _run() -> void:
	var game := root.get_node("Game")
	game.start_hosting()
	game.start_game()
	await _wait(1.0)
	var world := root.get_node_or_null("Main/World")
	var me = world.local_player()
	var money0: int = game.money

	# The board and the shop
	_check(game.orders.size() == Deliveries.BOARD_SIZE, "the job board has %d orders" % game.orders.size())
	_check(_find(world.city, "JobBoard") != null, "the delivery shop has its job board built in")
	_check(world.delivery.scooter != null and world.delivery.scooter.global_position.distance_to(game.shop_front()) < 12.0, "the scooter is parked outside the shop")
	_check(game.job.is_empty(), "no job at the start")

	# Take a job with nobody on the scooter: the parcel waits at the door
	var first: Dictionary = game.orders[0]
	game.s_take_order(first.id)
	_check(not game.job.is_empty() and game.job.id == first.id, "taking an order starts the job")
	_check(game.job.state == "loose" and game.job.pos.distance_to(game.shop_front()) < 0.01, "the parcel waits at the shop door")
	_check(game.orders.size() == Deliveries.BOARD_SIZE and game.order_serial == Deliveries.BOARD_SIZE + 1, "the board refills")
	var second: Dictionary = game.orders[0]
	game.s_take_order(second.id)
	_check(game.job.id == first.id, "only one job at a time")
	await _wait(0.2)
	_check(world.delivery.parcel.visible and world.delivery.parcel.enabled, "the loose parcel can be picked up")
	_check(world.delivery.dest.visible and not world.delivery.dest.enabled, "the address is marked but you cannot deliver without the parcel")

	# Deliver without carrying: refused
	game.s_deliver()
	_check(not game.job.is_empty(), "cannot hand over a parcel you are not holding")

	# Scooter seats
	game.s_seat(2)
	_check(game.seat_pillion == 1 and game.seat_driver == 0, "hop on behind")
	game.s_seat(1)
	_check(game.seat_driver == 0, "one rider cannot take both seats")
	game.s_unseat()
	_check(game.seat_pillion == 0, "hop off")
	game.s_seat(1)
	_check(game.seat_driver == 1, "take the driving seat")
	await _wait(0.3)
	_check(me.riding == 1 and me.collision_layer == 0, "the player is riding and no longer collides with the scooter")
	_check(me.global_position.distance_to(world.delivery.scooter.seat_global(1)) < 0.5, "the rider sits on the seat")
	_check(not world.delivery.scooter.drive_seat.enabled, "a taken seat offers no prompt")

	# Driving
	var sc = world.delivery.scooter
	var p0: Vector3 = sc.global_position
	Input.action_press("forward")
	for _i in 90:
		await physics_frame
	Input.action_release("forward")
	_check(sc.speed > 3.0, "throttle speeds the scooter up (%.1f m/s)" % sc.speed)
	_check(sc.global_position.distance_to(p0) > 3.0, "the scooter moves (%.1f m)" % sc.global_position.distance_to(p0))
	_check(absf(sc.global_position.y) < 1.0, "it stays on the ground")
	for _i in 200:
		await physics_frame
	_check(sc.speed < 4.0, "it rolls to a stop")

	# Parcel balance: the pillion rider holds the parcel
	game.s_unseat()
	await _wait(0.6)
	game.s_parcel_pickup()
	_check(game.carried_job_by(1) and game.job.carrier == 1, "picking the parcel up puts it in your hands")
	game.s_seat(2)
	await _wait(0.3)
	_check(me.riding == 2, "riding pillion with the parcel")
	me.parcel_tilt = 0.0
	for _i in 30:
		sc.speed = 10.0
		sc.yaw_rate = -1.0
		me._balance_parcel(0.033, sc)
	_check(me.parcel_tilt < -0.1, "a right-hand corner pushes the parcel outwards (%.2f)" % me.parcel_tilt)
	Input.action_press("right")
	for _i in 15:
		sc.speed = 0.0
		sc.yaw_rate = 0.0
		me._balance_parcel(0.033, sc)
	Input.action_release("right")
	_check(me.parcel_tilt > -0.3 and absf(me.parcel_tilt) < 1.0, "A and D steady it again (%.2f)" % me.parcel_tilt)
	var integ0: float = game.job.integrity
	me.parcel_tilt = 0.0
	game.s_parcel_bump(10.0)
	_check(game.job.integrity == integ0 - 10.0, "a bump scuffs the parcel")
	me.parcel_tilt = 0.99
	sc.speed = 12.0
	sc.yaw_rate = 4.0
	me._balance_parcel(0.1, sc)
	await _wait(0.2)
	_check(game.job.state == "loose" and game.job.integrity == integ0 - 10.0 - Deliveries.DROP_DAMAGE, "lose your grip and the parcel falls and is damaged")
	_check(me.parcel_tilt == 0.0, "the balance resets after the drop")

	# Fetch it and deliver
	game.s_unseat()
	await _wait(0.6)
	game.s_parcel_pickup()
	_check(game.carried_job_by(1), "pick the dropped parcel up again")
	var m_before: int = game.money
	var expect := Deliveries.payout(int(game.job.pay), float(game.job.integrity), false)
	var tip := Deliveries.tip(int(game.job.id), game.world_seed, expect)
	world.delivery.dest.global_position = me.global_position
	await _wait(0.3)
	_check(world.delivery.dest.enabled, "carrying the parcel, the door offers the hand-over")
	world.delivery.dest.activate(me)
	await _wait(0.2)
	_check(game.job.is_empty() and game.money == m_before + expect + tip, "delivery pays $%d (+$%d tip) for a battered parcel" % [expect, tip])
	_check(expect < Deliveries.payout(int(first.pay), 100.0, false), "a battered parcel pays less than a clean one")

	# Late
	game.s_take_order(game.orders[0].id)
	var late_pay: int = game.job.pay
	game.s_parcel_pickup()
	game.job.time_left = -1.0
	game._tick_job(0.5)
	_check(game.job.late, "a late job is flagged")
	var m2: int = game.money
	game.s_deliver()
	_check(game.money == m2 + Deliveries.payout(late_pay, 100.0, true), "a late delivery pays half")

	# Things go wrong on the road
	game.s_take_order(game.orders[0].id)
	game.s_parcel_pickup()
	var leak_i: float = game.job.integrity
	game._job_event("leak")
	_check(game.job.leak > 0.0, "a leak starts")
	game._tick_job(5.0)
	_check(game.job.integrity < leak_i - 1.5, "a leaking parcel loses condition (%.1f)" % game.job.integrity)
	var t_before: float = game.job.time_left
	game._job_event("hurry")
	_check(game.job.time_left == t_before - Deliveries.HURRY_TIME, "an impatient customer takes time off the clock")
	var lot_before: int = game.job.lot
	var pay_before: int = game.job.pay
	var t2: float = game.job.time_left
	game._job_event("reroute")
	_check(game.job.lot != lot_before and game.job.pay > pay_before and game.job.time_left > t2, "a customer who moves pays a bit more and gives more time")
	_check(game.job.addr == game.city.address(game.city.lot_by_id(game.job.lot)), "the new address matches the new door")
	game._job_event("nonsense")
	game._job_event_in = 0.01
	var snap := [game.job.leak, game.job.time_left, game.job.lot]
	game._tick_job(0.1)
	_check(game.job.leak != snap[0] or game.job.lot != snap[2] or game.job.time_left < snap[1] - 0.2, "random trouble turns up on a long trip")
	_check(Deliveries.tip(5, 1, 300) == Deliveries.tip(5, 1, 300) and Deliveries.reaction(5, 1) == Deliveries.reaction(5, 1), "tips and reactions are stable per order")
	var tipped := 0
	var tip_ok := true
	for i in 200:
		var tv := Deliveries.tip(i, 99, 300)
		if tv > 0:
			tipped += 1
			if tv < 25 or tv > 125:
				tip_ok = false
	_check(tip_ok and tipped > 20 and tipped < 90, "about a quarter of customers tip, between 10 and 40 percent (%d of 200)" % tipped)
	game.s_abandon_job()

	# Abandon
	game.s_take_order(game.orders[0].id)
	game.s_abandon_job()
	_check(game.job.is_empty(), "a job can be binned")
	_check(game.money > money0, "the crew earned money from deliveries")

	# Phase gating: nothing works during the drive
	game.phase = game.Phase.DRIVE
	game.s_take_order(game.orders[0].id)
	_check(game.job.is_empty(), "no deliveries during the drive home")
	game.phase = game.Phase.SCAVENGE

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(_fails)
