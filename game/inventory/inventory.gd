class_name Inventory
extends Node

signal item_quantity_changed(item: ItemDefinition, quantity: int)
signal item_capacity_reached(item: ItemDefinition)
signal item_consumed(item: ItemDefinition)
signal item_discarded(item: ItemDefinition, quantity: int)

const ITEM_DEFINITION_PATHS: Array[String] = [
	"res://data/items/cocco.tres",
	"res://data/items/stoffa.tres",
	"res://data/items/legno.tres",
	"res://data/items/pietra.tres",
	"res://data/items/fungo.tres",
	"res://data/items/bacca.tres",
]

var _definitions: Dictionary[StringName, ItemDefinition] = {}
var _quantities: Dictionary[StringName, int] = {}


func _ready() -> void:
	for definition_path in ITEM_DEFINITION_PATHS:
		var definition := load(definition_path) as ItemDefinition
		if definition == null:
			push_error("Definizione inventario non valida: %s" % definition_path)
			continue
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


func can_add_item(item_id: StringName) -> bool:
	var definition := get_item_definition(item_id)
	if definition == null:
		return false
	return get_quantity(item_id) < definition.max_quantity


func consume_item(item_id: StringName) -> bool:
	var definition := get_item_definition(item_id)
	if definition == null or not definition.consumable:
		return false
	if _remove_item(item_id, 1) != 1:
		return false
	item_consumed.emit(definition)
	return true


func discard_item(item_id: StringName, amount: int = 1) -> int:
	var definition := get_item_definition(item_id)
	if definition == null:
		return 0
	var removed_quantity := _remove_item(item_id, amount)
	if removed_quantity > 0:
		item_discarded.emit(definition, removed_quantity)
	return removed_quantity


func get_quantity(item_id: StringName) -> int:
	return _quantities.get(item_id, 0)


func get_item_definition(item_id: StringName) -> ItemDefinition:
	return _definitions.get(item_id) as ItemDefinition


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


func _remove_item(item_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var definition := get_item_definition(item_id)
	if definition == null:
		return 0
	var current_quantity := get_quantity(item_id)
	var removed_quantity := mini(amount, current_quantity)
	if removed_quantity <= 0:
		return 0
	var new_quantity := current_quantity - removed_quantity
	_quantities[item_id] = new_quantity
	item_quantity_changed.emit(definition, new_quantity)
	return removed_quantity
