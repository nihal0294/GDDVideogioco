class_name InventoryScreen
extends Control

@onready var categories: TabContainer = %Categories
@onready var objects_list: ItemList = %ObjectsList

var inventory: Inventory = null


func setup(source_inventory: Inventory) -> void:
	if inventory != null and inventory.item_quantity_changed.is_connected(
		_on_item_quantity_changed
	):
		inventory.item_quantity_changed.disconnect(_on_item_quantity_changed)

	inventory = source_inventory
	if inventory != null:
		inventory.item_quantity_changed.connect(_on_item_quantity_changed)
	_refresh_objects()


func open() -> void:
	show()
	categories.current_tab = 0
	objects_list.grab_focus()


func close() -> void:
	hide()


func _on_item_quantity_changed(_item: ItemDefinition, _quantity: int) -> void:
	_refresh_objects()


func _refresh_objects() -> void:
	objects_list.clear()
	if inventory == null:
		_add_empty_placeholder()
		return

	var visible_item_count: int = 0
	for item in inventory.get_items_in_category(&"object"):
		var quantity := inventory.get_quantity(item.item_id)
		if quantity <= 0:
			continue
		var item_index := objects_list.add_item(
			"%s    %d/%d" % [item.display_name, quantity, item.max_quantity]
		)
		objects_list.set_item_metadata(item_index, item.item_id)
		visible_item_count += 1

	if visible_item_count == 0:
		_add_empty_placeholder()


func _add_empty_placeholder() -> void:
	var item_index := objects_list.add_item("Nessun oggetto raccolto")
	objects_list.set_item_disabled(item_index, true)
