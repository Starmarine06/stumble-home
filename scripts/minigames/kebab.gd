class_name Kebab
extends RefCounted
## Kebab-shop order logic. Pure rules, no networking: the caller decides who
## may read the order and who is holding the knife.

const MENU: Array[String] = [
	"Lamb", "Chicken", "Onion", "Tomato", "Lettuce", "Chilli", "Garlic sauce", "Pickles",
]
const MIN_ITEMS := 4
const MAX_ITEMS := 6

var order: Array[String] = []
var items: Array[String] = []
var time_limit := 45.0
var elapsed := 0.0
## Chance of grabbing the neighbouring menu item at wobble 1.0.
var misgrab_rate := 0.35

var _rng := RandomNumberGenerator.new()


func new_order(seed_value: int) -> Array[String]:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var n := r.randi_range(MIN_ITEMS, MAX_ITEMS)
	order = []
	for i in n:
		order.append(MENU[r.randi() % MENU.size()])
	items = []
	elapsed = 0.0
	_rng.seed = seed_value ^ 0x5eed
	return order


## Only the order reader (the Navigator) gets the list; everyone else gets "".
func describe(role: int, reader_role: int) -> String:
	if role != reader_role:
		return ""
	var parts: Array[String] = []
	for i in order.size():
		parts.append("%d. %s" % [i + 1, order[i]])
	return "One kebab, and don't you dare mess it up:\n" + "\n".join(parts)


func neighbour(ingredient: String) -> String:
	var i := MENU.find(ingredient)
	if i < 0:
		return ingredient
	return MENU[(i + 1) % MENU.size()]


## Adds the ingredient, or its menu neighbour if the hands slip. Returns what
## actually landed on the kebab ("" if time is up or the kebab is full).
func pick(ingredient: String, wobble: float) -> String:
	if is_over() or items.size() >= MAX_ITEMS + 2:
		return ""
	var chance := clampf(wobble, 0.0, 1.0) * misgrab_rate
	var got := ingredient
	if _rng.randf() < chance:
		got = neighbour(ingredient)
	items.append(got)
	return got


func undo() -> bool:
	if items.is_empty():
		return false
	items.pop_back()
	return true


func tick(delta: float) -> void:
	elapsed += delta


func time_left() -> float:
	return maxf(time_limit - elapsed, 0.0)


func is_over() -> bool:
	return elapsed >= time_limit


func is_complete() -> bool:
	return items == order


## 0..1: share of slots that are right. Out of time with a wrong or unfinished
## kebab caps at 0.5.
func score() -> float:
	if order.is_empty():
		return 0.0
	var right := 0
	for i in mini(items.size(), order.size()):
		if items[i] == order[i]:
			right += 1
	var s := float(right) / float(maxi(order.size(), items.size()))
	if is_over() and not is_complete():
		s = minf(s, 0.5)
	return s


## Every field gets better with score. wanted_delta is wanted level cleared
## (negative means the cops noticed the mess).
func reward(s: float) -> Dictionary:
	s = clampf(s, 0.0, 1.0)
	return {
		"sober": lerpf(0.0, 0.3, s),
		"hp": lerpf(0.0, 25.0, s),
		"wanted_delta": lerpf(-0.1, 0.2, s),
	}
