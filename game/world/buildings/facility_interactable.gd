class_name FacilityInteractable
extends Node3D

signal action_requested(action_id: StringName, actor: CharacterBody3D)

enum VisualKind {
	NPC,
	BOX,
	MACHINE,
}

@export var action_id: StringName = &"facility"
@export var display_name: String = "Servizio"
@export var visual_color: Color = Color(0.4, 0.65, 0.85)
@export var visual_kind: VisualKind = VisualKind.NPC
@onready var body_mesh: MeshInstance3D = $Body
@onready var label: Label3D = $Label
@onready var interaction_area: InteractableArea3D = $InteractionArea
@onready var solid_shape: CollisionShape3D = $SolidBody/CollisionShape3D


func _ready() -> void:
	_configure_visual_shape()
	label.text = display_name
	var material := StandardMaterial3D.new()
	material.albedo_color = visual_color
	material.roughness = 0.62
	body_mesh.material_override = material
	interaction_area.interaction_id = action_id
	interaction_area.display_name = display_name
	interaction_area.max_generated_items = 0
	interaction_area.item_generation_probability = 0.0
	interaction_area.interacted.connect(_on_interacted)


func _on_interacted(interactor: Node3D) -> void:
	var actor := interactor as CharacterBody3D
	if actor != null:
		action_requested.emit(action_id, actor)


func _configure_visual_shape() -> void:
	if visual_kind == VisualKind.NPC:
		return
	var box_mesh := BoxMesh.new()
	var box_shape := BoxShape3D.new()
	if visual_kind == VisualKind.BOX:
		box_mesh.size = Vector3(2.0, 1.1, 1.35)
		box_shape.size = box_mesh.size
		body_mesh.position.y = 0.55
		solid_shape.position.y = 0.55
	else:
		box_mesh.size = Vector3(1.35, 2.4, 1.0)
		box_shape.size = box_mesh.size
		body_mesh.position.y = 1.2
		solid_shape.position.y = 1.2
		label.position.y = 2.8
	body_mesh.mesh = box_mesh
	solid_shape.shape = box_shape
