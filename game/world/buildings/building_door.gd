class_name BuildingDoor
extends Node3D

signal transition_requested(
	door: BuildingDoor,
	destination_map_id: StringName,
	destination_spawn_id: StringName,
	actor: CharacterBody3D
)

@export var door_id: StringName = &"building_door"
@export var display_name: String = "Porta"
@export var destination_map_id: StringName = &""
@export var destination_spawn_id: StringName = &"default"
@onready var interaction_area: InteractableArea3D = $InteractionArea


func _ready() -> void:
	interaction_area.interaction_id = door_id
	interaction_area.display_name = display_name
	interaction_area.max_generated_items = 0
	interaction_area.item_generation_probability = 0.0
	interaction_area.interacted.connect(_on_interacted)


func _on_interacted(interactor: Node3D) -> void:
	var actor := interactor as CharacterBody3D
	if actor == null or destination_map_id.is_empty():
		return
	transition_requested.emit(
		self,
		destination_map_id,
		destination_spawn_id,
		actor
	)
