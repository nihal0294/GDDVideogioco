class_name AstralInstance
extends Resource

signal experience_changed(current_experience: int, required_experience: int)
signal leveled_up(previous_level: int, new_level: int)
signal moves_changed()

const EXPERIENCE_PER_LEVEL: int = 100
const MAX_MOVE_COUNT: int = 4

@export var definition: AstralDefinition
@export_range(1, 999, 1) var level: int = 1
@export var current_health: int = 0
@export_range(0, 9999999, 1) var experience: int = 0

@export_storage var _moves: Array[AstralMoveDefinition] = []

var moves: Array[AstralMoveDefinition]:
	get:
		return _copy_limited_moves(_moves)


func setup(source_definition: AstralDefinition, source_level: int = 1) -> void:
	definition = source_definition
	level = maxi(source_level, 1)
	experience = 0
	var starting_moves: Array[AstralMoveDefinition] = []
	if definition != null:
		starting_moves.assign(definition.starting_moves)
	_moves = _copy_limited_moves(starting_moves)
	reset_health()


func reset_health() -> void:
	current_health = definition.max_health if definition != null else 0


func take_damage(amount: int) -> int:
	if amount <= 0 or is_defeated():
		return 0
	var applied_damage := mini(amount, current_health)
	current_health -= applied_damage
	return applied_damage


func is_defeated() -> bool:
	return definition == null or current_health <= 0


func get_experience_to_next_level() -> int:
	return EXPERIENCE_PER_LEVEL


func gain_experience(amount: int) -> int:
	if amount <= 0 or definition == null:
		return 0

	experience += amount
	var levels_gained := 0
	var required_experience := get_experience_to_next_level()
	while experience >= required_experience:
		experience -= required_experience
		var previous_level := level
		level += 1
		levels_gained += 1
		leveled_up.emit(previous_level, level)
		required_experience = get_experience_to_next_level()
	experience_changed.emit(experience, required_experience)
	return levels_gained


func get_moves() -> Array[AstralMoveDefinition]:
	return _copy_limited_moves(_moves)


func get_move_count() -> int:
	return _moves.size()


func get_move(index: int) -> AstralMoveDefinition:
	if index < 0 or index >= _moves.size():
		return null
	return _moves[index]


func learn_move(move: AstralMoveDefinition) -> bool:
	if (
		move == null
		or _moves.size() >= MAX_MOVE_COUNT
		or _contains_move(_moves, move)
	):
		return false
	_moves.append(move)
	moves_changed.emit()
	return true


func replace_move(index: int, move: AstralMoveDefinition) -> bool:
	if index < 0 or index >= _moves.size() or move == null:
		return false
	if _contains_move(_moves, move, index):
		return false
	if _moves[index] == move:
		return true
	_moves[index] = move
	moves_changed.emit()
	return true


func reorder_move(from_index: int, to_index: int) -> bool:
	if not _is_valid_move_index(from_index) or not _is_valid_move_index(to_index):
		return false
	if from_index == to_index:
		return true
	var move: AstralMoveDefinition = _moves.pop_at(from_index)
	_moves.insert(to_index, move)
	moves_changed.emit()
	return true


func duplicate_runtime() -> AstralInstance:
	var runtime_copy := AstralInstance.new()
	runtime_copy.definition = definition
	runtime_copy.level = maxi(level, 1)
	runtime_copy.current_health = clampi(
		current_health,
		0,
		definition.max_health if definition != null else 0
	)
	runtime_copy.experience = maxi(experience, 0)
	runtime_copy._moves = runtime_copy._copy_limited_moves(_moves)
	return runtime_copy


func _copy_limited_moves(
	source_moves: Array[AstralMoveDefinition]
) -> Array[AstralMoveDefinition]:
	var copied_moves: Array[AstralMoveDefinition] = []
	for move: AstralMoveDefinition in source_moves:
		if move == null or _contains_move(copied_moves, move):
			continue
		copied_moves.append(move)
		if copied_moves.size() >= MAX_MOVE_COUNT:
			break
	return copied_moves


func _contains_move(
	move_list: Array[AstralMoveDefinition],
	candidate: AstralMoveDefinition,
	ignored_index: int = -1
) -> bool:
	for index: int in move_list.size():
		if index == ignored_index:
			continue
		var existing_move := move_list[index]
		if existing_move == candidate:
			return true
		if (
			not candidate.move_id.is_empty()
			and existing_move != null
			and existing_move.move_id == candidate.move_id
		):
			return true
	return false


func _is_valid_move_index(index: int) -> bool:
	return index >= 0 and index < _moves.size()
