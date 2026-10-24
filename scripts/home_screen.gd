extends Node3D

@onready var play_btn: TextureButton = find_child("PlayButton", true, false)
@onready var create_room_btn: TextureButton = find_child("CreateRoomButton", true, false)
@onready var quit_btn: TextureButton = find_child("QuitButton", true, false)
@onready var status_panel: Control = find_child("StatusToast", true, false)
@onready var status_lbl: Label = find_child("StatusLabel", true, false)
@onready var camera: Camera3D = find_child("MenuCamera", true, false)
@onready var logo_rect: TextureRect = find_child("LogoTexture", true, false)
@onready var name_input: LineEdit = find_child("NameInput", true, false)
@onready var role_desc_lbl: Label = find_child("RoleDescriptionLabel", true, false)

# Role cards
@onready var card_driver: Control = find_child("CardDriver", true, false)
@onready var card_navigator: Control = find_child("CardNavigator", true, false)
@onready var card_mechanic: Control = find_child("CardMechanic", true, false)
@onready var card_lookout: Control = find_child("CardLookout", true, false)

var time_elapsed: float = 0.0
var initial_cam_pos: Vector3 = Vector3(-4.0, 2.6, 14.5)
var initial_cam_rot: Vector3 = Vector3(deg_to_rad(-3.0), deg_to_rad(10.0), 0.0)
var status_timer: float = 0.0
var logo_initial_pos: Vector2 = Vector2.ZERO

const ROLE_PERKS := {
	"driver": "DRIVER (The Sloppy): Strong arms for hauling parts! Drives the car home, but steering wanders, lags, and nods off.",
	"navigator": "NAVIGATOR (The Blabber): Only one who sees the route GPS! Shouts directions while flickering arrows try to mislead you.",
	"mechanic": "MECHANIC (The Shaky): Hauls heavy parts without tiring. Compass points directly to missing car parts! Shaky hands on engine overheat.",
	"lookout": "LOOKOUT (The Paranoid): Spot cops, oncoming traffic, stray dogs & muggers 25 meters away before anyone else sees them!"
}

func _ready() -> void:
	# Unlock mouse for interactive menu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if camera:
		initial_cam_pos = camera.position
		initial_cam_rot = camera.rotation
		
	if logo_rect:
		logo_initial_pos = logo_rect.position

	# Initialize Player Name from Net autoload if available
	if name_input:
		if has_node("/root/Net"):
			var net = get_node("/root/Net")
			if net.get("player_name") and net.player_name != "":
				name_input.text = net.player_name
			else:
				name_input.text = "Drunkard"
				net.player_name = "Drunkard"
		name_input.text_changed.connect(_on_name_changed)

	# Connect Buttons
	if play_btn:
		play_btn.pressed.connect(_on_play_pressed)
		play_btn.mouse_entered.connect(func(): _on_btn_hover(play_btn))
		play_btn.mouse_exited.connect(func(): _on_btn_unhover(play_btn))
		play_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if create_room_btn:
		create_room_btn.pressed.connect(_on_create_room_pressed)
		create_room_btn.mouse_entered.connect(func(): _on_btn_hover(create_room_btn))
		create_room_btn.mouse_exited.connect(func(): _on_btn_unhover(create_room_btn))
		create_room_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)
		quit_btn.mouse_entered.connect(func(): _on_btn_hover(quit_btn))
		quit_btn.mouse_exited.connect(func(): _on_btn_unhover(quit_btn))
		quit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Setup Role Card Hovers
	_setup_card(card_driver, "driver")
	_setup_card(card_navigator, "navigator")
	_setup_card(card_mechanic, "mechanic")
	_setup_card(card_lookout, "lookout")

	if status_panel:
		status_panel.visible = false

func _setup_card(card: Control, role_key: String) -> void:
	if not card:
		return
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.mouse_entered.connect(func():
		_play_sfx(&"ui_click")
		if role_desc_lbl:
			role_desc_lbl.text = ROLE_PERKS.get(role_key, "")
		var tw = create_tween().set_parallel(true)
		tw.tween_property(card, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.15)
	)
	card.mouse_exited.connect(func():
		var tw = create_tween().set_parallel(true)
		tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.15)
		tw.tween_property(card, "modulate", Color.WHITE, 0.15)
	)
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_play_sfx(&"clang")
			if role_desc_lbl:
				role_desc_lbl.text = "★ SELECTED: " + ROLE_PERKS.get(role_key, "")
			_show_toast("Selected: " + role_key.to_upper() + " for next run!")
	)

func _process(delta: float) -> void:
	time_elapsed += delta
	
	# Atmospheric drunken cinematic sway for the menu camera
	if camera:
		var sway_x = sin(time_elapsed * 0.45) * 0.40
		var sway_y = cos(time_elapsed * 0.35) * 0.16
		camera.position = initial_cam_pos + Vector3(sway_x, sway_y, 0.0)
		camera.rotation.y = initial_cam_rot.y + sin(time_elapsed * 0.28) * 0.022
		camera.rotation.z = sin(time_elapsed * 0.5) * 0.007

	# Cartoon drunken float & bob on logo
	if logo_rect:
		var bob_y = sin(time_elapsed * 2.2) * 6.0
		var rot_wobble = sin(time_elapsed * 1.8) * 0.02
		logo_rect.position.y = logo_initial_pos.y + bob_y
		logo_rect.rotation = rot_wobble

	# Status toast auto-fade
	if status_timer > 0.0:
		status_timer -= delta
		if status_timer <= 0.0 and status_panel:
			var tw = create_tween()
			tw.tween_property(status_panel, "modulate:a", 0.0, 0.3)
			tw.tween_callback(func(): status_panel.visible = false)

func _on_btn_hover(btn: Control) -> void:
	_play_sfx(&"ui_click")
	var tw = create_tween()
	tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_btn_unhover(btn: Control) -> void:
	var tw = create_tween()
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)

func _on_name_changed(new_name: String) -> void:
	var cleaned = new_name.strip_edges()
	if cleaned != "" and has_node("/root/Net"):
		get_node("/root/Net").player_name = cleaned

func _on_play_pressed() -> void:
	print("▶ PLAY clicked! Dropping player into Stumble Home world...")
	_play_sfx(&"win")
	get_tree().change_scene_to_file("res://scenes/feature_main.tscn")

func _on_create_room_pressed() -> void:
	print("👥 CREATE ROOM clicked (Multiplayer placeholder)")
	_play_sfx(&"horn")
	_show_toast("⚡ MULTIPLAYER: Room codes & matchmaking are coming soon!")

func _on_quit_pressed() -> void:
	print("✕ QUIT clicked. Exiting game.")
	_play_sfx(&"lose")
	get_tree().quit()

func _show_toast(msg: String) -> void:
	if status_panel and status_lbl:
		status_lbl.text = msg
		status_panel.visible = true
		status_panel.modulate.a = 1.0
		status_timer = 4.0
		var tw = create_tween()
		status_panel.scale = Vector2(0.85, 0.85)
		tw.tween_property(status_panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _play_sfx(event: StringName) -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").play(event)
