class_name PartChecklist
extends Control
## Parts checklist: one row per part with its picture, a tick box that shows the
## state (waiting, in your hands, fitted, loose), plus a progress strip and,
## for anyone who is not the Mechanic, a tiredness meter.

const ROW_H := 46.0
const HEAD_H := 40.0
const PAD := 12.0

var show_tired := false
var tired := 0.0
var out_frac := 0.0   # 0 = awake, else fraction of the pass-out left

var _panel := StyleBoxFlat.new()
var _font := ThemeDB.fallback_font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(250, 270)
	size = custom_minimum_size
	_panel.bg_color = Color(0.06, 0.07, 0.1, 0.78)
	_panel.border_color = Color(0.98, 0.78, 0.25, 0.9)
	_panel.set_border_width_all(2)
	_panel.set_corner_radius_all(14)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))

	# Clipboard clip and title.
	draw_rect(Rect2(size.x * 0.5 - 22, -6, 44, 14), Color(0.98, 0.78, 0.25), true)
	draw_rect(Rect2(size.x * 0.5 - 22, -6, 44, 14), Color(0.1, 0.1, 0.1), false, 2.0)
	draw_string(_font, Vector2(PAD + 2, 30), "PARTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.92, 0.6))

	var fitted := 0
	for i in Game.parts.size():
		var p: Dictionary = Game.parts[i]
		var y := HEAD_H + i * ROW_H
		var shake := Vector2.ZERO
		var tint := Color(1, 1, 1, 0.05)
		var box_col := Color(0.35, 0.37, 0.42)
		var mark := 0 # 0 empty, 1 carried, 2 fitted, 3 loose
		match p.state:
			Game.PS.CARRIED:
				mark = 1
				box_col = Color(1.0, 0.82, 0.25)
				tint = Color(1.0, 0.82, 0.25, 0.10 + 0.08 * sin(t * 6.0))
			Game.PS.INSTALLED:
				fitted += 1
				if p.q >= Game.SOLID_Q:
					mark = 2
					box_col = Color(0.3, 0.85, 0.4)
					tint = Color(0.3, 0.85, 0.4, 0.12)
				else:
					mark = 3
					box_col = Color(1.0, 0.5, 0.15)
					var amp := 3.0 if p.warned else 1.0
					shake = Vector2(sin(t * 40.0), cos(t * 33.0)) * amp
					tint = Color(1.0, 0.3, 0.1, 0.14 + (0.14 * sin(t * 12.0) if p.warned else 0.0))
		var row := Rect2(Vector2(PAD, y) + shake, Vector2(size.x - 2 * PAD, ROW_H - 6))
		var rs := StyleBoxFlat.new()
		rs.bg_color = tint
		rs.set_corner_radius_all(8)
		draw_style_box(rs, row)

		# Tick box.
		var bx := row.position + Vector2(8, (row.size.y - 26) * 0.5)
		var brect := Rect2(bx, Vector2(26, 26))
		if mark != 0:
			draw_rect(brect, box_col.darkened(0.55))
		draw_rect(brect, box_col, false, 2.5)
		var bc := brect.get_center()
		match mark:
			1: # arrow: it's in your hands
				var bob := sin(t * 7.0) * 2.0
				draw_colored_polygon(PackedVector2Array([bc + Vector2(0, -8 + bob), bc + Vector2(8, 4 + bob), bc + Vector2(-8, 4 + bob)]), box_col)
			2: # tick
				draw_polyline(PackedVector2Array([bc + Vector2(-8, 0), bc + Vector2(-2, 7), bc + Vector2(9, -8)]), box_col, 4.0)
			3: # warning bang
				draw_line(bc + Vector2(0, -8), bc + Vector2(0, 2), box_col, 4.0)
				draw_circle(bc + Vector2(0, 8), 2.5, box_col)

		PartIcons.draw(self, i, row.position + Vector2(62, row.size.y * 0.5), 12.0, 1.0 if mark != 0 else 0.55)
		var name_col := Color(1, 1, 1, 0.95) if mark != 0 else Color(1, 1, 1, 0.5)
		draw_string(_font, row.position + Vector2(88, row.size.y * 0.5 + 6), Game.PART_NAMES[i],
			HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 92, 15, name_col)

	# Progress strip: one segment per part.
	var py := HEAD_H + Game.parts.size() * ROW_H + 4.0
	var seg_w := (size.x - 2 * PAD - 3.0 * 4.0) / maxf(Game.parts.size(), 1.0)
	for i in Game.parts.size():
		var r := Rect2(PAD + i * (seg_w + 4.0), py, seg_w, 10)
		draw_rect(r, Color(1, 1, 1, 0.12))
		if i < fitted:
			draw_rect(r, Color(0.3, 0.85, 0.4))

	if show_tired:
		_draw_tired(py + 26.0, t)


func _draw_tired(y: float, t: float) -> void:
	var moon_c := Vector2(PAD + 14, y + 10)
	var moon_col := Color(0.75, 0.8, 1.0)
	draw_circle(moon_c, 9.0, moon_col)
	draw_circle(moon_c + Vector2(5, -3), 8.0, Color(0.06, 0.07, 0.1))
	var bar := Rect2(PAD + 34, y + 2, size.x - 2 * PAD - 34, 16)
	draw_rect(bar, Color(1, 1, 1, 0.12))
	var frac := tired
	var col := Color(0.5, 0.65, 1.0).lerp(Color(1.0, 0.3, 0.25), clampf((tired - 0.5) / 0.5, 0.0, 1.0))
	if out_frac > 0.0:
		frac = out_frac
		col = Color(1.0, 0.25, 0.25, 0.7 + 0.3 * sin(t * 8.0))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(frac, 0.0, 1.0), bar.size.y)), col)
	draw_rect(bar, Color(1, 1, 1, 0.5), false, 2.0)
