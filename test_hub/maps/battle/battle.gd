class_name TestHubBattleRoom
extends Node3D

signal map_transition_requested(
	destination_map_id: StringName,
	destination_spawn_id: StringName,
	actor: CharacterBody3D
)
signal facility_action_requested(action_id: StringName, actor: CharacterBody3D)
signal test_battle_start_requested(
	enemy_definition: AstralDefinition,
	enemy_level: int,
	actor: CharacterBody3D
)

@onready var exit_door: BuildingDoor = $ExitDoor
@onready var facilities: Node3D = $Facilities
@onready var enemy_picker: AstralPickerScreen = $EnemyPickerScreen
@onready var info_toast: NotificationToast = $InfoToast

var _selected_enemy_definition: AstralDefinition = null
var _selected_enemy_level: int = 5


func _ready() -> void:
	exit_door.transition_requested.connect(_on_door_transition_requested)
	for child: Node in facilities.get_children():
		var facility := child as FacilityInteractable
		if facility != null:
			facility.action_requested.connect(_on_facility_action_requested)
	enemy_picker.astral_selected.connect(_on_enemy_selected)


func get_map_id() -> StringName:
	return &"test_hub_battle"


func get_location_name() -> String:
	return "Battle Testing"


func get_spawn_position(_spawn_id: StringName = &"default") -> Vector3:
	return Vector3(0, 1.15, 5.2)


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
	match action_id:
		&"battle_choose_enemy":
			enemy_picker.open()
		&"battle_start":
			if _selected_enemy_definition == null:
				info_toast.show_message("Choose an enemy first (Enemy box).")
				return
			test_battle_start_requested.emit(
				_selected_enemy_definition,
				_selected_enemy_level,
				actor
			)
		_:
			facility_action_requested.emit(action_id, actor)


func _on_enemy_selected(definition: AstralDefinition, level: int) -> void:
	_selected_enemy_definition = definition
	_selected_enemy_level = level
	info_toast.show_message(
		"Test enemy: %s (Lv. %d)" % [definition.display_name, level]
	)
