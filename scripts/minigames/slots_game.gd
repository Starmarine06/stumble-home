class_name SlotsGame
extends Control
## Casino Slot Machine Minigame:
## Spin and stop the 3 reels to hit matching symbols and win the Spark Plugs!

signal finished(success: bool)

const SYMBOLS := ["777", "BAR", "CHERRY", "BELL", "DIAMOND"]
const SYM_COLORS := [
	Color(0.98, 0.25, 0.25), # 777
	Color(0.95, 0.75, 0.20), # BAR
	Color(0.85, 0.20, 0.40), # CHERRY
	Color(0.95, 0.85, 0.30), # BELL
	Color(0.30, 0.85, 0.95)  # DIAMOND
]

var reel_states := [0, 0, 0] # Current symbol index on each reel
var reel_spinning := [true, true, true]
var reel_speeds := [14.0, 16.0, 18.0]
var reel_pos := [0.0, 0.0, 0.0]
var stopped_count: int = 0
var is_complete: bool = false
var drunk_level: float = 0.85
var elapsed: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(620, 480)
	size = custom_minimum_size
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tree_exited.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	_play_sfx(&"horn")

func _process(delta: float) -> void:
	if is_complete:
		return
	elapsed += delta
	
	for i in 3:
		if reel_spinning[i]:
			reel_pos[i] += reel_speeds[i] * delta
			reel_states[i] = int(reel_pos[i]) % SYMBOLS.size()
			
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if is_complete:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		stop_next_reel()

func stop_next_reel() -> void:
	if stopped_count >= 3:
		return
	
	reel_spinning[stopped_count] = false
	_play_sfx(&"clang")
	stopped_count += 1
	
	# If on 3rd reel, give drunken nudge favor to match previous reels!
	if stopped_count == 3:
		# Forgiving drunk assist: 65% chance 3rd reel nudges to match
		if randf() < 0.65:
			reel_states[2] = reel_states[0]
			
		is_complete = true
		var won = (reel_states[0] == reel_states[1] or reel_states[1] == reel_states[2] or reel_states[0] == reel_states[2])
		if won:
			_play_sfx(&"win")
		else:
			_play_sfx(&"part_fit_bad")
			
		get_tree().create_timer(1.2).timeout.connect(func():
			finished.emit(won)
			queue_free()
		)

func _draw() -> void:
	# Outer Slot Machine Cabinet (Gold & Dark Crimson)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.04, 0.06, 0.95)
	bg.border_color = Color(0.95, 0.78, 0.22)
	bg.set_border_width_all(4)
	bg.set_corner_radius_all(18)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(24, 38), "🎰 LUCKY 7s SLOTS  •  TRIPLES PAY 4x", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.98, 0.85, 0.35))
	var prompt_txt = "Press [Click / Space] to Stop Reel %d!" % (stopped_count + 1) if stopped_count < 3 else "Reels Locked!"
	draw_string(font, Vector2(24, 64), prompt_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.90, 0.95))
	
	# Draw 3 Slot Reel Windows
	var reel_w = 140.0
	var reel_h = 220.0
	var start_x = (size.x - (3 * reel_w + 2 * 20)) * 0.5
	var reel_y = 100.0
	
	for i in 3:
		var rx = start_x + i * (reel_w + 20)
		var r_rect = Rect2(rx, reel_y, reel_w, reel_h)
		
		# Reel Glass Window
		draw_rect(r_rect, Color(0.04, 0.05, 0.08), true)
		draw_rect(r_rect, Color(0.85, 0.70, 0.20) if not reel_spinning[i] else Color(0.4, 0.4, 0.4), false, 3.0)
		
		# Center payout line
		draw_line(Vector2(rx, reel_y + reel_h * 0.5), Vector2(rx + reel_w, reel_y + reel_h * 0.5), Color(1, 0.2, 0.2, 0.4), 2.0)
		
		# Draw Symbol
		var sym_idx = reel_states[i]
		var sym_name = SYMBOLS[sym_idx]
		var sym_col = SYM_COLORS[sym_idx]
		
		# Drunken blur streak if spinning
		if reel_spinning[i]:
			var blur_offset = sin(elapsed * 25.0 + i) * 12.0
			draw_string(font, Vector2(rx + 10, reel_y + reel_h * 0.5 + 10 + blur_offset), sym_name, HORIZONTAL_ALIGNMENT_CENTER, int(reel_w - 20), 28, Color(sym_col.r, sym_col.g, sym_col.b, 0.4))
		
		draw_string(font, Vector2(rx + 10, reel_y + reel_h * 0.5 + 10), sym_name, HORIZONTAL_ALIGNMENT_CENTER, int(reel_w - 20), 30, sym_col)
		
		# Indicator LED at top of reel
		var led_col = Color(0.2, 0.9, 0.3) if not reel_spinning[i] else Color(0.9, 0.8, 0.2)
		draw_circle(Vector2(rx + reel_w * 0.5, reel_y - 12), 6.0, led_col)
	
	# Stop Button / Instructions at Bottom
	var btn_rect = Rect2(size.x * 0.5 - 120, 360, 240, 55)
	draw_rect(btn_rect, Color(0.85, 0.20, 0.25), true)
	draw_rect(btn_rect, Color.WHITE, false, 2.5)
	var btn_label = "STOP REEL %d [SPACE]" % (stopped_count + 1) if stopped_count < 3 else "EVALUATING..."
	draw_string(font, Vector2(btn_rect.position.x, btn_rect.position.y + 35), btn_label, HORIZONTAL_ALIGNMENT_CENTER, int(btn_rect.size.x), 18, Color.WHITE)
	
	# Result Banner
	if is_complete:
		var won = (reel_states[0] == reel_states[1] or reel_states[1] == reel_states[2] or reel_states[0] == reel_states[2])
		var banner_rect = Rect2(size.x * 0.5 - 240, reel_y + 40, 480, 95)
		var b_col = Color(0.12, 0.65, 0.25, 0.96) if won else Color(0.75, 0.18, 0.18, 0.96)
		draw_rect(banner_rect, b_col, true)
		draw_rect(banner_rect, Color.WHITE, false, 3.0)
		var msg = ("🎰 TRIPLE! 4x YOUR STAKE!" if reel_states[0] == reel_states[1] and reel_states[1] == reel_states[2] else "🎉 PAIR! HALF YOUR STAKE BACK") if won else "❌ NO MATCH! STAKE GONE!"
		draw_string(font, Vector2(size.x * 0.5 - 220, reel_y + 98), msg, HORIZONTAL_ALIGNMENT_CENTER, 440, 22, Color.WHITE)

func _play_sfx(s: StringName) -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").play(s)
