extends SceneTree
## Tuning defaults and overrides. Run:
##   godot --headless --path . -s res://tests/tuning_test.gd

# The values that used to be hard-coded in game.gd, drunk.gd, drive.gd, player.gd, hud.gd.
const OLD := {
	"trip_min": 6.0, "trip_max": 14.0, "trip_level_base": 1.6,
	"trip_stun_base": 0.7, "trip_stun_per_level": 0.6,
	"stumble_gain": 0.25, "stumble_drain": 0.5,
	"stumble_threshold": 1.0, "stumble_warn_time": 1.2,
	"grab_cooldown": 0.4, "pickup_strain": 0.1,
	"loose_min": 10.0, "loose_max": 22.0, "loose_q_base": 0.4,
	"passout_secs": 25.0, "fatigue_carry_base": 0.01, "fatigue_carry_per_kg": 0.003,
	"fatigue_recover": 0.03, "fatigue_wake": 0.4,
	"overheat_first_min": 18.0, "overheat_first_max": 28.0,
	"overheat_repeat_min": 25.0, "overheat_repeat_max": 40.0,
	"overheat_hp_drain": 1.5, "cool_fail_damage": 5.0,
	"cop_first_min": 14.0, "cop_first_max": 20.0,
	"cop_repeat_min": 20.0, "cop_repeat_max": 30.0, "cop_window": 7.0,
	"cop_success_wanted": -8.0, "cop_fail_wanted": 10.0, "cop_miss_wanted": 25.0,
	"wanted_decay_scavenge": 0.6, "wanted_decay_drive": 0.3,
	"nod_first_min": 10.0, "nod_first_max": 16.0,
	"nod_repeat_min": 14.0, "nod_repeat_max": 22.0,
	"hiccup_min": 5.0, "hiccup_max": 9.0,
	"nav_wrong_rate": 0.35,
}

var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Defaults equal the old hard-coded values.
	var d := Tuning.defaults()
	_check(d.size() == OLD.size(), "defaults() has %d keys" % OLD.size())
	var all_ok := true
	for k in OLD:
		if not d.has(k) or not is_equal_approx(d[k], OLD[k]) or not is_equal_approx(Tuning.get_value(k), OLD[k]):
			all_ok = false
			print("  mismatch: ", k)
	_check(all_ok, "every default equals the old value")

	# Unknown keys do not crash and do not change anything.
	Tuning.apply({"no_such_key": 5.0})
	_check(is_equal_approx(Tuning.get_value("cop_window"), 7.0), "unknown key ignored")

	# Cop repeat override reaches the host referee.
	var game := root.get_node("Game")
	Tuning.apply({"cop_repeat_min": 1.0, "cop_repeat_max": 1.0})
	game.phase = game.Phase.DRIVE
	game.role_owner[Roles.Id.LOOKOUT] = game.my_id()
	game._cop_open = true
	game._cop_timer = 99.0
	game.s_cop_result(true)
	_check(is_equal_approx(game._cop_timer, 1.0), "_cop_timer == 1.0 after s_cop_result")

	# Wanted change on success comes from Tuning.
	Tuning.reset()
	game.wanted = 50.0
	game._cop_open = true
	game.s_cop_result(true)
	_check(is_equal_approx(game.wanted, 42.0), "cop success lowers wanted by 8")
	game.phase = game.Phase.MENU

	# A fast-moving level 0.9 Drunk trips inside an overridden window; an idle one never does.
	Tuning.apply({"stumble_gain": 2.0, "stumble_warn_time": 0.5})
	var dr := Drunk.new(0.9)
	var idle := Drunk.new(0.9)
	var trips := [0, 0]
	var first := [-1.0]
	dr.tripped.connect(func(): trips[0] += 1)
	idle.tripped.connect(func(): trips[1] += 1)
	var t := 0.0
	while t < 3.0:
		dr.tick(1.0 / 60.0, true, 1.0)
		idle.tick(1.0 / 60.0, true, 0.0)
		t += 1.0 / 60.0
		if trips[0] > 0 and first[0] < 0.0:
			first[0] = t
	# risk fills in ~0.36 s at gain 2, then 0.5 s warning
	_check(trips[0] >= 1, "fast drunk tripped under overridden stumble tuning")
	_check(first[0] > 0.0 and first[0] <= 1.5, "first trip inside override window (%.2fs)" % first[0])
	_check(trips[1] == 0, "idle drunk never trips")

	# defaults() restores everything.
	Tuning.apply({"cop_repeat_min": 1.0, "trip_min": 2.0, "nav_wrong_rate": 0.9})
	Tuning.reset()
	var restored := true
	for k in OLD:
		if not is_equal_approx(Tuning.get_value(k), OLD[k]):
			restored = false
	_check(restored, "reset restores every default")
	Tuning.apply(Tuning.defaults())
	_check(is_equal_approx(Tuning.trip_min, 6.0), "apply(defaults()) is a no-op")

	print("FAILURES: %d" % _fails)
	quit(1 if _fails > 0 else 0)
