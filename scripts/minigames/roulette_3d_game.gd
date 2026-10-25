class_name Roulette3DGame
extends Node3D

## Real-Life 3D Casino Roulette Game Session Controller
## Features:
## - Full 3D camera cutscene transition focusing on the roulette table
## - Real-life counter-rotating physics:
##     Rotor spins clockwise (gradual friction decay)
##     Ivory ball launched counter-clockwise on outer brass track rim at high speed
## - Centrifugal decay, inward spiraling, deflector bouncing, fret hopping & pocket settling
## - European 37-pocket determination matching roulette_wheel_face.png
## - Glowing golden spotlight pocket marker & croupier announcements
## - Payout resolution & Spare Tyre award

signal finished(won_tyre: bool, payout: int)

const WHEEL_NUMBERS := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const RED_NUMBERS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

const RouletteTable3DClass = preload("res://scripts/minigames/roulette_table_3d.gd")

enum SessionState {
	TRANSITION_IN,
	BALL_LAUNCH,
	RIM_ORBIT,
	SPIRAL_DROP,
	DEFLECTOR_BOUNCE,
	FRET_HOPPING,
	SETTLED,
	RESULT_ANNOUNCE,
	TRANSITION_OUT
}

var state: SessionState = SessionState.TRANSITION_IN
var state_timer: float = 0.0

# References
var player: CharacterBody3D = null
var roulette_table: Node3D = null
var croupier_npc: Node = null

# Betting Info
var bet_amount: int = 50
var bet_type: String = "RED"
var bet_param: Variant = null

# Camera Transition Rig (uses player body & camera directly, matching Darts)
var cutscene_start_player_pos: Vector3 = Vector3.ZERO
var cutscene_start_player_yaw: float = 0.0
var cutscene_start_head_pitch: float = 0.0
var target_player_table_pos: Vector3 = Vector3(17.32, 0.80, -32.85)
var target_player_yaw: float = 0.0
var target_head_pitch: float = deg_to_rad(-36.0)

# Physics Simulation Variables
var rotor_angle: float = 0.0
var rotor_speed: float = 5.2 # rad/s clockwise (+)
var rotor_friction: float = 0.28 # rad/s^2

var ball_angle: float = 0.0
var ball_speed: float = -22.0 # rad/s counter-clockwise (-)
var ball_friction: float = 1.95 # rad/s^2
var ball_radius: float = 0.42 # Outer track radius
var ball_y: float = -0.018 # Rim height
var ball_v_y: float = 0.0

var settled_pocket_idx: int = 0
var winning_number: int = 0
var winning_color: String = "RED"
var is_bet_won: bool = false
var payout_amount: int = 0
var spare_tyre_awarded: bool = false

# HUD Overlay
var hud_overlay: CanvasLayer = null
var banner_label: Label = null
var sub_label: Label = null

func start_roulette_session(
	p_player: CharacterBody3D,
	p_table: Node3D,
	p_croupier: Node,
	p_bet_amt: int,
	p_bet_type: String,
	p_param: Variant = null
) -> void:
	player = p_player
	bet_amount = p_bet_amt
	bet_type = p_bet_type
	bet_param = p_param
	croupier_npc = p_croupier

	# Resolve Roulette Table
	if p_table and p_table.has_method("set_rotor_rotation"):
		roulette_table = p_table
	elif p_table:
		var found = p_table.find_child("RouletteTable3D", true, false)
		if found and found.has_method("set_rotor_rotation"):
			roulette_table = found
		elif p_table.get_parent() and p_table.get_parent().has_method("set_rotor_rotation"):
			roulette_table = p_table.get_parent()

	if not roulette_table and is_inside_tree() and get_tree().root:
		roulette_table = get_tree().root.find_child("RouletteTable3D", true, false) as Node3D

	if roulette_table and roulette_table.has_method("clear_win_marker"):
		roulette_table.clear_win_marker()

	# Record cutscene start parameters from player
	if player:
		cutscene_start_player_pos = player.global_position
		cutscene_start_player_yaw = player.rotation.y
		if ("head" in player) and player.head:
			cutscene_start_head_pitch = player.head.rotation.x
		if roulette_table and roulette_table.is_inside_tree():
			var table_pos = roulette_table.global_position
			target_player_table_pos = table_pos + Vector3(-0.68, 0.0, 1.15)
	
	_setup_hud()

	# Transition in (0.65s smooth walk to front of table overlooking wheel)
	state = SessionState.TRANSITION_IN
	state_timer = 0.65
	_play_sfx(&"clang")

func _setup_hud() -> void:
	hud_overlay = CanvasLayer.new()
	add_child(hud_overlay)

	var root_ctrl = Control.new()
	root_ctrl.name = "Root"
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_overlay.add_child(root_ctrl)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 180
	panel.offset_right = -180
	panel.offset_top = 16
	panel.offset_bottom = 110

	var box = StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.07, 0.12, 0.92)
	box.border_color = Color(0.96, 0.78, 0.22)
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.shadow_size = 14
	box.shadow_color = Color(0, 0, 0, 0.75)
	panel.add_theme_stylebox_override("panel", box)
	root_ctrl.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	banner_label = Label.new()
	banner_label.text = "🎲 CROUPIER ANTOINE: \"Rien ne va plus! Place your bets!\""
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 18)
	banner_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.25))
	vbox.add_child(banner_label)

	sub_label = Label.new()
	var bet_desc = bet_type
	if bet_type == "NUMBER":
		bet_desc = "Single Number %s (36x Jackpot)" % str(bet_param)
	sub_label.text = "Wager: $%d on %s  •  Prize: cash payout!" % [bet_amount, bet_desc]
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 13)
	sub_label.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98))
	vbox.add_child(sub_label)

func _process(delta: float) -> void:
	# Keep mouse captured / disabled during 3D session
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Always simulate rotor deceleration smoothly
	rotor_speed = maxf(0.0, rotor_speed - rotor_friction * delta)
	rotor_angle = fmod(rotor_angle + rotor_speed * delta, TAU)
	if roulette_table and roulette_table.has_method("set_rotor_rotation"):
		roulette_table.set_rotor_rotation(rotor_angle)

	# State Machine for 3D Roulette Spin & Ball Physics
	match state:
		SessionState.TRANSITION_IN:
			state_timer -= delta
			var t = clampf(1.0 - (state_timer / 0.65), 0.0, 1.0)
			var smooth_t = ease(t, -2.0)
			if player:
				player.global_position = cutscene_start_player_pos.lerp(target_player_table_pos, smooth_t)
				player.rotation.y = lerp_angle(cutscene_start_player_yaw, target_player_yaw, smooth_t)
				if ("head" in player) and player.head:
					player.head.rotation.x = lerpf(cutscene_start_head_pitch, target_head_pitch, smooth_t)
			if state_timer <= 0.0:
				_launch_ball()

		SessionState.BALL_LAUNCH:
			# Ball launched at full speed counter-clockwise
			state = SessionState.RIM_ORBIT
			state_timer = 2.4 # High speed outer track rim orbit
			if banner_label:
				banner_label.text = "💫 BALL LAUNCHED! Spinning at high velocity around outer rim track..."

		SessionState.RIM_ORBIT:
			# Outer track rim phase: ball is glued by centrifugal force to track at R = 0.42m
			ball_speed = minf(-10.5, ball_speed + ball_friction * delta)
			ball_angle = fmod(ball_angle + ball_speed * delta, TAU)
			ball_radius = 0.42
			ball_y = -0.016 + sin(ball_angle * 3.0) * 0.002
			if roulette_table:
				roulette_table.set_ball_position(ball_radius, ball_angle, ball_y)
			
			state_timer -= delta
			if state_timer <= 0.0 or absf(ball_speed) < 11.5:
				state = SessionState.SPIRAL_DROP
				state_timer = 1.6
				if banner_label:
					banner_label.text = "🌀 Centrifugal force decaying! Ball spiraling down toward deflector pins..."

		SessionState.SPIRAL_DROP:
			# Ball loses centrifugal hold and spirals downward inward
			ball_speed = minf(-6.0, ball_speed + (ball_friction * 1.5) * delta)
			ball_angle = fmod(ball_angle + ball_speed * delta, TAU)
			# Radius drops smoothly from 0.42 down to 0.36 (deflector pin radius)
			var drop_t = clampf(1.0 - (state_timer / 1.6), 0.0, 1.0)
			ball_radius = lerpf(0.42, 0.36, drop_t)
			ball_y = lerpf(-0.016, -0.034, drop_t)
			if roulette_table:
				roulette_table.set_ball_position(ball_radius, ball_angle, ball_y)
			
			state_timer -= delta
			if state_timer <= 0.0:
				state = SessionState.DEFLECTOR_BOUNCE
				state_timer = 1.4
				_play_sfx(&"crash")

		SessionState.DEFLECTOR_BOUNCE:
			# Ball strikes deflector pins (diamonds): hops, chatters, and bounces chaotically
			ball_speed = minf(-3.5, ball_speed + (ball_friction * 2.0) * delta)
			# Perturb ball angle with hop jitter
			ball_angle = fmod(ball_angle + ball_speed * delta, TAU)
			ball_radius = lerpf(0.36, 0.31, clampf(1.0 - (state_timer / 1.4), 0.0, 1.0))
			
			# Hop bounce physics
			var hop_wave = absf(sin(state_timer * 18.0))
			ball_y = -0.038 + hop_wave * 0.012
			if hop_wave > 0.85:
				_play_sfx(&"clang")
			
			if roulette_table:
				roulette_table.set_ball_position(ball_radius, ball_angle, ball_y)
			
			state_timer -= delta
			if state_timer <= 0.0:
				state = SessionState.FRET_HOPPING
				state_timer = 1.2
				if banner_label:
					banner_label.text = "⚡ Rattling over pocket dividers into pocket..."

		SessionState.FRET_HOPPING:
			# Ball drops onto the 37 pocket frets of the spinning rotor turntable
			# Speed decelerates rapidly to match rotor speed
			ball_speed = lerpf(ball_speed, rotor_speed, delta * 3.5)
			ball_angle = fmod(ball_angle + ball_speed * delta, TAU)
			ball_radius = 0.30 # Settling radius
			var fret_chatter = absf(sin(state_timer * 24.0)) * (state_timer / 1.2)
			ball_y = -0.042 + fret_chatter * 0.008
			if fret_chatter > 0.004 and randf() < 0.25:
				_play_sfx(&"rattle")

			if roulette_table:
				roulette_table.set_ball_position(ball_radius, ball_angle, ball_y)

			state_timer -= delta
			if state_timer <= 0.0 or absf(ball_speed - rotor_speed) < 0.4:
				_settle_ball_in_pocket()

		SessionState.SETTLED:
			# Ball is firmly settled inside the winning pocket of the spinning rotor
			_update_settled_ball_position()
			state_timer -= delta
			if state_timer <= 0.0:
				state = SessionState.RESULT_ANNOUNCE
				state_timer = 2.8

		SessionState.RESULT_ANNOUNCE:
			# Display outcome, payout, and award Spare Tyre
			_update_settled_ball_position()
			state_timer -= delta
			if state_timer <= 0.0:
				state = SessionState.TRANSITION_OUT
				state_timer = 0.6

		SessionState.TRANSITION_OUT:
			_update_settled_ball_position()
			state_timer -= delta
			if state_timer <= 0.0:
				_finish_session()

func _launch_ball() -> void:
	state = SessionState.BALL_LAUNCH
	rotor_speed = 5.2 + randf_range(-0.4, 0.4) # Clockwise ~50 RPM
	rotor_angle = randf() * TAU
	ball_speed = -22.0 + randf_range(-2.0, 2.0) # Counter-clockwise ~210 RPM
	ball_angle = randf() * TAU
	ball_radius = 0.42
	ball_y = -0.016
	_play_sfx(&"clang")

func _settle_ball_in_pocket() -> void:
	state = SessionState.SETTLED
	state_timer = 0.8
	_play_sfx(&"clang")

	# Evaluate which pocket the ball landed in!
	# Sector size for 37 pockets:
	var sector_rad = TAU / 37.0
	
	# Relative angle of ball with respect to the rotor turntable:
	# In our 3D setup, pocket 0 is oriented at -90 deg (-Z axis).
	# Delta angle between ball and rotor:
	var rel_angle = fposmod(ball_angle - rotor_angle - deg_to_rad(-90.0), TAU)
	settled_pocket_idx = int(round(rel_angle / sector_rad)) % 37
	
	winning_number = WHEEL_NUMBERS[settled_pocket_idx]
	if winning_number == 0:
		winning_color = "GREEN"
	elif winning_number in RED_NUMBERS:
		winning_color = "RED"
	else:
		winning_color = "BLACK"

	# Highlight winning pocket with golden spotlight ring
	if roulette_table:
		roulette_table.highlight_pocket(settled_pocket_idx)

	# Evaluate Bet & Payout
	_evaluate_bet_result()

func _update_settled_ball_position() -> void:
	if not roulette_table:
		return
	var sector_rad = TAU / 37.0
	var pocket_rel_angle = deg_to_rad(-90.0) + float(settled_pocket_idx) * sector_rad
	var final_world_angle = rotor_angle + pocket_rel_angle
	roulette_table.set_ball_position(0.30, final_world_angle, -0.043)

func _evaluate_bet_result() -> void:
	is_bet_won = false
	var multiplier = 0

	match bet_type:
		"RED":
			if winning_color == "RED":
				is_bet_won = true
				multiplier = 2
		"BLACK":
			if winning_color == "BLACK":
				is_bet_won = true
				multiplier = 2
		"EVEN":
			if winning_number > 0 and winning_number % 2 == 0:
				is_bet_won = true
				multiplier = 2
		"ODD":
			if winning_number % 2 == 1:
				is_bet_won = true
				multiplier = 2
		"LOW":
			if winning_number >= 1 and winning_number <= 18:
				is_bet_won = true
				multiplier = 2
		"HIGH":
			if winning_number >= 19 and winning_number <= 36:
				is_bet_won = true
				multiplier = 2
		"1ST_12":
			if winning_number >= 1 and winning_number <= 12:
				is_bet_won = true
				multiplier = 3
		"2ND_12":
			if winning_number >= 13 and winning_number <= 24:
				is_bet_won = true
				multiplier = 3
		"3RD_12":
			if winning_number >= 25 and winning_number <= 36:
				is_bet_won = true
				multiplier = 3
		"NUMBER":
			var target_num = int(bet_param)
			if winning_number == target_num:
				is_bet_won = true
				multiplier = 36

	if is_bet_won:
		payout_amount = bet_amount * multiplier
		spare_tyre_awarded = true
		_play_sfx(&"win")
		_play_sfx(&"horn")
		if banner_label:
			banner_label.text = "🎉 NUMBER %d (%s)! WINNER!" % [winning_number, winning_color]
			banner_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
		if sub_label:
			sub_label.text = "🏆 WON $%d PAYOUT!" % payout_amount
	else:
		payout_amount = 0
		_play_sfx(&"part_fit_bad")
		if banner_label:
			banner_label.text = "🎯 NUMBER %d (%s)" % [winning_number, winning_color]
			banner_label.add_theme_color_override("font_color", Color(0.95, 0.65, 0.35))
		if sub_label:
			sub_label.text = "Better luck next spin! Try again with Croupier Antoine."

func _finish_session() -> void:
	if player and ("head" in player) and player.head:
		var tw = player.create_tween()
		if tw:
			tw.tween_property(player.head, "rotation:x", 0.0, 0.25)

	if hud_overlay:
		hud_overlay.queue_free()

	# Recapture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player and ("is_mouse_unlocked" in player):
		player.is_mouse_unlocked = false

	finished.emit(spare_tyre_awarded, payout_amount)
	queue_free()

func _play_sfx(event: StringName) -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").play(event)
