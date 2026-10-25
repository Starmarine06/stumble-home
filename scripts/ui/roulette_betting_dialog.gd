class_name RouletteBettingDialog
extends Control

## Enhanced 3D Roulette Betting Dialog
## Features:
## - 100% Dead-Center Full-Screen Modal Overlay with Cinematic Dim Backdrop
## - Compact, ergonomic layout guaranteed to fit on any resolution (1280x720, 1080p, 4K)
## - Full wallet scaling ($50 min to full wallet max / ALL IN)
## - Stepper buttons [- $50], [- $10], Slider, [+ $10], [+ $50]
## - Percentage presets [Min ($50)], [25%], [50%], [75%], [🔥 ALL IN]
## - Authentic Roulette Bet Choices:
##     Outside Bets: RED (2x), BLACK (2x), EVEN (2x), ODD (2x), 1-18 (2x), 19-36 (2x)
##     Dozen Bets: 1st 12 (3x), 2nd 12 (3x), 3rd 12 (3x)
##     Single Number Jackpot: 0 to 36 (36x JACKPOT)
## - Spin & Cancel buttons with Enter/Space/Escape keyboard shortcuts
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
var spin_btn: Button
var cancel_btn: Button

func _init(p_wallet: int = 1000) -> void:
	name = "RouletteBettingDialog"
	wallet_cash = maxi(50, p_wallet)
	current_bet = mini(100, wallet_cash)
	if current_bet < 50:
		current_bet = wallet_cash
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	tree_exited.connect(func():
		var tree = Engine.get_main_loop() as SceneTree
		var pl = tree.get_first_node_in_group("player") if tree else null
		if pl and ("is_mouse_unlocked" in pl):
			pl.is_mouse_unlocked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)

func _ready() -> void:
	# Ensure full rect coverage without any residual offsets
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 1. Dim Backdrop Overlay (Focuses player attention on modal dialog)
	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.06, 0.75)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# 2. Centering Container (Guarantees dead center placement on any screen resolution)
	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# 3. Main Modal Panel (Compact ~420px height to fit all screens with plenty of margin)
	var modal_panel = PanelContainer.new()
	modal_panel.name = "ModalPanel"
	modal_panel.custom_minimum_size = Vector2(560, 420)
	modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(modal_panel)
	
	# Rich Casino Gold & Dark Slate Box Style
	var box = StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	box.border_color = Color(0.96, 0.78, 0.22) # Gold
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	box.shadow_size = 24
	box.shadow_color = Color(0, 0, 0, 0.85)
	modal_panel.add_theme_stylebox_override("panel", box)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	modal_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Header Title
	var title = Label.new()
	title.text = "🎲 CEASER CASINO VIP 3D ROULETTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.25))
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Place your bet with Antoine. The crew's money is on the table."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	# 1. BET TYPE SELECTION
	var bet_cat_lbl = Label.new()
	bet_cat_lbl.text = "SELECT YOUR BET:"
	bet_cat_lbl.add_theme_font_size_override("font_size", 12)
	bet_cat_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.25))
	vbox.add_child(bet_cat_lbl)

	# Outside Bets Row 1: RED (2x), BLACK (2x)
	var row_colors = HBoxContainer.new()
	row_colors.add_theme_constant_override("separation", 8)
	vbox.add_child(row_colors)

	var btn_red = _create_bet_btn("RED", "🔴 RED (2x Payout)", Color(0.95, 0.35, 0.35))
	btn_red.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_red.custom_minimum_size = Vector2(100, 32)
	row_colors.add_child(btn_red)

	var btn_black = _create_bet_btn("BLACK", "⚫ BLACK (2x Payout)", Color(0.80, 0.82, 0.88))
	btn_black.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_black.custom_minimum_size = Vector2(100, 32)
	row_colors.add_child(btn_black)

	# Outside Bets Row 2: EVEN (2x), ODD (2x), 1-18 (2x), 19-36 (2x)
	var row_outside = HBoxContainer.new()
	row_outside.add_theme_constant_override("separation", 6)
	vbox.add_child(row_outside)

	var btn_even = _create_bet_btn("EVEN", "EVEN (2x)")
	btn_even.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_even.custom_minimum_size = Vector2(60, 28)
	row_outside.add_child(btn_even)

	var btn_odd = _create_bet_btn("ODD", "ODD (2x)")
	btn_odd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_odd.custom_minimum_size = Vector2(60, 28)
	row_outside.add_child(btn_odd)

	var btn_low = _create_bet_btn("LOW", "1 - 18 (2x)")
	btn_low.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_low.custom_minimum_size = Vector2(65, 28)
	row_outside.add_child(btn_low)

	var btn_high = _create_bet_btn("HIGH", "19 - 36 (2x)")
	btn_high.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_high.custom_minimum_size = Vector2(65, 28)
	row_outside.add_child(btn_high)

	# Dozens Row: 1st 12, 2nd 12, 3rd 12 (3x) + Single Number Jackpot
	var row_inside = HBoxContainer.new()
	row_inside.add_theme_constant_override("separation", 6)
	vbox.add_child(row_inside)

	var btn_d1 = _create_bet_btn("1ST_12", "1st 12 (3x)")
	btn_d1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_d1.custom_minimum_size = Vector2(65, 28)
	row_inside.add_child(btn_d1)

	var btn_d2 = _create_bet_btn("2ND_12", "2nd 12 (3x)")
	btn_d2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_d2.custom_minimum_size = Vector2(65, 28)
	row_inside.add_child(btn_d2)

	var btn_d3 = _create_bet_btn("3RD_12", "3rd 12 (3x)")
	btn_d3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_d3.custom_minimum_size = Vector2(65, 28)
	row_inside.add_child(btn_d3)

	var btn_num = _create_bet_btn("NUMBER", "★ No. (36x)", Color(0.40, 0.75, 1.0))
	btn_num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_num.custom_minimum_size = Vector2(80, 28)
	row_inside.add_child(btn_num)

	number_spinbox = SpinBox.new()
	number_spinbox.min_value = 0
	number_spinbox.max_value = 36
	number_spinbox.value = selected_number
	number_spinbox.custom_minimum_size = Vector2(65, 28)
	number_spinbox.value_changed.connect(func(val: float):
		selected_number = int(val)
		_select_bet_type("NUMBER")
	)
	row_inside.add_child(number_spinbox)

	vbox.add_child(HSeparator.new())

	# 2. BET AMOUNT SLIDER & STEPPERS
	var bet_hdr_row = HBoxContainer.new()
	vbox.add_child(bet_hdr_row)

	var bet_lbl = Label.new()
	bet_lbl.text = "WAGER AMOUNT:"
	bet_lbl.add_theme_font_size_override("font_size", 12)
	bet_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.25))
	bet_hdr_row.add_child(bet_lbl)

	bet_display_lbl = Label.new()
	bet_display_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bet_display_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bet_display_lbl.text = "$%d  (Wallet: $%d)" % [current_bet, wallet_cash]
	bet_display_lbl.add_theme_font_size_override("font_size", 13)
	bet_display_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
	bet_hdr_row.add_child(bet_display_lbl)

	# Stepper + Slider Row
	var slider_row = HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", 6)
	vbox.add_child(slider_row)

	var sub50 = Button.new()
	sub50.text = "−$50"
	sub50.custom_minimum_size = Vector2(46, 30)
	sub50.pressed.connect(func(): _adjust_bet(-50))
	slider_row.add_child(sub50)

	var sub10 = Button.new()
	sub10.text = "−$10"
	sub10.custom_minimum_size = Vector2(44, 30)
	sub10.pressed.connect(func(): _adjust_bet(-10))
	slider_row.add_child(sub10)

	bet_slider = HSlider.new()
	bet_slider.min_value = 50.0
	bet_slider.max_value = float(maxi(50, wallet_cash))
	bet_slider.step = 5.0
	bet_slider.value = float(current_bet)
	bet_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bet_slider.custom_minimum_size = Vector2(160, 30)
	_style_slider(bet_slider)
	bet_slider.value_changed.connect(_on_slider_value_changed)
	slider_row.add_child(bet_slider)

	var add10 = Button.new()
	add10.text = "+$10"
	add10.custom_minimum_size = Vector2(44, 30)
	add10.pressed.connect(func(): _adjust_bet(+10))
	slider_row.add_child(add10)

	var add50 = Button.new()
	add50.text = "+$50"
	add50.custom_minimum_size = Vector2(46, 30)
	add50.pressed.connect(func(): _adjust_bet(+50))
	slider_row.add_child(add50)

	# Preset Percentage Buttons Row
	var preset_row = HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 5)
	vbox.add_child(preset_row)

	var p_min = Button.new()
	p_min.text = "Min ($50)"
	p_min.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_min.custom_minimum_size = Vector2(50, 26)
	p_min.pressed.connect(func(): _set_bet(50))
	preset_row.add_child(p_min)

	var p_25 = Button.new()
	p_25.text = "25%"
	p_25.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_25.custom_minimum_size = Vector2(40, 26)
	p_25.pressed.connect(func(): _set_bet(int(wallet_cash * 0.25)))
	preset_row.add_child(p_25)

	var p_50 = Button.new()
	p_50.text = "50%"
	p_50.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_50.custom_minimum_size = Vector2(40, 26)
	p_50.pressed.connect(func(): _set_bet(int(wallet_cash * 0.50)))
	preset_row.add_child(p_50)

	var p_75 = Button.new()
	p_75.text = "75%"
	p_75.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_75.custom_minimum_size = Vector2(40, 26)
	p_75.pressed.connect(func(): _set_bet(int(wallet_cash * 0.75)))
	preset_row.add_child(p_75)

	var p_all = Button.new()
	p_all.text = "🔥 ALL IN ($%d)" % wallet_cash
	p_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_all.custom_minimum_size = Vector2(60, 26)
	p_all.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
	p_all.pressed.connect(func(): _set_bet(wallet_cash))
	preset_row.add_child(p_all)

	# 3. SUMMARY PANEL
	var summary_panel = PanelContainer.new()
	var sum_box = StyleBoxFlat.new()
	sum_box.bg_color = Color(0.04, 0.05, 0.08, 0.85)
	sum_box.border_color = Color(0.25, 0.35, 0.5)
	sum_box.set_border_width_all(1)
	sum_box.set_corner_radius_all(6)
	summary_panel.add_theme_stylebox_override("panel", sum_box)
	vbox.add_child(summary_panel)

	var sum_margin = MarginContainer.new()
	for s in ["left", "right"]:
		sum_margin.add_theme_constant_override("margin_" + s, 8)
	for s in ["top", "bottom"]:
		sum_margin.add_theme_constant_override("margin_" + s, 5)
	summary_panel.add_child(sum_margin)

	summary_lbl = Label.new()
	summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_lbl.add_theme_font_size_override("font_size", 12)
	sum_margin.add_child(summary_lbl)

	# 4. ACTION BUTTONS (SPIN / CANCEL)
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	cancel_btn = Button.new()
	cancel_btn.name = "CancelBtn"
	cancel_btn.text = "❌ Walk Away [ESC]"
	cancel_btn.custom_minimum_size = Vector2(160, 38)
	cancel_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_row.add_child(cancel_btn)

	spin_btn = Button.new()
	spin_btn.name = "SpinBtn"
	spin_btn.text = "🎲 PLACE BET & SPIN WHEEL! [ENTER]"
	spin_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_btn.custom_minimum_size = Vector2(250, 38)
	spin_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	spin_btn.add_theme_font_size_override("font_size", 14)
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

	# Set focus on spin button for immediate Enter key support
	spin_btn.grab_focus()

func _create_bet_btn(b_type: String, text_label: String, tint_col: Color = Color.WHITE) -> Button:
	var btn = Button.new()
	btn.text = text_label
	btn.custom_minimum_size = Vector2(80, 30)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
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
	track_box.content_margin_top = 4
	track_box.content_margin_bottom = 4
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
		bet_display_lbl.text = "$%d  (Wallet: $%d)" % [current_bet, wallet_cash]
	
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
		summary_lbl.text = "BET: %s  •  WAGER: $%d  •  WIN PAYOUT: $%d (+%d Net)" % [label_name, current_bet, total_payout, net_profit]

func _input(event: InputEvent) -> void:
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
