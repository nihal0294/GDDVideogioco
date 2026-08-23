class_name PlayerEconomyService
extends RefCounted

const OK: StringName = &"ok"
const NOT_AUTHORITY: StringName = &"not_authority"
const INVALID_ITEM: StringName = &"invalid_item"
const INVENTORY_FULL: StringName = &"inventory_full"
const NOT_ENOUGH_CURRENCY: StringName = &"not_enough_currency"
const CURRENCY_FULL: StringName = &"currency_full"
const NOT_OWNED: StringName = &"not_owned"
const MUTATION_FAILED: StringName = &"mutation_failed"
const INVALID_WAGER: StringName = &"invalid_wager"
const COIN_FLIP_WAGERS: Array[int] = [10, 50, 100]

var _inventory: Inventory = null
var _profile: PlayerProfile = null
var _authority_enabled: bool = true
var _random := RandomNumberGenerator.new()


func _init() -> void:
	_random.randomize()


func setup(inventory: Inventory, profile: PlayerProfile) -> void:
	_inventory = inventory
	_profile = profile


func set_authority_enabled(enabled: bool) -> void:
	_authority_enabled = enabled


func request_purchase(item_id: StringName) -> Dictionary:
	if not _authority_enabled:
		return _result(NOT_AUTHORITY)
	var item := _get_item(item_id)
	if item == null or item.buy_price <= 0:
		return _result(INVALID_ITEM)
	if not _inventory.can_add_item(item_id):
		return _result(INVENTORY_FULL, item)
	if not _profile.spend_florins(item.buy_price):
		return _result(NOT_ENOUGH_CURRENCY, item, item.buy_price)
	if _inventory.add_item(item_id, 1) != 1:
		_profile.add_florins(item.buy_price)
		return _result(MUTATION_FAILED, item, item.buy_price)
	return _result(OK, item, item.buy_price)


func request_sale(item_id: StringName) -> Dictionary:
	if not _authority_enabled:
		return _result(NOT_AUTHORITY)
	var item := _get_item(item_id)
	if item == null or item.buy_price <= 0:
		return _result(INVALID_ITEM)
	var price := item.get_sell_price()
	if _profile.florins > PlayerProfile.MAX_FLORINS - price:
		return _result(CURRENCY_FULL, item, price)
	if _inventory.spend_item(item_id, 1) != 1:
		return _result(NOT_OWNED, item, price)
	if not _profile.add_florins(price):
		_inventory.add_item(item_id, 1)
		return _result(MUTATION_FAILED, item, price)
	return _result(OK, item, price)


func request_coin_flip(wager: int, chose_heads: bool) -> Dictionary:
	if not _authority_enabled:
		return {"success": false, "code": NOT_AUTHORITY}
	if not COIN_FLIP_WAGERS.has(wager):
		return {"success": false, "code": INVALID_WAGER}
	if _profile == null or not _profile.spend_florins(wager):
		return {"success": false, "code": NOT_ENOUGH_CURRENCY}
	var balance_after_wager := _profile.florins
	var landed_heads := _random.randi_range(0, 1) == 0
	var won := landed_heads == chose_heads
	var payout := wager * 2 if won else 0
	if payout > 0:
		_profile.add_florins(payout)
	return {
		"success": true,
		"code": OK,
		"landed_heads": landed_heads,
		"won": won,
		"payout": payout,
		"wager": wager,
		"balance_after_wager": balance_after_wager,
	}


func set_random_seed(seed_value: int) -> void:
	_random.seed = seed_value


func _get_item(item_id: StringName) -> ItemDefinition:
	if _inventory == null or _profile == null or item_id.is_empty():
		return null
	return _inventory.get_item_definition(item_id)


func _result(
	code: StringName,
	item: ItemDefinition = null,
	price: int = 0
) -> Dictionary:
	return {
		"success": code == OK,
		"code": code,
		"item_id": String(item.item_id) if item != null else "",
		"price": price,
	}
