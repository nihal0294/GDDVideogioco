extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://game/main/main.tscn")
const FALL_FRAMES := 180

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)

	var world_map := main.get_node_or_null("WorldMap") as VerdantValley
	var terrain := main.get_node_or_null("WorldMap/GeneratedTerrain") as Node3D
	var vegetation := main.get_node_or_null("WorldMap/Vegetation") as Node3D
	var prop_collisions := main.get_node_or_null(
		"WorldMap/PropCollisions"
	) as StaticBody3D
	var boundary_collisions := main.get_node_or_null(
		"WorldMap/BoundaryVegetationCollisions"
	) as StaticBody3D
	var interactables: Array[InteractableArea3D] = []
	if world_map != null:
		interactables = world_map.get_interactables()
	var player := main.get_node_or_null("Player") as CharacterBody3D
	var player_body := main.get_node_or_null("Player/Visual/Body") as MeshInstance3D
	var camera_rig := main.get_node_or_null("Player/CameraRig") as SpringArm3D
	var interaction_detector := main.get_node_or_null(
		"Player/InteractionDetector"
	) as PlayerInteractionDetector
	var inventory := main.get_node_or_null("Inventory") as Inventory
	var game_ui := main.get_node_or_null("GameUI") as GameUI
	var pause_menu := main.get_node_or_null("GameUI/PauseMenu") as PauseMenu
	var inventory_screen := main.get_node_or_null(
		"GameUI/InventoryScreen"
	) as InventoryScreen
	var notification_toast := main.get_node_or_null(
		"GameUI/NotificationToast"
	) as NotificationToast
	var sun := main.get_node_or_null("Sun") as DirectionalLight3D

	_expect(player != null, "Player mancante dalla scena main.")
	_expect(
		world_map != null
		and world_map.map_size.x >= 150.0
		and world_map.map_size.y >= 150.0,
		"VerdantValley non è la mappa iniziale 150x150."
	)
	_expect(
		main.get_node_or_null("LargeIsland") == null,
		"LargeIsland è ancora collegata alla scena Main."
	)
	_expect(
		ResourceLoader.exists(
			"res://game/world/maps/large_island/large_island.tscn",
			"PackedScene"
		),
		"La scena autonoma LargeIsland non è più disponibile."
	)
	_expect(
		_terrain_is_configured(world_map, terrain),
		"Terreno o collisioni di VerdantValley non sono configurati correttamente."
	)
	_expect(
		_nature_is_configured(world_map, vegetation),
		"Gli asset naturalistici non sono distribuiti tramite MultiMesh."
	)
	_expect(
		_prop_collisions_are_configured(world_map, prop_collisions),
		"Collisioni di alberi e rocce non configurate."
	)
	_expect(
		_boundary_vegetation_is_configured(main, boundary_collisions),
		"La vegetazione fisica di confine non sostituisce correttamente i muri."
	)
	_expect(
		_interactables_are_configured(world_map, interactables),
		"I trigger degli oggetti naturalistici non sono configurati correttamente."
	)
	_expect(
		_terrain_has_relief(world_map),
		"VerdantValley non presenta rilievi sufficienti."
	)
	_expect(sun != null and sun.shadow_enabled, "Ombre del sole non abilitate.")
	_expect(
		player_body != null and player_body.cast_shadow != 0,
		"Il corpo del player non proietta ombre."
	)
	_expect(
		_camera_is_behind_and_elevated(camera_rig),
		"La camera non è alle spalle con visuale diagonale dall'alto."
	)
	_expect(_jump_uses_space(), "L'azione jump non è associata al tasto Space.")
	_expect(
		_interact_uses_keyboard_and_gamepad(),
		"L'azione interact non è associata a E e al gamepad."
	)
	_expect(interaction_detector != null, "Detector di interazione del player mancante.")
	_expect(inventory != null, "Inventario runtime mancante.")
	_expect(
		_item_definitions_are_configured(),
		"Descrizioni o consumabilità degli oggetti non configurate correttamente."
	)
	_expect(game_ui != null, "Controller UI mancante.")
	_expect(notification_toast != null, "Riquadro notifiche mancante.")
	_expect(_ui_actions_use_expected_keys(), "Binding Esc/Tab della UI non corretti.")

	if player == null:
		_finish(main)
		return

	for _frame in range(FALL_FRAMES):
		await physics_frame

	_expect(player.is_on_floor(), "Il player non atterra su VerdantValley.")
	var landed_height := player.global_position.y
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	_expect(
		player.velocity.y > 0.0 and player.global_position.y > landed_height,
		"Il salto da terra non applica una velocità verticale positiva."
	)

	if inventory != null and not interactables.is_empty():
		_test_nature_drops(interactables, inventory, player)

	if inventory != null:
		for item_id in [&"cocco", &"stoffa", &"legno", &"pietra", &"fungo", &"bacca"]:
			inventory.add_item(item_id, 20)
			_expect(
				inventory.get_quantity(item_id) == 10,
				"Il cap di 10 non viene rispettato per %s." % item_id
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
		for item_id in [&"legno", &"pietra", &"fungo", &"bacca"]:
			_expect(
				_inventory_list_has_item(objects_list, item_id, 10),
				"%s non appare nella categoria Oggetti." % item_id
			)
		var categories := inventory_screen.get_node("%Categories") as TabContainer
		_expect(categories.get_tab_count() == 4, "Categorie inventario incomplete.")
		_expect(
			inventory_screen.anchor_right == 1.0
			and inventory_screen.anchor_bottom == 1.0,
			"L'inventario non usa il layout a schermo intero."
		)

		var consume_button := inventory_screen.get_node("%ConsumeButton") as Button
		var discard_button := inventory_screen.get_node("%DiscardButton") as Button
		var item_description := inventory_screen.get_node("%ItemDescription") as Label
		var coconut_index := _find_inventory_item_index(objects_list, &"cocco")
		_expect(coconut_index >= 0, "Il cocco non è selezionabile nella UI.")
		if coconut_index >= 0:
			objects_list.select(coconut_index)
			objects_list.item_selected.emit(coconut_index)
			_expect(
				item_description != null and not item_description.text.strip_edges().is_empty(),
				"La descrizione dell'oggetto selezionato non è mostrata."
			)
			_expect(not consume_button.disabled, "Il cocco non risulta consumabile.")
			consume_button.pressed.emit()
			_expect(inventory.get_quantity(&"cocco") == 9, "Consumare il cocco non lo rimuove.")

		var cloth_index := _find_inventory_item_index(objects_list, &"stoffa")
		_expect(cloth_index >= 0, "La stoffa non è selezionabile nella UI.")
		if cloth_index >= 0:
			objects_list.select(cloth_index)
			objects_list.item_selected.emit(cloth_index)
			_expect(consume_button.disabled, "La stoffa risulta consumabile.")
			_expect(not discard_button.disabled, "La stoffa non può essere buttata.")
			discard_button.pressed.emit()
			_expect(inventory.get_quantity(&"stoffa") == 9, "Buttare la stoffa non la rimuove.")

	if game_ui != null and pause_menu != null and inventory_screen != null:
		await _send_action(&"toggle_inventory")
		_expect(inventory_screen.visible, "Tab non apre l'inventario.")
		_expect(paused, "L'inventario aperto non sospende il gioco.")
		await _send_action(&"toggle_inventory")
		_expect(not inventory_screen.visible, "Tab non chiude l'inventario.")
		_expect(not paused, "Il gioco resta sospeso dopo l'inventario.")

		await _send_action(&"toggle_menu")
		_expect(pause_menu.visible, "Esc non apre il menu.")
		_expect(paused, "Il menu aperto non sospende il gioco.")
		_expect(_menu_buttons_are_unconnected(pause_menu), "I pulsanti menu hanno già azioni.")
		await _send_action(&"toggle_menu")
		_expect(not pause_menu.visible, "Esc non chiude il menu.")
		_expect(not paused, "Il gioco resta sospeso dopo il menu.")
	_finish(main)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _item_definitions_are_configured() -> bool:
	var expected_consumability: Dictionary[StringName, bool] = {
		&"cocco": true,
		&"stoffa": false,
		&"legno": false,
		&"pietra": false,
		&"fungo": true,
		&"bacca": true,
	}
	for item_id: StringName in expected_consumability:
		var path := "res://data/items/%s.tres" % item_id
		var definition := load(path) as ItemDefinition
		if definition == null:
			return false
		if definition.description.strip_edges().is_empty():
			return false
		if definition.consumable != expected_consumability[item_id]:
			return false
	return true


func _boundary_vegetation_is_configured(
	main: Node,
	boundary_collisions: StaticBody3D
) -> bool:
	if main.get_node_or_null("WorldMap/MapBoundary") != null:
		return false
	if boundary_collisions == null or boundary_collisions.get_child_count() < 400:
		return false

	for child: Node in boundary_collisions.get_children():
		var collision := child as CollisionShape3D
		if collision == null:
			return false
		var is_box_shape := collision.shape is BoxShape3D
		var is_cylinder_shape := collision.shape is CylinderShape3D
		if not is_box_shape and not is_cylinder_shape:
			return false
	return true


func _interactables_are_configured(
	world_map: VerdantValley,
	interactables: Array[InteractableArea3D]
) -> bool:
	if world_map == null:
		return false
	var expected_minimum := (
		world_map.tree_count
		world_map.shrub_count
		world_map.mushroom_count
		+ 25
	)
	if interactables.size() < expected_minimum:
		return false

	var category_counts: Dictionary[StringName, int] = {
		&"tree": 0,
		&"rock": 0,
		&"mushroom": 0,
		&"shrub": 0,
	}
	var used_ids: Dictionary[StringName, bool] = {}
	for interactable: InteractableArea3D in interactables:
		if interactable.interaction_id.is_empty() or used_ids.has(interactable.interaction_id):
			return false
		used_ids[interactable.interaction_id] = true
		if not category_counts.has(interactable.object_category):
			return false
		category_counts[interactable.object_category] += 1
		if interactable.max_item_count != 2:
			return false
		if not is_equal_approx(interactable.item_spawn_probability, 0.5):
			return false
		if interactable.get_remaining_item_count() < 0:
			return false
		if interactable.get_remaining_item_count() > 2:
			return false

	for count: int in category_counts.values():
		if count <= 0:
			return false
	return true


func _test_nature_drops(
	interactables: Array[InteractableArea3D],
	inventory: Inventory,
	player: PlayerController
) -> void:
	var drops: Dictionary[StringName, StringName] = {
		&"tree": &"legno",
		&"rock": &"pietra",
		&"mushroom": &"fungo",
		&"shrub": &"bacca",
	}
	for category: StringName in drops:
		var interactable := _find_interactable(interactables, category)
		_expect(interactable != null, "Oggetto raccoglibile mancante: %s." % category)
		if interactable == null:
			continue
		interactable.set_remaining_item_count(1)
		interactable.interact(player)
		var item_id: StringName = drops[category]
		_expect(
			inventory.get_quantity(item_id) == 1,
			"Il drop %s non viene aggiunto all'inventario." % item_id
		)


func _find_interactable(
	interactables: Array[InteractableArea3D],
	category: StringName
) -> InteractableArea3D:
	for interactable: InteractableArea3D in interactables:
		if interactable.object_category == category:
			return interactable
	return null


func _terrain_is_configured(world_map: VerdantValley, terrain: Node3D) -> bool:
	if world_map == null or terrain == null:
		return false
	var expected_chunks := (
		ceili(world_map.map_size.x / world_map.chunk_size)
		* ceili(world_map.map_size.y / world_map.chunk_size)
	)
	if terrain.get_child_count() != expected_chunks:
		return false
	for chunk in terrain.get_children():
		var mesh_instance := chunk.get_node_or_null("Mesh") as MeshInstance3D
		var collision := chunk.get_node_or_null(
			"StaticBody3D/CollisionShape3D"
		) as CollisionShape3D
		if (
			mesh_instance == null
			or mesh_instance.mesh == null
			or collision == null
			or not collision.shape is ConcavePolygonShape3D
		):
			return false
	return true


func _nature_is_configured(world_map: VerdantValley, vegetation: Node3D) -> bool:
	if world_map == null or vegetation == null or vegetation.get_child_count() < 20:
		return false
	var rendered_instances := 0
	var has_textured_material := false
	for child in vegetation.get_children():
		var multi_mesh_instance := child as MultiMeshInstance3D
		if (
			multi_mesh_instance == null
			or multi_mesh_instance.multimesh == null
			or multi_mesh_instance.multimesh.mesh == null
			or multi_mesh_instance.multimesh.instance_count <= 0
		):
			return false
		rendered_instances += multi_mesh_instance.multimesh.instance_count
		var mesh := multi_mesh_instance.multimesh.mesh
		for surface_index in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface_index) as BaseMaterial3D
			if material != null and material.albedo_texture != null:
				has_textured_material = true
	return (
		has_textured_material
		and rendered_instances >= world_map.get_generated_visual_count()
		and world_map.get_generated_visual_count() >= 900
	)


func _prop_collisions_are_configured(
	world_map: VerdantValley,
	prop_collisions: StaticBody3D
) -> bool:
	if world_map == null or prop_collisions == null:
		return false
	if prop_collisions.get_child_count() < world_map.tree_count + 25:
		return false
	for child in prop_collisions.get_children():
		var collision_shape := child as CollisionShape3D
		if collision_shape == null or collision_shape.shape == null:
			return false
	return true


func _terrain_has_relief(world_map: VerdantValley) -> bool:
	if world_map == null:
		return false
	var minimum_height := INF
	var maximum_height := -INF
	for world_z in range(-60, 61, 15):
		for world_x in range(-60, 61, 15):
			var height := world_map.get_terrain_height(world_x, world_z)
			minimum_height = minf(minimum_height, height)
			maximum_height = maxf(maximum_height, height)
	return maximum_height - minimum_height > 8.0


func _camera_is_behind_and_elevated(camera_rig: SpringArm3D) -> bool:
	if camera_rig == null:
		return false
	var camera := camera_rig.get_node_or_null("Camera3D") as Camera3D
	if camera == null or not camera.current:
		return false
	if camera_rig.rotation.x > deg_to_rad(-40.0):
		return false
	if camera_rig.rotation.x < deg_to_rad(-50.0):
		return false
	if camera_rig.spring_length < 8.0 or camera_rig.spring_length > 10.0:
		return false
	return camera.fov <= 52.0


func _legacy_camera_is_behind_and_elevated(camera_rig: SpringArm3D) -> bool:
	if camera_rig == null:
		return false
	var camera := camera_rig.get_node_or_null("Camera3D") as Camera3D
	return (
		camera != null
		and camera.current
		and camera_rig.rotation.x < deg_to_rad(-20.0)
		and camera_rig.rotation.x > deg_to_rad(-40.0)
		and camera_rig.spring_length >= 5.0
		and camera_rig.spring_length <= 7.0
		and camera.fov <= 55.0
	)


func _jump_uses_space() -> bool:
	for event in InputMap.action_get_events("jump"):
		var key_event := event as InputEventKey
		if key_event != null and key_event.physical_keycode == KEY_SPACE:
			return true
	return false


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


func _find_inventory_item_index(item_list: ItemList, item_id: StringName) -> int:
	for item_index in range(item_list.item_count):
		if item_list.get_item_metadata(item_index) == item_id:
			return item_index
	return -1


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


func _finish(main: Node) -> void:
	main.queue_free()
	if failed:
		quit(1)
	else:
		print("Main scene smoke test: OK")
		quit(0)
