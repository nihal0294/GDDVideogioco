class_name Grimoire
extends Node

signal entry_state_changed(entry_id: StringName)
signal catalog_changed()

enum DiscoveryState {
	UNKNOWN,
	SEEN,
	CAPTURED,
}

@export var catalog: Array[GrimoireEntry] = []

var _discovery_states: Dictionary[StringName, int] = {}
var _roster: AstralRoster = null


func setup(roster: AstralRoster) -> void:
	_disconnect_roster()
	_roster = roster
	if _roster != null:
		if not _roster.astral_captured.is_connected(_on_astral_captured):
			_roster.astral_captured.connect(_on_astral_captured)
		for astral: AstralInstance in _roster.get_astrals():
			register_captured(astral.definition)
	catalog_changed.emit()


func get_entries() -> Array[GrimoireEntry]:
	var entries: Array[GrimoireEntry] = []
	entries.assign(catalog)
	entries.sort_custom(_sort_entries_by_number)
	return entries


func get_entry(entry_id: StringName) -> GrimoireEntry:
	for entry: GrimoireEntry in catalog:
		if entry != null and entry.get_entry_id() == entry_id:
			return entry
	return null


func register_seen(definition: AstralDefinition) -> bool:
	return _set_discovery_state(definition, DiscoveryState.SEEN)


func register_captured(definition: AstralDefinition) -> bool:
	return _set_discovery_state(definition, DiscoveryState.CAPTURED)


func get_discovery_state(entry_id: StringName) -> int:
	return int(_discovery_states.get(entry_id, DiscoveryState.UNKNOWN))


func is_seen(entry_id: StringName) -> bool:
	return get_discovery_state(entry_id) >= DiscoveryState.SEEN


func is_captured(entry_id: StringName) -> bool:
	return get_discovery_state(entry_id) == DiscoveryState.CAPTURED


func get_seen_species_count() -> int:
	var count := 0
	for state_value: Variant in _discovery_states.values():
		var state := int(state_value)
		if state >= DiscoveryState.SEEN:
			count += 1
	return count


func get_captured_species_count() -> int:
	var count := 0
	for state_value: Variant in _discovery_states.values():
		var state := int(state_value)
		if state == DiscoveryState.CAPTURED:
			count += 1
	return count


func get_save_data() -> Dictionary:
	var states: Dictionary = {}
	for entry_id: StringName in _discovery_states:
		states[String(entry_id)] = _discovery_states[entry_id]
	return states


func load_save_data(data: Dictionary) -> void:
	_discovery_states.clear()
	for raw_entry_id: Variant in data:
		if not (raw_entry_id is String or raw_entry_id is StringName):
			continue
		var entry_id := StringName(raw_entry_id)
		if get_entry(entry_id) == null:
			continue
		var raw_state: Variant = data[raw_entry_id]
		if not (raw_state is int) and not (
			raw_state is float and is_finite(float(raw_state))
		):
			continue
		var state := clampi(
			int(raw_state),
			DiscoveryState.UNKNOWN,
			DiscoveryState.CAPTURED
		)
		if state == DiscoveryState.UNKNOWN:
			continue
		_discovery_states[entry_id] = state
	if _roster != null:
		for astral: AstralInstance in _roster.get_astrals():
			if astral == null or astral.definition == null:
				continue
			var astral_id := astral.definition.astral_id
			if get_entry(astral_id) != null:
				_discovery_states[astral_id] = DiscoveryState.CAPTURED
	for entry: GrimoireEntry in catalog:
		if entry != null:
			entry_state_changed.emit(entry.get_entry_id())
	catalog_changed.emit()


func _set_discovery_state(
	definition: AstralDefinition,
	new_state: DiscoveryState
) -> bool:
	if definition == null or definition.astral_id.is_empty():
		return false
	if get_entry(definition.astral_id) == null:
		return false
	var current_state := get_discovery_state(definition.astral_id)
	if current_state >= new_state:
		return false
	_discovery_states[definition.astral_id] = new_state
	entry_state_changed.emit(definition.astral_id)
	return true


func _on_astral_captured(astral: AstralInstance) -> void:
	if astral != null:
		register_captured(astral.definition)


func _disconnect_roster() -> void:
	if (
		_roster != null
		and is_instance_valid(_roster)
		and _roster.astral_captured.is_connected(_on_astral_captured)
	):
		_roster.astral_captured.disconnect(_on_astral_captured)
	_roster = null


func _sort_entries_by_number(
	first: GrimoireEntry,
	second: GrimoireEntry
) -> bool:
	if first == null:
		return false
	if second == null:
		return true
	return first.entry_number < second.entry_number
