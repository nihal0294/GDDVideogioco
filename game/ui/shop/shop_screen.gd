class_name ShopScreen
extends Control

signal close_requested()
signal notification_requested(message: String)

@onready var currency_label: Label = %CurrencyLabel
@onready var mode_button: Button = %ModeButton
@onready var item_list: ItemList = %ItemList
@onready var description_label: Label = %DescriptionLabel
@onready var action_button: Button = %ActionButton

var _inventory: Inventory = null
var _profile: PlayerProfile = null
var _economy: PlayerEconomyService = null
var _selling: bool = false


func _ready() -> void:
	mode_button.pressed.connect(_toggle_mode)
	item_list.item_selected.connect(func(_index: int) -> void: _refresh_details())
	action_button.pressed.connect(_on_action_pressed)
	%CloseButton.pressed.connect(func() -> void: close_requested.emit())


func setup(
	inventory: Inventory,
	profile: PlayerProfile,
	economy: PlayerEconomyService = null
) -> void:
	_disconnect_sources()
	_inventory = inventory
	_profile = profile
	_economy = economy
	if _economy == null:
		_economy = PlayerEconomyService.new()
		_economy.setup(_inventory, _profile)
	if _inventory != null:
		_inventory.item_quantity_changed.connect(_on_inventory_changed)
	if _profile != null:
		_profile.florins_changed.connect(_on_florins_changed)
	_refresh()


func open() -> void:
	_selling = false
	show()
	_refresh()
	item_list.grab_focus()


func close() -> void:
	hide()


func _toggle_mode() -> void:
	_selling = not _selling
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var selected_id := _get_selected_item_id()
	item_list.clear()
	mode_button.text = "Passa a Compra" if _selling else "Passa a Vendita"
	action_button.text = "Vendi" if _selling else "Compra"
	currency_label.text = "%d %s" % [
		_profile.florins if _profile != null else 0,
		_profile.currency_name if _profile != null else "Fiorini",
	]
	if _inventory != null:
		for item: ItemDefinition in _inventory.get_items_in_category(&"object"):
			if item.buy_price <= 0:
				continue
			var owned := _inventory.get_quantity(item.item_id)
			if _selling and owned <= 0:
				continue
			var price := item.get_sell_price() if _selling else item.buy_price
			var index := item_list.add_item("%s  ·  %d F  ·  posseduti %d" % [
				item.display_name, price, owned,
			])
			item_list.set_item_metadata(index, item.item_id)
			if item.item_id == selected_id:
				item_list.select(index)
	if item_list.item_count == 0:
		var empty_index := item_list.add_item(
			"Nessun oggetto da vendere" if _selling else "Catalogo vuoto"
		)
		item_list.set_item_disabled(empty_index, true)
	if item_list.get_selected_items().is_empty() and item_list.item_count > 0:
		if not item_list.is_item_disabled(0):
			item_list.select(0)
	_refresh_details()


func _refresh_details() -> void:
	var item := _get_selected_definition()
	action_button.disabled = item == null
	if item == null:
		description_label.text = "Seleziona un oggetto."
		return
	var price := item.get_sell_price() if _selling else item.buy_price
	description_label.text = "%s\nPrezzo: %d Fiorini. Quantità: %d/%d." % [
		item.description,
		price,
		_inventory.get_quantity(item.item_id),
		item.max_quantity,
	]


func _on_action_pressed() -> void:
	var item := _get_selected_definition()
	if item == null or _economy == null:
		return
	var result := (
		_economy.request_sale(item.item_id)
		if _selling
		else _economy.request_purchase(item.item_id)
	)
	_show_operation_result(result, item)
	_refresh()


func _show_operation_result(result: Dictionary, item: ItemDefinition) -> void:
	var code := StringName(result.get("code", &"mutation_failed"))
	var price := int(result.get("price", 0))
	match code:
		PlayerEconomyService.OK:
			notification_requested.emit(
				"Hai venduto %s per %d Fiorini." % [item.display_name, price]
				if _selling
				else "Hai acquistato %s." % item.display_name
			)
		PlayerEconomyService.INVENTORY_FULL:
			notification_requested.emit("Non hai spazio per %s." % item.display_name)
		PlayerEconomyService.NOT_ENOUGH_CURRENCY:
			notification_requested.emit("Non hai abbastanza Fiorini.")
		PlayerEconomyService.CURRENCY_FULL:
			notification_requested.emit("Non puoi portare altri Fiorini.")
		PlayerEconomyService.NOT_AUTHORITY:
			notification_requested.emit("L'azione deve essere convalidata dall'autorita di gioco.")
		PlayerEconomyService.NOT_OWNED:
			notification_requested.emit("Non possiedi piu questo oggetto.")
		_:
			notification_requested.emit("L'operazione non e stata completata.")


func _get_selected_definition() -> ItemDefinition:
	var item_id := _get_selected_item_id()
	return (
		_inventory.get_item_definition(item_id)
		if _inventory != null and not item_id.is_empty()
		else null
	) as ItemDefinition


func _get_selected_item_id() -> StringName:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return &""
	var metadata: Variant = item_list.get_item_metadata(selected[0])
	return StringName(metadata) if metadata != null else &""


func _on_inventory_changed(_item: ItemDefinition, _quantity: int) -> void:
	_refresh()


func _on_florins_changed(_amount: int) -> void:
	_refresh()


func _disconnect_sources() -> void:
	if _inventory != null and _inventory.item_quantity_changed.is_connected(_on_inventory_changed):
		_inventory.item_quantity_changed.disconnect(_on_inventory_changed)
	if _profile != null and _profile.florins_changed.is_connected(_on_florins_changed):
		_profile.florins_changed.disconnect(_on_florins_changed)
