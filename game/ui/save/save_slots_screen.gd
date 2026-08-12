class_name SaveSlotsScreen
extends Control

signal save_slot_requested(slot_index: int)
signal load_slot_requested(slot_index: int)
signal back_requested

enum Mode {
	SAVE,
	LOAD,
}

const MAX_SLOTS: int = 10

@onready var title_label: Label = %TitleLabel
@onready var mode_hint: Label = %ModeHint
@onready var back_button: Button = %BackButton
@onready var _slot_buttons: Array[Button] = [
	%Slot01Button,
	%Slot02Button,
	%Slot03Button,
	%Slot04Button,
	%Slot05Button,
	%Slot06Button,
	%Slot07Button,
	%Slot08Button,
	%Slot09Button,
	%Slot10Button,
]

var _mode: int = Mode.LOAD
var _slot_summaries: Array[Dictionary] = []


func _ready() -> void:
	for index: int in _slot_buttons.size():
		_slot_buttons[index].pressed.connect(_on_slot_pressed.bind(index))
	back_button.pressed.connect(_on_back_pressed)
	_refresh_screen()


func open(mode: int, slot_summaries: Array) -> void:
	_mode = Mode.SAVE if mode == Mode.SAVE else Mode.LOAD
	refresh_slots(slot_summaries)
	show()
	call_deferred("_focus_first_available")


func open_for_save(slot_summaries: Array) -> void:
	open(Mode.SAVE, slot_summaries)


func open_for_load(slot_summaries: Array) -> void:
	open(Mode.LOAD, slot_summaries)


func close() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	hide()


func refresh_slots(slot_summaries: Array) -> void:
	_slot_summaries.clear()
	for summary: Variant in slot_summaries:
		if summary is Dictionary:
			_slot_summaries.append((summary as Dictionary).duplicate(true))
	if is_node_ready():
		_refresh_screen()


func get_mode() -> int:
	return _mode


func _refresh_screen() -> void:
	var saving := _mode == Mode.SAVE
	title_label.text = "Salva partita" if saving else "Carica partita"
	mode_hint.text = (
		"Seleziona uno slot. Uno slot occupato verrà sovrascritto."
		if saving
		else "Seleziona uno dei salvataggi disponibili."
	)
	for index: int in _slot_buttons.size():
		var slot_data := _find_slot_data(index)
		var occupied := _is_occupied(slot_data)
		var button := _slot_buttons[index]
		button.disabled = not saving and not occupied
		button.text = _format_slot_text(index + 1, slot_data, occupied)
		button.tooltip_text = _format_slot_tooltip(index + 1, occupied)
	_configure_focus_navigation()


func _find_slot_data(slot_index: int) -> Dictionary:
	for index: int in _slot_summaries.size():
		var data := _slot_summaries[index]
		var data_slot_index := int(
			data.get("slot_index", data.get("slot", data.get("index", index)))
		)
		if data_slot_index == slot_index:
			return data
	return {}


func _is_occupied(slot_data: Dictionary) -> bool:
	if slot_data.is_empty():
		return false
	if slot_data.has("occupied"):
		return bool(slot_data["occupied"])
	if slot_data.has("exists"):
		return bool(slot_data["exists"])
	if slot_data.has("is_empty"):
		return not bool(slot_data["is_empty"])
	return (
		slot_data.has("saved_at")
		or slot_data.has("saved_at_text")
		or slot_data.has("timestamp")
		or slot_data.has("metadata")
	)


func _format_slot_text(
	slot_number: int,
	slot_data: Dictionary,
	occupied: bool
) -> String:
	if not occupied:
		var empty_action := "Seleziona per salvare" if _mode == Mode.SAVE else "Vuoto"
		return "SLOT %02d\n%s" % [slot_number, empty_action]

	var data := _with_metadata(slot_data)
	var timestamp := _first_text(
		data,
		[&"saved_at_text", &"timestamp_text", &"date", &"saved_at"]
	)
	if timestamp.is_empty():
		timestamp = "Data non disponibile"
	var location := _first_text(
		data,
		[&"location", &"map_name", &"map_id", &"area"]
	)
	if location.is_empty():
		location = "Luogo non disponibile"
	else:
		location = location.replace("_", " ").capitalize()
	var details := _build_details(data)
	var detail_suffix := "" if details.is_empty() else "  •  %s" % details
	return "SLOT %02d  •  %s\n%s%s" % [
		slot_number,
		timestamp,
		location,
		detail_suffix,
	]


func _format_slot_tooltip(slot_number: int, occupied: bool) -> String:
	if _mode == Mode.SAVE:
		return (
			"Sovrascrivi il salvataggio nello slot %d." % slot_number
			if occupied
			else "Crea un salvataggio nello slot %d." % slot_number
		)
	return (
		"Carica lo slot %d." % slot_number
		if occupied
		else "Questo slot è vuoto."
	)


func _with_metadata(slot_data: Dictionary) -> Dictionary:
	var combined := slot_data.duplicate(true)
	var metadata: Variant = slot_data.get("metadata", {})
	if metadata is Dictionary:
		combined.merge(metadata as Dictionary, false)
	return combined


func _build_details(data: Dictionary) -> String:
	var explicit_summary := _first_text(data, [&"summary", &"description"])
	if not explicit_summary.is_empty():
		return explicit_summary
	var details: Array[String] = []
	var level := _first_text(data, [&"player_level", &"level"])
	if not level.is_empty():
		details.append("Livello %s" % level)
	var astral_count := _first_text(
		data,
		[&"astral_count", &"monster_count", &"captured_count"]
	)
	if not astral_count.is_empty():
		details.append("%s Astral" % astral_count)
	var play_time := _first_text(data, [&"play_time", &"play_time_text"])
	if not play_time.is_empty():
		details.append(play_time)
	return "  •  ".join(details)


func _first_text(data: Dictionary, keys: Array[StringName]) -> String:
	for key: StringName in keys:
		if not data.has(key):
			continue
		var value: Variant = data[key]
		if value == null:
			continue
		var text_value := str(value).strip_edges()
		if not text_value.is_empty():
			return text_value
	return ""


func _on_slot_pressed(slot_index: int) -> void:
	if _mode == Mode.SAVE:
		save_slot_requested.emit(slot_index)
	else:
		load_slot_requested.emit(slot_index)


func _on_back_pressed() -> void:
	back_requested.emit()


func _focus_first_available() -> void:
	if not visible:
		return
	for button: Button in _slot_buttons:
		if not button.disabled:
			button.grab_focus()
			return
	back_button.grab_focus()


func _configure_focus_navigation() -> void:
	var available_buttons: Array[Button] = []
	for button: Button in _slot_buttons:
		button.focus_neighbor_top = NodePath()
		button.focus_neighbor_bottom = NodePath()
		button.focus_neighbor_right = button.get_path_to(back_button)
		if not button.disabled:
			available_buttons.append(button)
	for index: int in available_buttons.size():
		var button := available_buttons[index]
		if index > 0:
			button.focus_neighbor_top = button.get_path_to(available_buttons[index - 1])
		if index + 1 < available_buttons.size():
			button.focus_neighbor_bottom = button.get_path_to(available_buttons[index + 1])
	if available_buttons.is_empty():
		back_button.focus_neighbor_top = NodePath()
		return
	available_buttons.back().focus_neighbor_bottom = (
		available_buttons.back().get_path_to(back_button)
	)
	back_button.focus_neighbor_top = back_button.get_path_to(available_buttons.back())
