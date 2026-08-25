class_name DevTestHubPortal
extends Node3D

signal transition_requested(
	portal: DevTestHubPortal,
	destination_map_id: StringName,
	destination_spawn_id: StringName,
	actor: CharacterBody3D
)

@export var destination_map_id: StringName = &"test_hub"
@export var destination_spawn_id: StringName = &"default"

@onready var interaction_area: InteractableArea3D = $InteractionArea
@onready var warning_label: Label3D = $WarningLabel
@onready var beacon: MeshInstance3D = $Beacon

var _request_pending: bool = false


func _ready() -> void:
	interaction_area.interaction_id = &"dev_test_hub_portal"
	interaction_area.display_name = "DEV Test Hub Portal"
	interaction_area.max_generated_items = 0
	interaction_area.item_generation_probability = 0.0
	warning_label.text = "⚠ DEV ONLY — TEST HUB PORTAL\nNOT PART OF THE GAME"
	if not interaction_area.interacted.is_connected(_on_interacted):
		interaction_area.interacted.connect(_on_interacted)


func _process(delta: float) -> void:
	beacon.rotation.y = wrapf(beacon.rotation.y + delta * 1.4, 0.0, TAU)


func reset_request() -> void:
	_request_pending = false


func _on_interacted(interactor: Node3D) -> void:
	var actor := interactor as CharacterBody3D
	if actor == null or _request_pending or destination_map_id.is_empty():
		return
	_request_pending = true
	transition_requested.emit(
		self,
		destination_map_id,
		destination_spawn_id,
		actor
	)
	call_deferred("reset_request")
