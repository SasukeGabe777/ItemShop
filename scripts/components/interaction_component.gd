class_name InteractionComponent
extends Area2D
## Marks a body/area as interactable; the town player queries the nearest one.

signal interacted()

@export var prompt: String = "Interact"
@export var action_id: String = ""


func _init() -> void:
	monitoring = false
	monitorable = true


func trigger() -> void:
	interacted.emit()
