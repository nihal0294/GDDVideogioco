extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://game/main/main.tscn")
const FALL_FRAMES: int = 180

var failed: bool = false
var interacted_object_id: StringName = &""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)

	var player := main.get_node_or_null("Player") as CharacterBody3D
	var island_collision := main.get_node_or_null(
		"Island/CollisionShape3D"
	) as CollisionShape3D
	var island_mesh := main.get_node_or_null("Island/MapMesh") as MeshInstance3D
	var interactables := main.get_node_or_null("Island/Interactables") as Node3D
	var player_body := main.get_node_or_null("Player/Visual/Body") as MeshInstance3D
	var interaction_detector := main.get_node_or_null(
		"Player/InteractionDetector"
	) as PlayerInteractionDetector
	var inventory := main.get_node_or_null("Inventory") as Inventory
	var game_ui := main.get_node_or_null("GameUI") as GameUI
	var pause_menu := main.get_node_or_null("GameUI/PauseMenu") as PauseMenu
	var inventory_screen := main.get_node_or_null(
		"GameUI/InventoryScreen"
	) as InventoryScreen
	var sun := main.get_node_or_null("Sun") as DirectionalLight3D

	_expect(player != null, "Player mancante dalla scena main.")
	_expect(
		island_collision != null and island_collision.shape is ConcavePolygonShape3D,
		"Collisione trimesh della mappa non generata."
	)
	_expect(sun != null and sun.shadow_enabled, "Ombre del sole non abilitate.")
	_expect(
		player_body != null and player_body.cast_shadow != 0,
		"Il corpo del player non proietta ombre."
	)
	_expect(_mesh_has_textured_surfaces(island_mesh), "Materiali della mappa incompleti.")
	_expect(_jump_uses_space(), "L'azione jump non è associata al tasto Space.")
	_expect(
		_interactables_are_configured(interactables),
		"I 21 trigger della mappa non sono configurati correttamente."
	)
	_expect(
		_interact_uses_keyboard_and_gamepad(),
		"L'azione interact non è associata a E e al gamepad."
	)
	_expect(interaction_detector != null, "Detector di interazione del player mancante.")
	_expect(inventory != null, "Inventario runtime mancante.")
	_expect(game_ui != null, "Controller UI mancante.")
	_expect(_ui_actions_use_expected_keys(), "Binding Esc/Tab della UI non corretti.")

	if player == null:
		_finish(main)
		return

	for _frame in range(FALL_FRAMES):
		await physics_frame

	_expect(player.is_on_floor(), "Il player non atterra sulla mappa.")
	var landed_height := player.global_position.y

	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")

	_expect(
		player.velocity.y > 0.0 and player.global_position.y > landed_height,
		"Il salto da terra non applica una velocità verticale positiva."
	)

	if interaction_detector != null and interactables != null:
		var first_interactable := interactables.get_child(0) as InteractableArea3D
		main.get_node("Island").connect(
			"map_object_interacted",
			_on_map_object_interacted
		)
		player.global_position = (
			first_interactable.global_position - interaction_detector.position
		)
		player.velocity = Vector3.ZERO
		for _frame in range(3):
			await physics_frame

		_expect(
			interaction_detector.current_target != null,
			"Il player non rileva il trigger vicino."
		)
		if interaction_detector.current_target != null:
			var expected_id := interaction_detector.current_target.interaction_id
			_expect(
				interaction_detector.try_interact(),
				"Il metodo di interazione non viene eseguito."
			)
			_expect(
				interacted_object_id == expected_id,
				"Il segnale della mappa non inoltra l'oggetto interagito."
			)

			interacted_object_id = &""
			var press_event := InputEventAction.new()
			press_event.action = &"interact"
			press_event.pressed = true
			root.push_input(press_event)
			await process_frame
			var release_event := InputEventAction.new()
			release_event.action = &"interact"
			release_event.pressed = false
			root.push_input(release_event)
			_expect(
				interacted_object_id == expected_id,
				"L'input interact non richiama l'interazione corrente."
			)

			if inventory != null:
				_expect(
					inventory.get_quantity(&"cocco") == 2,
					"La palma non assegna cocco all'inventario."
				)
				for _attempt in range(12):
					first_interactable.interact(player)
				_expect(
					inventory.get_quantity(&"cocco") == 10,
					"Il cap di 10 cocchi non viene rispettato."
				)

				var tent := interactables.get_node("Tent01") as InteractableArea3D
				for _attempt in range(12):
					tent.interact(player)
				_expect(
					inventory.get_quantity(&"stoffa") == 10,
					"La tenda non assegna stoffa con cap 10."
				)

	if inventory_screen != null:
		var objects_list := inventory_screen.get_node("%ObjectsList") as ItemList
		_expect(
			_inventory_list_has_item(objects_list, &"cocco", 10),
			"Il cocco non appare nella categoria Oggetti."
		)
		_expect(
			_inventory_list_has_item(objects_list, &"stoffa", 10),
			"La stoffa non appare nella categoria Oggetti."
		)
		var categories := inventory_screen.get_node("%Categories") as TabContainer
		_expect(categories.get_tab_count() == 4, "Categorie inventario incomplete.")
		_expect(
			inventory_screen.anchor_right == 1.0 and inventory_screen.anchor_bottom == 1.0,
			"L'inventario non usa il layout a schermo intero."
		)

	if game_ui != null and pause_menu != null and inventory_screen != null:
		await _send_action(&"toggle_inventory")
		_expect(inventory_screen.visible, "Tab non apre l'inventario.")
		_expect(paused, "L'inventario aperto non sospende il gioco.")
		await _send_action(&"toggle_inventory")
		_expect(not inventory_screen.visible, "Tab non chiude l'inventario.")
		_expect(not paused, "Il gioco resta sospeso dopo la chiusura dell'inventario.")

		await _send_action(&"toggle_menu")
		_expect(pause_menu.visible, "Esc non apre il menu.")
		_expect(paused, "Il menu aperto non sospende il gioco.")
		_expect(_menu_buttons_are_unconnected(pause_menu), "I pulsanti menu hanno già azioni.")
		await _send_action(&"toggle_menu")
		_expect(not pause_menu.visible, "Esc non chiude il menu.")
		_expect(not paused, "Il gioco resta sospeso dopo la chiusura del menu.")
	_finish(main)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _mesh_has_textured_surfaces(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance == null or mesh_instance.mesh == null:
		return false
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material := mesh_instance.mesh.surface_get_material(surface_index) as BaseMaterial3D
		if material == null or material.albedo_texture == null:
			return false
	return true


func _jump_uses_space() -> bool:
	for event in InputMap.action_get_events("jump"):
		var key_event := event as InputEventKey
		if key_event != null and key_event.physical_keycode == KEY_SPACE:
			return true
	return false


func _interactables_are_configured(container: Node3D) -> bool:
	if container == null or container.get_child_count() != 21:
		return false
	var ids: Dictionary[StringName, bool] = {}
	for child in container.get_children():
		var interactable := child as InteractableArea3D
		if interactable == null or interactable.interaction_id.is_empty():
			return false
		if ids.has(interactable.interaction_id):
			return false
		ids[interactable.interaction_id] = true
		var shape := interactable.get_node("CollisionShape3D") as CollisionShape3D
		if shape == null or not shape.shape is SphereShape3D:
			return false
	return true


func _interact_uses_keyboard_and_gamepad() -> bool:
	var has_keyboard: bool = false
	var has_gamepad: bool = false
	for event in InputMap.action_get_events("interact"):
		var key_event := event as InputEventKey
		if key_event != null and key_event.physical_keycode == KEY_E:
			has_keyboard = true
		var joypad_event := event as InputEventJoypadButton
		if joypad_event != null and joypad_event.button_index == JOY_BUTTON_A:
			has_gamepad = true
	return has_keyboard and has_gamepad


func _ui_actions_use_expected_keys() -> bool:
	return (
		_action_uses_key(&"toggle_menu", KEY_ESCAPE)
		and _action_uses_key(&"toggle_inventory", KEY_TAB)
	)


func _action_uses_key(action: StringName, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event != null and key_event.physical_keycode == key:
			return true
	return false


func _inventory_list_has_item(
	item_list: ItemList,
	item_id: StringName,
	expected_quantity: int
) -> bool:
	if item_list == null:
		return false
	for item_index in range(item_list.item_count):
		if item_list.get_item_metadata(item_index) != item_id:
			continue
		return ("%d/10" % expected_quantity) in item_list.get_item_text(item_index)
	return false


func _menu_buttons_are_unconnected(menu: PauseMenu) -> bool:
	for button_name in [&"OptionsButton", &"SaveButton", &"ExitButton"]:
		var button := menu.find_child(button_name) as Button
		if button == null or not button.pressed.get_connections().is_empty():
			return false
	return true


func _send_action(action: StringName) -> void:
	var press_event := InputEventAction.new()
	press_event.action = action
	press_event.pressed = true
	root.push_input(press_event)
	await process_frame
	var release_event := InputEventAction.new()
	release_event.action = action
	release_event.pressed = false
	root.push_input(release_event)
	await process_frame


func _on_map_object_interacted(
	object_id: StringName,
	_category: StringName,
	_interactor: Node3D
) -> void:
	interacted_object_id = object_id


func _finish(main: Node) -> void:
	main.queue_free()
	if failed:
		quit(1)
	else:
		print("Main scene smoke test: OK")
		quit(0)
