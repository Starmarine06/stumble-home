class_name KebabPanel
extends Control
## Kebab shop panel. The reader sees the order and nothing else useful; everyone
## else sees ingredient buttons, the kebab so far and the clock.

signal picked(ingredient: String)
signal undo_pressed
signal closed

var reader := false : set = set_reader
var order_text := "" : set = set_order_text
var kebab: Array[String] = []
var time_left := 0.0

var _order_label := Label.new()
var _kebab_label := Label.new()
var _timer_label := Label.new()
var _buttons := VBoxContainer.new()
var _grid := GridContainer.new()
var _undo := Button.new()
var _close := Button.new()


func _init() -> void:
	custom_minimum_size = Vector2(460, 420)
	size = custom_minimum_size
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.9)
	sb.border_color = Color(0.98, 0.78, 0.25, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	bg.add_theme_stylebox_override("panel", sb)
	add_child(bg)
	var col := VBoxContainer.new()
	bg.add_child(col)

	var title := Label.new()
	title.text = "KEBAB SHOP"
	col.add_child(title)
	col.add_child(_timer_label)
	_order_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_order_label)
	col.add_child(_buttons)
	_buttons.add_child(_grid)
	_grid.columns = 2
	for ing in Kebab.MENU:
		var b := Button.new()
		b.text = ing
		b.name = "btn_" + ing
		b.pressed.connect(func() -> void: picked.emit(ing))
		_grid.add_child(b)
	_kebab_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_buttons.add_child(_kebab_label)
	_undo.text = "Undo (oops)"
	_undo.pressed.connect(func() -> void: undo_pressed.emit())
	_buttons.add_child(_undo)
	_close.text = "Walk away"
	_close.pressed.connect(func() -> void: closed.emit())
	col.add_child(_close)
	_refresh()


func set_reader(v: bool) -> void:
	reader = v
	_refresh()


func set_order_text(v: String) -> void:
	order_text = v
	_refresh()


func set_state(items: Array[String], left: float) -> void:
	kebab = items
	time_left = left
	_refresh()


func order_visible() -> bool:
	return _order_label.visible


func _refresh() -> void:
	_order_label.visible = reader
	_order_label.text = order_text if reader else ""
	_buttons.visible = not reader
	_timer_label.text = "Time left: %ds" % ceili(time_left)
	_kebab_label.text = "Your kebab: " + (", ".join(kebab) if not kebab.is_empty() else "empty, like your wallet")
