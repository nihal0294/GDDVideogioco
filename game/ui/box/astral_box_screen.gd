class_name AstralBoxScreen
extends Control

signal close_requested()
signal notification_requested(message: String)

const PRESENTATION := preload("res://game/astrals/astral_presentation.gd")

@onready var box_label: Label = %BoxLabel
@onready var previous_box_button: Button = %PreviousBoxButton
@onready var next_box_button: Button = %NextBoxButton
@onready var party_list: ItemList = %PartyList
@onready var box_list: ItemList = %BoxList
@onready var details_label: Label = %DetailsLabel
@onready var status_label: Label = %StatusLabel
@onready var deposit_button: Button = %DepositButton
@onready var withdraw_button: Button = %WithdrawButton
@onready var swap_button: Button = %SwapButton
@onready var move_button: Button = %MoveButton
@onready var release_button: Button = %ReleaseButton
@onready var equip_button: Button = %EquipButton
@onready var evolve_button: Button = %EvolveButton
@onready var back_button: Button = %BackButton
@onready var release_confirmation: ConfirmationDialog = $ReleaseConfirmation
@onready var evolution_menu: PopupMenu = $EvolutionMenu

var _roster: AstralRoster = null
var _inventory: Inventory = null
var _current_box: int = 0
var _selected_party_index: int = -1
var _selected_box_slot: int = -1
var _selection_kind: StringName = &""
var _move_source := Vector2i(-1, -1)
var _pending_release_kind: StringName = &""
var _pending_release_index := Vector2i(-1, -1)


func _ready() -> void:
	previous_box_button.pressed.connect(_change_box.bind(-1))
	next_box_button.pressed.connect(_change_box.bind(1))
	party_list.item_selected.connect(_on_party_selected)
	box_list.item_selected.connect(_on_box_selected)
	party_list.item_activated.connect(_on_party_activated)
	box_list.item_activated.connect(_on_box_activated)
	deposit_button.pressed.connect(_deposit_selected)
	withdraw_button.pressed.connect(_withdraw_selected)
	swap_button.pressed.connect(_swap_selected)
	move_button.pressed.connect(_move_selected)
	release_button.pressed.connect(_request_release)
	evolve_button.pressed.connect(_request_evolution)
	evolution_menu.id_pressed.connect(_on_evolution_selected)
	back_button.pressed.connect(close_requested.emit)
	release_confirmation.confirmed.connect(_confirm_release)
	equip_button.disabled = true
	equip_button.tooltip_text = "Il sistema di equipaggiamento verrà implementato in seguito."


func setup(roster: AstralRoster, inventory: Inventory = null) -> void:
	if (
		_roster != null
		and is_instance_valid(_roster)
		and _roster.roster_changed.is_connected(_on_roster_changed)
	):
		_roster.roster_changed.disconnect(_on_roster_changed)
	_roster = roster
	_inventory = inventory
	if _roster != null and not _roster.roster_changed.is_connected(_on_roster_changed):
		_roster.roster_changed.connect(_on_roster_changed)
	_rebuild()


func open() -> void:
	show()
	_rebuild()
	call_deferred("_focus_initial_control")


func close() -> void:
	_move_source = Vector2i(-1, -1)
	_pending_release_kind = &""
	release_confirmation.hide()
	hide()


func get_current_box_index() -> int:
	return _current_box


func select_box(box_index: int) -> void:
	if _roster == null:
		return
	_current_box = posmod(box_index, _roster.get_box_count())
	_selected_box_slot = -1
	_rebuild()


func _change_box(direction: int) -> void:
	if _roster == null:
		return
	_current_box = posmod(_current_box + direction, _roster.get_box_count())
	_selected_box_slot = -1
	_rebuild()
	box_list.grab_focus()


func _rebuild() -> void:
	party_list.clear()
	box_list.clear()
	if _roster == null:
		box_label.text = "BOX --/--"
		details_label.text = "Archivio Astral non disponibile."
		_update_buttons()
		return
	box_label.text = "BOX %02d / %02d" % [
		_current_box + 1,
		_roster.get_box_count(),
	]
	for party_index: int in AstralRoster.MAX_PARTY_SIZE:
		var astral := _roster.get_astral(party_index)
		var text := "%d. Slot libero" % (party_index + 1)
		if astral != null:
			text = "%d. %s · Lv.%d" % [
				party_index + 1,
				PRESENTATION.format_identity(astral),
				astral.level,
			]
		var row := party_list.add_item(text)
		party_list.set_item_metadata(row, party_index)
	var stored_astrals := _roster.get_box_astrals(_current_box)
	for slot_index: int in AstralRoster.BOX_CAPACITY:
		var stored := stored_astrals[slot_index]
		var text := "%02d\nVuoto" % (slot_index + 1)
		if stored != null:
			text = "%02d\n%s\nLv.%d" % [
				slot_index + 1,
				PRESENTATION.format_identity(stored),
				stored.level,
			]
		var cell := box_list.add_item(text)
		box_list.set_item_metadata(cell, slot_index)
	_restore_selections()
	_refresh_details()
	_update_buttons()


func _restore_selections() -> void:
	if _selected_party_index >= 0 and _selected_party_index < party_list.item_count:
		party_list.select(_selected_party_index)
	if _selected_box_slot >= 0 and _selected_box_slot < box_list.item_count:
		box_list.select(_selected_box_slot)


func _on_party_selected(index: int) -> void:
	_selected_party_index = int(party_list.get_item_metadata(index))
	_selection_kind = &"party"
	_refresh_details()
	_update_buttons()


func _on_box_selected(index: int) -> void:
	_selected_box_slot = int(box_list.get_item_metadata(index))
	_selection_kind = &"box"
	_refresh_details()
	_update_buttons()


func _on_party_activated(_index: int) -> void:
	_deposit_selected()


func _on_box_activated(_index: int) -> void:
	_withdraw_selected()


func _deposit_selected() -> void:
	if _roster == null or _selected_party_index < 0:
		return
	var destination_slot := -1
	if (
		_selected_box_slot >= 0
		and _roster.get_box_astral(_current_box, _selected_box_slot) == null
	):
		destination_slot = _selected_box_slot
	if not _roster.deposit_astral(
		_selected_party_index,
		_current_box,
		destination_slot
	):
		notification_requested.emit(
			"Deposito non riuscito: lascia almeno un Astral in squadra e verifica lo spazio."
		)
		return
	_selected_party_index = -1
	_selection_kind = &""
	notification_requested.emit("Astral depositato nel Box %02d." % (_current_box + 1))
	_rebuild()


func _withdraw_selected() -> void:
	if _roster == null or _selected_box_slot < 0:
		return
	if not _roster.withdraw_astral(_current_box, _selected_box_slot):
		notification_requested.emit("Ritiro non riuscito: la squadra è piena o lo slot è vuoto.")
		return
	_selected_box_slot = -1
	_selection_kind = &""
	notification_requested.emit("Astral ritirato in squadra.")
	_rebuild()


func _swap_selected() -> void:
	if _roster == null or _selected_party_index < 0 or _selected_box_slot < 0:
		return
	if not _roster.swap_party_with_box(
		_selected_party_index,
		_current_box,
		_selected_box_slot
	):
		notification_requested.emit("Seleziona un Astral sia in squadra sia nel Box.")
		return
	notification_requested.emit("Astral scambiati.")
	_rebuild()


func _move_selected() -> void:
	if _roster == null:
		return
	if _move_source.x < 0:
		if _selected_box_slot < 0 or _roster.get_box_astral(
			_current_box,
			_selected_box_slot
		) == null:
			notification_requested.emit("Seleziona un Astral del Box da spostare.")
			return
		_move_source = Vector2i(_current_box, _selected_box_slot)
		status_label.text = "Spostamento: scegli qualsiasi Box e slot di destinazione."
		move_button.text = "Sposta qui"
		return
	if _selected_box_slot < 0:
		notification_requested.emit("Seleziona lo slot di destinazione.")
		return
	if _roster.move_box_astral(
		_move_source.x,
		_move_source.y,
		_current_box,
		_selected_box_slot
	):
		notification_requested.emit("Astral spostato nel Box %02d." % (_current_box + 1))
	_move_source = Vector2i(-1, -1)
	status_label.text = "Seleziona un Astral per gestirlo."
	move_button.text = "Sposta"
	_rebuild()


func _request_release() -> void:
	if _roster == null:
		return
	var selected := _get_selected_astral()
	if selected == null:
		return
	_pending_release_kind = _selection_kind
	_pending_release_index = (
		Vector2i(_selected_party_index, -1)
		if _selection_kind == &"party"
		else Vector2i(_current_box, _selected_box_slot)
	)
	release_confirmation.dialog_text = (
		"Liberare definitivamente %s? Questa operazione non può essere annullata."
		% selected.definition.display_name
	)
	release_confirmation.popup_centered()


func _confirm_release() -> void:
	if _roster == null:
		return
	var released := false
	if _pending_release_kind == &"party":
		released = _roster.release_party_astral(_pending_release_index.x)
	elif _pending_release_kind == &"box":
		released = _roster.release_box_astral(
			_pending_release_index.x,
			_pending_release_index.y
		)
	_pending_release_kind = &""
	_pending_release_index = Vector2i(-1, -1)
	if released:
		notification_requested.emit("Astral liberato definitivamente.")
		_selected_party_index = -1
		_selected_box_slot = -1
		_selection_kind = &""
	else:
		notification_requested.emit("Non puoi liberare l'ultimo Astral della squadra.")
	_rebuild()


func _request_evolution() -> void:
	var astral := _get_selected_astral()
	if _roster == null or astral == null:
		return
	var options := _roster.get_available_evolutions(astral, _inventory)
	if options.is_empty():
		return
	evolution_menu.clear()
	for option_index: int in options.size():
		var option := options[option_index]
		evolution_menu.add_item(
			"%s - %s" % [option.target.display_name, option.get_method_text()],
			option_index
		)
		evolution_menu.set_item_metadata(option_index, option)
	evolution_menu.popup_centered(Vector2i(460, 0))


func _on_evolution_selected(menu_id: int) -> void:
	var astral := _get_selected_astral()
	var menu_index := evolution_menu.get_item_index(menu_id)
	if _roster == null or astral == null or menu_index < 0:
		return
	var option := evolution_menu.get_item_metadata(menu_index) as AstralEvolutionOption
	var previous_name := astral.definition.display_name
	if not _roster.evolve_astral(astral, option, _inventory):
		notification_requested.emit("Le condizioni per l'evoluzione non sono soddisfatte.")
		return
	notification_requested.emit(
		"%s si è evoluto in %s!" % [previous_name, astral.definition.display_name]
	)
	_rebuild()


func _get_selected_astral() -> AstralInstance:
	if _roster == null:
		return null
	if _selection_kind == &"party":
		return _roster.get_astral(_selected_party_index)
	if _selection_kind == &"box":
		return _roster.get_box_astral(_current_box, _selected_box_slot)
	return null


func _refresh_details() -> void:
	var astral := _get_selected_astral()
	if astral == null or astral.definition == null:
		details_label.text = "Nessun Astral selezionato.\n\nOggetto equipaggiato: —"
		return
	details_label.text = (
		"%s\nLivello %d\nHP %d/%d\nElemento: %s\n\nOggetto equipaggiato: Nessuno"
		% [
			PRESENTATION.format_identity(astral),
			astral.level,
			astral.current_health,
			astral.get_max_health(),
			PRESENTATION.format_element(astral.definition.primary_element),
		]
	)


func _update_buttons() -> void:
	var has_party := _roster != null and _roster.get_astral(
		_selected_party_index
	) != null
	var has_box := _roster != null and _roster.get_box_astral(
		_current_box,
		_selected_box_slot
	) != null
	deposit_button.disabled = not has_party or _roster.get_astral_count() <= 1
	withdraw_button.disabled = not has_box or _roster.get_astral_count() >= AstralRoster.MAX_PARTY_SIZE
	swap_button.disabled = not has_party or not has_box
	move_button.disabled = _move_source.x < 0 and not has_box
	release_button.disabled = not (has_party or has_box) or (
		has_party and _roster.get_astral_count() <= 1
	)
	var selected := _get_selected_astral()
	evolve_button.visible = (
		selected != null
		and not selected.get_available_evolutions().is_empty()
	)
	evolve_button.disabled = (
		selected == null
		or _roster.get_available_evolutions(selected, _inventory).is_empty()
	)


func _on_roster_changed() -> void:
	_rebuild()


func _focus_initial_control() -> void:
	if party_list.item_count > 0:
		party_list.select(0)
		_on_party_selected(0)
	party_list.grab_focus()
