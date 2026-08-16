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
@export var visual_color: Color = Color(0.45, 0.75, 1.0, 1.0)


func get_base_stat_total() -> int:
	return (
		_max_health
		+ _attack_power
		+ _physical_defense
		+ _magic_attack
		+ _magic_defense
		+ _speed
	)


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
