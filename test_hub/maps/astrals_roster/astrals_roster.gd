class_name TestHubAstralsRosterRoom
extends Node3D

signal map_transition_requested(
	destination_map_id: StringName,
	destination_spawn_id: StringName,
	actor: CharacterBody3D
)
signal facility_action_requested(action_id: StringName, actor: CharacterBody3D)
signal test_astral_gift_requested(
	definition: AstralDefinition,
	level: int,
	actor: CharacterBody3D
)

@onready var exit_door: BuildingDoor = $ExitDoor
@onready var facilities: Node3D = $Facilities
@onready var astral_picker: AstralPickerScreen = $AstralPickerScreen
@onready var info_toast: NotificationToast = $InfoToast

var _pending_gift_actor: CharacterBody3D = null


func _ready() -> void:
	exit_door.transition_requested.connect(_on_door_transition_requested)
	for child: Node in facilities.get_children():
		var facility := child as FacilityInteractable
		if facility != null:
			facility.action_requested.connect(_on_facility_action_requested)
	astral_picker.astral_selected.connect(_on_astral_selected)


func get_map_id() -> StringName:
	return &"test_hub_astrals_roster"


func get_location_name() -> String:
	return "Astrals / Roster Testing"


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
		&"give_test_astral":
			_pending_gift_actor = actor
			astral_picker.open()
		_:
			facility_action_requested.emit(action_id, actor)


func _on_astral_selected(definition: AstralDefinition, level: int) -> void:
	if _pending_gift_actor == null:
		return
	test_astral_gift_requested.emit(definition, level, _pending_gift_actor)
	_pending_gift_actor = null
	info_toast.show_message(
		"Requested test Astral: %s (Lv. %d)" % [definition.display_name, level]
	)
