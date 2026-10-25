class_name Interactable
extends Node3D
## Something a player walks up to and presses [E] on: the parts terminal, casino tables,
## the delivery board. The local Player finds the nearest one in range and shows its prompt.

signal activated(player: Node3D)

var prompt := "[E] use"
var range_m := 2.5
## Return false to hide the prompt and ignore [E] (a closed shop, a game already in use).
var enabled := true


func _ready() -> void:
	add_to_group("interactable")


func in_range(p: Vector3) -> bool:
	return enabled and global_position.distance_to(p) <= range_m


func activate(player: Node3D) -> void:
	activated.emit(player)
