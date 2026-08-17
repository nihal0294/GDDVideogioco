class_name AstralRoster
extends Node

signal astral_captured(astral: AstralInstance)
signal roster_changed()
signal roster_reordered(from_index: int, to_index: int)
signal active_astral_changed(astral: AstralInstance)
signal storage_changed()
signal astral_released(astral: AstralInstance)
signal astral_evolved(
	astral: AstralInstance,
	previous_definition: AstralDefinition,
	new_definition: AstralDefinition
)

const MAX_PARTY_SIZE: int = 6
const BOX_COUNT: int = 50
const BOX_CAPACITY: int = 30

@export var starter: AstralDefinition
@export var starter_id: StringName = &"venomquill"
@export_range(1, 999, 1) var starter_level: int = 5

var _astrals: Array[AstralInstance] = []
var _boxes: Array[Array] = []
var _last_captured_astral: AstralInstance = null

func _ready() -> void:
	_ensure_boxes()
	if starter == null:
		starter = AstralCatalog.load_definition(starter_id)
	if starter == null or not _astrals.is_empty():
		return
	var starter_instance := AstralInstance.new()
	starter_instance.setup(starter, starter_level)
	_astrals.append(starter_instance)
	active_astral_changed.emit(starter_instance)
	roster_changed.emit()


func get_active_astral() -> AstralInstance:
	if _astrals.is_empty():
		return null
	return _astrals.front()


func get_astral_count() -> int:
	return _astrals.size()


func get_astral(index: int) -> AstralInstance:
	if index < 0 or index >= _astrals.size():
		return null
	return _astrals[index]


func get_astrals() -> Array[AstralInstance]:
	var astrals: Array[AstralInstance] = []
	astrals.assign(_astrals)
	return astrals


func get_all_astrals() -> Array[AstralInstance]:
	var result := get_astrals()
	_ensure_boxes()
	for box: Array in _boxes:
		for candidate: Variant in box:
			var astral := candidate as AstralInstance
			if astral != null:
				result.append(astral)
	return result


## Cura temporanea di tutta la squadra attiva. Non coinvolge gli Astral nei Box.
func heal_party_to_full() -> int:
	var healed_count := 0
	for astral: AstralInstance in _astrals:
		if astral == null or astral.definition == null:
			continue
		var maximum_health := astral.get_max_health()
		if astral.current_health >= maximum_health:
			continue
		astral.current_health = maximum_health
		healed_count += 1
	if healed_count > 0:
		roster_changed.emit()
	return healed_count


func get_total_astral_count() -> int:
	return get_all_astrals().size()


func get_box_count() -> int:
	return BOX_COUNT


func get_box_capacity() -> int:
	return BOX_CAPACITY


func get_box_astrals(box_index: int) -> Array[AstralInstance]:
	var result: Array[AstralInstance] = []
	if not _is_valid_box_index(box_index):
		return result
	_ensure_boxes()
	for candidate: Variant in _boxes[box_index]:
		result.append(candidate as AstralInstance)
	return result


func get_box_astral(box_index: int, slot_index: int) -> AstralInstance:
	if not _is_valid_box_slot(box_index, slot_index):
		return null
	_ensure_boxes()
	return _boxes[box_index][slot_index] as AstralInstance


func get_last_captured_astral() -> AstralInstance:
	return _last_captured_astral


func get_available_evolutions(
	astral: AstralInstance,
	inventory: Inventory = null
) -> Array[AstralEvolutionOption]:
	var available: Array[AstralEvolutionOption] = []
	if astral == null or not get_all_astrals().has(astral):
		return available
	for option: AstralEvolutionOption in astral.get_available_evolutions():
		if option.method == AstralEvolutionOption.Method.ITEM:
			if inventory == null or inventory.get_quantity(option.required_item_id) <= 0:
				continue
		available.append(option)
	return available


func evolve_astral(
	astral: AstralInstance,
	option: AstralEvolutionOption,
	inventory: Inventory = null
) -> bool:
	if astral == null or not get_all_astrals().has(astral):
		return false
	if not astral.can_evolve_with(option):
		return false
	if option.method == AstralEvolutionOption.Method.ITEM:
		if inventory == null or inventory.get_quantity(option.required_item_id) <= 0:
			return false
	var previous_definition := astral.definition
	var consumed_item := false
	if option.method == AstralEvolutionOption.Method.ITEM:
		consumed_item = inventory.consume_targeted_item(option.required_item_id)
		if not consumed_item:
			return false
	if not astral.evolve_with(option):
		if consumed_item:
			inventory.add_item(option.required_item_id, 1)
		return false
	astral_evolved.emit(astral, previous_definition, astral.definition)
	roster_changed.emit()
	return true


func get_usable_astral_indices(exclude_active: bool = false) -> Array[int]:
	var usable_indices: Array[int] = []
	for index: int in _astrals.size():
		if exclude_active and index == 0:
			continue
		var astral := _astrals[index]
		if astral != null and not astral.is_defeated():
			usable_indices.append(index)
	return usable_indices


func has_usable_astral(exclude_active: bool = false) -> bool:
	for index: int in _astrals.size():
		if exclude_active and index == 0:
			continue
		var astral := _astrals[index]
		if astral != null and not astral.is_defeated():
			return true
	return false


func move_astral(from_index: int, to_index: int) -> bool:
	if not _is_valid_index(from_index) or not _is_valid_index(to_index):
		return false
	if from_index == to_index:
		return true
	var previous_active := get_active_astral()
	var astral: AstralInstance = _astrals.pop_at(from_index)
	_astrals.insert(to_index, astral)
	_emit_reorder_signals(from_index, to_index, previous_active)
	return true


func swap_astrals(first_index: int, second_index: int) -> bool:
	if not _is_valid_index(first_index) or not _is_valid_index(second_index):
		return false
	if first_index == second_index:
		return true
	var previous_active := get_active_astral()
	var first_astral := _astrals[first_index]
	_astrals[first_index] = _astrals[second_index]
	_astrals[second_index] = first_astral
	_emit_reorder_signals(first_index, second_index, previous_active)
	return true


func set_active_astral(index: int) -> bool:
	if not _is_valid_index(index):
		return false
	return move_astral(index, 0)


func deposit_astral(
	party_index: int,
	box_index: int,
	slot_index: int = -1
) -> bool:
	if not _is_valid_index(party_index) or _astrals.size() <= 1:
		return false
	var destination_slot := slot_index
	if destination_slot < 0:
		destination_slot = _find_first_empty_slot(box_index)
	if (
		not _is_valid_box_slot(box_index, destination_slot)
		or get_box_astral(box_index, destination_slot) != null
	):
		return false
	var previous_active := get_active_astral()
	var astral: AstralInstance = _astrals.pop_at(party_index)
	_boxes[box_index][destination_slot] = astral
	_emit_party_and_storage_changed(previous_active)
	return true


func withdraw_astral(box_index: int, slot_index: int) -> bool:
	if _astrals.size() >= MAX_PARTY_SIZE:
		return false
	var astral := get_box_astral(box_index, slot_index)
	if astral == null:
		return false
	var previous_active := get_active_astral()
	_boxes[box_index][slot_index] = null
	_astrals.append(astral)
	_emit_party_and_storage_changed(previous_active)
	return true


func swap_party_with_box(
	party_index: int,
	box_index: int,
	slot_index: int
) -> bool:
	if not _is_valid_index(party_index):
		return false
	var stored_astral := get_box_astral(box_index, slot_index)
	if stored_astral == null:
		return false
	var previous_active := get_active_astral()
	var party_astral := _astrals[party_index]
	_astrals[party_index] = stored_astral
	_boxes[box_index][slot_index] = party_astral
	_emit_party_and_storage_changed(previous_active)
	return true


func move_box_astral(
	from_box: int,
	from_slot: int,
	to_box: int,
	to_slot: int
) -> bool:
	var source := get_box_astral(from_box, from_slot)
	if source == null or not _is_valid_box_slot(to_box, to_slot):
		return false
	if from_box == to_box and from_slot == to_slot:
		return true
	var destination := get_box_astral(to_box, to_slot)
	_boxes[to_box][to_slot] = source
	_boxes[from_box][from_slot] = destination
	storage_changed.emit()
	roster_changed.emit()
	return true


func release_party_astral(party_index: int) -> bool:
	if not _is_valid_index(party_index) or _astrals.size() <= 1:
		return false
	var previous_active := get_active_astral()
	var released: AstralInstance = _astrals.pop_at(party_index)
	astral_released.emit(released)
	_emit_party_and_storage_changed(previous_active)
	return true


func release_box_astral(box_index: int, slot_index: int) -> bool:
	var released := get_box_astral(box_index, slot_index)
	if released == null:
		return false
	_boxes[box_index][slot_index] = null
	astral_released.emit(released)
	storage_changed.emit()
	roster_changed.emit()
	return true


func capture_astral(instance: AstralInstance) -> bool:
	if instance == null or instance.definition == null:
		return false

	var previous_active := get_active_astral()
	var captured_astral := instance.duplicate_runtime()
	_last_captured_astral = captured_astral
	if _astrals.size() < MAX_PARTY_SIZE:
		_astrals.append(captured_astral)
	else:
		var empty_slot := _find_first_empty_storage_slot()
		if empty_slot.x < 0:
			_last_captured_astral = null
			return false
		_boxes[empty_slot.x][empty_slot.y] = captured_astral
	astral_captured.emit(captured_astral)
	if get_active_astral() != previous_active:
		active_astral_changed.emit(get_active_astral())
	storage_changed.emit()
	roster_changed.emit()
	return true


func get_save_data() -> Dictionary:
	var saved_party: Array[Dictionary] = []
	for astral: AstralInstance in _astrals:
		if astral != null and astral.definition != null:
			saved_party.append(astral.get_save_data())
	_ensure_boxes()
	var saved_boxes: Array = []
	for box: Array in _boxes:
		var saved_slots: Array = []
		for candidate: Variant in box:
			var astral := candidate as AstralInstance
			if astral != null and astral.definition != null:
				saved_slots.append(astral.get_save_data())
			else:
				saved_slots.append(null)
		saved_boxes.append(saved_slots)
	return {
		"format_version": 2,
		"party": saved_party,
		"boxes": saved_boxes,
	}


func load_save_data(data: Variant) -> bool:
	var raw_party: Array = []
	var raw_boxes: Array = []
	if data is Array:
		raw_party = data as Array
	elif data is Dictionary:
		var data_dictionary := data as Dictionary
		var party_value: Variant = data_dictionary.get("party", [])
		var boxes_value: Variant = data_dictionary.get("boxes", [])
		if party_value is Array:
			raw_party = party_value as Array
		if boxes_value is Array:
			raw_boxes = boxes_value as Array
	else:
		return false
	var loaded_party: Array[AstralInstance] = []
	var loaded_boxes := _create_empty_boxes()
	var astral_definitions := _load_astral_definitions()
	var move_definitions := _load_move_definitions()
	for raw_astral: Variant in raw_party:
		var loaded_astral := _deserialize_astral(
			raw_astral,
			astral_definitions,
			move_definitions
		)
		if loaded_astral == null:
			continue
		if loaded_party.size() < MAX_PARTY_SIZE:
			loaded_party.append(loaded_astral)
		else:
			_store_in_first_empty_slot(loaded_boxes, loaded_astral)
	if loaded_party.is_empty():
		return false
	for box_index: int in mini(raw_boxes.size(), BOX_COUNT):
		var raw_box: Variant = raw_boxes[box_index]
		if not (raw_box is Array):
			continue
		var raw_slots := raw_box as Array
		for slot_index: int in mini(raw_slots.size(), BOX_CAPACITY):
			if loaded_boxes[box_index][slot_index] != null:
				continue
			var loaded_astral := _deserialize_astral(
				raw_slots[slot_index],
				astral_definitions,
				move_definitions
			)
			if loaded_astral != null:
				loaded_boxes[box_index][slot_index] = loaded_astral
	var previous_active := get_active_astral()
	_astrals.assign(loaded_party)
	_boxes.assign(loaded_boxes)
	_last_captured_astral = null
	if get_active_astral() != previous_active:
		active_astral_changed.emit(get_active_astral())
	storage_changed.emit()
	roster_changed.emit()
	return true


func _deserialize_astral(
	raw_astral: Variant,
	astral_definitions: Dictionary[StringName, AstralDefinition],
	move_definitions: Dictionary[StringName, AstralMoveDefinition]
) -> AstralInstance:
	if not (raw_astral is Dictionary):
		return null
	var astral_data := raw_astral as Dictionary
	var raw_astral_id: Variant = astral_data.get("astral_id", "")
	if not (raw_astral_id is String or raw_astral_id is StringName):
		return null
	var normalized_id := AstralCatalog.normalize_astral_id(
		StringName(raw_astral_id)
	)
	var definition := astral_definitions.get(normalized_id) as AstralDefinition
	if definition == null:
		return null
	var normalized_data := astral_data.duplicate(true)
	normalized_data["astral_id"] = String(normalized_id)
	var instance := AstralInstance.new()
	if not instance.load_save_data(normalized_data, definition, move_definitions):
		return null
	return instance


func _ensure_boxes() -> void:
	if _boxes.size() == BOX_COUNT:
		return
	_boxes = _create_empty_boxes()


func _create_empty_boxes() -> Array[Array]:
	var boxes: Array[Array] = []
	for _box_index: int in BOX_COUNT:
		var slots: Array[AstralInstance] = []
		slots.resize(BOX_CAPACITY)
		slots.fill(null)
		boxes.append(slots)
	return boxes


func _find_first_empty_slot(box_index: int) -> int:
	if not _is_valid_box_index(box_index):
		return -1
	_ensure_boxes()
	for slot_index: int in BOX_CAPACITY:
		if _boxes[box_index][slot_index] == null:
			return slot_index
	return -1


func _find_first_empty_storage_slot() -> Vector2i:
	_ensure_boxes()
	for box_index: int in BOX_COUNT:
		var slot_index := _find_first_empty_slot(box_index)
		if slot_index >= 0:
			return Vector2i(box_index, slot_index)
	return Vector2i(-1, -1)


func _store_in_first_empty_slot(
	boxes: Array[Array],
	astral: AstralInstance
) -> bool:
	for box_index: int in boxes.size():
		for slot_index: int in boxes[box_index].size():
			if boxes[box_index][slot_index] == null:
				boxes[box_index][slot_index] = astral
				return true
	return false


func _load_astral_definitions() -> Dictionary[StringName, AstralDefinition]:
	return AstralCatalog.load_definitions()


func _load_move_definitions() -> Dictionary[StringName, AstralMoveDefinition]:
	return AstralCatalog.load_moves()


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < _astrals.size()


func _is_valid_box_index(box_index: int) -> bool:
	return box_index >= 0 and box_index < BOX_COUNT


func _is_valid_box_slot(box_index: int, slot_index: int) -> bool:
	return _is_valid_box_index(box_index) and slot_index >= 0 and slot_index < BOX_CAPACITY


func _emit_party_and_storage_changed(previous_active: AstralInstance) -> void:
	if get_active_astral() != previous_active:
		active_astral_changed.emit(get_active_astral())
	storage_changed.emit()
	roster_changed.emit()


func _emit_reorder_signals(
	from_index: int,
	to_index: int,
	previous_active: AstralInstance
) -> void:
	roster_reordered.emit(from_index, to_index)
	if get_active_astral() != previous_active:
		active_astral_changed.emit(get_active_astral())
	roster_changed.emit()
