class_name AstralDefinition
extends Resource

const MIN_BASE_STAT: int = 5
const MAX_BASE_STAT: int = 255
const MAX_BASE_STAT_TOTAL: int = 1200

var _max_health: int = 50
var _attack_power: int = 50
var _physical_defense: int = 50
var _magic_attack: int = 50
var _magic_defense: int = 50
var _speed: int = 50

@export_group("Identità")
@export var astral_id: StringName = &""
@export var display_name: String = "Astral"
@export_multiline var description: String = ""
@export var primary_element: StringName = &"neutro"
@export var secondary_element: StringName = &""
@export var species_name: String = "Sconosciuta"

@export_group("Statistiche base")
@export_range(5, 255, 1) var max_health: int:
	get:
		return _max_health
	set(value):
		_max_health = _clamp_base_stat(value, _max_health)
@export_range(5, 255, 1) var attack_power: int:
	get:
		return _attack_power
	set(value):
		_attack_power = _clamp_base_stat(value, _attack_power)
@export_range(5, 255, 1) var physical_defense: int:
	get:
		return _physical_defense
	set(value):
		_physical_defense = _clamp_base_stat(value, _physical_defense)
@export_range(5, 255, 1) var magic_attack: int:
	get:
		return _magic_attack
	set(value):
		_magic_attack = _clamp_base_stat(value, _magic_attack)
@export_range(5, 255, 1) var magic_defense: int:
	get:
		return _magic_defense
	set(value):
		_magic_defense = _clamp_base_stat(value, _magic_defense)
@export_range(5, 255, 1) var speed: int:
	get:
		return _speed
	set(value):
		_speed = _clamp_base_stat(value, _speed)

@export_group("Progressione e combattimento")
@export_range(0, 99999, 1) var experience_yield: int = 25
@export var starting_moves: Array[AstralMoveDefinition] = []
@export var learnset: Array[AstralLearnsetEntry] = []
@export var evolution_options: Array[AstralEvolutionOption] = []
@export var visual_color: Color = Color(0.45, 0.75, 1.0, 1.0)

@export_group("Modello 3D")
@export_file("*.glb", "*.gltf", "*.tscn") var model_path: String = ""
@export_range(0.01, 10.0, 0.01) var model_scale_multiplier: float = 1.0
@export var model_rotation_degrees := Vector3.ZERO

var _cached_model_scene: PackedScene = null
var _model_load_requested: bool = false


func get_base_stat_total() -> int:
	return (
		_max_health
		+ _attack_power
		+ _physical_defense
		+ _magic_attack
		+ _magic_defense
		+ _speed
	)


func get_model_scene() -> PackedScene:
	if _cached_model_scene != null:
		return _cached_model_scene
	if model_path.is_empty():
		return null
	request_model_scene_load()
	if _model_load_requested:
		_cached_model_scene = ResourceLoader.load_threaded_get(
			model_path
		) as PackedScene
		_model_load_requested = false
	else:
		_cached_model_scene = load(model_path) as PackedScene
	return _cached_model_scene


func request_model_scene_load() -> void:
	if _cached_model_scene != null or model_path.is_empty():
		return
	if ResourceLoader.has_cached(model_path):
		_cached_model_scene = load(model_path) as PackedScene
		return
	if _model_load_requested:
		return
	var load_error := ResourceLoader.load_threaded_request(
		model_path,
		"PackedScene",
		true,
		ResourceLoader.CACHE_MODE_REUSE
	)
	_model_load_requested = load_error == OK or load_error == ERR_BUSY


func poll_model_scene_load() -> int:
	if _cached_model_scene != null:
		return ResourceLoader.THREAD_LOAD_LOADED
	if model_path.is_empty():
		return ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
	request_model_scene_load()
	if not _model_load_requested:
		return ResourceLoader.THREAD_LOAD_FAILED
	var status := ResourceLoader.load_threaded_get_status(model_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_cached_model_scene = ResourceLoader.load_threaded_get(
			model_path
		) as PackedScene
		_model_load_requested = false
	elif (
		status == ResourceLoader.THREAD_LOAD_FAILED
		or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
	):
		_model_load_requested = false
	return status


func has_valid_base_stats() -> bool:
	return (
		get_base_stat_total() <= MAX_BASE_STAT_TOTAL
		and _is_valid_base_stat(_max_health)
		and _is_valid_base_stat(_attack_power)
		and _is_valid_base_stat(_physical_defense)
		and _is_valid_base_stat(_magic_attack)
		and _is_valid_base_stat(_magic_defense)
		and _is_valid_base_stat(_speed)
	)


func set_base_stats(
	base_health: int,
	base_attack: int,
	base_physical_defense: int,
	base_magic_attack: int,
	base_magic_defense: int,
	base_speed: int
) -> bool:
	var values: Array[int] = [
		base_health,
		base_attack,
		base_physical_defense,
		base_magic_attack,
		base_magic_defense,
		base_speed,
	]
	var total := 0
	for stat_value: int in values:
		if not _is_valid_base_stat(stat_value):
			return false
		total += stat_value
	if total > MAX_BASE_STAT_TOTAL:
		return false
	_max_health = base_health
	_attack_power = base_attack
	_physical_defense = base_physical_defense
	_magic_attack = base_magic_attack
	_magic_defense = base_magic_defense
	_speed = base_speed
	emit_changed()
	return true


func get_elements() -> Array[StringName]:
	var elements: Array[StringName] = []
	if not primary_element.is_empty():
		elements.append(primary_element)
	if (
		not secondary_element.is_empty()
		and secondary_element != primary_element
	):
		elements.append(secondary_element)
	return elements


func has_element(element_id: StringName) -> bool:
	if element_id.is_empty():
		return false
	return (
		primary_element == element_id
		or secondary_element == element_id
	)


func get_all_moves() -> Array[AstralMoveDefinition]:
	var result: Array[AstralMoveDefinition] = []
	for move: AstralMoveDefinition in starting_moves:
		_append_unique_move(result, move)
	for entry: AstralLearnsetEntry in learnset:
		if entry != null:
			_append_unique_move(result, entry.move)
	return result


func get_moves_available_at_level(level: int) -> Array[AstralMoveDefinition]:
	var result: Array[AstralMoveDefinition] = []
	for move: AstralMoveDefinition in starting_moves:
		_append_unique_move(result, move)
	var sorted_entries: Array[AstralLearnsetEntry] = []
	sorted_entries.assign(learnset)
	sorted_entries.sort_custom(
		func(first: AstralLearnsetEntry, second: AstralLearnsetEntry) -> bool:
			return first.required_level < second.required_level
	)
	for entry: AstralLearnsetEntry in sorted_entries:
		if entry != null and entry.required_level <= level:
			_append_unique_move(result, entry.move)
	return result


func get_available_evolutions(level: int) -> Array[AstralEvolutionOption]:
	var result: Array[AstralEvolutionOption] = []
	for option: AstralEvolutionOption in evolution_options:
		if option != null and option.target != null and level >= option.required_level:
			result.append(option)
	return result


func _append_unique_move(
	moves: Array[AstralMoveDefinition],
	move: AstralMoveDefinition
) -> void:
	if move == null:
		return
	for existing: AstralMoveDefinition in moves:
		if existing == move or (
			existing != null
			and not move.move_id.is_empty()
			and existing.move_id == move.move_id
		):
			return
	moves.append(move)


func _clamp_base_stat(requested_value: int, current_value: int) -> int:
	var total_without_current := get_base_stat_total() - current_value
	var maximum_for_stat := mini(
		MAX_BASE_STAT,
		MAX_BASE_STAT_TOTAL - total_without_current
	)
	return clampi(
		requested_value,
		MIN_BASE_STAT,
		maxi(MIN_BASE_STAT, maximum_for_stat)
	)


static func _is_valid_base_stat(value: int) -> bool:
	return value >= MIN_BASE_STAT and value <= MAX_BASE_STAT
