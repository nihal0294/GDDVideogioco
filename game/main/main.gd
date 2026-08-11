extends Node3D

const DROPS_BY_CATEGORY: Dictionary[StringName, StringName] = {
	&"palm": &"cocco",
	&"tent": &"stoffa",
	&"tree": &"legno",
	&"rock": &"pietra",
	&"mushroom": &"fungo",
	&"shrub": &"bacca",
}

@onready var world_map: Node3D = $WorldMap
@onready var player: CharacterBody3D = $Player
@onready var inventory: Inventory = $Inventory
@onready var game_ui: GameUI = $GameUI


func _ready() -> void:
	if world_map.has_signal("map_interactable_interacted"):
		world_map.connect(
			"map_interactable_interacted",
			_on_map_interactable_interacted
		)
	if world_map.has_method("get_spawn_position"):
		player.global_position = world_map.call("get_spawn_position")
	game_ui.setup(inventory)


func _on_map_interactable_interacted(
	interactable: InteractableArea3D,
	_interactor: Node3D
) -> void:
	var item_id: StringName = DROPS_BY_CATEGORY.get(interactable.category, &"")
	if item_id.is_empty():
		return

	var item := inventory.get_item_definition(item_id)
	if item == null:
		return
	if interactable.remaining_item_count <= 0:
		game_ui.show_notification(
			"%s non contiene più oggetti da raccogliere." % interactable.display_name
		)
		return
	if not inventory.can_add_item(item_id):
		game_ui.show_notification(
			"Inventario pieno: non hai più spazio per %s." % item.display_name
		)
		return
	if not interactable.take_generated_item():
		return

	inventory.add_item(item_id)
	var current_quantity := inventory.get_quantity(item_id)
	game_ui.show_notification(
		"Hai raccolto %s (%d/%d)." % [
			item.display_name,
			current_quantity,
			item.max_quantity,
		]
	)
	if current_quantity >= item.max_quantity:
		game_ui.show_notification(
			"Inventario pieno: non hai più spazio per %s." % item.display_name,
			true
		)
