class_name Tuning
extends RefCounted
## Every balance number in one place. Gameplay code reads these statics; tests and
## difficulty modes change them with apply({...}) and put them back with defaults().
## Per-role drunk levels live in roles.gd.

# Trips (drunk.gd): next trip in randf_range(min, max) * (trip_level_base - level) seconds.
static var trip_min := 6.0
static var trip_max := 14.0
static var trip_level_base := 1.6
static var trip_stun_base := 0.7
static var trip_stun_per_level := 0.6

# Hands (player.gd)
static var grab_cooldown := 0.4
static var pickup_strain := 0.1          # strain added by the heave off the floor (12 kg part)

# Parts and fatigue (game.gd)
static var loose_min := 10.0
static var loose_max := 22.0
static var loose_q_base := 0.4           # loose timer scales by (loose_q_base + fit quality)
static var passout_secs := 25.0
static var fatigue_carry_base := 0.01    # per second while hauling
static var fatigue_carry_per_kg := 0.003
static var fatigue_recover := 0.03       # per second while empty-handed
static var fatigue_wake := 0.4           # fatigue after waking up

# Overheating (game.gd)
static var overheat_first_min := 18.0
static var overheat_first_max := 28.0
static var overheat_repeat_min := 25.0
static var overheat_repeat_max := 40.0
static var overheat_hp_drain := 1.5      # car HP per second while hot
static var cool_fail_damage := 5.0

# Cops (game.gd)
static var cop_first_min := 14.0
static var cop_first_max := 20.0
static var cop_repeat_min := 20.0
static var cop_repeat_max := 30.0
static var cop_window := 7.0
static var cop_success_wanted := -8.0
static var cop_fail_wanted := 10.0
static var cop_miss_wanted := 25.0

# Wanted decay per second (game.gd)
static var wanted_decay_scavenge := 0.6
static var wanted_decay_drive := 0.3

# Driving (drive.gd)
static var nod_first_min := 10.0
static var nod_first_max := 16.0
static var nod_repeat_min := 14.0
static var nod_repeat_max := 22.0
static var hiccup_min := 5.0
static var hiccup_max := 9.0

# Navigator (hud.gd): chance an arrow is wrong = nav_wrong_rate * drunk level.
static var nav_wrong_rate := 0.35


static func _table() -> Dictionary:
	return {
		"trip_min": 6.0, "trip_max": 14.0, "trip_level_base": 1.6,
		"trip_stun_base": 0.7, "trip_stun_per_level": 0.6,
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


## The shipped values, keyed by name.
static func defaults() -> Dictionary:
	return _table()


## Set values by key. Unknown keys are skipped with a warning.
static func apply(overrides: Dictionary) -> void:
	var known := _table()
	for k in overrides:
		if known.has(k):
			set_value(k, float(overrides[k]))
		else:
			push_warning("Tuning: unknown key '%s' ignored" % str(k))


## Put every value back to its default.
static func reset() -> void:
	apply(_table())


static func set_value(key: String, v: float) -> void:
	match key:
		"trip_min": trip_min = v
		"trip_max": trip_max = v
		"trip_level_base": trip_level_base = v
		"trip_stun_base": trip_stun_base = v
		"trip_stun_per_level": trip_stun_per_level = v
		"grab_cooldown": grab_cooldown = v
		"pickup_strain": pickup_strain = v
		"loose_min": loose_min = v
		"loose_max": loose_max = v
		"loose_q_base": loose_q_base = v
		"passout_secs": passout_secs = v
		"fatigue_carry_base": fatigue_carry_base = v
		"fatigue_carry_per_kg": fatigue_carry_per_kg = v
		"fatigue_recover": fatigue_recover = v
		"fatigue_wake": fatigue_wake = v
		"overheat_first_min": overheat_first_min = v
		"overheat_first_max": overheat_first_max = v
		"overheat_repeat_min": overheat_repeat_min = v
		"overheat_repeat_max": overheat_repeat_max = v
		"overheat_hp_drain": overheat_hp_drain = v
		"cool_fail_damage": cool_fail_damage = v
		"cop_first_min": cop_first_min = v
		"cop_first_max": cop_first_max = v
		"cop_repeat_min": cop_repeat_min = v
		"cop_repeat_max": cop_repeat_max = v
		"cop_window": cop_window = v
		"cop_success_wanted": cop_success_wanted = v
		"cop_fail_wanted": cop_fail_wanted = v
		"cop_miss_wanted": cop_miss_wanted = v
		"wanted_decay_scavenge": wanted_decay_scavenge = v
		"wanted_decay_drive": wanted_decay_drive = v
		"nod_first_min": nod_first_min = v
		"nod_first_max": nod_first_max = v
		"nod_repeat_min": nod_repeat_min = v
		"nod_repeat_max": nod_repeat_max = v
		"hiccup_min": hiccup_min = v
		"hiccup_max": hiccup_max = v
		"nav_wrong_rate": nav_wrong_rate = v


## Current value of a key (for tests).
static func get_value(key: String) -> float:
	return _read(key)


static func _read(key: String) -> float:
	var out := 0.0
	match key:
		"trip_min": out = trip_min
		"trip_max": out = trip_max
		"trip_level_base": out = trip_level_base
		"trip_stun_base": out = trip_stun_base
		"trip_stun_per_level": out = trip_stun_per_level
		"grab_cooldown": out = grab_cooldown
		"pickup_strain": out = pickup_strain
		"loose_min": out = loose_min
		"loose_max": out = loose_max
		"loose_q_base": out = loose_q_base
		"passout_secs": out = passout_secs
		"fatigue_carry_base": out = fatigue_carry_base
		"fatigue_carry_per_kg": out = fatigue_carry_per_kg
		"fatigue_recover": out = fatigue_recover
		"fatigue_wake": out = fatigue_wake
		"overheat_first_min": out = overheat_first_min
		"overheat_first_max": out = overheat_first_max
		"overheat_repeat_min": out = overheat_repeat_min
		"overheat_repeat_max": out = overheat_repeat_max
		"overheat_hp_drain": out = overheat_hp_drain
		"cool_fail_damage": out = cool_fail_damage
		"cop_first_min": out = cop_first_min
		"cop_first_max": out = cop_first_max
		"cop_repeat_min": out = cop_repeat_min
		"cop_repeat_max": out = cop_repeat_max
		"cop_window": out = cop_window
		"cop_success_wanted": out = cop_success_wanted
		"cop_fail_wanted": out = cop_fail_wanted
		"cop_miss_wanted": out = cop_miss_wanted
		"wanted_decay_scavenge": out = wanted_decay_scavenge
		"wanted_decay_drive": out = wanted_decay_drive
		"nod_first_min": out = nod_first_min
		"nod_first_max": out = nod_first_max
		"nod_repeat_min": out = nod_repeat_min
		"nod_repeat_max": out = nod_repeat_max
		"hiccup_min": out = hiccup_min
		"hiccup_max": out = hiccup_max
		"nav_wrong_rate": out = nav_wrong_rate
	return out
