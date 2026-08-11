class_name InventoryScreen
extends Control

signal notification_requested(message: String)

@onready var categories: TabContainer = %Categories
@onready var objects_list: ItemList = %ObjectsList
@onready var item_description: Label = %ItemDescription
@onready var consume_button: Button = %ConsumeButton
@onready var discard_button: Button = %DiscardButton

var inventory: Inventory = null


func _ready() -> void:
	objects_list.item_selected.connect(_on_object_selected)
	consume_button.pressed.connect(_on_consume_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	_update_action_buttons()


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
	var previously_selected_id := _get_selected_item_id()
	objects_list.clear()
	if inventory == null:
		_add_empty_placeholder()
		_update_action_buttons()
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
		objects_list.set_item_tooltip(item_index, item.description)
		if item.item_id == previously_selected_id:
			objects_list.select(item_index)
		visible_item_count += 1

	if visible_item_count == 0:
		_add_empty_placeholder()
	_update_action_buttons()


func _add_empty_placeholder() -> void:
	var item_index := objects_list.add_item("Nessun oggetto raccolto")
	objects_list.set_item_disabled(item_index, true)


func _on_object_selected(_item_index: int) -> void:
	_update_action_buttons()


func _on_consume_pressed() -> void:
	var item_id := _get_selected_item_id()
	if inventory == null or item_id.is_empty():
		return
	var item := inventory.get_item_definition(item_id)
	if item == null or not inventory.consume_item(item_id):
		notification_requested.emit("Questo oggetto non può essere consumato.")
		return
	notification_requested.emit("Hai consumato %s." % item.display_name)


func _on_discard_pressed() -> void:
	var item_id := _get_selected_item_id()
	if inventory == null or item_id.is_empty():
		return
	var item := inventory.get_item_definition(item_id)
	if item == null or inventory.discard_item(item_id) != 1:
		return
	notification_requested.emit("Hai buttato %s." % item.display_name)


func _get_selected_item_id() -> StringName:
	var selected_items := objects_list.get_selected_items()
	if selected_items.is_empty():
		return &""
	return StringName(objects_list.get_item_metadata(selected_items[0]))


func _update_action_buttons() -> void:
	var item_id := _get_selected_item_id()
	var item := (
		inventory.get_item_definition(item_id)
		if inventory != null and not item_id.is_empty()
		else null
	) as ItemDefinition
	discard_button.disabled = item == null
	consume_button.disabled = item == null or not item.consumable
	item_description.text = (
		item.description
		if item != null
		else "Seleziona un oggetto per leggerne la descrizione."
	)
