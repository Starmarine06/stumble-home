extends Control

@onready var badge_rect: TextureRect = find_child("BadgeRect", true, false)
@onready var prompt_lbl: Label = find_child("PromptLabel", true, false)
@onready var content_box: Control = find_child("ContentBox", true, false)
@onready var fade_rect: ColorRect = find_child("FadeOverlay", true, false)

var time_elapsed: float = 0.0
var auto_advance_timer: float = 4.5
var is_transitioning: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Start with content faded in smoothly
	if content_box:
		content_box.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(content_box, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if fade_rect:
		fade_rect.modulate.a = 1.0
		var tw_fade = create_tween()
		tw_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.5)

	# Audio chime
	if has_node("/root/Audio"):
		get_node("/root/Audio").play(&"part_fit_good")

func _process(delta: float) -> void:
	if is_transitioning:
		return

	time_elapsed += delta

	# Gentle breathing bounce on 18+ badge
	if badge_rect:
		var scale_val = 1.0 + sin(time_elapsed * 3.0) * 0.04
		badge_rect.scale = Vector2(scale_val, scale_val)

	# Pulsing prompt label
	if prompt_lbl:
		var alpha_pulse = 0.55 + 0.45 * sin(time_elapsed * 4.0)
		prompt_lbl.modulate.a = alpha_pulse

	# Auto advance countdown
	auto_advance_timer -= delta
	if auto_advance_timer <= 0.0:
		_proceed_to_home()

func _input(event: InputEvent) -> void:
	if is_transitioning:
		return

	# Any key press or mouse click instantly advances
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		_proceed_to_home()

func _proceed_to_home() -> void:
	if is_transitioning:
		return
	is_transitioning = true

	if has_node("/root/Audio"):
		get_node("/root/Audio").play(&"ui_click")

	# Smooth fade out transition to Home Screen
	if fade_rect:
		var tw = create_tween()
		tw.tween_property(fade_rect, "modulate:a", 1.0, 0.4)
		tw.tween_callback(func():
			get_tree().change_scene_to_file("res://scenes/home_screen.tscn")
		)
	else:
		get_tree().change_scene_to_file("res://scenes/home_screen.tscn")
