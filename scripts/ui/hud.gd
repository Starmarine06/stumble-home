class_name Hud
extends CanvasLayer
## In-night HUD: role card, wanted/car bars, prompts, toasts, and the
## role-specific panels (Navigator route, Lookout cop alert, Mechanic engine).

var world: World
var drunk_level := 0.9
var minigame_active := false

var _fx: DrunkFx
var _role_label: Label
var _goal_label: Label
var _checklist: PartChecklist
var _compass: PartCompass
var _cross: PartCrosshair
var _wanted_bar: ProgressBar
var _hp_bar: ProgressBar
var _prompt: Label
var _toast: Label
var _toast_t := 0.0
var _nav_label: Label
var _alert_label: Label
var _mg_holder: Control
var _cop_left := 0.0
var _cop_side := ""
var _nav_shown := 0
var _nav_roll := 0.0


func _ready() -> void:
	add_to_group("hud")
	layer = 10
	_fx = DrunkFx.new()
	add_child(_fx)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_role_label = _label(root, Vector2(16, 12), 18)
	_goal_label = _label(root, Vector2(16, 120), 20)
	_goal_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_checklist = PartChecklist.new()
	_checklist.position = Vector2(16, 150)
	root.add_child(_checklist)
	_compass = PartCompass.new()
	_compass.position = Vector2(1280 - 180, 110)
	root.add_child(_compass)
	_cross = PartCrosshair.new()
	root.add_child(_cross)

	var bars := VBoxContainer.new()
	bars.position = Vector2(1280 - 260, 14)
	bars.custom_minimum_size = Vector2(240, 0)
	root.add_child(bars)
	var wl := Label.new()
	wl.text = "WANTED"
	bars.add_child(wl)
	_wanted_bar = _bar(bars, Color(0.9, 0.2, 0.25))
	var hl := Label.new()
	hl.text = "CAR"
	bars.add_child(hl)
	_hp_bar = _bar(bars, Color(0.3, 0.85, 0.4))

	_prompt = _label(root, Vector2(0, 600), 22)
	_prompt.size = Vector2(1280, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast = _label(root, Vector2(0, 90), 22)
	_toast.size = Vector2(1280, 30)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
	_nav_label = _label(root, Vector2(0, 220), 34)
	_nav_label.size = Vector2(1280, 120)
	_nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label = _label(root, Vector2(0, 340), 30)
	_alert_label.size = Vector2(1280, 60)
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mg_holder = Control.new()
	_mg_holder.position = Vector2(380, 430)
	_mg_holder.size = Vector2(520, 90)
	root.add_child(_mg_holder)

	var names := []
	for r in Game.my_roles():
		names.append("%s (%s)" % [Roles.role_name(r), Roles.INFO[r]["type"]])
	_role_label.text = "You are: %s" % ", ".join(names)
	Game.toast_msg.connect(show_toast)
	Game.cop_warning.connect(_on_cop_warning)
	Game.drive_started.connect(func(_s): show_toast("Parts fitted! Everybody in. Drive home!"))


func _exit_tree() -> void:
	if Game.toast_msg.is_connected(show_toast):
		Game.toast_msg.disconnect(show_toast)
	if Game.cop_warning.is_connected(_on_cop_warning):
		Game.cop_warning.disconnect(_on_cop_warning)


func _label(parent: Control, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(parent: Control, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(240, 18)
	b.show_percentage = false
	b.max_value = 100.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	b.add_theme_stylebox_override("fill", sb)
	parent.add_child(b)
	return b


func set_prompt(text: String) -> void:
	_prompt.text = text


func show_toast(text: String) -> void:
	_toast.text = text
	_toast_t = 4.0


func start_minigame(hits: int, misses: int, title: String, limit: float, done: Callable, level: float) -> void:
	if minigame_active:
		return
	var mg := ShakyBar.new()
	mg.hits_needed = hits
	mg.misses_allowed = misses
	mg.title = title
	mg.time_limit = limit
	mg.drunk = level
	minigame_active = true
	mg.finished.connect(func(ok: bool):
		minigame_active = false
		done.call(ok))
	_mg_holder.add_child(mg)


func _on_cop_warning(side: String, seconds: float) -> void:
	_cop_left = seconds
	_cop_side = side


func _process(delta: float) -> void:
	_fx.drunk = drunk_level
	_toast_t -= delta
	if _toast_t <= 0.0:
		_toast.text = ""
	_wanted_bar.value = Game.wanted
	_hp_bar.value = Game.car_hp
	_hp_bar.visible = Game.phase == Game.Phase.DRIVE
	_cop_left = maxf(0.0, _cop_left - delta)

	_alert_label.text = ""
	_nav_label.text = ""
	if Game.phase == Game.Phase.SCAVENGE:
		_scavenge_hud(delta)
	elif Game.phase == Game.Phase.DRIVE:
		_drive_hud(delta)


func _scavenge_hud(_delta: float) -> void:
	var me_id := Game.my_id()
	var tired := Game.fatigue_of(me_id)
	var out := Game.is_out(me_id)
	if out:
		_fx.blackout = 1.0
	else:
		_fx.blackout = clampf((tired - 0.6) / 0.4, 0.0, 1.0) * (0.3 + 0.2 * sin(Time.get_ticks_msec() * 0.006))
	_goal_label.text = ""
	_role_label.text = _role_text("scavenge")

	var is_mech := Game.has_role(Roles.Id.MECHANIC)
	_checklist.visible = true
	_checklist.show_tired = not is_mech
	_checklist.tired = tired
	_checklist.out_frac = Game.out_left.get(me_id, 0.0) / Game.PASSOUT_SECS if out else 0.0

	var me := world.local_player() if world else null
	_cross.visible = me != null and not out
	if me:
		_cross.strain = me.strain
		_cross.can_grab = me.aim_part != -1
		_cross.holding = me.holding
		_cross.fit_q = me.fit_q
	_update_compass(me, is_mech and not out)


## Mechanic only: points at the nearest loose part, or at the car while you carry one.
func _update_compass(me: Player, allowed: bool) -> void:
	_compass.lit = false
	if not allowed or me == null:
		return
	var target := Vector3.ZERO
	var part := -1
	var held := Game.carried_by(Game.my_id())
	if held != -1:
		target = Game.CAR_POS
	else:
		var bd := INF
		for i in Game.parts.size():
			var p: Dictionary = Game.parts[i]
			if p.state == Game.PS.WORLD:
				var d := me.global_position.distance_to(p.pos)
				if d < bd:
					bd = d
					part = i
					target = p.pos
		if part == -1:
			return
	var to := target - me.global_position
	var fwd := Vector2(-sin(me.rotation.y), -cos(me.rotation.y))
	var wobble := sin(Time.get_ticks_msec() * 0.003) * 0.35 * drunk_level
	_compass.target_part = part
	_compass.angle = fwd.angle_to(Vector2(to.x, to.z)) + wobble
	_compass.closeness = 1.0 - clampf(Vector2(to.x, to.z).length() / 40.0, 0.0, 1.0)
	_compass.lit = true


func _drive_hud(delta: float) -> void:
	_goal_label.text = "Get the crew home before the cops catch you. Don't wreck the car."
	_checklist.visible = false
	_compass.lit = false
	_cross.visible = false
	_role_label.text = _role_text("drive")
	var drive := world.drive if world else null
	if drive == null:
		return
	_fx.blackout = drive.blackout
	if Game.has_role(Roles.Id.DRIVER):
		_prompt.text = "W/S gas & brake   A/D steer   (you nod off now and then)"
	if Game.has_role(Roles.Id.NAVIGATOR):
		var n := drive.nav()
		_nav_roll -= delta
		if _nav_roll <= 0.0:
			_nav_roll = 0.6
			var wrong := randf() < Tuning.nav_wrong_rate * drunk_level
			_nav_shown = n.dir * (-1 if wrong else 1)
		if n.final:
			_nav_label.text = "HOME in %d m" % int(n.dist)
		else:
			var word := "RIGHT >>" if _nav_shown > 0 else "<< LEFT"
			_nav_label.text = "Turn in %d m\n%s" % [int(n.dist), word]
	if Game.has_role(Roles.Id.MECHANIC) and Game.engine_hot:
		_alert_label.text = "ENGINE OVERHEATING!  [E] cool it down"
		_alert_label.add_theme_color_override("font_color", Color(1, 0.5, 0.2))
		if Input.is_action_just_pressed("act") and not minigame_active:
			start_minigame(2, 3, "COOL THE ENGINE", 0.0, func(ok: bool): Game.request_cool(ok), drunk_level)
	if Game.has_role(Roles.Id.LOOKOUT) and _cop_left > 0.0:
		_alert_label.text = "COPS ON THE %s!  [E] steady yourself and signal  (%ds)" % [_cop_side, int(_cop_left) + 1]
		_alert_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		if Input.is_action_just_pressed("act") and not minigame_active:
			start_minigame(1, 2, "DUCK AND SIGNAL", _cop_left, func(ok: bool):
				_cop_left = 0.0
				Game.request_cop_result(ok), drunk_level)


func _role_text(key: String) -> String:
	var out := []
	for r in Game.my_roles():
		out.append("%s (%s): %s" % [Roles.role_name(r), Roles.INFO[r]["type"], Roles.INFO[r][key]])
	return "\n".join(out)


func _arrow(ang: float) -> String:
	var a := wrapf(ang, -PI, PI)
	var dirs := ["^", "^>", ">", "v>", "v", "<v", "<", "<^"]
	var i := posmod(int(round(a / (PI / 4.0))), 8)
	return dirs[i]
