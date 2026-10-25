extends SceneTree
## Headless: the casino tables take stakes from the shared pool and pay back against them.
##   godot --headless --path . -s res://tests/casino_test.gd

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


## First child of the player's HUD layer whose script file ends with this name.
func _dialog(me: Node, file: String) -> Node:
	for c in me.get_node("HUD").get_children():
		var sc: Script = c.get_script()
		if sc != null and sc.resource_path.ends_with(file):
			return c
	return null


func _run() -> void:
	var game := root.get_node("Game")
	game.start_hosting()
	game.start_game()
	await _wait(1.0)
	var world := root.get_node_or_null("Main/World")
	var me = world.local_player()
	var casino = world.casino
	_check(casino != null and casino.tables.size() == 4, "casino has its four tables")
	_check(casino.find_child("RouletteTable3D", true, false) != null, "casino scene is built")
	_check(casino.find_child("NPC_Barney", true, false) != null, "Barney is in the building")
	_check(me.get_node_or_null("HUD") != null and me.interact_prompt_lbl != null, "player has the casino HUD layer")
	var shadowed := 0
	for l in casino.find_children("*", "Light3D", true, false):
		if l.shadow_enabled:
			shadowed += 1
	_check(shadowed == 0, "no casino light casts shadows (they overflow the shadow atlas and flicker)")
	_check(me.player_money == game.money, "player_money reads the shared pool")

	game.money = 1000

	# Slots
	casino.tables["slots"].activate(me)
	_check(casino.busy and me.ui_lock, "slots table locks the player")
	var dlg = _dialog(me, "simple_bet_dialog.gd")
	_check(dlg != null, "slots shows a stake screen")
	dlg.bet_confirmed.emit(100)
	await _wait(0.2)
	_check(game.money == 900, "slots stake leaves the pool")
	var mg: Control = _dialog(me, "slots_game.gd")
	_check(mg != null, "slots game starts after the stake")
	mg.reel_states = [2, 2, 2]
	mg.finished.emit(true)
	await _wait(0.2)
	_check(game.money == 1300, "slots triple pays 4x the stake")
	_check(not casino.busy and not me.ui_lock, "slots frees the player")
	mg.queue_free()

	# Cup pong, lost then won
	casino.tables["cup_pong"].activate(me)
	_dialog(me, "simple_bet_dialog.gd").bet_confirmed.emit(300)
	await _wait(0.2)
	_check(game.money == 1000, "cup pong stake leaves the pool")
	mg = _dialog(me, "cup_pong_game.gd")
	mg.finished.emit(false)
	await _wait(0.2)
	_check(game.money == 1000 and not casino.busy, "lost cup pong keeps the stake gone")
	mg.queue_free()
	casino.tables["cup_pong"].activate(me)
	_dialog(me, "simple_bet_dialog.gd").bet_confirmed.emit(100)
	await _wait(0.2)
	mg = _dialog(me, "cup_pong_game.gd")
	mg.finished.emit(true)
	await _wait(0.2)
	_check(game.money == 1100, "won cup pong doubles the stake")
	mg.queue_free()

	# Walking away costs nothing; an empty pool refuses
	casino.tables["slots"].activate(me)
	_dialog(me, "simple_bet_dialog.gd").cancelled.emit()
	_check(not casino.busy and not me.ui_lock and game.money == 1100, "walking away costs nothing")
	_dialog(me, "simple_bet_dialog.gd").queue_free()
	game.money = 0
	casino.tables["slots"].activate(me)
	_check(not casino.busy, "an empty pool keeps you out of the casino")
	game.money = 1000

	# Darts
	casino.tables["darts"].activate(me)
	var dd := _dialog(me, "darts_betting_dialog.gd")
	_check(dd != null, "darts shows its betting screen")
	dd.bet_confirmed.emit(50)
	await _wait(0.5)
	_check(game.money == 950, "darts stake leaves the pool")
	var session: Node = null
	for c in me.get_children():
		if c.get_script() != null and c.get_script().resource_path.ends_with("darts_3d_game.gd"):
			session = c
	_check(session != null, "darts session starts")
	me.player_money += 175
	await _wait(0.2)
	_check(game.money == 1125, "darts winnings are paid into the pool")
	session.cleanup()
	session.finished.emit(false, 175)
	await _wait(0.2)
	_check(not casino.busy and not me.ui_lock, "darts frees the player")
	session.queue_free()

	# Roulette
	var table: Node3D = casino.find_child("RouletteTable3D", true, false)
	casino.tables["roulette"].activate(me)
	var rd := _dialog(me, "roulette_betting_dialog.gd")
	_check(rd != null, "roulette shows its betting screen")
	rd.bet_confirmed.emit(100, "RED", null)
	await _wait(0.5)
	_check(game.money == 1025, "roulette stake leaves the pool")
	_check(table.is_spinning, "the wheel is spinning")
	_check(not me.ui_lock, "you can walk around while the ball rolls")
	me.player_money += 200
	await _wait(0.2)
	_check(game.money == 1225, "roulette winnings are paid into the pool")
	table.spin_finished.emit(true, 1, "RED", 200)
	_check(not casino.busy and me.casino_kind == "", "roulette finishes cleanly")

	# No payout without a stake
	me.casino_kind = "roulette"
	me.player_money += 5000
	await _wait(0.2)
	_check(game.money == 1225, "a payout with no stake is ignored")

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(_fails)
