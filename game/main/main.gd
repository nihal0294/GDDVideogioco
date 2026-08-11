extends Node3D

const DROPS_BY_CATEGORY: Dictionary[StringName, StringName] = {
	&"palm": &"cocco",
	&"tent": &"stoffa",
}

@onready var island: Node = $Island
@onready var inventory: Inventory = $Inventory
@onready var game_ui: GameUI = $GameUI


func _ready() -> void:
	island.connect("map_object_interacted", _on_map_object_interacted)
	game_ui.setup(inventory)


func _on_map_object_interacted(
	_object_id: StringName,
	category: StringName,
	_interactor: Node3D
) -> void:
	var item_id: StringName = DROPS_BY_CATEGORY.get(category, &"")
	if item_id.is_empty():
		return
	inventory.add_item(item_id)
