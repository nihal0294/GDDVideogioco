class_name GrimoireScreen
extends Control

signal close_requested

const PRESENTATION := preload("res://game/astrals/astral_presentation.gd")

@onready var entry_list: ItemList = %EntryList
@onready var progress_label: Label = %ProgressLabel
@onready var portrait_color: ColorRect = %PortraitColor
@onready var entry_number: Label = %EntryNumber
@onready var astral_name: Label = %AstralName
@onready var discovery_status: Label = %DiscoveryStatus
@onready var elements_value: Label = %ElementsValue
@onready var spawn_value: Label = %SpawnValue
@onready var habitat_value: Label = %HabitatValue
@onready var description_value: Label = %DescriptionValue
@onready var field_notes_value: Label = %FieldNotesValue
@onready var stats_value: Label = %StatsValue
@onready var moves_value: Label = %MovesValue
@onready var cards_value: Label = %CardsValue
@onready var close_button: Button = %CloseButton

var grimoire: Grimoire = null
var _entries: Array[GrimoireEntry] = []
var _selected_entry_id: StringName = &""


func _ready() -> void:
	entry_list.item_selected.connect(_on_entry_selected)
	entry_list.item_activated.connect(_on_entry_selected)
	close_button.pressed.connect(_on_close_pressed)
	_clear_details()


func setup(source_grimoire: Grimoire) -> void:
	_disconnect_grimoire()
	grimoire = source_grimoire
	if grimoire != null:
		grimoire.entry_state_changed.connect(_on_entry_state_changed)
		grimoire.catalog_changed.connect(_refresh_catalog)
	_refresh_catalog()


func open() -> void:
	show()
	_refresh_catalog()
	call_deferred("_focus_entry_list")


func close() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	hide()


func _refresh_catalog() -> void:
	entry_list.clear()
	_entries.clear()
	if grimoire != null:
		_entries = grimoire.get_entries()
	for entry: GrimoireEntry in _entries:
		if entry == null:
			continue
		var entry_id := entry.get_entry_id()
		var state := grimoire.get_discovery_state(entry_id)
		var display_name := "???"
		var state_marker := ""
		if state >= Grimoire.DiscoveryState.SEEN and entry.astral != null:
			display_name = entry.astral.display_name
			state_marker = (
				"  ★"
				if state == Grimoire.DiscoveryState.CAPTURED
				else "  ◐"
			)
		var item_index := entry_list.add_item(
			"[%03d] %s%s" % [entry.entry_number, display_name, state_marker]
		)
		entry_list.set_item_metadata(item_index, entry_id)

	_update_progress()
	if _entries.is_empty():
		_clear_details()
		return
	var selected_index := _find_entry_index(_selected_entry_id)
	if selected_index < 0:
		selected_index = 0
	entry_list.select(selected_index)
	_on_entry_selected(selected_index)


func _on_entry_selected(index: int) -> void:
	if index < 0 or index >= _entries.size():
		_clear_details()
		return
	var entry := _entries[index]
	if entry == null:
		_clear_details()
		return
	_selected_entry_id = entry.get_entry_id()
	_show_entry(entry)


func _show_entry(entry: GrimoireEntry) -> void:
	var state := grimoire.get_discovery_state(entry.get_entry_id())
	entry_number.text = "Voce n. %03d" % entry.entry_number
	if state == Grimoire.DiscoveryState.UNKNOWN or entry.astral == null:
		portrait_color.color = Color(0.06, 0.075, 0.095, 1.0)
		astral_name.text = "Specie sconosciuta"
		discovery_status.text = "NON ANCORA AVVISTATO"
		elements_value.text = "???"
		spawn_value.text = "???"
		habitat_value.text = "???"
		description_value.text = "Avvista questa specie per sbloccare la pagina."
		field_notes_value.text = "Informazioni non disponibili."
		stats_value.text = "???"
		moves_value.text = "???"
		cards_value.text = "Animazione 3D bloccata — carte associate mancanti."
		return

	var definition := entry.astral
	astral_name.text = definition.display_name
	elements_value.text = _format_elements(definition)
	spawn_value.text = entry.get_spawn_zones_text()
	if state == Grimoire.DiscoveryState.SEEN:
		var color := definition.visual_color
		var luminance := color.get_luminance()
		portrait_color.color = Color(luminance, luminance, luminance, 1.0)
		discovery_status.text = "AVVISTATO — CATTURA PER COMPLETARE"
		habitat_value.text = "Dati incompleti"
		description_value.text = "La sagoma è stata registrata nel Grimorio."
		field_notes_value.text = "Cattura la specie per sbloccare le note di campo."
		stats_value.text = "Dati incompleti"
		moves_value.text = "Dati incompleti"
		cards_value.text = "Animazione 3D bloccata — carte associate mancanti."
		return

	portrait_color.color = definition.visual_color
	discovery_status.text = "CATTURATO — SCHEDA COMPLETA"
	habitat_value.text = entry.habitat
	description_value.text = definition.description
	field_notes_value.text = entry.field_notes
	stats_value.text = "HP %d    ATT %d    VEL %d" % [
		definition.max_health,
		definition.attack_power,
		definition.speed,
	]
	var move_names: Array[String] = []
	for move: AstralMoveDefinition in definition.starting_moves:
		if move != null:
			move_names.append("%s (CD %d)" % [move.display_name, move.cooldown_turns])
	moves_value.text = " • ".join(move_names) if not move_names.is_empty() else "Nessuna"
	cards_value.text = "Animazione 3D bloccata — carte associate mancanti."


func _update_progress() -> void:
	if grimoire == null:
		progress_label.text = "Visti 0/0    •    Catturati 0/0"
		return
	progress_label.text = "Visti %d/%d    •    Catturati %d/%d" % [
		grimoire.get_seen_species_count(),
		_entries.size(),
		grimoire.get_captured_species_count(),
		_entries.size(),
	]


func _format_elements(definition: AstralDefinition) -> String:
	var labels: Array[String] = []
	for element_id: StringName in definition.get_elements():
		labels.append(PRESENTATION.format_element(element_id))
	return " / ".join(labels) if not labels.is_empty() else PRESENTATION.format_element(&"neutro")


func _find_entry_index(entry_id: StringName) -> int:
	for index: int in _entries.size():
		if _entries[index] != null and _entries[index].get_entry_id() == entry_id:
			return index
	return -1


func _on_entry_state_changed(_entry_id: StringName) -> void:
	_refresh_catalog()


func _on_close_pressed() -> void:
	close_requested.emit()


func _focus_entry_list() -> void:
	if visible and not _entries.is_empty():
		entry_list.grab_focus()


func _clear_details() -> void:
	entry_number.text = "Voce n. ---"
	astral_name.text = "Nessuna voce selezionata"
	discovery_status.text = ""
	portrait_color.color = Color(0.06, 0.075, 0.095, 1.0)
	elements_value.text = "—"
	spawn_value.text = "—"
	habitat_value.text = "—"
	description_value.text = "Seleziona una voce del Grimorio."
	field_notes_value.text = "—"
	stats_value.text = "—"
	moves_value.text = "—"
	cards_value.text = "—"


func _disconnect_grimoire() -> void:
	if grimoire == null or not is_instance_valid(grimoire):
		return
	if grimoire.entry_state_changed.is_connected(_on_entry_state_changed):
		grimoire.entry_state_changed.disconnect(_on_entry_state_changed)
	if grimoire.catalog_changed.is_connected(_refresh_catalog):
		grimoire.catalog_changed.disconnect(_refresh_catalog)
