class_name ItemDefinition
extends Resource

@export var item_id: StringName = &""
@export var display_name: String = "Oggetto"
@export_multiline var description: String = ""
@export var category: StringName = &"object"
@export_range(1, 999, 1) var max_quantity: int = 10
@export_range(0, 999999, 1) var buy_price: int = 0
@export var consumable: bool = false
@export var requires_astral_target: bool = false


func get_sell_price() -> int:
	return maxi(buy_price / 10, 1) if buy_price > 0 else 0
