class_name GameUI
extends CanvasLayer

@onready var pause_menu: PauseMenu = $PauseMenu
@onready var options_screen: OptionsScreen = $OptionsScreen
@onready var developer_formulas_screen: DeveloperFormulasScreen = $DeveloperFormulasScreen
@onready var element_chart_screen: ElementChartScreen = $ElementChartScreen
@onready var save_slots_screen: SaveSlotsScreen = $SaveSlotsScreen
@onready var inventory_screen: InventoryScreen = $InventoryScreen
@onready var squad_screen: SquadScreen = $SquadScreen
@onready var grimoire_screen: GrimoireScreen = $GrimoireScreen
@onready var player_profile_screen: PlayerProfileScreen = $PlayerProfileScreen
@onready var notification_toast: NotificationToast = $NotificationToast
@onready var transition_fade: ColorRect = $TransitionFade

var _pause_locks: Dictionary[StringName, bool] = {}
var _fade_tween: Tween = null
var _save_manager: SaveManager = null


func _ready() -> void:
	pause_menu.continue_requested.connect(_on_continue_requested)
	pause_menu.options_requested.connect(_on_options_requested)
	pause_menu.developer_formulas_requested.connect(_on_developer_formulas_requested)
	pause_menu.element_chart_requested.connect(_on_element_chart_requested)
	pause_menu.save_requested.connect(_on_save_requested)
	pause_menu.load_requested.connect(_on_load_requested)
	options_screen.apply_requested.connect(_on_options_apply_requested)
	options_screen.back_requested.connect(_return_to_pause_menu)
	developer_formulas_screen.back_requested.connect(_return_to_pause_menu)
	element_chart_screen.back_requested.connect(_return_to_pause_menu)
	save_slots_screen.save_slot_requested.connect(_on_save_slot_requested)
	save_slots_screen.load_slot_requested.connect(_on_load_slot_requested)
	save_slots_screen.back_requested.connect(_return_to_pause_menu)
	inventory_screen.notification_requested.connect(show_notification)
	squad_screen.close_requested.connect(_on_squad_close_requested)
	grimoire_screen.close_requested.connect(_on_grimoire_close_requested)
	player_profile_screen.close_requested.connect(_on_player_profile_close_requested)
	squad_screen.setup(_find_astral_roster())
	grimoire_screen.setup(_find_grimoire())
	player_profile_screen.setup(_find_player_profile())
	set_save_manager(_find_save_manager())


func setup(
	inventory: Inventory,
	roster: AstralRoster = null,
	grimoire: Grimoire = null,
	profile: PlayerProfile = null,
	save_manager: SaveManager = null
) -> void:
	inventory_screen.setup(inventory)
	var resolved_roster: AstralRoster = roster
	if resolved_roster == null:
		resolved_roster = _find_astral_roster()
	squad_screen.setup(resolved_roster)
	grimoire_screen.setup(grimoire if grimoire != null else _find_grimoire())
	player_profile_screen.setup(
		profile if profile != null else _find_player_profile()
	)
	set_save_manager(save_manager if save_manager != null else _find_save_manager())


func set_save_manager(save_manager: SaveManager) -> void:
	if (
		_save_manager != null
		and is_instance_valid(_save_manager)
		and _save_manager.slots_changed.is_connected(_on_save_slots_changed)
	):
		_save_manager.slots_changed.disconnect(_on_save_slots_changed)
	if (
		_save_manager != null
		and is_instance_valid(_save_manager)
		and _save_manager.operation_failed.is_connected(_on_save_operation_failed)
	):
		_save_manager.operation_failed.disconnect(_on_save_operation_failed)
	_save_manager = save_manager
	if (
		_save_manager != null
		and not _save_manager.slots_changed.is_connected(_on_save_slots_changed)
	):
		_save_manager.slots_changed.connect(_on_save_slots_changed)
	if (
		_save_manager != null
		and not _save_manager.operation_failed.is_connected(_on_save_operation_failed)
	):
		_save_manager.operation_failed.connect(_on_save_operation_failed)
	_refresh_save_availability()


func show_notification(message: String, enqueue: bool = false) -> void:
	notification_toast.show_message(message, enqueue)


func set_pause_lock(lock_id: StringName, active: bool) -> void:
	if lock_id.is_empty():
		return
	if active:
		_pause_locks[lock_id] = true
		pause_menu.close()
		options_screen.close()
		developer_formulas_screen.close()
		element_chart_screen.close()
		save_slots_screen.close()
		inventory_screen.close()
		squad_screen.close()
		grimoire_screen.close()
		player_profile_screen.close()
	else:
		_pause_locks.erase(lock_id)
	_sync_pause_state()


func has_pause_lock(lock_id: StringName) -> bool:
	return _pause_locks.has(lock_id)


func fade_to_black(duration: float = 0.35) -> void:
	_stop_fade_tween()
	transition_fade.show()
	transition_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_fade.color.a = 0.0
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(
		transition_fade,
		"color:a",
		1.0,
		maxf(duration, 0.0)
	)
	await _fade_tween.finished


func fade_from_black(duration: float = 0.35) -> void:
	_stop_fade_tween()
	transition_fade.show()
	transition_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_fade.color.a = 1.0
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(
		transition_fade,
		"color:a",
		0.0,
		maxf(duration, 0.0)
	)
	await _fade_tween.finished
	transition_fade.hide()
	transition_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.echo:
		return
	if not _pause_locks.is_empty():
		if (
			event.is_action_pressed("toggle_menu")
			or event.is_action_pressed("toggle_inventory")
			or event.is_action_pressed("toggle_squad")
			or event.is_action_pressed("toggle_grimoire")
			or event.is_action_pressed("toggle_player_profile")
		):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_menu"):
		if (
			options_screen.visible
			or developer_formulas_screen.visible
			or element_chart_screen.visible
			or save_slots_screen.visible
		):
			_return_to_pause_menu()
		else:
			_toggle_pause_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_inventory"):
		if _is_pause_subscreen_visible():
			get_viewport().set_input_as_handled()
			return
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_squad"):
		if _is_pause_subscreen_visible():
			get_viewport().set_input_as_handled()
			return
		_toggle_squad()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_grimoire"):
		if _is_pause_subscreen_visible():
			get_viewport().set_input_as_handled()
			return
		_toggle_grimoire()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_player_profile"):
		if _is_pause_subscreen_visible():
			get_viewport().set_input_as_handled()
			return
		_toggle_player_profile()
		get_viewport().set_input_as_handled()


func _toggle_pause_menu() -> void:
	if pause_menu.visible:
		pause_menu.close()
	else:
		_close_modal_screens(pause_menu)
		pause_menu.open(_save_manager != null and _save_manager.has_saves())
	_sync_pause_state()


func _toggle_inventory() -> void:
	if inventory_screen.visible:
		inventory_screen.close()
	else:
		_close_modal_screens(inventory_screen)
		inventory_screen.open()
	_sync_pause_state()


func _toggle_squad() -> void:
	if squad_screen.visible:
		squad_screen.close()
	else:
		_close_modal_screens(squad_screen)
		squad_screen.open()
	_sync_pause_state()


func _toggle_grimoire() -> void:
	if grimoire_screen.visible:
		grimoire_screen.close()
	else:
		_close_modal_screens(grimoire_screen)
		grimoire_screen.open()
	_sync_pause_state()


func _toggle_player_profile() -> void:
	if player_profile_screen.visible:
		player_profile_screen.close()
	else:
		_close_modal_screens(player_profile_screen)
		player_profile_screen.open()
	_sync_pause_state()


func _on_squad_close_requested() -> void:
	if not squad_screen.visible:
		return
	squad_screen.close()
	_sync_pause_state()


func _on_grimoire_close_requested() -> void:
	if grimoire_screen.visible:
		grimoire_screen.close()
		_sync_pause_state()


func _on_player_profile_close_requested() -> void:
	if player_profile_screen.visible:
		player_profile_screen.close()
		_sync_pause_state()


func _on_options_requested() -> void:
	pause_menu.close()
	options_screen.open()
	_sync_pause_state()


func _on_developer_formulas_requested() -> void:
	pause_menu.close()
	developer_formulas_screen.open()
	_sync_pause_state()


func _on_element_chart_requested() -> void:
	pause_menu.close()
	element_chart_screen.open()
	_sync_pause_state()


func _on_options_apply_requested() -> void:
	show_notification("Impostazioni applicate.")


func _on_save_requested() -> void:
	if _save_manager == null:
		show_notification("Il sistema di salvataggio non è disponibile.")
		return
	pause_menu.close()
	save_slots_screen.open(
		SaveSlotsScreen.Mode.SAVE,
		_save_manager.get_slot_summaries()
	)
	_sync_pause_state()


func _on_load_requested() -> void:
	if _save_manager == null or not _save_manager.has_saves():
		show_notification("Non ci sono salvataggi da caricare.")
		return
	pause_menu.close()
	save_slots_screen.open(
		SaveSlotsScreen.Mode.LOAD,
		_save_manager.get_slot_summaries()
	)
	_sync_pause_state()


func _on_continue_requested() -> void:
	if _save_manager == null or not _save_manager.continue_latest():
		if _save_manager == null:
			show_notification("Il sistema di salvataggio non è disponibile.")
		return
	_close_modal_screens()
	_sync_pause_state()
	show_notification("Ultimo salvataggio caricato.")


func _on_save_slot_requested(slot_index: int) -> void:
	if _save_manager == null or not _save_manager.create_save(slot_index):
		if _save_manager == null:
			show_notification("Il sistema di salvataggio non è disponibile.")
		return
	save_slots_screen.refresh_slots(_save_manager.get_slot_summaries())
	_refresh_save_availability()
	show_notification("Partita salvata nello slot %d." % (slot_index + 1))


func _on_load_slot_requested(slot_index: int) -> void:
	if _save_manager == null or not _save_manager.load_save(slot_index):
		if _save_manager == null:
			show_notification("Il sistema di salvataggio non è disponibile.")
		return
	_close_modal_screens()
	_sync_pause_state()
	show_notification("Salvataggio %d caricato." % (slot_index + 1))


func _return_to_pause_menu() -> void:
	options_screen.close()
	developer_formulas_screen.close()
	element_chart_screen.close()
	save_slots_screen.close()
	pause_menu.open(_save_manager != null and _save_manager.has_saves())
	_sync_pause_state()


func _on_save_slots_changed() -> void:
	_refresh_save_availability()
	if save_slots_screen.visible and _save_manager != null:
		save_slots_screen.refresh_slots(_save_manager.get_slot_summaries())


func _on_save_operation_failed(message: String) -> void:
	show_notification(message)


func _refresh_save_availability() -> void:
	pause_menu.set_continue_available(
		_save_manager != null and _save_manager.has_saves()
	)


func _close_modal_screens(exception_screen: Control = null) -> void:
	var screens: Array[Control] = [
		pause_menu,
		options_screen,
		developer_formulas_screen,
		element_chart_screen,
		save_slots_screen,
		inventory_screen,
		squad_screen,
		grimoire_screen,
		player_profile_screen,
	]
	for screen: Control in screens:
		if screen == exception_screen:
			continue
		if screen.has_method("close"):
			screen.call("close")
		else:
			screen.hide()


func _sync_pause_state() -> void:
	get_tree().paused = (
		not _pause_locks.is_empty()
		or pause_menu.visible
		or options_screen.visible
		or developer_formulas_screen.visible
		or element_chart_screen.visible
		or save_slots_screen.visible
		or inventory_screen.visible
		or squad_screen.visible
		or grimoire_screen.visible
		or player_profile_screen.visible
	)


func _is_pause_subscreen_visible() -> bool:
	return (
		options_screen.visible
		or developer_formulas_screen.visible
		or element_chart_screen.visible
		or save_slots_screen.visible
	)


func _find_astral_roster() -> AstralRoster:
	var main_node: Node = get_parent()
	if main_node == null:
		return null
	return main_node.get_node_or_null("AstralRoster") as AstralRoster


func _find_grimoire() -> Grimoire:
	var main_node := get_parent()
	if main_node == null:
		return null
	return main_node.get_node_or_null("Grimoire") as Grimoire


func _find_player_profile() -> PlayerProfile:
	var main_node := get_parent()
	if main_node == null:
		return null
	return main_node.get_node_or_null("PlayerProfile") as PlayerProfile


func _find_save_manager() -> SaveManager:
	var main_node := get_parent()
	if main_node == null:
		return null
	return main_node.get_node_or_null("SaveManager") as SaveManager


func _stop_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
