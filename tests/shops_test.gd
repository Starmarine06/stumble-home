extends SceneTree
## Headless: the corner shops, what they sell, the garage upgrades and the pawn shop.
##   godot --headless --path . -s res://tests/shops_test.gd

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


func _run() -> void:
	var game := root.get_node("Game")
	game.start_hosting()
	game.start_game()
	await _wait(1.0)
	var world := root.get_node_or_null("Main/World")
	var me = world.local_player()

	# Catalogue sanity
	for shop in ShopItems.shop_names():
		for it in ShopItems.items_of(shop):
			_check(it.has("id") and it.has("name") and it.has("price") and it.has("effect"), "%s/%s is a complete item" % [shop, it.get("id", "?")])
	_check(ShopItems.find("pub", "pint").price == 15 and ShopItems.find("pub", "nope").is_empty(), "items can be looked up")

	# Every shop has a counter in the world
	for shop in ShopItems.shop_names():
		_check(world.city.find_child("Counter_" + shop, true, false) != null, "the %s has a counter you can walk up to" % shop)

	game.money = 1000
	# Pharmacy: sobers the buyer
	me.drunk.level = 1.0
	game.s_buy_item("pharmacy", "pills")
	_check(game.money == 940, "pills cost $60 from the pool")
	_check(me.drunk.level < 0.6, "pills sober the buyer up (%.2f)" % me.drunk.level)
	game.s_buy_item("pharmacy", "pills")
	game.s_buy_item("pharmacy", "pills")
	_check(game.money == 820 and me.drunk.level >= 0.25, "pills can be bought again, but you cannot get below slightly drunk")

	# Pub: wakes you and makes you worse
	game.fatigue[1] = 0.9
	me.drunk.level = 0.5
	game.s_buy_item("pub", "pint")
	_check(game.fatigue_of(1) < 0.1, "a pint rests you")
	_check(me.drunk.level > 0.6, "a pint makes you drunker (%.2f)" % me.drunk.level)
	game.names[77] = "Pal"
	game.fatigue[77] = 0.8
	game.out_left[77] = 5.0
	var lvl: float = me.drunk.level
	game.s_buy_item("pub", "round")
	_check(game.fatigue_of(77) == 0.0 and not game.is_out(77) and me.drunk.level > lvl, "a round for the crew wakes and rests everyone, and fogs the buyer")
	game.out_left.erase(77)
	game.s_buy_item("pharmacy", "pills")
	game.out_left[1] = 5.0
	var m_out: int = game.money
	game.s_buy_item("pharmacy", "pills")
	_check(game.money == m_out, "you cannot shop while passed out")
	game.out_left.erase(1)
	game.names.erase(77)
	game.fatigue.erase(77)

	# Kebab
	game.fatigue[1] = 0.8
	var before_k: int = game.money
	game.s_buy_item("kebab", "doner")
	_check(game.money == before_k - 30 and game.fatigue_of(1) < 0.4, "a doner costs $30 and gives your legs back")

	# Garage upgrades
	var sc = world.delivery.scooter
	var base_speed: float = sc.top_speed()
	game.money = 1000
	game.s_buy_item("garage", "tuneup")
	_check(game.bought.has("garage/tuneup") and game.money == 700, "the tune-up costs $300")
	_check(sc.top_speed() > base_speed * 1.2, "a tuned scooter is faster (%.1f vs %.1f)" % [sc.top_speed(), base_speed])
	game.s_buy_item("garage", "tuneup")
	_check(game.money == 700, "the tune-up is a one-off")
	game.s_buy_item("garage", "rack")
	_check(game.bought.has("garage/rack") and game.money == 500, "the padded rack is bought")
	var steady_a := _lean(me, sc)
	game.bought.erase("garage/rack")
	var steady_b := _lean(me, sc)
	_check(absf(steady_a) < absf(steady_b), "the padded rack keeps the parcel steadier (%.2f vs %.2f)" % [steady_a, steady_b])
	game.bought["garage/rack"] = true

	# Pawn shop: cash now, heat later, once
	var m: int = game.money
	var w: float = game.wanted
	game.s_buy_item("pawn", "watch")
	_check(game.money == m + 150 and game.wanted >= w + 14.0, "pawning the watch pays $150 and raises the heat")
	game.s_buy_item("pawn", "watch")
	_check(game.money == m + 150, "you only have one grandad")

	# Not enough money, wrong place, wrong time
	game.money = 5
	game.s_buy_item("pharmacy", "pills")
	_check(game.money == 5, "no sale without the money")
	game.money = 500
	game.s_buy_item("pharmacy", "nothing")
	game.s_buy_item("nowhere", "pills")
	_check(game.money == 500, "no sale of things that do not exist")
	game.phase = game.Phase.DRIVE
	game.s_buy_item("pharmacy", "pills")
	game.phase = game.Phase.SCAVENGE
	_check(game.money == 500, "the shops are shut during the drive home")

	# The counter opens the shop panel and freezes you
	var counter = world.city.find_child("Counter_pharmacy", true, false)
	counter.activate(me)
	await _wait(0.1)
	_check(world.modal != null and world.modal.get("shop") == "pharmacy" and me.ui_lock, "the counter opens its shop and holds you still")
	world.close_modal()
	_check(world.modal == null and not me.ui_lock, "leaving frees you")

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(_fails)


## How far a parcel that starts a little off-centre has leaned after a second of sitting still,
## with whatever upgrades are bought. A leaning parcel keeps leaning, a padded rack less so.
func _lean(me, sc) -> float:
	me.parcel_tilt = 0.3
	me.drunk.level = 0.25
	for _i in 30:
		sc.speed = 0.0
		sc.yaw_rate = 0.0
		me._balance_parcel(0.033, sc)
	return me.parcel_tilt
