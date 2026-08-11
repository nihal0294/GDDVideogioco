class_name Inventory
extends Node

signal item_quantity_changed(item: ItemDefinition, quantity: int)
signal item_capacity_reached(item: ItemDefinition)

const ITEM_DEFINITIONS: Array[ItemDefinition] = [
	preload("res://data/items/cocco.tres"),
	preload("res://data/items/stoffa.tres"),
]

var _definitions: Dictionary[StringName, ItemDefinition] = {}
var _quantities: Dictionary[StringName, int] = {}


func _ready() -> void:
	for definition in ITEM_DEFINITIONS:
		if definition.item_id.is_empty():
			push_error("Definizione inventario senza item_id.")
			continue
		if _definitions.has(definition.item_id):
			push_error("item_id duplicato nell'inventario: %s" % definition.item_id)
			continue
		_definitions[definition.item_id] = definition
		_quantities[definition.item_id] = 0


func add_item(item_id: StringName, amount: int = 1) -> int:
	if amount <= 0:
		return 0

	var definition := _definitions.get(item_id) as ItemDefinition
	if definition == null:
		push_warning("Oggetto inventario sconosciuto: %s" % item_id)
		return 0

	var current_quantity: int = _quantities.get(item_id, 0)
	var added_quantity: int = mini(amount, definition.max_quantity - current_quantity)
	if added_quantity <= 0:
		item_capacity_reached.emit(definition)
		return 0

	var new_quantity := current_quantity + added_quantity
	_quantities[item_id] = new_quantity
	item_quantity_changed.emit(definition, new_quantity)
	if added_quantity < amount:
		item_capacity_reached.emit(definition)
	return added_quantity


func get_quantity(item_id: StringName) -> int:
	return _quantities.get(item_id, 0)


func get_items_in_category(category: StringName) -> Array[ItemDefinition]:
	var matching_items: Array[ItemDefinition] = []
	for definition in _definitions.values():
		if definition.category == category:
			matching_items.append(definition)
	matching_items.sort_custom(
		func(first: ItemDefinition, second: ItemDefinition) -> bool:
			return first.display_name < second.display_name
	)
	return matching_items
