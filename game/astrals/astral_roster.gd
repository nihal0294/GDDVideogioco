class_name AstralRoster
extends Node

signal astral_captured(astral: AstralInstance)
signal roster_changed()
signal roster_reordered(from_index: int, to_index: int)
signal active_astral_changed(astral: AstralInstance)

@export var starter: AstralDefinition
@export_range(1, 999, 1) var starter_level: int = 5

var _astrals: Array[AstralInstance] = []

const ASTRAL_DEFINITION_PATHS: Array[String] = [
	"res://data/astrals/player_placeholder.tres",
	"res://data/astrals/wyrm_di_lava.tres",
	"res://data/astrals/topo_onda.tres",
	"res://data/astrals/orso_fatato.tres",
	"res://data/astrals/slime_arcobaleno.tres",
	"res://data/astrals/wild_placeholder.tres",
]

const MOVE_DEFINITION_PATHS: Array[String] = [
	"res://data/moves/impatto_astrale.tres",
	"res://data/moves/frusta_di_liane.tres",
	"res://data/moves/lamafoglia.tres",
	"res://data/moves/assalto_radice.tres",
	"res://data/moves/scintilla.tres",
	"res://data/moves/fiammata.tres",
	"res://data/moves/carica_rovente.tres",
	"res://data/moves/spruzzo.tres",
	"res://data/moves/onda_crescente.tres",
	"res://data/moves/marea_impetuosa.tres",
	"res://data/moves/colpo_rapido.tres",
	"res://data/moves/urto_possente.tres",
	"res://data/moves/esplosione_astrale.tres",
]


func _ready() -> void:
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


func capture_astral(instance: AstralInstance) -> bool:
	if instance == null or instance.definition == null:
		return false

	var previous_active := get_active_astral()
	var captured_astral := instance.duplicate_runtime()
	_astrals.append(captured_astral)
	astral_captured.emit(captured_astral)
	if get_active_astral() != previous_active:
		active_astral_changed.emit(get_active_astral())
	roster_changed.emit()
	return true


func get_save_data() -> Array[Dictionary]:
	var saved_astrals: Array[Dictionary] = []
	for astral: AstralInstance in _astrals:
		if astral != null and astral.definition != null:
			saved_astrals.append(astral.get_save_data())
	return saved_astrals


func load_save_data(data: Array) -> bool:
	var loaded_astrals: Array[AstralInstance] = []
	var astral_definitions := _load_astral_definitions()
	var move_definitions := _load_move_definitions()
	for raw_astral: Variant in data:
		if not (raw_astral is Dictionary):
			continue
		var astral_data := raw_astral as Dictionary
		var raw_astral_id: Variant = astral_data.get("astral_id", "")
		if not (raw_astral_id is String or raw_astral_id is StringName):
			continue
		var astral_id := StringName(raw_astral_id)
		var definition := astral_definitions.get(astral_id) as AstralDefinition
		if definition == null:
			continue
		var instance := AstralInstance.new()
		if not instance.load_save_data(
			astral_data,
			definition,
			move_definitions
		):
			continue
		loaded_astrals.append(instance)
	if loaded_astrals.is_empty():
		return false
	var previous_active := get_active_astral()
	_astrals.assign(loaded_astrals)
	if get_active_astral() != previous_active:
		active_astral_changed.emit(get_active_astral())
	roster_changed.emit()
	return true


func _load_astral_definitions() -> Dictionary[StringName, AstralDefinition]:
	var definitions: Dictionary[StringName, AstralDefinition] = {}
	for path: String in ASTRAL_DEFINITION_PATHS:
		var definition := load(path) as AstralDefinition
		if definition != null and not definition.astral_id.is_empty():
			definitions[definition.astral_id] = definition
	return definitions


func _load_move_definitions() -> Dictionary[StringName, AstralMoveDefinition]:
	var definitions: Dictionary[StringName, AstralMoveDefinition] = {}
	for path: String in MOVE_DEFINITION_PATHS:
		var definition := load(path) as AstralMoveDefinition
		if definition != null and not definition.move_id.is_empty():
			definitions[definition.move_id] = definition
	return definitions


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < _astrals.size()


func _emit_reorder_signals(
	from_index: int,
	to_index: int,
	previous_active: AstralInstance
) -> void:
	roster_reordered.emit(from_index, to_index)
	if get_active_astral() != previous_active:
		active_astral_changed.emit(get_active_astral())
	roster_changed.emit()
