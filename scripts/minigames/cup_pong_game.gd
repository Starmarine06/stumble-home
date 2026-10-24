class_name CupPongGame
extends Control
## Casino Pub Cup Pong Minigame:
## Throw ping pong balls into red cups to win the Fuel Pump!
## Drunken sway wobbles your angle and power.

signal finished(success: bool)

var balls_left: int = 4
var cups_sunk: int = 0
var cups_needed: int = 2
var drunk_level: float = 0.85

var aim_angle: float = 0.0 # -1.0 to 1.0
var power: float = 0.0 # 0.0 to 1.0
var power_dir: float = 1.0
var elapsed: float = 0.0

var active_ball: Dictionary = {} # {pos, vel, t, target_cup}
var cups: Array[Dictionary] = [] # [{pos, sunk}]
var is_complete: bool = false
var table_center: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(620, 500)
	size = custom_minimum_size
	table_center = Vector2(size.x * 0.5, 200)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tree_exited.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	
	# Setup 6 red cups in triangle formation
	cups.clear()
	var rows = [
		[Vector2(0, -35)],
		[Vector2(-24, 0), Vector2(24, 0)],
		[Vector2(-48, 35), Vector2(0, 35), Vector2(48, 35)]
	]
	for r in rows:
		for offset in r:
			cups.append({"pos": table_center + offset, "sunk": false})

func _process(delta: float) -> void:
	if is_complete:
		return
	elapsed += delta
	
	# Oscillate power bar
	power += power_dir * 1.8 * delta
	if power >= 1.0:
		power = 1.0
		power_dir = -1.0
	elif power <= 0.0:
		power = 0.0
		power_dir = 1.0
		
	# Drunken aim sway
	aim_angle = sin(elapsed * 2.8) * 0.65 * drunk_level + cos(elapsed * 4.2) * 0.25 * drunk_level
	
	# Update flying ball animation if any
	if not active_ball.is_empty():
		active_ball.t += delta * 1.8
		var t: float = active_ball.t
		var start_p: Vector2 = active_ball.start
		var end_p: Vector2 = active_ball.target
		
		# Parabolic arc
		var curr_p = start_p.lerp(end_p, clampf(t, 0.0, 1.0))
		curr_p.y -= sin(clampf(t, 0.0, 1.0) * PI) * 110.0 # Arc height
		active_ball.pos = curr_p
		
		if t >= 1.0:
			# Ball landed!
			var hit_idx = active_ball.cup_idx
			if hit_idx != -1 and not cups[hit_idx].sunk:
				cups[hit_idx].sunk = true
				cups_sunk += 1
				_play_sfx(&"clang")
			else:
				_play_sfx(&"part_fit_bad")
			active_ball.clear()
			
			if cups_sunk >= cups_needed or balls_left <= 0:
				is_complete = true
				var won = (cups_sunk >= cups_needed)
				if won:
					_play_sfx(&"win")
				else:
					_play_sfx(&"part_fit_bad")
				get_tree().create_timer(1.2).timeout.connect(func():
					finished.emit(won)
					queue_free()
				)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if is_complete or not active_ball.is_empty():
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		throw_ball()

func throw_ball() -> void:
	if balls_left <= 0 or not active_ball.is_empty():
		return
	balls_left -= 1
	_play_sfx(&"ui_click")
	
	# Determine landing point based on aim_angle and power
	var launch_p = Vector2(size.x * 0.5, size.y - 45)
	var target_x = table_center.x + (aim_angle * 120.0)
	var target_y = table_center.y + (1.0 - power) * 90.0 - 45.0
	var landing_p = Vector2(target_x, target_y)
	
	# Check if lands in an unsunk cup
	var hit_cup_idx = -1
	for i in cups.size():
		if not cups[i].sunk and landing_p.distance_to(cups[i].pos) < 26.0:
			hit_cup_idx = i
			landing_p = cups[i].pos # Snap to cup
			break
			
	active_ball = {
		"start": launch_p,
		"target": landing_p,
		"pos": launch_p,
		"t": 0.0,
		"cup_idx": hit_cup_idx
	}

func _draw() -> void:
	# Background Panel
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.14, 0.94)
	bg.border_color = Color(0.95, 0.75, 0.20)
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(16)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(24, 38), "🏓 PUB CUP PONG  •  WIN THE FUEL PUMP!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.98, 0.85, 0.35))
	draw_string(font, Vector2(24, 64), "Balls Left: %d  |  Cups Sunk: %d / %d needed  [Click / Space to Throw]" % [balls_left, cups_sunk, cups_needed], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.90, 0.95))
	
	# Draw Wooden Ping Pong Table
	var table_rect = Rect2(size.x * 0.5 - 150, 110, 300, 200)
	draw_rect(table_rect, Color(0.18, 0.35, 0.22), true) # Green table felt
	draw_rect(table_rect, Color(0.92, 0.92, 0.92), false, 3.0) # White border
	draw_line(Vector2(size.x * 0.5, 110), Vector2(size.x * 0.5, 310), Color(0.92, 0.92, 0.92), 2.0)
	
	# Draw Cups
	for c in cups:
		var p: Vector2 = c.pos
		var is_sunk: bool = c.sunk
		if is_sunk:
			draw_circle(p, 16.0, Color(0.15, 0.15, 0.18))
			draw_circle(p, 10.0, Color(0.85, 0.65, 0.15)) # Beer splash inside!
		else:
			# Red Solo Cup
			draw_circle(p + Vector2(2, 3), 16.0, Color(0, 0, 0, 0.4))
			draw_circle(p, 16.0, Color(0.88, 0.15, 0.15))
			draw_circle(p, 13.0, Color(0.98, 0.30, 0.30))
			draw_circle(p, 8.0, Color(0.95, 0.75, 0.20)) # Golden liquid
			draw_arc(p, 16.0, 0, TAU, 32, Color.WHITE, 1.5)
	
	# Draw Aim Line (Drunken wobbling trajectory)
	var launch_p = Vector2(size.x * 0.5, size.y - 45)
	var aim_target = Vector2(table_center.x + aim_angle * 120.0, table_center.y + (1.0 - power) * 90.0 - 45.0)
	if active_ball.is_empty() and not is_complete:
		draw_dashed_line(launch_p, aim_target, Color(1.0, 0.9, 0.4, 0.7), 2.5, 6.0)
		draw_circle(aim_target, 8.0, Color(1.0, 0.3, 0.3, 0.8))
	
	# Draw Flying Ball
	if not active_ball.is_empty():
		var bp: Vector2 = active_ball.pos
		draw_circle(bp + Vector2(2, 4), 8.0, Color(0, 0, 0, 0.35))
		draw_circle(bp, 8.0, Color(1.0, 0.95, 0.85))
		draw_arc(bp, 8.0, 0, TAU, 24, Color(0.8, 0.8, 0.8), 1.0)
	
	# Draw Power Bar Indicator on Right Side
	var bar_rect = Rect2(size.x - 55, 120, 24, 180)
	draw_rect(bar_rect, Color(0.1, 0.1, 0.15), true)
	draw_rect(bar_rect, Color(0.9, 0.9, 0.9), false, 2.0)
	var fill_h = bar_rect.size.y * power
	var fill_rect = Rect2(bar_rect.position.x + 2, bar_rect.position.y + bar_rect.size.y - fill_h, bar_rect.size.x - 4, fill_h)
	var col_p = Color(0.2, 0.85, 0.3).lerp(Color(0.95, 0.25, 0.2), power)
	draw_rect(fill_rect, col_p, true)
	draw_string(font, Vector2(bar_rect.position.x - 8, bar_rect.position.y - 8), "PWR", HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color.WHITE)
	
	# Result banner
	if is_complete:
		var banner_rect = Rect2(size.x * 0.5 - 220, size.y * 0.5 - 45, 440, 90)
		var b_col = Color(0.12, 0.65, 0.25, 0.95) if cups_sunk >= cups_needed else Color(0.75, 0.18, 0.18, 0.95)
		draw_rect(banner_rect, b_col, true)
		draw_rect(banner_rect, Color.WHITE, false, 3.0)
		var msg = "🎉 WON FUEL PUMP! (%d CUPS)" % cups_sunk if cups_sunk >= cups_needed else "❌ MISSED! ONLY %d/%d CUPS. TRY AGAIN!" % [cups_sunk, cups_needed]
		draw_string(font, Vector2(size.x * 0.5 - 200, size.y * 0.5 + 8), msg, HORIZONTAL_ALIGNMENT_CENTER, 400, 22, Color.WHITE)

func _play_sfx(s: StringName) -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").play(s)
