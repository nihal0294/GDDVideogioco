class_name InteractableArea3D
extends Area3D

signal focus_changed(is_focused: bool)
signal interacted(interactor: Node3D)

@export var interaction_id: StringName = &""
@export var display_name: String = "Oggetto"
@export var category: StringName = &"object"
@export_range(0.1, 10.0, 0.05) var interaction_radius: float = 1.25

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var is_focused: bool = false


func _ready() -> void:
	var sphere_shape := collision_shape.shape.duplicate() as SphereShape3D
	if sphere_shape == null:
		push_error("Il trigger interagibile richiede una SphereShape3D.")
		return
	sphere_shape.radius = interaction_radius
	collision_shape.shape = sphere_shape


func get_interaction_prompt() -> String:
	return "Interagisci con %s" % display_name


func set_focused(value: bool) -> void:
	if is_focused == value:
		return
	is_focused = value
	focus_changed.emit(is_focused)


func interact(interactor: Node3D) -> void:
	interacted.emit(interactor)
