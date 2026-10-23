class_name Roles
extends RefCounted
## The four drunks. Everyone is very drunk; each one is drunk in a different way.
## Per-role drunk levels live here; all other balance numbers are in tuning.gd (Tuning).

enum Id { DRIVER, NAVIGATOR, MECHANIC, LOOKOUT }

const INFO := {
	Id.DRIVER: {
		"name": "Driver",
		"type": "The Sloppy",
		"color": Color(0.95, 0.35, 0.3),
		"drunk": 0.92,
		"scavenge": "Strong arms: carries parts more easily, but still tires.",
		"drive": "Steer the car home. Steering wanders, lags, hiccups, and you nod off now and then.",
	},
	Id.NAVIGATOR: {
		"name": "Navigator",
		"type": "The Blabber",
		"color": Color(0.35, 0.65, 0.95),
		"drunk": 0.88,
		"scavenge": "Hauling parts wears you out. Call out where they are and keep the crew moving.",
		"drive": "Only you see the route. The arrows flicker between true and wrong, so shout what you see and trust the majority.",
	},
	Id.MECHANIC: {
		"name": "Mechanic",
		"type": "The Shaky",
		"color": Color(0.98, 0.78, 0.25),
		"drunk": 0.9,
		"scavenge": "Strong, steady hands: you haul parts without tiring. Your compass points at the nearest missing part.",
		"drive": "Keep the engine cool. When it overheats, hit the sweet spot with shaking hands.",
	},
	Id.LOOKOUT: {
		"name": "Lookout",
		"type": "The Paranoid",
		"color": Color(0.5, 0.85, 0.45),
		"drunk": 0.86,
		"scavenge": "Part sense: parts glow within 25 m. Nobody else sees them from afar.",
		"drive": "Spot cops before they spot you. Steady yourself and signal in time or the wanted level jumps.",
	},
}

static func role_name(id: int) -> String:
	return INFO[id]["name"]

static func role_color(id: int) -> Color:
	return INFO[id]["color"]

static func role_drunk(id: int) -> float:
	return INFO[id]["drunk"]
