class_name PartCrosshair
extends Control
## Centre-of-screen dot. Opens into a hand ring when you can grab something, and
## the ring drains as your arms tire. Over a slot it colours with the fit quality.

var strain := 0.0
var can_grab := false
var holding := false
var fit_q := -1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var shadow := Color(0, 0, 0, 0.6)
	draw_circle(c, 4.0, shadow)
	draw_circle(c, 2.5, Color(1, 1, 1, 0.9))
	if can_grab:
		draw_arc(c, 16.0, 0, TAU, 40, Color(1, 0.9, 0.4, 0.95), 3.0)
	if holding:
		var left := 1.0 - strain
		var col := Color(0.4, 0.95, 0.5).lerp(Color(1.0, 0.25, 0.2), strain)
		draw_arc(c, 20.0, 0, TAU, 40, Color(0, 0, 0, 0.45), 6.0)
		draw_arc(c, 20.0, -PI * 0.5, -PI * 0.5 + TAU * left, 48, col, 5.0)
		if fit_q >= 0.0:
			var fc := Color(1.0, 0.25, 0.2).lerp(Color(0.3, 1.0, 0.4), clampf((fit_q - 0.3) / 0.6, 0.0, 1.0))
			draw_arc(c, 30.0, 0, TAU, 40, fc, 4.0)
