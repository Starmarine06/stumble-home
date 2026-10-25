class_name ShopItems
extends RefCounted
## What the corner shops sell. Every purchase comes out of the crew's shared pool.
## effect keys, all optional:
##   sober   drunk level knocked off the buyer (it creeps back up over about a minute)
##   drunk   drunk level added to the buyer
##   rest    how much tiredness is shaken off (1.0 = all of it)
##   wake    wakes the buyer if they have passed out
##   crew    the drunk/sober part applies to everybody, not just the buyer
##   wanted  heat added to the crew's wanted level
## once: sold a single time per night. A negative price means the shop pays the crew.

const CATALOG := {
	"pharmacy": {
		"title": "PHARMACY",
		"blurb": "A very tired man behind glass sells you the good stuff. Mostly legal.",
		"items": [
			{"id": "pills", "name": "Sober-up pills", "price": 60, "blurb": "Clears the head. Wears off in a minute.", "effect": {"sober": 0.5}},
			{"id": "water", "name": "Bottle of water", "price": 10, "blurb": "Bit of sense, bit of energy.", "effect": {"sober": 0.1, "rest": 0.3}},
		],
	},
	"kebab": {
		"title": "KEBABS",
		"blurb": "Open very late. Closes when it feels like it.",
		"items": [
			{"id": "doner", "name": "Large doner, everything on it", "price": 30, "blurb": "Soaks up the booze and puts the legs back.", "effect": {"sober": 0.2, "rest": 0.5}},
			{"id": "chips", "name": "Cheesy chips", "price": 15, "blurb": "Fuel.", "effect": {"rest": 0.3}},
		],
	},
	"pub": {
		"title": "THE WOBBLY PUB",
		"blurb": "The hair of the dog is a real thing, apparently.",
		"items": [
			{"id": "pint", "name": "Pint of mystery", "price": 15, "blurb": "Wakes you up, and then some.", "effect": {"drunk": 0.15, "wake": true, "rest": 1.0}},
			{"id": "round", "name": "A round for the crew", "price": 80, "blurb": "Everyone's rested. Everyone is worse at everything.", "effect": {"drunk": 0.2, "rest": 1.0, "wake": true, "crew": true}},
		],
	},
	"garage": {
		"title": "GARAGE",
		"blurb": "Uncle Dave does the scooter. Cash only. Do not ask about the van.",
		"items": [
			{"id": "tuneup", "name": "Scooter tune-up", "price": 300, "once": true, "blurb": "A quarter faster. Walls arrive sooner.", "effect": {}},
			{"id": "rack", "name": "Padded parcel rack", "price": 200, "once": true, "blurb": "The parcel leans a lot less.", "effect": {}},
		],
	},
	"pawn": {
		"title": "PAWN SHOP",
		"blurb": "No questions asked. The questions are asked later, by police.",
		"items": [
			{"id": "watch", "name": "Pawn grandad's watch", "price": -150, "once": true, "blurb": "Instant cash. It might have been stolen.", "effect": {"wanted": 15.0}},
		],
	},
}


static func shop_names() -> Array:
	return CATALOG.keys()


static func items_of(shop: String) -> Array:
	return CATALOG.get(shop, {}).get("items", [])


## The item dictionary, or {} if there is no such thing.
static func find(shop: String, id: String) -> Dictionary:
	for it in items_of(shop):
		if it.id == id:
			return it
	return {}
