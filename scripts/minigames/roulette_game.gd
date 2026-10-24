class_name RouletteGame
extends Control
## Casino Roulette Minigame:
## Spin the VIP casino wheel to win the heavy Spare Tyre!

signal finished(success: bool)

var chosen_color: String = "RED" # "RED" or "BLACK"
var wheel_angle: float = 0.0
var ball_angle: float = 0.0
var wheel_speed: float = 0.0
var ball_speed: float = 0.0
var is_spinning: bool = false
var is_complete: bool = false
var elapsed: float = 0.0
var final_color: String = ""

const NUM_SLOTS := 12
var slot_colors := []

func _ready() -> void:
	custom_minimum_size = Vector2(620, 520)
	size = custom_minimum_size
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tree_exited.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	
	slot_colors.clear()
	for i in NUM_SLOTS:
		if i == 0:
			slot_colors.append("GOLD") # Jackpot!
		elif i % 2 == 1:
			slot_colors.append("RED")
		else:
			slot_colors.append("BLACK")

func _process(delta: float) -> void:
	elapsed += delta
	if is_spinning:
		wheel_angle += wheel_speed * delta
		ball_angle += ball_speed * delta
		
		# Decelerate
		wheel_speed = maxf(0.0, wheel_speed - 2.5 * delta)
		ball_speed = maxf(0.0, ball_speed - 4.5 * delta)
		
		if ball_speed <= 0.05 and wheel_speed <= 0.05:
			is_spinning = false
			evaluate_result()
			
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if is_spinning or is_complete:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p = get_local_mouse_position()
		var b_y = 390.0
		var red_btn = Rect2(size.x * 0.5 - 190, b_y, 110, 45)
		var black_btn = Rect2(size.x * 0.5 - 60, b_y, 110, 45)
		var spin_btn = Rect2(size.x * 0.5 + 70, b_y, 130, 45)
		
		if red_btn.has_point(p):
			chosen_color = "RED"
			_play_sfx(&"ui_click")
			queue_redraw()
		elif black_btn.has_point(p):
			chosen_color = "BLACK"
			_play_sfx(&"ui_click")
			queue_redraw()
		elif spin_btn.has_point(p):
			spin_wheel()
		else:
			spin_wheel()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		spin_wheel()

func spin_wheel() -> void:
	if is_spinning or is_complete:
		return
	is_spinning = true
	wheel_speed = randf_range(8.0, 12.0)
	ball_speed = -randf_range(16.0, 22.0)
	_play_sfx(&"horn")

func evaluate_result() -> void:
	is_complete = true
	# Determine slot under pointer (pointer at top: -PI/2)
	var diff = wrapf(ball_angle - wheel_angle, 0.0, TAU)
	var slot_idx = int((diff / TAU) * NUM_SLOTS) % NUM_SLOTS
	final_color = slot_colors[slot_idx]
	
	var won = (final_color == chosen_color or final_color == "GOLD")
	if won:
		_play_sfx(&"win")
	else:
		_play_sfx(&"part_fit_bad")
		
	get_tree().create_timer(1.4).timeout.connect(func():
		finished.emit(won)
		queue_free()
	)

func _draw() -> void:
	# Casino Green Felt & Mahogany Panel
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.14, 0.09, 0.95)
	bg.border_color = Color(0.95, 0.78, 0.22)
	bg.set_border_width_all(4)
	bg.set_corner_radius_all(18)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(24, 38), "🎲 VIP CASINO ROULETTE  •  WIN THE SPARE TYRE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.98, 0.85, 0.35))
	draw_string(font, Vector2(24, 64), "Selected: %s  |  Press [SPACE] or Click 'SPIN WHEEL'!" % chosen_color, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.90, 0.95))
	
	var center = Vector2(size.x * 0.5, 230)
	var radius = 125.0
	
	# Outer rim
	draw_circle(center, radius + 18.0, Color(0.25, 0.12, 0.08)) # Mahogany rim
	draw_arc(center, radius + 18.0, 0, TAU, 64, Color(0.92, 0.75, 0.22), 4.0)
	
	# Wheel segments
	var slice_ang = TAU / float(NUM_SLOTS)
	for i in NUM_SLOTS:
		var a1 = wheel_angle + float(i) * slice_ang
		var a2 = wheel_angle + float(i + 1) * slice_ang
		var col = Color(0.85, 0.20, 0.22)
		if slot_colors[i] == "BLACK":
			col = Color(0.12, 0.14, 0.18)
		elif slot_colors[i] == "GOLD":
			col = Color(0.95, 0.82, 0.25)
			
		draw_colored_polygon(PackedVector2Array([
			center,
			center + Vector2(cos(a1), sin(a1)) * radius,
			center + Vector2(cos(a2), sin(a2)) * radius
		]), col)
		draw_line(center, center + Vector2(cos(a1), sin(a1)) * radius, Color(0.9, 0.8, 0.3, 0.7), 2.0)
	
	# Center turret
	draw_circle(center, 38.0, Color(0.92, 0.75, 0.22))
	draw_circle(center, 22.0, Color(0.35, 0.22, 0.10))
	draw_circle(center, 8.0, Color.WHITE)
	
	# Spinning Golden Ball
	var ball_p = center + Vector2(cos(ball_angle), sin(ball_angle)) * (radius - 12.0)
	draw_circle(ball_p + Vector2(2, 2), 7.0, Color(0, 0, 0, 0.4))
	draw_circle(ball_p, 7.0, Color(1.0, 0.95, 0.8))
	draw_arc(ball_p, 7.0, 0, TAU, 16, Color(1, 0.8, 0.2), 1.5)
	
	# Top Needle / Pointer
	var ptr = center + Vector2(0, -radius - 14)
	draw_colored_polygon(PackedVector2Array([
		ptr,
		ptr + Vector2(-10, -18),
		ptr + Vector2(10, -18)
	]), Color(0.95, 0.85, 0.25))
	draw_polyline(PackedVector2Array([ptr, ptr + Vector2(-10, -18), ptr + Vector2(10, -18), ptr]), Color.BLACK, 2.0)
	
	# Betting Buttons at Bottom
	var b_y = 390.0
	var red_btn = Rect2(size.x * 0.5 - 190, b_y, 110, 45)
	var black_btn = Rect2(size.x * 0.5 - 60, b_y, 110, 45)
	var spin_btn = Rect2(size.x * 0.5 + 70, b_y, 130, 45)
	
	# Red button
	draw_rect(red_btn, Color(0.85, 0.20, 0.25), true)
	draw_rect(red_btn, Color.WHITE if chosen_color == "RED" else Color(0.5, 0.5, 0.5), false, 3.0 if chosen_color == "RED" else 1.5)
	draw_string(font, Vector2(red_btn.position.x, b_y + 28), "RED", HORIZONTAL_ALIGNMENT_CENTER, int(red_btn.size.x), 18, Color.WHITE)
	
	# Black button
	draw_rect(black_btn, Color(0.14, 0.16, 0.20), true)
	draw_rect(black_btn, Color.WHITE if chosen_color == "BLACK" else Color(0.5, 0.5, 0.5), false, 3.0 if chosen_color == "BLACK" else 1.5)
	draw_string(font, Vector2(black_btn.position.x, b_y + 28), "BLACK", HORIZONTAL_ALIGNMENT_CENTER, int(black_btn.size.x), 18, Color.WHITE)
	
	# Spin button
	draw_rect(spin_btn, Color(0.95, 0.75, 0.20) if not is_spinning else Color(0.4, 0.4, 0.4), true)
	draw_rect(spin_btn, Color.WHITE, false, 2.0)
	draw_string(font, Vector2(spin_btn.position.x, b_y + 28), "SPIN! [SPACE]" if not is_spinning else "SPINNING...", HORIZONTAL_ALIGNMENT_CENTER, int(spin_btn.size.x), 16, Color(0.1, 0.1, 0.1) if not is_spinning else Color.WHITE)
	
	# Result banner
	if is_complete:
		var won = (final_color == chosen_color or final_color == "GOLD")
		var banner_rect = Rect2(size.x * 0.5 - 240, 180, 480, 95)
		var b_col = Color(0.12, 0.65, 0.25, 0.96) if won else Color(0.75, 0.18, 0.18, 0.96)
		draw_rect(banner_rect, b_col, true)
		draw_rect(banner_rect, Color.WHITE, false, 3.0)
		var msg = "🎉 WON SPARE TYRE! (%s)" % final_color if won else "❌ LANDED ON %s! TRY AGAIN!" % final_color
		draw_string(font, Vector2(size.x * 0.5 - 220, 238), msg, HORIZONTAL_ALIGNMENT_CENTER, 440, 22, Color.WHITE)

func _play_sfx(s: StringName) -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").play(s)
