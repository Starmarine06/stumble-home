class_name ParcelBar
extends Control
## The pillion rider's parcel: a needle that drifts off-centre and has to be kept in the green.

var tilt := 0.0         # -1 .. 1
var integrity := 100.0


func _init() -> void:
	custom_minimum_size = Vector2(360, 44)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(0, 12, w, 20), Color(0.05, 0.05, 0.08, 0.8))
	draw_rect(Rect2(w * 0.5 - w * 0.17, 12, w * 0.34, 20), Color(0.2, 0.7, 0.3, 0.55))
	draw_rect(Rect2(0, 12, w * 0.12, 20), Color(0.85, 0.2, 0.2, 0.55))
	draw_rect(Rect2(w * 0.88, 12, w * 0.12, 20), Color(0.85, 0.2, 0.2, 0.55))
	var x := w * 0.5 + clampf(tilt, -1.0, 1.0) * w * 0.5
	var hot := absf(tilt) > 0.7
	draw_rect(Rect2(x - 4, 6, 8, 32), Color(1.0, 0.35, 0.3) if hot else Color(1, 1, 1))
	draw_rect(Rect2(0, 12, w, 20), Color.WHITE, false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, 8), "PARCEL  A / D to steady it   (%d%% intact)" % int(integrity), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.9, 0.6))
