class_name PartIcons
extends RefCounted
## Little vector pictures of the car parts, drawn straight onto any CanvasItem.
## idx matches Game.PART_NAMES; -1 draws the car itself.

const COLORS := [Color(0.92, 0.25, 0.22), Color(0.95, 0.75, 0.2), Color(0.3, 0.9, 0.9), Color(0.55, 0.57, 0.62)]


static func part_color(idx: int) -> Color:
	return COLORS[idx] if idx >= 0 and idx < COLORS.size() else Color(0.9, 0.9, 0.95)


## c is the centre, s the half-size in pixels.
static func draw(ci: CanvasItem, idx: int, c: Vector2, s: float, alpha := 1.0) -> void:
	var col := part_color(idx)
	col.a = alpha
	var dark := Color(0.08, 0.08, 0.1, alpha)
	var light := Color(1, 1, 1, alpha * 0.85)
	match idx:
		0: # battery
			ci.draw_rect(Rect2(c + Vector2(-s, -s * 0.55), Vector2(2 * s, s * 1.5)), col)
			ci.draw_rect(Rect2(c + Vector2(-s, -s * 0.55), Vector2(2 * s, s * 1.5)), dark, false, 2.0)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.9), Vector2(s * 0.4, s * 0.35)), dark)
			ci.draw_rect(Rect2(c + Vector2(s * 0.3, -s * 0.9), Vector2(s * 0.4, s * 0.35)), dark)
			ci.draw_line(c + Vector2(-s * 0.6, s * 0.2), c + Vector2(-s * 0.2, s * 0.2), light, 2.0)
			ci.draw_line(c + Vector2(s * 0.4, s * 0.2), c + Vector2(s * 0.8, s * 0.2), light, 2.0)
			ci.draw_line(c + Vector2(s * 0.6, 0.0), c + Vector2(s * 0.6, s * 0.4), light, 2.0)
		1: # fuel pump
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s), Vector2(s * 1.2, 2 * s)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s), Vector2(s * 1.2, 2 * s)), dark, false, 2.0)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.5, -s * 0.8), Vector2(s * 0.8, s * 0.7)), dark)
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.5, -s * 0.3), c + Vector2(s * 0.9, -s * 0.3),
				c + Vector2(s * 0.9, s * 0.5)]), col, 3.0)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.9, s * 0.8), Vector2(s * 1.6, s * 0.25)), dark)
		2: # spark plug
			ci.draw_rect(Rect2(c + Vector2(-s * 0.18, -s), Vector2(s * 0.36, s * 0.35)), light)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.45, -s * 0.65), Vector2(s * 0.9, s * 1.0)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.45, -s * 0.65), Vector2(s * 0.9, s * 1.0)), dark, false, 2.0)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.3, s * 0.35), Vector2(s * 0.6, s * 0.4)), dark)
			ci.draw_line(c + Vector2(0, s * 0.75), c + Vector2(0, s), light, 2.0)
		3: # tyre
			ci.draw_circle(c, s, dark)
			ci.draw_circle(c, s * 0.88, col.darkened(0.55))
			ci.draw_circle(c, s * 0.5, col)
			ci.draw_circle(c, s * 0.18, dark)
		_: # car
			ci.draw_rect(Rect2(c + Vector2(-s, -s * 0.1), Vector2(2 * s, s * 0.6)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.6), Vector2(s * 1.1, s * 0.55)), col.darkened(0.2))
			ci.draw_circle(c + Vector2(-s * 0.55, s * 0.55), s * 0.25, dark)
			ci.draw_circle(c + Vector2(s * 0.55, s * 0.55), s * 0.25, dark)
