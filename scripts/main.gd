extends Node
## Menu, lobby and result screens. The night itself lives in World.

var _ui: CanvasLayer
var _screen: Control
var _status: Label
var _world: World
var _code_edit: LineEdit
var _ip_edit: LineEdit
var _name_edit: LineEdit


func _ready() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	Net.status_changed.connect(_set_status)
	Net.hosted.connect(func(_c): Game.start_hosting())
	Net.joined.connect(Game.on_joined)
	Net.host_failed.connect(_set_status)
	Net.join_failed.connect(_set_status)
	Game.phase_changed.connect(_on_phase)
	Game.roster_changed.connect(_refresh_lobby)
	Game.toast_msg.connect(func(t): if Game.phase == Game.Phase.MENU: _set_status(t))
	_on_phase()
	_run_auto_args()


func _run_auto_args() -> void:
	var start_night := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--night="):
			start_night = clampi(int(arg.get_slice("=", 1)) - 1, 0, Nights.count() - 1)
	for arg in OS.get_cmdline_user_args():
		match arg:
			"--auto=solo":
				Game.start_hosting()
				if start_night >= 0:
					Game.start_game(start_night)
			"--auto=host":
				Net.host_enet()
			"--auto=join":
				Net.join_enet("127.0.0.1")


## F11 flips between fullscreen and a window sized to the player's display.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var w := get_window()
		if w.mode == Window.MODE_FULLSCREEN:
			w.mode = Window.MODE_WINDOWED
			var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			w.size = Vector2i(screen.size * 0.85)
			w.position = screen.position + (screen.size - w.size) / 2
		else:
			w.mode = Window.MODE_FULLSCREEN


func _set_status(text: String) -> void:
	if _status:
		_status.text = text


func _on_phase() -> void:
	match Game.phase:
		Game.Phase.MENU:
			_clear_world()
			_show_menu()
		Game.Phase.LOBBY:
			_clear_world()
			_show_lobby()
		Game.Phase.SCAVENGE:
			_clear_screen()
			# A new night (next or retry) always gets a fresh world.
			_clear_world()
			_world = World.new()
			_world.name = "World"
			add_child(_world)
		Game.Phase.RESULT:
			_show_result()


func _clear_world() -> void:
	if _world:
		remove_child(_world)
		_world.queue_free()
		_world = null


func _clear_screen() -> void:
	if _screen:
		_screen.queue_free()
		_screen = null
	_status = null


func _panel(title: String, width := 560) -> VBoxContainer:
	_clear_screen()
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(holder)
	_screen = holder
	var bg := PanelContainer.new()
	holder.add_child(bg)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	bg.add_child(margin)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 34)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	return box


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# --- Menu ----------------------------------------------------------------------------

func _show_menu() -> void:
	var box := _panel("STUMBLE HOME")
	var sub := Label.new()
	sub.text = "Four drunks. One broken car. Get home before the cops get you."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	_name_edit = LineEdit.new()
	_name_edit.text = Net.player_name
	_name_edit.placeholder_text = "Your name"
	_name_edit.max_length = 16
	box.add_child(_name_edit)
	_button(box, "Host online game (EOS)", func():
		_apply_name()
		_set_status("Working...")
		Net.host_eos())
	var row := HBoxContainer.new()
	box.add_child(row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "Room code"
	_code_edit.max_length = Net.CODE_LEN
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_code_edit)
	_button(row, "Join online", func():
		_apply_name()
		_set_status("Working...")
		Net.join_eos(_code_edit.text))
	box.add_child(HSeparator.new())
	var lan := Label.new()
	lan.text = "Local testing"
	box.add_child(lan)
	var row2 := HBoxContainer.new()
	box.add_child(row2)
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(_ip_edit)
	_button(row2, "Host LAN", func():
		_apply_name()
		Net.host_enet())
	_button(row2, "Join LAN", func():
		_apply_name()
		Net.join_enet(_ip_edit.text))
	_button(box, "Practice solo (you play all four roles)", func():
		_apply_name()
		Game.start_hosting())
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status)
	var warn := Label.new()
	warn.text = "18+ . Please drink responsibly in real life."
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.modulate = Color(1, 1, 1, 0.5)
	box.add_child(warn)


func _apply_name() -> void:
	var n := _name_edit.text.strip_edges()
	if n != "":
		Net.player_name = n


# --- Lobby ------------------------------------------------------------------------------

var _role_buttons := {}
var _player_list: Label
var _night_label: Label
var _start_btn: Button


func _show_lobby() -> void:
	var box := _panel("ROOM  %s" % Net.room_code if Net.room_code != "" else "PRACTICE ROOM", 700)
	_night_label = Label.new()
	_night_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_night_label)
	var hint := Label.new()
	hint.text = "Share the room code. Everyone claims a drunk. Unclaimed roles are handed out automatically (with fewer than 4 players, some of you play two)."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(hint)
	_role_buttons.clear()
	for r in Roles.Id.values():
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 74)
		b.pressed.connect(func(): Game.claim_role(r))
		box.add_child(b)
		_role_buttons[r] = b
	_player_list = Label.new()
	box.add_child(_player_list)
	var row := HBoxContainer.new()
	box.add_child(row)
	_start_btn = _button(row, "Start the night", func(): Game.start_game())
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(row, "Leave", func():
		Net.leave()
		Game.go_menu())
	_status = Label.new()
	box.add_child(_status)
	_refresh_lobby()


func _refresh_lobby() -> void:
	if Game.phase != Game.Phase.LOBBY or _player_list == null or not is_instance_valid(_player_list):
		return
	for r in Roles.Id.values():
		var info: Dictionary = Roles.INFO[r]
		var owner: int = Game.role_owner.get(r, -1)
		var who := "free - click to claim"
		if owner != -1:
			who = "taken by %s" % Game.names.get(owner, "?")
		var b: Button = _role_buttons[r]
		b.text = "%s - %s   [%s]\n%s" % [info["name"], info["type"], who, info["drive"]]
		b.modulate = info["color"].lerp(Color.WHITE, 0.55)
	_night_label.text = Nights.get_night(Game.night).title
	_player_list.text = "Players (%d/%d): %s" % [Game.names.size(), Net.MAX_PLAYERS, ", ".join(Game.names.values())]
	_start_btn.visible = Game.is_host()


# --- Result -------------------------------------------------------------------------------

func _show_result() -> void:
	var box := _panel("YOU MADE IT HOME!" if Game.won else "NIGHT OVER", 560)
	var nt := Label.new()
	nt.text = Nights.get_night(Game.night).title
	nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(nt)
	var l := Label.new()
	l.text = Game.result_text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	if Game.is_host():
		if Game.has_next_night():
			_button(box, "Next night", func(): Game.next_night())
		else:
			_button(box, "Retry night", func(): Game.retry_night())
		_button(box, "Back to the lobby", func(): Game.return_to_lobby())
	else:
		var w := Label.new()
		w.text = "Waiting for the host..."
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(w)
