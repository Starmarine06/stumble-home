class_name Drunk
extends RefCounted
## Per-player drunk model: laggy input, wandering steering, random trips.

signal tripped

var base := 0.9
var level := 0.9
var stun := 0.0

var _t := 0.0
var _trip_in := 6.0
var _lag_buf: Array = []
var _noise := FastNoiseLite.new()


func _init(p_base: float = 0.9) -> void:
	base = p_base
	level = p_base
	_noise.seed = randi()
	_noise.frequency = 0.35
	_trip_in = _next_trip()


func sober(amount: float) -> void:
	level = maxf(0.25, level - amount)


func lag() -> float:
	return 0.08 + 0.3 * level


func is_stunned() -> bool:
	return stun > 0.0


## Advance timers. Trips only happen when allow_trips is true (on foot).
func tick(delta: float, allow_trips: bool = true) -> void:
	_t += delta
	level = move_toward(level, base, 0.01 * delta)
	if stun > 0.0:
		stun = maxf(0.0, stun - delta)
	elif allow_trips:
		_trip_in -= delta
		if _trip_in <= 0.0:
			stun = 0.7 + 0.6 * level
			_trip_in = _next_trip()
			tripped.emit()


## 2D walking input -> drunk walking input.
func steer(raw: Vector2) -> Vector2:
	var lagged := _lagged(raw)
	var ang := _noise.get_noise_1d(_t * 4.0) * level * 1.3
	var wobble := Vector2(sin(_t * 2.3), cos(_t * 1.7)) * level * 0.25
	var out := Vector2.ZERO
	if lagged.length() > 0.01:
		out = lagged.rotated(ang) + wobble * lagged.length()
	else:
		out = wobble * 0.15
	return out.limit_length(1.0) * (1.0 - 0.2 * level)


## 1D steering input (-1..1) -> drunk steering.
func steer1(raw: float) -> float:
	var lagged := _lagged(Vector2(raw, 0.0)).x
	var sway := _noise.get_noise_1d(_t * 4.0) * level * 0.9
	return clampf(lagged + sway, -1.0, 1.0)


func _lagged(raw: Vector2) -> Vector2:
	_lag_buf.append([_t, raw])
	while _lag_buf.size() > 1 and _lag_buf[1][0] <= _t - lag():
		_lag_buf.pop_front()
	return _lag_buf[0][1]


func _next_trip() -> float:
	return randf_range(6.0, 14.0) * (1.6 - level)
