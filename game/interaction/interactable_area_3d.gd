class_name InteractableArea3D
extends Area3D

signal focus_changed(is_focused: bool)
signal interacted(interactor: Node3D)
signal item_stock_changed(remaining_quantity: int)

@export var interaction_id: StringName = &""
@export var display_name: String = "Oggetto"
@export var category: StringName = &"object"
@export_range(0.1, 10.0, 0.05) var interaction_radius: float = 1.25
@export_group("Generazione oggetti")
@export_range(0, 10, 1) var max_generated_items: int = 2
@export_range(0.0, 1.0, 0.01) var item_generation_probability: float = 0.5

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var is_focused: bool = false
var remaining_item_count: int = 0


func _ready() -> void:
	var sphere_shape := collision_shape.shape.duplicate() as SphereShape3D
	if sphere_shape == null:
		push_error("Il trigger interagibile richiede una SphereShape3D.")
		return
	sphere_shape.radius = interaction_radius
	collision_shape.shape = sphere_shape
	generate_item_stock()


func get_interaction_prompt() -> String:
	return "Interagisci con %s" % display_name


func set_focused(value: bool) -> void:
	if is_focused == value:
		return
	is_focused = value
	focus_changed.emit(is_focused)


func interact(interactor: Node3D) -> void:
	interacted.emit(interactor)


func generate_item_stock(random_number_generator: RandomNumberGenerator = null) -> void:
	remaining_item_count = 0
	for _item_index in range(max_generated_items):
		var random_value := (
			random_number_generator.randf()
			if random_number_generator != null
			else randf()
		)
		if random_value < item_generation_probability:
			remaining_item_count += 1
	item_stock_changed.emit(remaining_item_count)


func take_generated_item() -> bool:
	if remaining_item_count <= 0:
		return false
	remaining_item_count -= 1
	item_stock_changed.emit(remaining_item_count)
	return true


func set_remaining_item_count(value: int) -> void:
	remaining_item_count = clampi(value, 0, max_generated_items)
	item_stock_changed.emit(remaining_item_count)
