class_name TestBuildingShell
extends Node3D

enum SystemStatus {
	PLACEHOLDER,
	IMPLEMENTED,
	WORK_IN_PROGRESS,
	NOT_IMPLEMENTED,
}

signal map_transition_requested(
	destination_map_id: StringName,
	destination_spawn_id: StringName,
	actor: CharacterBody3D
)
signal info_requested(text: String)

@export var building_id: StringName = &"test_building"
@export var display_name: String = "Building":
	set(value):
		display_name = value
		_refresh_signs()
@export var feature_summary: String = "features features features":
	set(value):
		feature_summary = value
		_refresh_signs()
@export var status: SystemStatus = SystemStatus.PLACEHOLDER:
	set(value):
		status = value
		_refresh_signs()
@export var interior_map_id: StringName = &""
@export var interior_spawn_id: StringName = &"default"

@onready var shell_mesh: MeshInstance3D = $Shell
@onready var name_sign: Label3D = $NameSign
@onready var door: BuildingDoor = $Door


func _ready() -> void:
	door.door_id = StringName("%s_door" % building_id)
	door.display_name = display_name
	door.destination_map_id = interior_map_id
	door.destination_spawn_id = interior_spawn_id
	if not door.transition_requested.is_connected(_on_door_transition_requested):
		door.transition_requested.connect(_on_door_transition_requested)
	if not door.interaction_area.interacted.is_connected(_on_door_interacted):
		door.interaction_area.interacted.connect(_on_door_interacted)
	_refresh_signs()


func _refresh_signs() -> void:
	if name_sign == null or shell_mesh == null:
		return
	name_sign.text = display_name.to_upper()
	var material := StandardMaterial3D.new()
	material.albedo_color = _status_color(status)
	material.roughness = 0.85
	shell_mesh.material_override = material


func _on_door_interacted(_interactor: Node3D) -> void:
	if not interior_map_id.is_empty():
		return
	info_requested.emit("%s\n\n%s" % [feature_summary, _status_label(status)])


func _status_label(value: SystemStatus) -> String:
	match value:
		SystemStatus.IMPLEMENTED:
			return "IMPLEMENTED"
		SystemStatus.WORK_IN_PROGRESS:
			return "WORK IN PROGRESS"
		SystemStatus.NOT_IMPLEMENTED:
			return "SYSTEM NOT IMPLEMENTED"
		_:
			return "PLACEHOLDER - SYSTEM NOT YET ASSIGNED"


func _status_color(value: SystemStatus) -> Color:
	match value:
		SystemStatus.IMPLEMENTED:
			return Color(0.3, 0.72, 0.38)
		SystemStatus.WORK_IN_PROGRESS:
			return Color(0.86, 0.65, 0.16)
		SystemStatus.NOT_IMPLEMENTED:
			return Color(0.45, 0.46, 0.5)
		_:
			return Color(0.55, 0.62, 0.7)


func _on_door_transition_requested(
	_door: BuildingDoor,
	destination_map_id: StringName,
	destination_spawn_id: StringName,
	actor: CharacterBody3D
) -> void:
	map_transition_requested.emit(destination_map_id, destination_spawn_id, actor)
