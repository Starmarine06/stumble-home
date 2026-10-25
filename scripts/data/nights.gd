class_name Nights
extends RefCounted
## One entry per night of the campaign. home_blocks is how many blocks from the casino the crew's home can be (min, max). start_money is the crew's pool before any casino or delivery income.
## hazards is passed to Hazards.plan; tuning holds Tuning overrides, applied by apply_tuning().

const NIGHTS := [
	{
		"id": "night_1",
		"title": "Night 1: Skint, Sloshed And Stranded",
		"flavour": "You are hammered, the car is a wreck, and the nearest bed is miles away. Earn the cash for four parts, bolt them on, and try not to fall over the dog.",
		"home_blocks": [9, 14],
		"start_money": 200,
		"hazards": {"traffic_count": 0, "dog_count": 0, "mugger_count": 0, "checkpoint_count": 2},
		"kebab_shop": false,
		"tuning": {},
	},
	{
		"id": "night_2",
		"title": "Night 2: Kebab Or Die",
		"flavour": "Round two. Hungrier, drunker, and the cops brought a friend. Someone needs a kebab, and someone else needs to stop pointing at the wrong turn.",
		"home_blocks": [11, 15],
		"start_money": 300,
		"hazards": {"traffic_count": 4, "dog_count": 5, "mugger_count": 2, "checkpoint_count": 4},
		"kebab_shop": true,
		"tuning": {
			"cop_first_min": 11.0, "cop_first_max": 16.0,
			"cop_repeat_min": 16.0, "cop_repeat_max": 24.0,
			"nav_wrong_rate": 0.45,
			"overheat_repeat_min": 22.0, "overheat_repeat_max": 34.0,
		},
	},
]


static func count() -> int:
	return NIGHTS.size()


## Night definition by index, clamped to the valid range. Returns a copy.
static func get_night(i: int) -> Dictionary:
	return NIGHTS[clampi(i, 0, NIGHTS.size() - 1)].duplicate(true)


## Reset Tuning to defaults, then apply this night's overrides.
static func apply_tuning(i: int) -> void:
	Tuning.apply(Tuning.defaults())
	Tuning.apply(get_night(i).tuning)
