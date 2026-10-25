class_name PartsShopPanel
extends Control
## The parts terminal. Anyone can browse; a buy request goes to the host, which checks the pool.

signal closed

var _money_label := Label.new()
var _rows: Array = []   # [{label, button}]
var _total_label := Label.new()


func _init() -> void:
	custom_minimum_size = Vector2(480, 330)
	size = custom_minimum_size
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.92)
	sb.border_color = Color(0.4, 0.85, 0.5, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	bg.add_theme_stylebox_override("panel", sb)
	add_child(bg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	bg.add_child(col)

	var title := Label.new()
	title.text = "PARTS TERMINAL  (delivered to the car)"
	col.add_child(title)
	col.add_child(_money_label)
	for i in Game.PART_NAMES.size():
		var row := HBoxContainer.new()
		var l := Label.new()
		l.custom_minimum_size = Vector2(300, 0)
		row.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 0)
		b.pressed.connect(Game.request_buy.bind(i))
		row.add_child(b)
		col.add_child(row)
		_rows.append({"label": l, "button": b})
	col.add_child(_total_label)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): closed.emit())
	col.add_child(close)
	refresh()
	Game.money_changed.connect(refresh)
	Game.parts_changed.connect(refresh)


func _exit_tree() -> void:
	if Game.money_changed.is_connected(refresh):
		Game.money_changed.disconnect(refresh)
	if Game.parts_changed.is_connected(refresh):
		Game.parts_changed.disconnect(refresh)


func refresh() -> void:
	_money_label.text = "Crew pool: $%d" % Game.money
	for i in _rows.size():
		var shelf: bool = Game.parts[i].state == Game.PS.SHELF
		var price := PartsShop.price(i)
		_rows[i].label.text = "%s   $%d" % [Game.parts[i].name, price]
		var b: Button = _rows[i].button
		b.text = "Buy" if shelf else "Owned"
		b.disabled = not shelf or Game.money < price
	_total_label.text = "Still to buy: $%d" % Game.parts_total_unbought()
