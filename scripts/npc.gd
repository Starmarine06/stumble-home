extends CharacterBody3D
class_name NPC

@export var character_name: String = "Citizen"
@export var role_title: String = "Patron"
@export var dialogues: Array[String] = [
	"Nice night out here at ceaser.",
	"Keep having a good time!"
]

var dialogue_index: int = 0
var speech_timer: float = 0.0
var idle_seed: float = 0.0

@onready var name_tag: Label3D = get_node_or_null("NameTag")
@onready var speech_bubble: Label3D = get_node_or_null("SpeechBubble")
@onready var head_mesh: Node3D = get_node_or_null("Head")
@onready var chest_mesh: Node3D = get_node_or_null("Chest")

func _ready() -> void:
	idle_seed = randf() * 100.0
	if not name_tag:
		name_tag = find_child("NameTag", true, false)
	if not speech_bubble:
		speech_bubble = find_child("SpeechBubble", true, false)
	if not head_mesh:
		head_mesh = find_child("Head", true, false)
	if not chest_mesh:
		chest_mesh = find_child("Chest", true, false)

	if name_tag:
		name_tag.text = "[ %s ]\n%s" % [character_name, role_title]
		name_tag.visible = true

	if speech_bubble:
		speech_bubble.visible = false

func _process(delta: float) -> void:
	var t = Time.get_ticks_msec() * 0.002 + idle_seed
	
	# Gentle idle breathing animation
	if chest_mesh:
		var breath = sin(t * 1.5) * 0.02
		chest_mesh.scale = Vector3(1.0 + breath, 1.0 + breath * 1.2, 1.0 + breath)
	
	if head_mesh:
		head_mesh.rotation.y = sin(t * 0.8) * 0.08
		head_mesh.rotation.x = sin(t * 1.2) * 0.04

	# Speech bubble timeout
	if speech_timer > 0.0:
		speech_timer -= delta
		if speech_timer <= 0.0 and speech_bubble:
			speech_bubble.visible = false

func talk() -> Dictionary:
	if dialogues.size() == 0:
		return {
			"name": character_name,
			"role": role_title,
			"text": "..."
		}
	
	var text = dialogues[dialogue_index % dialogues.size()]
	dialogue_index = (dialogue_index + 1) % dialogues.size()
	
	if speech_bubble:
		speech_bubble.text = "\"%s\"" % text
		speech_bubble.visible = true
		speech_timer = 6.0
	
	return {
		"name": character_name,
		"role": role_title,
		"text": text
	}
