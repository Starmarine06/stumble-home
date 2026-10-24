class_name DartsBettingDialog
extends Control

## Casino Darts Betting Modal with Enhanced Sliding Bar System & Stepper Controls
## Minimum bet: $50, Maximum bet: Player's total shared wallet cash (Allows calling ALL IN).

signal bet_confirmed(amount: int)
signal cancelled()

var current_bet: int = 50
var player_cash: int = 1000

var cash_label: Label
var bet_label: Label
var payout_label: Label
var bet_slider: HSlider

func _init(p_cash: int = 1000) -> void:
	name = "DartsBettingDialog"
	player_cash = p_cash
	var min_allowed = mini(50, player_cash) if player_cash > 0 else 0
	current_bet = min_allowed
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 1. Dim Backdrop Overlay (Focuses player attention on modal dialog)
	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.06, 0.70)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# 2. Centering Container (Guarantees dead center placement on any screen resolution)
	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# 3. Main Modal Panel
	var modal_panel = PanelContainer.new()
	modal_panel.name = "ModalPanel"
	modal_panel.custom_minimum_size = Vector2(580, 500)
	modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(modal_panel)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.14, 0.98)
	sb.border_color = Color(0.95, 0.78, 0.22)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.shadow_size = 28
	sb.shadow_color = Color(0, 0, 0, 0.85)
	modal_panel.add_theme_stylebox_override("panel", sb)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	modal_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# 1. Header Title
	var title = Label.new()
	title.text = "🎯 BARNEY'S CASINO DARTS CHALLENGE"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Set your stake from the 4-patron shared wallet! Score 50+ points to win multiplied cash AND the Camper Van Battery!"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(subtitle)

	# 2. Player Shared Cash Display
	cash_label = Label.new()
	cash_label.text = "💰 SHARED WALLET: $%d" % player_cash
	cash_label.add_theme_font_size_override("font_size", 16)
	cash_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
	cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cash_label)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# 3. Large Stake Display Card
	var stake_card = PanelContainer.new()
	var sc_sb = StyleBoxFlat.new()
	sc_sb.bg_color = Color(0.12, 0.15, 0.22, 0.9)
	sc_sb.border_color = Color(1.0, 0.84, 0.25)
	sc_sb.set_border_width_all(2)
	sc_sb.set_corner_radius_all(8)
	stake_card.add_theme_stylebox_override("panel", sc_sb)
	vbox.add_child(stake_card)

	var sc_margin = MarginContainer.new()
	sc_margin.add_theme_constant_override("margin_top", 8)
	sc_margin.add_theme_constant_override("margin_bottom", 8)
	stake_card.add_child(sc_margin)

	bet_label = Label.new()
	bet_label.text = "CURRENT STAKE: $%d" % current_bet
	bet_label.add_theme_font_size_override("font_size", 22)
	bet_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc_margin.add_child(bet_label)

	# 4. Sliding Bar System with Stepper Controls ([- $50], [- $10], [+ $10], [+ $50])
	var min_val = float(mini(50, player_cash))
	var max_val = float(maxi(50, player_cash))

	var slider_row = HBoxContainer.new()
	slider_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slider_row.add_theme_constant_override("separation", 8)
	vbox.add_child(slider_row)

	var stepper_btn_style = func(txt: String) -> Button:
		var btn = Button.new()
		btn.text = txt
		btn.custom_minimum_size = Vector2(54, 38)
		var sb_n = StyleBoxFlat.new()
		sb_n.bg_color = Color(0.14, 0.17, 0.25)
		sb_n.border_color = Color(0.85, 0.70, 0.22)
		sb_n.set_border_width_all(1)
		sb_n.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", sb_n)
		var sb_h = StyleBoxFlat.new()
		sb_h.bg_color = Color(0.22, 0.26, 0.38)
		sb_h.border_color = Color(1.0, 0.88, 0.35)
		sb_h.set_border_width_all(2)
		sb_h.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("hover", sb_h)
		return btn

	# Big Minus Button [- $50]
	var btn_minus_50 = stepper_btn_style.call("−$50")
	btn_minus_50.pressed.connect(func():
		bet_slider.value = clampf(bet_slider.value - 50.0, min_val, max_val)
	)
	slider_row.add_child(btn_minus_50)

	# Small Minus Button [- $10]
	var btn_minus_10 = stepper_btn_style.call("−$10")
	btn_minus_10.pressed.connect(func():
		bet_slider.value = clampf(bet_slider.value - 10.0, min_val, max_val)
	)
	slider_row.add_child(btn_minus_10)

	# Enhanced HSlider
	bet_slider = HSlider.new()
	bet_slider.min_value = min_val
	bet_slider.max_value = max_val
	bet_slider.step = 5.0
	bet_slider.value = float(current_bet)
	bet_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bet_slider.custom_minimum_size = Vector2(280, 38)

	# Custom track background style
	var track_sb = StyleBoxFlat.new()
	track_sb.bg_color = Color(0.10, 0.12, 0.18)
	track_sb.border_color = Color(0.55, 0.50, 0.30)
	track_sb.set_border_width_all(1)
	track_sb.set_corner_radius_all(6)
	track_sb.content_margin_top = 6
	track_sb.content_margin_bottom = 6
	bet_slider.add_theme_stylebox_override("slider", track_sb)

	# Glowing gold filled portion of track (grabber_area)
	var grab_fill = StyleBoxFlat.new()
	grab_fill.bg_color = Color(0.95, 0.75, 0.20)
	grab_fill.set_corner_radius_all(6)
	grab_fill.content_margin_top = 6
	grab_fill.content_margin_bottom = 6
	bet_slider.add_theme_stylebox_override("grabber_area", grab_fill)

	var grab_fill_hl = StyleBoxFlat.new()
	grab_fill_hl.bg_color = Color(1.0, 0.88, 0.35)
	grab_fill_hl.set_corner_radius_all(6)
	grab_fill_hl.content_margin_top = 6
	grab_fill_hl.content_margin_bottom = 6
	bet_slider.add_theme_stylebox_override("grabber_area_highlight", grab_fill_hl)

	var grab_tex = load("res://assets/textures/ui_slider_grabber.png")
	if grab_tex:
		bet_slider.add_theme_icon_override("grabber", grab_tex)
		bet_slider.add_theme_icon_override("grabber_highlight", grab_tex)
		bet_slider.add_theme_icon_override("grabber_disabled", grab_tex)

	# Mouse wheel scroll on slider
	bet_slider.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
				bet_slider.value = clampf(bet_slider.value + 10.0, min_val, max_val)
				get_viewport().set_input_as_handled()
			elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				bet_slider.value = clampf(bet_slider.value - 10.0, min_val, max_val)
				get_viewport().set_input_as_handled()
	)

	bet_slider.value_changed.connect(func(val: float):
		current_bet = int(val)
		_update_ui()
	)
	slider_row.add_child(bet_slider)

	# Small Plus Button [+ $10]
	var btn_plus_10 = stepper_btn_style.call("+$10")
	btn_plus_10.pressed.connect(func():
		bet_slider.value = clampf(bet_slider.value + 10.0, min_val, max_val)
	)
	slider_row.add_child(btn_plus_10)

	# Big Plus Button [+ $50]
	var btn_plus_50 = stepper_btn_style.call("+$50")
	btn_plus_50.pressed.connect(func():
		bet_slider.value = clampf(bet_slider.value + 50.0, min_val, max_val)
	)
	slider_row.add_child(btn_plus_50)

	# Slider Range Labels (Min vs Max / ALL IN)
	var range_row = HBoxContainer.new()
	var min_lbl = Label.new()
	min_lbl.text = "Min: $%d" % int(min_val)
	min_lbl.add_theme_font_size_override("font_size", 12)
	min_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	range_row.add_child(min_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_row.add_child(spacer)

	var max_lbl = Label.new()
	max_lbl.text = "Max / ALL IN: $%d" % player_cash
	max_lbl.add_theme_font_size_override("font_size", 12)
	max_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
	range_row.add_child(max_lbl)
	vbox.add_child(range_row)

	# Quick Jump Preset Buttons
	var quick_row = HBoxContainer.new()
	quick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_row.add_theme_constant_override("separation", 10)
	vbox.add_child(quick_row)

	var btn_p_min = Button.new()
	btn_p_min.text = "Min ($%d)" % int(min_val)
	btn_p_min.pressed.connect(func():
		bet_slider.value = min_val
	)
	quick_row.add_child(btn_p_min)

	if player_cash >= 200:
		var btn_25 = Button.new()
		var amt_25 = int(player_cash * 0.25 / 10.0) * 10
		btn_25.text = "25%% ($%d)" % amt_25
		btn_25.pressed.connect(func():
			bet_slider.value = float(amt_25)
		)
		quick_row.add_child(btn_25)

	if player_cash >= 100:
		var btn_half = Button.new()
		var amt_half = int(player_cash * 0.50 / 10.0) * 10
		btn_half.text = "50%% ($%d)" % amt_half
		btn_half.pressed.connect(func():
			bet_slider.value = float(amt_half)
		)
		quick_row.add_child(btn_half)

	if player_cash >= 300:
		var btn_75 = Button.new()
		var amt_75 = int(player_cash * 0.75 / 10.0) * 10
		btn_75.text = "75%% ($%d)" % amt_75
		btn_75.pressed.connect(func():
			bet_slider.value = float(amt_75)
		)
		quick_row.add_child(btn_75)

	var btn_all_in = Button.new()
	btn_all_in.text = "🔥 ALL IN ($%d)" % player_cash
	var all_in_sb = StyleBoxFlat.new()
	all_in_sb.bg_color = Color(0.75, 0.20, 0.15)
	all_in_sb.set_corner_radius_all(6)
	btn_all_in.add_theme_stylebox_override("normal", all_in_sb)
	btn_all_in.pressed.connect(func():
		bet_slider.value = max_val
	)
	quick_row.add_child(btn_all_in)

	# 5. Payout Tiers Preview Panel
	var tier_panel = PanelContainer.new()
	var t_sb = StyleBoxFlat.new()
	t_sb.bg_color = Color(0.04, 0.05, 0.08, 0.88)
	t_sb.border_color = Color(0.3, 0.4, 0.5, 0.5)
	t_sb.set_border_width_all(1)
	t_sb.set_corner_radius_all(8)
	tier_panel.add_theme_stylebox_override("panel", t_sb)
	vbox.add_child(tier_panel)

	var t_margin = MarginContainer.new()
	t_margin.add_theme_constant_override("margin_left", 14)
	t_margin.add_theme_constant_override("margin_right", 14)
	t_margin.add_theme_constant_override("margin_top", 8)
	t_margin.add_theme_constant_override("margin_bottom", 8)
	tier_panel.add_child(t_margin)

	payout_label = Label.new()
	payout_label.add_theme_font_size_override("font_size", 13)
	payout_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	t_margin.add_child(payout_label)

	_update_ui()

	# 6. Action Buttons Row
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_row)

	var cancel_btn = Button.new()
	cancel_btn.text = "Walk Away"
	cancel_btn.custom_minimum_size = Vector2(140, 44)
	cancel_btn.pressed.connect(func():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		cancelled.emit()
		queue_free()
	)
	btn_row.add_child(cancel_btn)

	var confirm_btn = Button.new()
	confirm_btn.text = "🎯 CONFIRM & TAKE DARTS"
	confirm_btn.custom_minimum_size = Vector2(250, 44)
	var c_sb = StyleBoxFlat.new()
	c_sb.bg_color = Color(0.18, 0.65, 0.28)
	c_sb.set_corner_radius_all(6)
	confirm_btn.add_theme_stylebox_override("normal", c_sb)
	confirm_btn.pressed.connect(func():
		if player_cash < current_bet:
			bet_label.text = "⚠️ INSUFFICIENT CASH FOR $%d BET!" % current_bet
			bet_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
			return
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		bet_confirmed.emit(current_bet)
		queue_free()
	)
	btn_row.add_child(confirm_btn)

	# Modal guarantee: capture mouse immediately whenever this dialog exits tree
	tree_exited.connect(func():
		print("DartsBettingDialog tree_exited: Setting MOUSE_MODE_CAPTURED")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _update_ui() -> void:
	if bet_label:
		if current_bet >= player_cash and player_cash > 0:
			bet_label.text = "🔥 STAKE: $%d (ALL IN!)" % current_bet
			bet_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.30))
		else:
			var pct = int((float(current_bet) / float(maxi(1, player_cash))) * 100.0)
			bet_label.text = "STAKE: $%d  (%d%% of Wallet)" % [current_bet, pct]
			bet_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))

	if payout_label:
		var p35 = int(current_bet * 1.5)
		var p50 = int(current_bet * 2.5)
		var p75 = int(current_bet * 4.0)
		var p100 = int(current_bet * 7.0)
		payout_label.text = (
			"🏆 POTENTIAL PAYOUT MULTIPLIERS FOR $%d STAKE:\n" % current_bet
			+ "  • 35 - 49 pts:  1.5x Payout  ➔  $%d\n" % p35
			+ "  • 50 - 74 pts:  2.5x Payout  ➔  $%d  +  🔋 CAR BATTERY!\n" % p50
			+ "  • 75 - 99 pts:  4.0x Payout  ➔  $%d  +  🔋 CAR BATTERY!\n" % p75
			+ "  • 100+ pts:     7.0x Payout  ➔  $%d  +  🔋 CAR BATTERY! (JACKPOT)" % p100
		)
