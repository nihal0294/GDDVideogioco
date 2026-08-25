class_name TestHub
extends Node3D

signal map_transition_requested(
	destination_map_id: StringName,
	destination_spawn_id: StringName,
	actor: CharacterBody3D
)

const SPAWN_POSITION := Vector3(0.0, 1.15, -40.0)

@onready var buildings: Node3D = $Buildings
@onready var info_toast: NotificationToast = $InfoToast


func _ready() -> void:
	for child: Node in buildings.get_children():
		var building := child as TestBuildingShell
		if building == null:
			continue
		if not building.map_transition_requested.is_connected(
			_on_building_transition_requested
		):
			building.map_transition_requested.connect(_on_building_transition_requested)
		if not building.info_requested.is_connected(_on_building_info_requested):
			building.info_requested.connect(_on_building_info_requested)


func get_map_id() -> StringName:
	return &"test_hub"


func get_location_name() -> String:
	return "Test Hub"


func get_spawn_position(spawn_id: StringName = &"default") -> Vector3:
	if spawn_id == &"from_battle":
		return Vector3(-4.0, 1.15, -28.0)
	if spawn_id == &"from_astrals_roster":
		return Vector3(-4.0, 1.15, -14.0)
	return SPAWN_POSITION


func _on_building_transition_requested(
	destination_map_id: StringName,
	destination_spawn_id: StringName,
	actor: CharacterBody3D
) -> void:
	map_transition_requested.emit(destination_map_id, destination_spawn_id, actor)


func _on_building_info_requested(text: String) -> void:
	info_toast.show_message(text)
