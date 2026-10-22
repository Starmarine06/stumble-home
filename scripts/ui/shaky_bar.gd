class_name ShakyBar
extends Control
## "Steady hands" mini-game: press E while the jittery cursor is inside the
## green zone. Drunkenness makes the cursor jitter, lag and the zone shrink.

signal finished(success: bool)

var hits_needed := 3
var misses_allowed := 4
var time_limit := 0.0
var drunk := 0.9
var title := "STEADY..."

var _t := 0.0
var _hits := 0
var _misses := 0
var _zone_c := 0.5
var _zone_w := 0.16
var _cursor := 0.5
var _history: Array = []
var _noise := FastNoiseLite.new()
var _done := false


func _ready() -> void:
	custom_minimum_size = Vector2(520, 90)
	size = custom_minimum_size
	_noise.seed = randi()
	_noise.frequency = 0.6
	_zone_w = 0.24 - 0.12 * drunk
	_move_zone()


func _move_zone() -> void:
	_zone_c = randf_range(0.2, 0.8)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var speed := 1.4 + 1.6 * drunk
	var base := 0.5 + 0.5 * sin(_t * speed)
	var jitter := _noise.get_noise_1d(_t * 9.0) * 0.35 * drunk
	_cursor = clampf(base + jitter, 0.0, 1.0)
	_history.append([_t, _cursor])
	while _history.size() > 1 and _history[1][0] <= _t - 0.15 * drunk:
		_history.pop_front()
	if time_limit > 0.0:
		time_limit -= delta
		if time_limit <= 0.0:
			_end(false)
			return
	if Input.is_action_just_pressed("act"):
		var lagged: float = _history[0][1]
		if absf(lagged - _zone_c) <= _zone_w * 0.5:
			_hits += 1
			if _hits >= hits_needed:
				_end(true)
				return
			_move_zone()
		else:
			_misses += 1
			if _misses > misses_allowed:
				_end(false)
				return
	queue_redraw()


func _end(ok: bool) -> void:
	_done = true
	finished.emit(ok)
	queue_free()


func _draw() -> void:
	var bar := Rect2(10, 40, size.x - 20, 28)
	draw_rect(bar, Color(0.1, 0.1, 0.14, 0.9))
	var zx := bar.position.x + (_zone_c - _zone_w * 0.5) * bar.size.x
	draw_rect(Rect2(zx, bar.position.y, _zone_w * bar.size.x, bar.size.y), Color(0.3, 0.9, 0.4, 0.85))
	var cx := bar.position.x + _cursor * bar.size.x
	draw_rect(Rect2(cx - 3, bar.position.y - 6, 6, bar.size.y + 12), Color(1, 1, 1))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(10, 28), "%s  hits %d/%d   misses %d/%d   [E]" % [title, _hits, hits_needed, _misses, misses_allowed + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1))
