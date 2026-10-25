class_name Deliveries
extends RefCounted
## The sketchy delivery job board. Pure logic: orders are made from a seed and the city, so every
## peer can build the same board; only taking and finishing a job goes through the host.

const ITEMS := [
	"a suspiciously warm paper bag", "a locked briefcase that rattles", "three live crabs in a sock",
	"a parcel marked DEFINITELY LEGAL", "forty-one kebab skewers", "a ficus nobody asked for",
	"grandad's medicine", "a tub of something labelled CHEESE", "a bag of mixed keys",
	"a sealed envelope. It is ticking.", "one (1) swan, sedated", "a Tupperware of regret",
]
const REACTIONS := [
	"\"Cheers, mate. You never saw me.\"", "\"Is it still moving? Good.\"", "\"You're late. Fine. Whatever. Give.\"",
	"The door opens six inches. A hand takes the parcel. The door shuts.", "\"Oh, lovely. Is that smell normal?\"",
	"\"I did not order this. I will keep it though.\"", "\"Dave said you'd be taller.\"",
	"A dog sniffs the parcel, then you, then sneezes.", "\"Wrong house. But I'll take it.\"",
]
const TIP_CHANCE := 0.25
const TIP_MIN := 0.1
const TIP_MAX := 0.4
const REROUTE_PAY_BONUS := 1.25
const REROUTE_EXTRA_TIME := 60.0
const HURRY_TIME := 25.0
const LEAK_SECS := 30.0
const LEAK_PER_S := 0.4
const BOARD_SIZE := 6
const MIN_TRIP := 250.0         # metres, shop to door along the streets
const MAX_TRIP := 2400.0
const PAY_BASE := 40
const PAY_PER_M := 0.22
const GRACE_S := 45.0           # on top of the travelling time
const TRAVEL_MPS := 5.0         # the pace the deadline assumes: a very drunk scooter
const LATE_FACTOR := 0.5        # pay when the deadline has passed
const MIN_INTEGRITY_PAY := 0.4  # a wrecked parcel still pays this much of the full fee
const DROP_DAMAGE := 20.0
const MAX_BUMP := 15.0


## An order from the shop to a random door, with a stable id.
static func make_order(city: CityLayout, rng: RandomNumberGenerator, id: int) -> Dictionary:
	var shop: Dictionary = city.landmarks.get("delivery", {})
	var from: Vector3 = shop.street_point if not shop.is_empty() else city.carpark_center()
	var lots := city.all_lots()
	var lot: Dictionary = {}
	for _try in 60:
		var l: Dictionary = lots[rng.randi_range(0, lots.size() - 1)]
		if l.kind == "park" or l.kind == "special":
			continue
		var dist := trip_distance(from, l.street_point)
		if dist >= MIN_TRIP and dist <= MAX_TRIP:
			lot = l
			break
	if lot.is_empty():
		lot = lots[rng.randi_range(0, lots.size() - 1)]
	var d := trip_distance(from, lot.street_point)
	return {
		"id": id, "item": ITEMS[rng.randi_range(0, ITEMS.size() - 1)], "lot": int(lot.id),
		"addr": city.address(lot), "dist": int(d), "pay": full_pay(d), "time": time_limit(d),
	}


## The board as it stands after `serial` orders have been handed out.
static func board(city: CityLayout, seed_value: int, first_id := 0, count := BOARD_SIZE) -> Array:
	var out: Array = []
	for i in count:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value * 7 + (first_id + i) * 7919
		out.append(make_order(city, rng, first_id + i))
	return out


static func trip_distance(a: Vector3, b: Vector3) -> float:
	return absf(a.x - b.x) + absf(a.z - b.z)    # streets run on a grid


static func full_pay(dist: float) -> int:
	return int(round((PAY_BASE + PAY_PER_M * dist) / 5.0)) * 5


static func time_limit(dist: float) -> int:
	return int(GRACE_S + dist / TRAVEL_MPS)


## What the customer hands over: the full fee, less for a battered parcel, halved when late.
static func payout(order_pay: int, integrity: float, late: bool) -> int:
	var f := lerpf(MIN_INTEGRITY_PAY, 1.0, clampf(integrity / 100.0, 0.0, 1.0))
	if late:
		f *= LATE_FACTOR
	return int(round(order_pay * f / 5.0)) * 5


## What the customer says at the door: stable for a given order.
static func reaction(order_id: int, seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 13 + order_id * 101
	return REACTIONS[rng.randi_range(0, REACTIONS.size() - 1)]


## A tip, sometimes: a quarter of customers add 10 to 40 percent, in multiples of $5.
static func tip(order_id: int, seed_value: int, base_pay: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 17 + order_id * 211
	if rng.randf() >= TIP_CHANCE:
		return 0
	return int(round(base_pay * rng.randf_range(TIP_MIN, TIP_MAX) / 5.0)) * 5


## A rough compass word for where `to` lies from `from` ("NE", "W"); z grows southwards.
static func compass(from: Vector3, to: Vector3) -> String:
	var v := Vector2(to.x - from.x, from.z - to.z)
	if v.length() < 8.0:
		return "HERE"
	var names := ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]
	var idx := int(round(v.angle() / (PI * 0.25)))
	return names[posmod(idx, 8)]
