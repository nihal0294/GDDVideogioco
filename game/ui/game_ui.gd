class_name GameUI
extends CanvasLayer

@onready var pause_menu: PauseMenu = $PauseMenu
@onready var inventory_screen: InventoryScreen = $InventoryScreen
@onready var squad_screen: SquadScreen = $SquadScreen
@onready var notification_toast: NotificationToast = $NotificationToast
@onready var transition_fade: ColorRect = $TransitionFade

var _pause_locks: Dictionary[StringName, bool] = {}
var _fade_tween: Tween = null


func _ready() -> void:
	inventory_screen.notification_requested.connect(show_notification)
	squad_screen.close_requested.connect(_on_squad_close_requested)
	squad_screen.setup(_find_astral_roster())


func setup(
	inventory: Inventory,
	roster: AstralRoster = null
) -> void:
	inventory_screen.setup(inventory)
	var resolved_roster: AstralRoster = roster
	if resolved_roster == null:
		resolved_roster = _find_astral_roster()
	squad_screen.setup(resolved_roster)


func show_notification(message: String, enqueue: bool = false) -> void:
	notification_toast.show_message(message, enqueue)


func set_pause_lock(lock_id: StringName, active: bool) -> void:
	if lock_id.is_empty():
		return
	if active:
		_pause_locks[lock_id] = true
		pause_menu.close()
		inventory_screen.close()
		squad_screen.close()
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
		):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_menu"):
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_squad"):
		_toggle_squad()
		get_viewport().set_input_as_handled()


func _toggle_pause_menu() -> void:
	if pause_menu.visible:
		pause_menu.close()
	else:
		inventory_screen.close()
		squad_screen.close()
		pause_menu.open()
	_sync_pause_state()


func _toggle_inventory() -> void:
	if inventory_screen.visible:
		inventory_screen.close()
	else:
		pause_menu.close()
		squad_screen.close()
		inventory_screen.open()
	_sync_pause_state()


func _toggle_squad() -> void:
	if squad_screen.visible:
		squad_screen.close()
	else:
		pause_menu.close()
		inventory_screen.close()
		squad_screen.open()
	_sync_pause_state()


func _on_squad_close_requested() -> void:
	if not squad_screen.visible:
		return
	squad_screen.close()
	_sync_pause_state()


func _sync_pause_state() -> void:
	get_tree().paused = (
		not _pause_locks.is_empty()
		or pause_menu.visible
		or inventory_screen.visible
		or squad_screen.visible
	)


func _find_astral_roster() -> AstralRoster:
	var main_node: Node = get_parent()
	if main_node == null:
		return null
	return main_node.get_node_or_null("AstralRoster") as AstralRoster


func _stop_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
