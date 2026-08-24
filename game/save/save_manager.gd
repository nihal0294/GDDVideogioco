class_name SaveManager
extends Node

signal save_created(slot_index: int)
signal save_deleted(slot_index: int)
signal game_loaded(slot_index: int)
signal operation_failed(message: String)
signal slots_changed
signal map_change_requested(map_id: StringName)

const SAVE_VERSION: int = 1
const MAX_SAVE_SLOTS: int = 10
const DEFAULT_SAVE_DIRECTORY: String = "user://saves"

@export var save_directory: String = DEFAULT_SAVE_DIRECTORY

var _player: CharacterBody3D = null
var _inventory: Inventory = null
var _roster: AstralRoster = null
var _grimoire: Grimoire = null
var _profile: PlayerProfile = null
var _world_map: Node3D = null
var _storage: SaveStorage = LocalFileSaveStorage.new()


func setup(
	player: CharacterBody3D,
	inventory: Inventory,
	roster: AstralRoster,
	grimoire: Grimoire,
	profile: PlayerProfile,
	world_map: Node3D
) -> void:
	_player = player
	_inventory = inventory
	_roster = roster
	_grimoire = grimoire
	_profile = profile
	_world_map = world_map
	_ensure_save_directory()
	slots_changed.emit()


func setup_session(session: PlayerSession, world_map: Node3D) -> void:
	if session == null:
		return
	setup(
		session.actor,
		session.inventory,
		session.astral_roster,
		session.grimoire,
		session.profile,
		world_map
	)


func set_storage(storage: SaveStorage) -> bool:
	if storage == null:
		_report_failure("Storage dei salvataggi non valido.")
		return false
	_storage = storage
	var storage_ready := _ensure_save_directory()
	if storage_ready:
		slots_changed.emit()
	return storage_ready


func get_storage() -> SaveStorage:
	return _storage


func set_world_map(world_map: Node3D) -> void:
	_world_map = world_map


func set_save_directory(path: String) -> bool:
	var normalized := path.strip_edges().trim_suffix("/")
	if not normalized.begins_with("user://") or ".." in normalized:
		_report_failure("La cartella dei salvataggi deve trovarsi in user://.")
		return false
	save_directory = normalized
	var directory_ready := _ensure_save_directory()
	if directory_ready:
		slots_changed.emit()
	return directory_ready


func get_save_directory() -> String:
	return save_directory


func get_current_map_id() -> StringName:
	return _get_map_id()


func get_slot_path(slot_index: int) -> String:
	if not _is_valid_slot(slot_index):
		return ""
	return "%s/save_%02d.json" % [save_directory, slot_index + 1]


func has_saves() -> bool:
	return get_latest_slot_index() >= 0


func get_latest_slot_index() -> int:
	var latest_slot := -1
	var latest_sequence := -1
	var latest_timestamp := -1.0
	for summary: Dictionary in get_slot_summaries():
		if not bool(summary.get("occupied", false)):
			continue
		var sequence := int(summary.get("sequence", 0))
		var timestamp := float(summary.get("saved_at_unix", 0.0))
		if (
			sequence > latest_sequence
			or (sequence == latest_sequence and timestamp > latest_timestamp)
		):
			latest_slot = int(summary.get("slot_index", -1))
			latest_sequence = sequence
			latest_timestamp = timestamp
	return latest_slot


func get_slot_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for slot_index: int in MAX_SAVE_SLOTS:
		var data := _read_slot_data(slot_index, false)
		if data.is_empty():
			summaries.append({
				"slot_index": slot_index,
				"occupied": false,
			})
			continue
		var metadata := data.get("metadata", {}) as Dictionary
		summaries.append({
			"slot_index": slot_index,
			"occupied": true,
			"saved_at_text": str(data.get("saved_at_text", "")),
			"saved_at_unix": float(data.get("saved_at_unix", 0.0)),
			"sequence": int(data.get("sequence", 0)),
			"metadata": metadata.duplicate(true),
		})
	return summaries


func create_save(slot_index: int) -> bool:
	if not _is_valid_slot(slot_index) or not _dependencies_are_ready():
		_report_failure("Slot o stato di gioco non valido.")
		return false
	if not _ensure_save_directory():
		return false

	var now_unix := Time.get_unix_time_from_system()
	var save_data := {
		"save_version": SAVE_VERSION,
		"slot_index": slot_index,
		"sequence": _get_next_sequence(),
		"saved_at_unix": now_unix,
		"saved_at_text": Time.get_datetime_string_from_unix_time(
			int(now_unix),
			true
		),
		"metadata": _build_metadata(),
		"player": _get_player_save_data(),
		"inventory": _inventory.get_save_data(),
		"astrals": _roster.get_save_data(),
		"grimoire": _grimoire.get_save_data(),
		"profile": _profile.get_save_data(),
		"world": _get_world_save_data(),
	}
	if not _storage.write_text(
		get_slot_path(slot_index),
		JSON.stringify(save_data, "\t")
	):
		_report_failure(
			"Impossibile scrivere lo slot %d: errore %d."
			% [slot_index + 1, _storage.get_last_error()]
		)
		return false
	save_created.emit(slot_index)
	slots_changed.emit()
	return true


func load_save(slot_index: int) -> bool:
	if not _is_valid_slot(slot_index) or not _dependencies_are_ready():
		_report_failure("Slot o stato di gioco non valido.")
		return false
	var data := _read_slot_data(slot_index, true)
	if data.is_empty() or not _validate_payload(data):
		return false
	var world_data := data.get("world", {}) as Dictionary
	var saved_map_id := StringName(world_data.get("map_id", &""))
	if not saved_map_id.is_empty() and saved_map_id != _get_map_id():
		map_change_requested.emit(saved_map_id)
		if _get_map_id() != _normalize_legacy_map_id(saved_map_id):
			_report_failure("La mappa del salvataggio non è disponibile.")
			return false

	var roster_data: Variant = data.get("astrals", [])
	if not _roster.load_save_data(roster_data):
		_report_failure("Il salvataggio non contiene una squadra valida.")
		return false
	_inventory.load_save_data(data.get("inventory", {}) as Dictionary)
	_grimoire.load_save_data(data.get("grimoire", {}) as Dictionary)
	_profile.load_save_data(data.get("profile", {}) as Dictionary)
	_apply_player_save_data(data.get("player", {}) as Dictionary)
	_apply_world_save_data(world_data)
	game_loaded.emit(slot_index)
	return true


func delete_save(slot_index: int) -> bool:
	if not _is_valid_slot(slot_index):
		_report_failure("Slot non valido.")
		return false
	var path := get_slot_path(slot_index)
	if not _storage.file_exists(path):
		_report_failure("Lo slot %d è già vuoto." % (slot_index + 1))
		return false
	if not _storage.delete_file(path):
		_report_failure(
			"Impossibile eliminare lo slot %d: errore %d."
			% [slot_index + 1, _storage.get_last_error()]
		)
		return false
	save_deleted.emit(slot_index)
	slots_changed.emit()
	return true


func continue_latest() -> bool:
	var latest_slot := get_latest_slot_index()
	return latest_slot >= 0 and load_save(latest_slot)


func _build_metadata() -> Dictionary:
	var active_astral := _roster.get_active_astral()
	var location_name := String(_get_map_id())
	if _world_map != null and _world_map.has_method("get_location_name"):
		location_name = String(_world_map.call("get_location_name"))
	return {
		"map_id": String(_get_map_id()),
		"location": location_name,
		"player_level": active_astral.level if active_astral != null else 1,
		"astral_count": _roster.get_total_astral_count(),
		"captured_count": _profile.captured_monster_count,
	}


func _get_player_save_data() -> Dictionary:
	var visual := _player.get_node_or_null("Visual") as Node3D
	return {
		"position": _vector3_to_array(_player.global_position),
		"visual_rotation_y": visual.rotation.y if visual != null else 0.0,
	}


func _apply_player_save_data(data: Dictionary) -> void:
	var position := _array_to_vector3(data.get("position", []), _player.global_position)
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	var visual := _player.get_node_or_null("Visual") as Node3D
	if visual != null:
		visual.rotation.y = _finite_float(
			data.get("visual_rotation_y", visual.rotation.y),
			visual.rotation.y
		)


func _get_world_save_data() -> Dictionary:
	var interactable_stock: Dictionary = {}
	if _world_map.has_method("get_interactables"):
		var raw_interactables: Variant = _world_map.call("get_interactables")
		if raw_interactables is Array:
			for candidate: Variant in raw_interactables:
				var interactable := candidate as InteractableArea3D
				if interactable != null and not interactable.interaction_id.is_empty():
					interactable_stock[String(interactable.interaction_id)] = (
						interactable.remaining_item_count
					)
	var result := {
		"map_id": String(_get_map_id()),
		"interactable_stock": interactable_stock,
	}
	if _world_map.has_method("get_trainer_save_data"):
		var trainer_data: Variant = _world_map.call("get_trainer_save_data")
		if trainer_data is Dictionary:
			result["trainers"] = (trainer_data as Dictionary).duplicate(true)
	if _world_map.has_method("get_npc_save_data"):
		var npc_data: Variant = _world_map.call("get_npc_save_data")
		if npc_data is Dictionary:
			result["npcs"] = (npc_data as Dictionary).duplicate(true)
	var day_night := _get_day_night_cycle()
	if day_night != null:
		result["time"] = day_night.get_save_data()
	return result


func _apply_world_save_data(data: Dictionary) -> void:
	var time_data: Variant = data.get("time", {})
	var day_night := _get_day_night_cycle()
	if day_night != null and time_data is Dictionary:
		day_night.load_save_data(time_data as Dictionary)
	var raw_trainers: Variant = data.get("trainers", {})
	if (
		raw_trainers is Dictionary
		and _world_map.has_method("load_trainer_save_data")
	):
		_world_map.call(
			"load_trainer_save_data",
			raw_trainers as Dictionary
		)
	var raw_npcs: Variant = data.get("npcs", {})
	if raw_npcs is Dictionary and _world_map.has_method("load_npc_save_data"):
		_world_map.call("load_npc_save_data", raw_npcs as Dictionary)
	var raw_stock: Variant = data.get("interactable_stock", {})
	if not (raw_stock is Dictionary) or not _world_map.has_method("get_interactables"):
		return
	var stock := raw_stock as Dictionary
	var raw_interactables: Variant = _world_map.call("get_interactables")
	if not (raw_interactables is Array):
		return
	for candidate: Variant in raw_interactables:
		var interactable := candidate as InteractableArea3D
		if interactable == null or interactable.interaction_id.is_empty():
			continue
		var key := String(interactable.interaction_id)
		if stock.has(key):
			interactable.set_remaining_item_count(int(stock[key]))


func _get_day_night_cycle() -> DayNightCycle:
	if _world_map == null:
		return null
	return _world_map.get_node_or_null("TimeOfDay") as DayNightCycle


func _get_map_id() -> StringName:
	if _world_map == null:
		return &""
	if _world_map.has_method("get_map_id"):
		return _normalize_legacy_map_id(
			StringName(_world_map.call("get_map_id"))
		)
	return StringName(_world_map.name.to_snake_case())


func _normalize_legacy_map_id(map_id: StringName) -> StringName:
	if map_id == &"world_map" or map_id == &"verdant_valley":
		return &"verdant_forest"
	return map_id


func _read_slot_data(slot_index: int, report_errors: bool) -> Dictionary:
	var path := get_slot_path(slot_index)
	if path.is_empty() or not _storage.file_exists(path):
		if report_errors:
			_report_failure("Lo slot %d è vuoto." % (slot_index + 1))
		return {}
	var raw_content := _storage.read_text(path)
	if raw_content.is_empty() and _storage.get_last_error() != OK:
		if report_errors:
			_report_failure("Impossibile leggere lo slot %d." % (slot_index + 1))
		return {}
	var json := JSON.new()
	var parse_error := json.parse(raw_content)
	if parse_error != OK or not (json.data is Dictionary):
		if report_errors:
			_report_failure("Il salvataggio nello slot %d è danneggiato." % (slot_index + 1))
		return {}
	var data := json.data as Dictionary
	if int(data.get("save_version", -1)) != SAVE_VERSION:
		if report_errors:
			_report_failure("Versione del salvataggio non supportata.")
		return {}
	return data


func _validate_payload(data: Dictionary) -> bool:
	var required_dictionaries: Array[String] = [
		"player", "inventory", "grimoire", "profile", "world",
	]
	for key: String in required_dictionaries:
		if not (data.get(key, null) is Dictionary):
			_report_failure("Il salvataggio è incompleto (%s)." % key)
			return false
	var astral_data: Variant = data.get("astrals", null)
	if not (astral_data is Array or astral_data is Dictionary):
		_report_failure("Il salvataggio non contiene una squadra valida.")
		return false
	return true


func _get_next_sequence() -> int:
	var maximum_sequence := 0
	for summary: Dictionary in get_slot_summaries():
		maximum_sequence = maxi(maximum_sequence, int(summary.get("sequence", 0)))
	return maximum_sequence + 1


func _ensure_save_directory() -> bool:
	if not save_directory.begins_with("user://") or ".." in save_directory:
		_report_failure("Cartella dei salvataggi non valida.")
		return false
	if _storage == null or not _storage.ensure_directory(save_directory):
		_report_failure("Impossibile creare la cartella dei salvataggi.")
		return false
	return true


func _dependencies_are_ready() -> bool:
	return (
		_player != null
		and _inventory != null
		and _roster != null
		and _grimoire != null
		and _profile != null
		and _world_map != null
	)


func _is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < MAX_SAVE_SLOTS


func _report_failure(message: String) -> void:
	operation_failed.emit(message)
	push_warning(message)


static func _vector3_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func _array_to_vector3(value: Variant, fallback: Vector3) -> Vector3:
	if not (value is Array) or (value as Array).size() != 3:
		return fallback
	var values := value as Array
	return Vector3(
		_finite_float(values[0], fallback.x),
		_finite_float(values[1], fallback.y),
		_finite_float(values[2], fallback.z)
	)


static func _finite_float(value: Variant, fallback: float) -> float:
	if value is int:
		return float(value)
	if value is float and is_finite(float(value)):
		return float(value)
	return fallback
