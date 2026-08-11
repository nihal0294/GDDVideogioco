class_name GameUI
extends CanvasLayer

@onready var pause_menu: PauseMenu = $PauseMenu
@onready var inventory_screen: InventoryScreen = $InventoryScreen


func setup(inventory: Inventory) -> void:
	inventory_screen.setup(inventory)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_menu"):
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()


func _toggle_pause_menu() -> void:
	if pause_menu.visible:
		pause_menu.close()
	else:
		inventory_screen.close()
		pause_menu.open()
	_sync_pause_state()


func _toggle_inventory() -> void:
	if inventory_screen.visible:
		inventory_screen.close()
	else:
		pause_menu.close()
		inventory_screen.open()
	_sync_pause_state()


func _sync_pause_state() -> void:
	get_tree().paused = pause_menu.visible or inventory_screen.visible
