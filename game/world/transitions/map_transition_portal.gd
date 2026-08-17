class_name MapTransitionPortal
extends Node3D

signal transition_requested(
	portal: MapTransitionPortal,
	destination_map_id: StringName,
	destination_spawn_id: StringName,
	actor: CharacterBody3D
)

@export var portal_id: StringName = &"map_portal"
@export var display_name: String = "Portale"
@export var destination_map_id: StringName = &""
@export var destination_spawn_id: StringName = &"default"
@export var enabled: bool = true

@onready var interaction_area: InteractableArea3D = $InteractionArea
@onready var destination_label: Label3D = $DestinationLabel
@onready var portal_disc: MeshInstance3D = $PortalDisc

var _request_pending: bool = false


func _ready() -> void:
	interaction_area.interaction_id = portal_id
	interaction_area.display_name = display_name
	interaction_area.max_generated_items = 0
	interaction_area.item_generation_probability = 0.0
	destination_label.text = display_name
	if not interaction_area.interacted.is_connected(_on_interacted):
		interaction_area.interacted.connect(_on_interacted)
	add_to_group(&"map_transition_portals")


func _process(delta: float) -> void:
	portal_disc.rotation.y = wrapf(portal_disc.rotation.y + delta * 0.7, 0.0, TAU)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_request_pending = false
	interaction_area.monitorable = enabled
	interaction_area.collision_layer = 4 if enabled else 0
	destination_label.modulate.a = 1.0 if enabled else 0.45


func reset_request() -> void:
	_request_pending = false


func _on_interacted(interactor: Node3D) -> void:
	var actor := interactor as CharacterBody3D
	if (
		actor == null
		or not enabled
		or _request_pending
		or destination_map_id.is_empty()
	):
		return
	_request_pending = true
	transition_requested.emit(
		self,
		destination_map_id,
		destination_spawn_id,
		actor
	)
	call_deferred("reset_request")
