class_name RouletteBettingDialog
extends PanelContainer

## Enhanced 3D Roulette Betting Dialog
## Features:
## - Full wallet scaling ($50 min to full wallet max)
## - Stepper buttons [- $50], [- $10], Slider, [+ $10], [+ $50]
## - Percentage presets [Min ($50)], [25%], [50%], [75%], [🔥 ALL IN]
## - Authentic Roulette Bet Choices:
##     Outside Bets: RED (2x), BLACK (2x), EVEN (2x), ODD (2x), 1-18 (2x), 19-36 (2x)
##     Dozen Bets: 1st 12 (3x), 2nd 12 (3x), 3rd 12 (3x)
##     Single Number Jackpot: 0 to 36 (36x JACKPOT)
## - Guarantees mouse recapture on cancel/finish and stops player camera look

signal bet_confirmed(bet_amount: int, bet_type: String, bet_param: Variant)
signal cancelled()

var wallet_cash: int = 1000
var current_bet: int = 50
var selected_bet_type: String = "RED"
var selected_number: int = 7

# UI Elements
var bet_slider: HSlider
var bet_display_lbl: Label
var summary_lbl: Label
var number_spinbox: SpinBox
var num_container: HBoxContainer
var bet_buttons: Dictionary = {}

func _init(p_wallet: int = 1000) -> void:
	name = "RouletteBettingDialog"
	wallet_cash = maxi(50, p_wallet)
	current_bet = mini(100, wallet_cash)
	if current_bet < 50:
		current_bet = wallet_cash
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(580, 560)
	
	tree_exited.connect(func():
		var tree = Engine.get_main_loop() as SceneTree
		var pl = tree.get_first_node_in_group("player") if tree else null
		if pl and ("is_mouse_unlocked" in pl):
			pl.is_mouse_unlocked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)

func _ready() -> void:
	# Center on screen
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Rich Casino Gold & Dark Slate Box Style
	var box = StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.08, 0.12, 0.96)
	box.border_color = Color(0.96, 0.78, 0.22) # Gold
	box.set_border_width_all(3)
	box.set_corner_radius_all(16)
	box.shadow_size = 18
	box.shadow_color = Color(0, 0, 0, 0.75)
	add_theme_stylebox_override("panel", box)

	var margin = MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 22)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Header Title
	var title = Label.new()
	title.text = "🎲 CEASER CASINO VIP 3D ROULETTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.25))
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Place your bet with Croupier Antoine. Win your bet to claim the Spare Tyre!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	# 1. BET TYPE SELECTION
	var bet_cat_lbl = Label.new()
	bet_cat_lbl.text = "SELECT YOUR BET:"
	bet_cat_lbl.add_theme_font_size_override("font_size", 13)
	bet_cat_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.25))
	vbox.add_child(bet_cat_lbl)

	# Outside Bets Row 1: RED (2x), BLACK (2x)
	var row_colors = HBoxContainer.new()
	row_colors.add_theme_constant_override("separation", 10)
	vbox.add_child(row_colors)

	var btn_red = _create_bet_btn("RED", "🔴 RED (2x Payout)", Color(0.85, 0.18, 0.18))
	btn_red.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_colors.add_child(btn_red)

	var btn_black = _create_bet_btn("BLACK", "⚫ BLACK (2x Payout)", Color(0.18, 0.18, 0.22))
	btn_black.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_colors.add_child(btn_black)

	# Outside Bets Row 2: EVEN (2x), ODD (2x), 1-18 (2x), 19-36 (2x)
	var row_outside = HBoxContainer.new()
	row_outside.add_theme_constant_override("separation", 8)
	vbox.add_child(row_outside)

	var btn_even = _create_bet_btn("EVEN", "EVEN (2x)")
	btn_even.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_outside.add_child(btn_even)

	var btn_odd = _create_bet_btn("ODD", "ODD (2x)")
	btn_odd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_outside.add_child(btn_odd)

	var btn_low = _create_bet_btn("LOW", "1 - 18 (2x)")
	btn_low.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_outside.add_child(btn_low)

	var btn_high = _create_bet_btn("HIGH", "19 - 36 (2x)")
	btn_high.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_outside.add_child(btn_high)

	# Dozens Row: 1st 12, 2nd 12, 3rd 12 (3x)
	var row_dozens = HBoxContainer.new()
	row_dozens.add_theme_constant_override("separation", 8)
	vbox.add_child(row_dozens)

	var btn_d1 = _create_bet_btn("1ST_12", "1st 12 (3x)")
	btn_d1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_dozens.add_child(btn_d1)

	var btn_d2 = _create_bet_btn("2ND_12", "2nd 12 (3x)")
	btn_d2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_dozens.add_child(btn_d2)

	var btn_d3 = _create_bet_btn("3RD_12", "3rd 12 (3x)")
	btn_d3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_dozens.add_child(btn_d3)

	# Inside Bet: Single Number (36x Jackpot)
	num_container = HBoxContainer.new()
	num_container.add_theme_constant_override("separation", 8)
	vbox.add_child(num_container)

	var btn_num = _create_bet_btn("NUMBER", "★ SINGLE NUMBER (36x JACKPOT!)", Color(0.20, 0.45, 0.85))
	btn_num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	num_container.add_child(btn_num)

	var num_lbl = Label.new()
	num_lbl.text = "No:"
	num_container.add_child(num_lbl)

	number_spinbox = SpinBox.new()
	number_spinbox.min_value = 0
	number_spinbox.max_value = 36
	number_spinbox.value = selected_number
	number_spinbox.custom_minimum_size = Vector2(75, 36)
	number_spinbox.value_changed.connect(func(val: float):
		selected_number = int(val)
		_update_summary()
	)
	num_container.add_child(number_spinbox)

	var quick_rnd_btn = Button.new()
	quick_rnd_btn.text = "🎲 Lucky"
	quick_rnd_btn.pressed.connect(func():
		selected_number = randi() % 37
		number_spinbox.value = selected_number
		_select_bet_type("NUMBER")
	)
	num_container.add_child(quick_rnd_btn)

	vbox.add_child(HSeparator.new())

	# 2. BET AMOUNT SLIDER & STEPPERS
	var bet_hdr_row = HBoxContainer.new()
	vbox.add_child(bet_hdr_row)

	var bet_lbl = Label.new()
	bet_lbl.text = "WAGER AMOUNT:"
	bet_lbl.add_theme_font_size_override("font_size", 13)
	bet_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.25))
	bet_hdr_row.add_child(bet_lbl)

	bet_display_lbl = Label.new()
	bet_display_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bet_display_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bet_display_lbl.text = "$%d  (Shared Wallet: $%d)" % [current_bet, wallet_cash]
	bet_display_lbl.add_theme_font_size_override("font_size", 14)
	bet_display_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
	bet_hdr_row.add_child(bet_display_lbl)

	# Stepper + Slider Row
	var slider_row = HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", 6)
	vbox.add_child(slider_row)

	var sub50 = Button.new()
	sub50.text = "−$50"
	sub50.custom_minimum_size = Vector2(50, 36)
	sub50.pressed.connect(func(): _adjust_bet(-50))
	slider_row.add_child(sub50)

	var sub10 = Button.new()
	sub10.text = "−$10"
	sub10.custom_minimum_size = Vector2(46, 36)
	sub10.pressed.connect(func(): _adjust_bet(-10))
	slider_row.add_child(sub10)

	bet_slider = HSlider.new()
	bet_slider.min_value = 50.0
	bet_slider.max_value = float(maxi(50, wallet_cash))
	bet_slider.step = 5.0
	bet_slider.value = float(current_bet)
	bet_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bet_slider.custom_minimum_size = Vector2(180, 36)
	_style_slider(bet_slider)
	bet_slider.value_changed.connect(_on_slider_value_changed)
	slider_row.add_child(bet_slider)

	var add10 = Button.new()
	add10.text = "+$10"
	add10.custom_minimum_size = Vector2(46, 36)
	add10.pressed.connect(func(): _adjust_bet(+10))
	slider_row.add_child(add10)

	var add50 = Button.new()
	add50.text = "+$50"
	add50.custom_minimum_size = Vector2(50, 36)
	add50.pressed.connect(func(): _adjust_bet(+50))
	slider_row.add_child(add50)

	# Preset Percentage Buttons Row
	var preset_row = HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 6)
	vbox.add_child(preset_row)

	var p_min = Button.new()
	p_min.text = "Min ($50)"
	p_min.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_min.pressed.connect(func(): _set_bet(50))
	preset_row.add_child(p_min)

	var p_25 = Button.new()
	p_25.text = "25%"
	p_25.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_25.pressed.connect(func(): _set_bet(int(wallet_cash * 0.25)))
	preset_row.add_child(p_25)

	var p_50 = Button.new()
	p_50.text = "50%"
	p_50.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_50.pressed.connect(func(): _set_bet(int(wallet_cash * 0.50)))
	preset_row.add_child(p_50)

	var p_75 = Button.new()
	p_75.text = "75%"
	p_75.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_75.pressed.connect(func(): _set_bet(int(wallet_cash * 0.75)))
	preset_row.add_child(p_75)

	var p_all = Button.new()
	p_all.text = "🔥 ALL IN ($%d)" % wallet_cash
	p_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_all.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
	p_all.pressed.connect(func(): _set_bet(wallet_cash))
	preset_row.add_child(p_all)

	# 3. SUMMARY PANEL
	var summary_panel = PanelContainer.new()
	var sum_box = StyleBoxFlat.new()
	sum_box.bg_color = Color(0.04, 0.05, 0.08, 0.85)
	sum_box.border_color = Color(0.25, 0.35, 0.5)
	sum_box.set_border_width_all(1)
	sum_box.set_corner_radius_all(8)
	summary_panel.add_theme_stylebox_override("panel", sum_box)
	vbox.add_child(summary_panel)

	var sum_margin = MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		sum_margin.add_theme_constant_override("margin_" + s, 8)
	summary_panel.add_child(sum_margin)

	summary_lbl = Label.new()
	summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_lbl.add_theme_font_size_override("font_size", 13)
	sum_margin.add_child(summary_lbl)

	# 4. ACTION BUTTONS (SPIN / CANCEL)
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	var cancel_btn = Button.new()
	cancel_btn.text = "❌ Walk Away [ESC]"
	cancel_btn.custom_minimum_size = Vector2(170, 44)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_row.add_child(cancel_btn)

	var spin_btn = Button.new()
	spin_btn.text = "🎲 PLACE BET & SPIN WHEEL! [ENTER]"
	spin_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_btn.custom_minimum_size = Vector2(250, 44)
	spin_btn.add_theme_font_size_override("font_size", 15)
	spin_btn.add_theme_color_override("font_color", Color(0.98, 0.85, 0.22))
	spin_btn.pressed.connect(_on_spin_pressed)
	btn_row.add_child(spin_btn)

	# Initial selection
	_select_bet_type("RED")
	_update_summary()

	# Force mouse visible while dialog is active
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var pl = get_tree().get_first_node_in_group("player") if get_tree() else null
	if pl and ("is_mouse_unlocked" in pl):
		pl.is_mouse_unlocked = true

func _create_bet_btn(b_type: String, text_label: String, tint_col: Color = Color.WHITE) -> Button:
	var btn = Button.new()
	btn.text = text_label
	btn.custom_minimum_size = Vector2(90, 38)
	if tint_col != Color.WHITE:
		btn.add_theme_color_override("font_color", tint_col)
	btn.pressed.connect(func(): _select_bet_type(b_type))
	bet_buttons[b_type] = btn
	return btn

func _select_bet_type(b_type: String) -> void:
	selected_bet_type = b_type
	for key in bet_buttons.keys():
		var btn: Button = bet_buttons[key]
		if key == b_type:
			btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.25))
		else:
			btn.remove_theme_color_override("font_color")
	
	if number_spinbox and is_instance_valid(number_spinbox):
		number_spinbox.editable = (selected_bet_type == "NUMBER")
	_update_summary()

func _style_slider(slider: HSlider) -> void:
	var track_box = StyleBoxFlat.new()
	track_box.bg_color = Color(0.12, 0.15, 0.22)
	track_box.border_color = Color(0.28, 0.35, 0.48)
	track_box.set_border_width_all(1)
	track_box.set_corner_radius_all(4)
	track_box.content_margin_top = 6
	track_box.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track_box)

	var grab_area = StyleBoxFlat.new()
	grab_area.bg_color = Color(0.92, 0.75, 0.22)
	grab_area.set_corner_radius_all(4)
	slider.add_theme_stylebox_override("grabber_area", grab_area)
	slider.add_theme_stylebox_override("grabber_area_highlight", grab_area)

	var grab_tex = load("res://assets/textures/ui_slider_grabber.png") as Texture2D
	if grab_tex:
		slider.add_theme_icon_override("grabber", grab_tex)
		slider.add_theme_icon_override("grabber_highlight", grab_tex)

func _adjust_bet(delta_amt: int) -> void:
	_set_bet(current_bet + delta_amt)

func _set_bet(new_val: int) -> void:
	var min_wager = mini(50, wallet_cash)
	current_bet = clampi(new_val, min_wager, wallet_cash)
	if bet_slider:
		bet_slider.value = float(current_bet)
	_update_summary()

func _on_slider_value_changed(val: float) -> void:
	current_bet = int(val)
	_update_summary()

func _update_summary() -> void:
	if bet_display_lbl:
		bet_display_lbl.text = "$%d  (Shared Wallet: $%d)" % [current_bet, wallet_cash]
	
	var multiplier = 2
	var label_name = selected_bet_type
	match selected_bet_type:
		"RED":
			multiplier = 2
			label_name = "🔴 RED"
		"BLACK":
			multiplier = 2
			label_name = "⚫ BLACK"
		"EVEN":
			multiplier = 2
			label_name = "EVEN (2 to 36)"
		"ODD":
			multiplier = 2
			label_name = "ODD (1 to 35)"
		"LOW":
			multiplier = 2
			label_name = "1 - 18"
		"HIGH":
			multiplier = 2
			label_name = "19 - 36"
		"1ST_12":
			multiplier = 3
			label_name = "1st 12 (1-12)"
		"2ND_12":
			multiplier = 3
			label_name = "2nd 12 (13-24)"
		"3RD_12":
			multiplier = 3
			label_name = "3rd 12 (25-36)"
		"NUMBER":
			multiplier = 36
			label_name = "★ SINGLE NUMBER %d" % selected_number
	
	var total_payout = current_bet * multiplier
	var net_profit = total_payout - current_bet
	if summary_lbl:
		summary_lbl.text = "BET: %s  •  WAGER: $%d  •  WIN PAYOUT: $%d (+%d Net)\n🎁 PRIZE: Cash Payout + Camper Van SPARE TYRE!" % [label_name, current_bet, total_payout, net_profit]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_cancel_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_on_spin_pressed()
			get_viewport().set_input_as_handled()

func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()

func _on_spin_pressed() -> void:
	var param = selected_number if selected_bet_type == "NUMBER" else null
	bet_confirmed.emit(current_bet, selected_bet_type, param)
	queue_free()
