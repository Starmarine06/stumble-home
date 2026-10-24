class_name BalanceBar
extends Control
## Drunk Balance Indicator:
## Shows the player's active tilt and balance.
## [Q] leans/corrects left, [E] leans/corrects right.
## Tipping too far into the red causes the player to fall down!

var balance_tilt: float = 0.0 # -1.0 (hard left) to +1.0 (hard right)
var is_fallen: bool = false
var elapsed: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(340, 52)
	size = custom_minimum_size

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var font = ThemeDB.fallback_font
	var w = size.x
	var h = size.y
	
	# Background Frame
	var bg_rect = Rect2(0, 16, w, 24)
	var bg_col = Color(0.06, 0.08, 0.12, 0.85)
	if absf(balance_tilt) > 0.75:
		# Flashing red danger warning
		var pulse = sin(elapsed * 18.0) * 0.5 + 0.5
		bg_col = bg_col.lerp(Color(0.65, 0.12, 0.15, 0.95), pulse)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = Color(0.95, 0.78, 0.25, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	draw_style_box(sb, bg_rect)
	
	var mid_x = w * 0.5
	var bar_y = bg_rect.position.y
	var bar_h = bg_rect.size.y
	
	# Safe center zone (Green: -0.35 to +0.35)
	var safe_w = w * 0.35
	var safe_rect = Rect2(mid_x - safe_w * 0.5, bar_y + 2, safe_w, bar_h - 4)
	draw_rect(safe_rect, Color(0.20, 0.85, 0.35, 0.35), true)
	
	# Warning zones (Yellow/Orange)
	var warn_l = Rect2(mid_x - w * 0.40, bar_y + 2, w * 0.225, bar_h - 4)
	var warn_r = Rect2(mid_x + safe_w * 0.5, bar_y + 2, w * 0.225, bar_h - 4)
	draw_rect(warn_l, Color(0.95, 0.75, 0.20, 0.30), true)
	draw_rect(warn_r, Color(0.95, 0.75, 0.20, 0.30), true)
	
	# Danger zones (Red: outer edges)
	draw_rect(Rect2(4, bar_y + 2, 28, bar_h - 4), Color(0.95, 0.20, 0.20, 0.5), true)
	draw_rect(Rect2(w - 32, bar_y + 2, 28, bar_h - 4), Color(0.95, 0.20, 0.20, 0.5), true)
	
	# Center tick mark
	draw_line(Vector2(mid_x, bar_y), Vector2(mid_x, bar_y + bar_h), Color(1, 1, 1, 0.8), 2.0)
	
	# Drunk Balance Bubble / Needle
	var bubble_x = mid_x + (balance_tilt * (w * 0.5 - 18.0))
	var bubble_col = Color(0.25, 0.95, 0.45)
	if absf(balance_tilt) > 0.75:
		bubble_col = Color(1.0, 0.25, 0.25)
	elif absf(balance_tilt) > 0.35:
		bubble_col = Color(1.0, 0.80, 0.20)
		
	# Draw Glowing Bubble
	draw_circle(Vector2(bubble_x, bar_y + bar_h * 0.5), 9.0, bubble_col)
	draw_circle(Vector2(bubble_x, bar_y + bar_h * 0.5), 5.0, Color.WHITE)
	draw_arc(Vector2(bubble_x, bar_y + bar_h * 0.5), 11.0, 0, TAU, 24, Color.BLACK, 1.5)
	
	# Title & Key Prompts
	var title = "⚖️ [Q] ◄──  BALANCE PLAYER  ──► [E]"
	var title_col = Color(0.98, 0.85, 0.35)
	if is_fallen:
		title = "💥 FELL DOWN! REGAINING BALANCE..."
		title_col = Color(1.0, 0.3, 0.3)
	elif absf(balance_tilt) > 0.75:
		title = "⚠️ TIPPING OVER! PRESS %s TO RECOVER!" % ("[E]" if balance_tilt < 0 else "[Q]")
		title_col = Color(1.0, 0.35, 0.35)
		
	draw_string(font, Vector2(0, 12), title, HORIZONTAL_ALIGNMENT_CENTER, int(w), 13, title_col)
