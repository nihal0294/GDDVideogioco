class_name AstralDefinition
extends Resource

@export var astral_id: StringName = &""
@export var display_name: String = "Astral"
@export_multiline var description: String = ""
@export_range(1, 9999, 1) var max_health: int = 10
@export_range(1, 999, 1) var attack_power: int = 2
@export_range(1, 999, 1) var speed: int = 5
@export var primary_element: StringName = &"neutro"
@export var secondary_element: StringName = &""
@export_range(0, 99999, 1) var experience_yield: int = 25
@export var starting_moves: Array[AstralMoveDefinition] = []
@export var visual_color: Color = Color(0.45, 0.75, 1.0, 1.0)


func get_elements() -> Array[StringName]:
	var elements: Array[StringName] = []
	if not primary_element.is_empty():
		elements.append(primary_element)
	if (
		not secondary_element.is_empty()
		and secondary_element != primary_element
	):
		elements.append(secondary_element)
	return elements


func has_element(element_id: StringName) -> bool:
	if element_id.is_empty():
		return false
	return (
		primary_element == element_id
		or secondary_element == element_id
	)
