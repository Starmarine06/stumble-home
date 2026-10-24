class_name DartsGame
extends Control
## Casino Pub Darts Minigame:
## Throw 3 darts at the dartboard while your drunken hands sway and jitter.
## Score at least 35 points to win the Car Battery!

signal finished(success: bool)

var darts_left: int = 3
var total_score: int = 0
var target_score: int = 35
var drunk_level: float = 0.85

var crosshair_pos: Vector2 = Vector2.ZERO
var board_center: Vector2 = Vector2.ZERO
var board_radius: float = 140.0
var noise := FastNoiseLite.new()
var elapsed: float = 0.0
var darts_thrown: Array = [] # [Vector2 pos, int score]
var is_complete: bool = false
var throw_anim_t: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(620, 500)
	size = custom_minimum_size
	board_center = Vector2(size.x * 0.5, size.y * 0.5 + 20)
	crosshair_pos = board_center
	noise.seed = randi()
	noise.frequency = 0.75
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if is_complete:
		return
	elapsed += delta
	
	# Drunken unsteady sway and tremor on dart crosshair
	var mouse_p = get_local_mouse_position()
	var tremor_x = noise.get_noise_1d(elapsed * 8.0) * 45.0 * drunk_level
	var tremor_y = noise.get_noise_1d(elapsed * 8.0 + 100.0) * 45.0 * drunk_level
	var drift_x = sin(elapsed * 2.5) * 35.0 * drunk_level
	var drift_y = cos(elapsed * 2.1) * 30.0 * drunk_level
	
	var target = mouse_p + Vector2(tremor_x + drift_x, tremor_y + drift_y)
	crosshair_pos = crosshair_pos.lerp(target, clampf(14.0 * delta, 0.0, 1.0))
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if is_complete:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		throw_dart()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		throw_dart()

func throw_dart() -> void:
	if darts_left <= 0 or is_complete:
		return
	
	darts_left -= 1
	var hit_pos = crosshair_pos
	var dist = hit_pos.distance_to(board_center)
	var pts = 0
	
	if dist <= 12.0:
		pts = 50 # Double Bullseye
	elif dist <= 28.0:
		pts = 25 # Bullseye outer
	elif dist <= 75.0:
		pts = 20 # Inner high slice
	elif dist <= 120.0:
		pts = 15 # Middle ring
	elif dist <= board_radius:
		pts = 10 # Outer ring
	else:
		pts = 0 # Miss off the board
	
	total_score += pts
	darts_thrown.append([hit_pos, pts])
	_play_sfx(&"clang")
	
	if darts_left <= 0:
		is_complete = true
		var won = (total_score >= target_score)
		if won:
			_play_sfx(&"win")
		else:
			_play_sfx(&"part_fit_bad")
		get_tree().create_timer(1.2).timeout.connect(func():
			finished.emit(won)
			queue_free()
		)

func _draw() -> void:
	# Dark casino felt background
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.08, 0.12, 0.94)
	bg.border_color = Color(0.95, 0.75, 0.20)
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(16)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(24, 38), "🎯 CASINO DARTS  •  WIN THE BATTERY!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.98, 0.85, 0.35))
	draw_string(font, Vector2(24, 64), "Darts Left: %d  |  Score: %d / %d needed  [Click / Space to Throw]" % [darts_left, total_score, target_score], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.90, 0.95))
	
	# Draw Dartboard
	# Outer rim
	draw_circle(board_center, board_radius + 12.0, Color(0.12, 0.12, 0.15))
	draw_arc(board_center, board_radius + 12.0, 0, TAU, 64, Color(0.9, 0.8, 0.3), 3.0)
	
	# Slices
	for i in 20:
		var a1 = (TAU / 20.0) * float(i)
		var a2 = (TAU / 20.0) * float(i + 1)
		var col = Color(0.15, 0.16, 0.18) if (i % 2 == 0) else Color(0.85, 0.82, 0.75)
		draw_colored_polygon(PackedVector2Array([board_center, board_center + Vector2(cos(a1), sin(a1)) * board_radius, board_center + Vector2(cos(a2), sin(a2)) * board_radius]), col)
	
	# Concentric rings
	draw_arc(board_center, 120.0, 0, TAU, 48, Color(0.85, 0.2, 0.2), 6.0) # Double ring
	draw_arc(board_center, 75.0, 0, TAU, 48, Color(0.2, 0.8, 0.3), 6.0)  # Triple ring
	draw_circle(board_center, 28.0, Color(0.2, 0.75, 0.3))              # Outer bull (25)
	draw_circle(board_center, 12.0, Color(0.88, 0.18, 0.18))            # Inner bull (50)
	
	# Previously thrown darts
	for d in darts_thrown:
		var p: Vector2 = d[0]
		var pts: int = d[1]
		# Dart shadow
		draw_circle(p + Vector2(2, 2), 6.0, Color(0, 0, 0, 0.5))
		# Dart flight & shaft
		draw_circle(p, 5.0, Color(0.95, 0.8, 0.1))
		draw_line(p, p + Vector2(-12, -18), Color(0.95, 0.2, 0.2), 3.0)
		draw_string(font, p + Vector2(10, 4), "+%d" % pts, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 1.0, 0.4) if pts > 0 else Color(0.8, 0.3, 0.3))
	
	# Current Drunken Crosshair
	if not is_complete:
		var c_col = Color(1.0, 0.3, 0.3, 0.9)
		draw_arc(crosshair_pos, 16.0, 0, TAU, 32, c_col, 2.5)
		draw_line(crosshair_pos + Vector2(-22, 0), crosshair_pos + Vector2(22, 0), c_col, 2.0)
		draw_line(crosshair_pos + Vector2(0, -22), crosshair_pos + Vector2(0, 22), c_col, 2.0)
		draw_circle(crosshair_pos, 3.0, Color.WHITE)
	
	# Result banner
	if is_complete:
		var banner_rect = Rect2(board_center.x - 220, board_center.y - 45, 440, 90)
		var b_col = Color(0.12, 0.65, 0.25, 0.95) if total_score >= target_score else Color(0.75, 0.18, 0.18, 0.95)
		draw_rect(banner_rect, b_col, true)
		draw_rect(banner_rect, Color.WHITE, false, 3.0)
		var msg = "🎉 WON BATTERY! (%d PTS)" % total_score if total_score >= target_score else "❌ MISSED! %d/%d PTS. TRY AGAIN!" % [total_score, target_score]
		draw_string(font, Vector2(board_center.x - 200, board_center.y + 8), msg, HORIZONTAL_ALIGNMENT_CENTER, 400, 22, Color.WHITE)

func _play_sfx(s: StringName) -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").play(s)
