class_name SimpleBetDialog
extends Control
## A plain stake picker for the casino games that have no betting screen of their own
## (slots, cup pong). The stake comes out of the crew's shared pool.

signal bet_confirmed(amount: int)
signal cancelled

const MIN_BET := 50
const STEP := 10

var _wallet := 0
var _bet := 0
var _slider := HSlider.new()
var _bet_label := Label.new()


func _init(title: String, blurb: String, wallet: int) -> void:
	name = "SimpleBetDialog"
	_wallet = wallet
	var lo := mini(MIN_BET, wallet)
	_bet = clampi(100, lo, wallet)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.08, 0.96)
	sb.border_color = Color(0.98, 0.78, 0.25, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 22)
	col.add_child(t)
	var b := Label.new()
	b.text = blurb
	b.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(b)
	var w := Label.new()
	w.text = "Crew pool: $%d" % wallet
	col.add_child(w)

	_slider.min_value = lo
	_slider.max_value = maxi(wallet, lo)
	_slider.step = STEP if wallet >= STEP * 2 else 1
	_slider.value = _bet
	_slider.custom_minimum_size = Vector2(0, 24)
	_slider.value_changed.connect(_on_slider)
	col.add_child(_slider)
	col.add_child(_bet_label)
	_refresh()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var go := Button.new()
	go.text = "Bet"
	go.disabled = wallet <= 0
	go.pressed.connect(func(): bet_confirmed.emit(_bet))
	row.add_child(go)
	var all_in := Button.new()
	all_in.text = "All in"
	all_in.disabled = wallet <= 0
	all_in.pressed.connect(func(): bet_confirmed.emit(_wallet))
	row.add_child(all_in)
	var no := Button.new()
	no.text = "Walk away"
	no.pressed.connect(func(): cancelled.emit())
	row.add_child(no)


func _on_slider(v: float) -> void:
	_bet = int(v)
	_refresh()


func _refresh() -> void:
	_bet_label.text = "Stake: $%d" % _bet


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancelled.emit()
		get_viewport().set_input_as_handled()
