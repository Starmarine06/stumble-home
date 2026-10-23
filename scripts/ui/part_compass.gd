class_name PartCompass
extends Control
## Round dial that points at the nearest missing part (or at the car while you
## are carrying one). No words: the needle shows where, the ring fills as you
## get closer, and the centre badge shows which part it is.

const RADIUS := 62.0

var target_part := -1      # part icon shown in the hub; -1 = the car
var angle := 0.0           # needle direction relative to where you face, clockwise radians
var closeness := 0.0       # 0 far .. 1 on top of it
var lit := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(RADIUS * 2 + 24, RADIUS * 2 + 24)


func _process(_delta: float) -> void:
	visible = lit
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var c := size * 0.5
	var col := PartIcons.part_color(target_part)
	draw_circle(c, RADIUS + 6, Color(0.05, 0.06, 0.09, 0.8))
	draw_arc(c, RADIUS + 4, 0, TAU, 64, Color(1, 1, 1, 0.25), 3.0)

	# Closeness ring; pulses faster the nearer you are.
	var pulse := 0.75 + 0.25 * sin(t * (3.0 + 9.0 * closeness))
	var ring := col
	ring.a = pulse
	draw_arc(c, RADIUS - 2, -PI * 0.5, -PI * 0.5 + TAU * closeness, 64, ring, 6.0)

	# Fixed "you are facing this way" marker at the top.
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -RADIUS - 12), c + Vector2(-7, -RADIUS - 2), c + Vector2(7, -RADIUS - 2)]),
		Color(1, 1, 1, 0.9))

	# Needle.
	var dir := Vector2(sin(angle), -cos(angle))
	var side := Vector2(-dir.y, dir.x)
	var tip := c + dir * (RADIUS - 8.0)
	var base := c + dir * 20.0
	draw_colored_polygon(PackedVector2Array([tip, base + side * 11.0, base - side * 11.0]), col)
	draw_polyline(PackedVector2Array([tip, base + side * 11.0, base - side * 11.0, tip]), Color(0, 0, 0, 0.8), 2.0)

	# Hub with the part picture.
	draw_circle(c, 19.0, Color(0.05, 0.06, 0.09))
	draw_arc(c, 19.0, 0, TAU, 32, col, 2.0)
	PartIcons.draw(self, target_part, c, 10.0)
