class_name ItemDefinition
extends Resource

@export var item_id: StringName = &""
@export var display_name: String = "Oggetto"
@export var category: StringName = &"object"
@export_range(1, 999, 1) var max_quantity: int = 10
