class_name GameUI
extends CanvasLayer

@onready var pause_menu: PauseMenu = $PauseMenu
@onready var options_screen: OptionsScreen = $OptionsScreen
@onready var developer_formulas_screen: DeveloperFormulasScreen = $DeveloperFormulasScreen
@onready var element_chart_screen: ElementChartScreen = $ElementChartScreen
@onready var synergy_screen: SynergyScreen = $SynergyScreen
@onready var save_slots_screen: SaveSlotsScreen = $SaveSlotsScreen
@onready var inventory_screen: InventoryScreen = $InventoryScreen
@onready var squad_screen: SquadScreen = $SquadScreen
@onready var astral_box_screen: AstralBoxScreen = $AstralBoxScreen
@onready var grimoire_screen: GrimoireScreen = $GrimoireScreen
@onready var player_profile_screen: PlayerProfileScreen = $PlayerProfileScreen
@onready var notification_toast: NotificationToast = $NotificationToast
@onready var level_up_summary: LevelUpSummary = $LevelUpSummary
@onready var move_learn_prompt: MoveLearnPrompt = $MoveLearnPrompt
@onready var shop_screen: ShopScreen = $ShopScreen
@onready var astral_exchange_screen: AstralExchangeScreen = $AstralExchangeScreen
@onready var coin_flip_screen: CoinFlipScreen = $CoinFlipScreen
@onready var transition_fade: ColorRect = $TransitionFade
@onready var loading_label: Label = $TransitionFade/LoadingLabel

var _pause_locks: Dictionary[StringName, bool] = {}
var _fade_tween: Tween = null
var _save_manager: SaveManager = null
var _level_up_roster: AstralRoster = null
var _observed_astrals: Array[AstralInstance] = []


func _ready() -> void:
	pause_menu.continue_requested.connect(_on_continue_requested)
	pause_menu.options_requested.connect(_on_options_requested)
	pause_menu.developer_formulas_requested.connect(_on_developer_formulas_requested)
	pause_menu.element_chart_requested.connect(_on_element_chart_requested)
	pause_menu.synergies_requested.connect(_on_synergies_requested)
	pause_menu.save_requested.connect(_on_save_requested)
	pause_menu.load_requested.connect(_on_load_requested)
	options_screen.apply_requested.connect(_on_options_apply_requested)
	options_screen.back_requested.connect(_return_to_pause_menu)
	developer_formulas_screen.back_requested.connect(_return_to_pause_menu)
	element_chart_screen.back_requested.connect(_return_to_pause_menu)
	synergy_screen.back_requested.connect(_return_to_pause_menu)
	save_slots_screen.save_slot_requested.connect(_on_save_slot_requested)
	save_slots_screen.load_slot_requested.connect(_on_load_slot_requested)
	save_slots_screen.back_requested.connect(_return_to_pause_menu)
	inventory_screen.notification_requested.connect(show_notification)
	squad_screen.close_requested.connect(_on_squad_close_requested)
	squad_screen.notification_requested.connect(show_notification)
	astral_box_screen.close_requested.connect(_on_astral_box_close_requested)
	astral_box_screen.notification_requested.connect(show_notification)
	grimoire_screen.close_requested.connect(_on_grimoire_close_requested)
	player_profile_screen.close_requested.connect(_on_player_profile_close_requested)
	move_learn_prompt.replacement_confirmed.connect(
		_on_move_replacement_confirmed
	)
	move_learn_prompt.learning_declined.connect(_on_move_learning_declined)
	move_learn_prompt.request_started.connect(_sync_pause_state)
	move_learn_prompt.request_finished.connect(_sync_pause_state)
	shop_screen.close_requested.connect(_on_facility_screen_close_requested.bind(shop_screen))
	shop_screen.notification_requested.connect(show_notification)
	astral_exchange_screen.close_requested.connect(
		_on_facility_screen_close_requested.bind(astral_exchange_screen)
	)
	astral_exchange_screen.notification_requested.connect(show_notification)
	coin_flip_screen.close_requested.connect(
		_on_facility_screen_close_requested.bind(coin_flip_screen)
	)
	coin_flip_screen.notification_requested.connect(show_notification)
	squad_screen.setup(_find_astral_roster())
	synergy_screen.setup(_find_astral_roster())
	_set_level_up_roster(_find_astral_roster())
	astral_box_screen.setup(_find_astral_roster())
	grimoire_screen.setup(_find_grimoire())
	player_profile_screen.setup(_find_player_profile())
	set_save_manager(_find_save_manager())


func setup(
	inventory: Inventory,
	roster: AstralRoster = null,
	grimoire: Grimoire = null,
	profile: PlayerProfile = null,
	save_manager: SaveManager = null,
	player_session: PlayerSession = null
) -> void:
	inventory_screen.setup(inventory)
	var resolved_roster: AstralRoster = roster
	if resolved_roster == null:
		resolved_roster = _find_astral_roster()
	squad_screen.setup(resolved_roster, inventory)
	astral_box_screen.setup(resolved_roster, inventory)
	_set_level_up_roster(resolved_roster)
	grimoire_screen.setup(grimoire if grimoire != null else _find_grimoire())
	player_profile_screen.setup(
		profile if profile != null else _find_player_profile()
	)
	var resolved_profile := profile if profile != null else _find_player_profile()
	shop_screen.setup(
		inventory,
		resolved_profile,
		player_session.economy if player_session != null else null
	)
	astral_exchange_screen.setup(resolved_roster, resolved_profile)
	coin_flip_screen.setup(
		resolved_profile,
		player_session.economy if player_session != null else null
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
		astral_box_screen.close()
		grimoire_screen.close()
		player_profile_screen.close()
		shop_screen.close()
		astral_exchange_screen.close()
		coin_flip_screen.close()
	else:
		_pause_locks.erase(lock_id)
	_sync_pause_state()


func has_pause_lock(lock_id: StringName) -> bool:
	return _pause_locks.has(lock_id)


func open_shop() -> void:
	_open_facility_screen(shop_screen)


func open_astral_exchange() -> void:
	_open_facility_screen(astral_exchange_screen)


func open_coin_flip() -> void:
	_open_facility_screen(coin_flip_screen)


func open_astral_box() -> void:
	_close_modal_screens(astral_box_screen)
	astral_box_screen.open()
	_sync_pause_state()


func set_loading_visible(visible_state: bool, message: String = "Caricamento...") -> void:
	loading_label.text = message
	loading_label.visible = visible_state


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
	if move_learn_prompt.visible and _is_screen_toggle_event(event):
		get_viewport().set_input_as_handled()
		return
	if not _pause_locks.is_empty():
		if _is_screen_toggle_event(event):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_menu"):
		if (
			options_screen.visible
			or developer_formulas_screen.visible
			or element_chart_screen.visible
			or synergy_screen.visible
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
	elif event.is_action_pressed("toggle_astral_box"):
		if _is_pause_subscreen_visible():
			get_viewport().set_input_as_handled()
			return
		_toggle_astral_box()
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


func _toggle_astral_box() -> void:
	if astral_box_screen.visible:
		astral_box_screen.close()
	else:
		_close_modal_screens(astral_box_screen)
		astral_box_screen.open()
	_sync_pause_state()


func _open_facility_screen(screen: Control) -> void:
	if screen == null or not _pause_locks.is_empty():
		return
	_close_modal_screens(screen)
	if screen.has_method("open"):
		screen.call("open")
	else:
		screen.show()
	_sync_pause_state()


func _on_facility_screen_close_requested(screen: Control) -> void:
	if screen != null and screen.has_method("close"):
		screen.call("close")
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


func _on_astral_box_close_requested() -> void:
	if not astral_box_screen.visible:
		return
	astral_box_screen.close()
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


func _on_synergies_requested() -> void:
	pause_menu.close()
	synergy_screen.open()
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
	synergy_screen.close()
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
		synergy_screen,
		save_slots_screen,
		inventory_screen,
		squad_screen,
		astral_box_screen,
		grimoire_screen,
		player_profile_screen,
		shop_screen,
		astral_exchange_screen,
		coin_flip_screen,
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
		or synergy_screen.visible
		or save_slots_screen.visible
		or inventory_screen.visible
		or squad_screen.visible
		or astral_box_screen.visible
		or grimoire_screen.visible
		or player_profile_screen.visible
		or shop_screen.visible
		or astral_exchange_screen.visible
		or coin_flip_screen.visible
		or move_learn_prompt.visible
	)


func _is_screen_toggle_event(event: InputEvent) -> bool:
	return (
		event.is_action_pressed("toggle_menu")
		or event.is_action_pressed("toggle_inventory")
		or event.is_action_pressed("toggle_squad")
		or event.is_action_pressed("toggle_astral_box")
		or event.is_action_pressed("toggle_grimoire")
		or event.is_action_pressed("toggle_player_profile")
	)


func _is_pause_subscreen_visible() -> bool:
	return (
		options_screen.visible
		or developer_formulas_screen.visible
		or element_chart_screen.visible
		or synergy_screen.visible
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


func _set_level_up_roster(source_roster: AstralRoster) -> void:
	_disconnect_level_up_observers()
	_level_up_roster = source_roster
	if _level_up_roster == null:
		return
	if not _level_up_roster.roster_changed.is_connected(
		_refresh_level_up_observers
	):
		_level_up_roster.roster_changed.connect(_refresh_level_up_observers)
	_refresh_level_up_observers()


func _refresh_level_up_observers() -> void:
	_disconnect_astral_level_up_signals()
	if _level_up_roster == null:
		return
	for astral: AstralInstance in _level_up_roster.get_all_astrals():
		if astral == null:
			continue
		var callback := Callable(self, "_on_astral_leveled_up").bind(astral)
		if not astral.leveled_up.is_connected(callback):
			astral.leveled_up.connect(callback)
		var learned_callback := Callable(self, "_on_astral_move_learned").bind(
			astral
		)
		if not astral.move_learned.is_connected(learned_callback):
			astral.move_learned.connect(learned_callback)
		var requested_callback := Callable(
			self,
			"_on_astral_move_learning_requested"
		).bind(astral)
		if not astral.move_learning_requested.is_connected(requested_callback):
			astral.move_learning_requested.connect(requested_callback)
		_observed_astrals.append(astral)
		for pending_move: AstralMoveDefinition in astral.get_pending_moves():
			_on_astral_move_learning_requested(pending_move, astral)


func _disconnect_level_up_observers() -> void:
	_disconnect_astral_level_up_signals()
	if (
		_level_up_roster != null
		and is_instance_valid(_level_up_roster)
		and _level_up_roster.roster_changed.is_connected(
			_refresh_level_up_observers
		)
	):
		_level_up_roster.roster_changed.disconnect(_refresh_level_up_observers)


func _disconnect_astral_level_up_signals() -> void:
	for astral: AstralInstance in _observed_astrals:
		if astral == null or not is_instance_valid(astral):
			continue
		var callback := Callable(self, "_on_astral_leveled_up").bind(astral)
		if astral.leveled_up.is_connected(callback):
			astral.leveled_up.disconnect(callback)
		var learned_callback := Callable(self, "_on_astral_move_learned").bind(
			astral
		)
		if astral.move_learned.is_connected(learned_callback):
			astral.move_learned.disconnect(learned_callback)
		var requested_callback := Callable(
			self,
			"_on_astral_move_learning_requested"
		).bind(astral)
		if astral.move_learning_requested.is_connected(requested_callback):
			astral.move_learning_requested.disconnect(requested_callback)
	_observed_astrals.clear()


func _on_astral_leveled_up(
	previous_level: int,
	new_level: int,
	astral: AstralInstance
) -> void:
	level_up_summary.enqueue_summary(astral, previous_level, new_level)


func _on_astral_move_learned(
	move: AstralMoveDefinition,
	astral: AstralInstance
) -> void:
	if move == null or astral == null or astral.definition == null:
		return
	show_notification(
		"%s ha imparato %s." % [
			astral.definition.display_name,
			move.display_name,
		],
		true
	)


func _on_astral_move_learning_requested(
	move: AstralMoveDefinition,
	astral: AstralInstance
) -> void:
	move_learn_prompt.enqueue_request(astral, move)


func _on_move_replacement_confirmed(
	astral: AstralInstance,
	move: AstralMoveDefinition,
	replaced_index: int
) -> void:
	if not astral.learn_pending_move_replacing(move, replaced_index):
		show_notification("Non è stato possibile imparare la nuova mossa.", true)


func _on_move_learning_declined(
	astral: AstralInstance,
	move: AstralMoveDefinition
) -> void:
	if not astral.decline_pending_move(move):
		return
	show_notification(
		"%s ha rinunciato a imparare %s." % [
			astral.definition.display_name,
			move.display_name,
		],
		true
	)


func _stop_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
