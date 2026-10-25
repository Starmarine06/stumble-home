class_name OrderBoardPanel
extends Control
## The delivery shop's job board. One job at a time, crew-wide: taking one puts the parcel on the
## counter (or into the pillion rider's hands) and starts the clock.

signal closed

var _status := Label.new()
var _rows: Array = []        # [{label, button}]
var _abandon := Button.new()


func _init() -> void:
	custom_minimum_size = Vector2(700, 440)
	size = custom_minimum_size
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.03, 0.94)
	sb.border_color = Color(0.95, 0.55, 0.1, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	bg.add_theme_stylebox_override("panel", sb)
	add_child(bg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	bg.add_child(col)

	var title := Label.new()
	title.text = "SKETCHY DELIVERIES  (no questions, no receipts)"
	title.add_theme_font_size_override("font_size", 20)
	col.add_child(title)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_status)
	for _i in Deliveries.BOARD_SIZE:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.custom_minimum_size = Vector2(540, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(l)
		var b := Button.new()
		b.text = "Take"
		b.custom_minimum_size = Vector2(90, 0)
		row.add_child(b)
		col.add_child(row)
		_rows.append({"label": l, "button": b})
	var bottom := HBoxContainer.new()
	col.add_child(bottom)
	_abandon.text = "Bin the current job"
	_abandon.pressed.connect(Game.request_abandon_job)
	bottom.add_child(_abandon)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): closed.emit())
	bottom.add_child(close)
	refresh()
	Game.orders_changed.connect(refresh)
	Game.job_changed.connect(refresh)


func _exit_tree() -> void:
	if Game.orders_changed.is_connected(refresh):
		Game.orders_changed.disconnect(refresh)
	if Game.job_changed.is_connected(refresh):
		Game.job_changed.disconnect(refresh)


static func clock(seconds: float) -> String:
	var s := int(maxf(seconds, 0.0))
	return "%d:%02d" % [s / 60, s % 60]


func refresh() -> void:
	var busy := not Game.job.is_empty()
	if busy:
		_status.text = "ON THE ROAD: %s to %s. %s left, parcel at %d%%." % [Game.job.item, Game.job.addr, clock(float(Game.job.time_left)), int(Game.job.integrity)]
	else:
		_status.text = "Pick a job. Longer trips pay more. Late halves the fee, a battered parcel pays less."
	_abandon.disabled = not busy
	for i in _rows.size():
		var l: Label = _rows[i].label
		var b: Button = _rows[i].button
		if i >= Game.orders.size():
			l.text = ""
			b.visible = false
			continue
		var o: Dictionary = Game.orders[i]
		b.visible = true
		l.text = "%s  >  %s   (%d m, %s)   $%d" % [str(o.item).capitalize(), o.addr, int(o.dist), clock(float(o.time)), int(o.pay)]
		b.disabled = busy
		for c in b.pressed.get_connections():
			b.pressed.disconnect(c.callable)
		b.pressed.connect(Game.request_take_order.bind(int(o.id)))
