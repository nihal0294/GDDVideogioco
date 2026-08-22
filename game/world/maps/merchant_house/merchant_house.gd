class_name MerchantHouse
extends Node3D

signal map_transition_requested(
	destination_map_id: StringName,
	destination_spawn_id: StringName,
	actor: CharacterBody3D
)
signal facility_action_requested(action_id: StringName, actor: CharacterBody3D)

@onready var exit_door: BuildingDoor = $ExitDoor
@onready var facilities: Node3D = $Facilities


func _ready() -> void:
	exit_door.transition_requested.connect(_on_door_transition_requested)
	for child: Node in facilities.get_children():
		var facility := child as FacilityInteractable
		if facility != null:
			facility.action_requested.connect(_on_facility_action_requested)


func get_map_id() -> StringName:
	return &"merchant_house"


func get_location_name() -> String:
	return "Casa del Viandante"


func get_spawn_position(_spawn_id: StringName = &"default") -> Vector3:
	return Vector3(0, 1.15, 5.2)


func get_interactables() -> Array[InteractableArea3D]:
	var result: Array[InteractableArea3D] = []
	result.append(exit_door.interaction_area)
	for child: Node in facilities.get_children():
		var facility := child as FacilityInteractable
		if facility != null:
			result.append(facility.interaction_area)
	return result


func _on_door_transition_requested(
	_door: BuildingDoor,
	destination_map_id: StringName,
	destination_spawn_id: StringName,
	actor: CharacterBody3D
) -> void:
	map_transition_requested.emit(destination_map_id, destination_spawn_id, actor)


func _on_facility_action_requested(
	action_id: StringName,
	actor: CharacterBody3D
) -> void:
	facility_action_requested.emit(action_id, actor)
