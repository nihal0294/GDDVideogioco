class_name AstralInstance
extends Resource

signal experience_changed(current_experience: int, required_experience: int)
signal leveled_up(previous_level: int, new_level: int)
signal moves_changed()

enum Sex {
	MALE,
	FEMALE,
}

const EXPERIENCE_PER_LEVEL: int = 100
const MAX_MOVE_COUNT: int = 4
const MAX_LEVEL: int = 999

@export var definition: AstralDefinition
@export_range(1, 999, 1) var level: int = 1
@export var current_health: int = 0
@export_range(0, 9999999, 1) var experience: int = 0
@export_enum("Maschio", "Femmina") var sex: int = Sex.MALE

@export_storage var _moves: Array[AstralMoveDefinition] = []

var moves: Array[AstralMoveDefinition]:
	get:
		return _copy_limited_moves(_moves)


func setup(
	source_definition: AstralDefinition,
	source_level: int = 1,
	forced_sex: int = -1
) -> void:
	definition = source_definition
	level = maxi(source_level, 1)
	experience = 0
	sex = (
		forced_sex
		if forced_sex == Sex.MALE or forced_sex == Sex.FEMALE
		else sex_from_roll(randf())
	)
	var starting_moves: Array[AstralMoveDefinition] = []
	if definition != null:
		starting_moves.assign(definition.starting_moves)
	_moves = _copy_limited_moves(starting_moves)
	reset_health()


func setup_with_random(
	source_definition: AstralDefinition,
	source_level: int,
	random: RandomNumberGenerator
) -> void:
	var generated_sex := -1
	if random != null:
		generated_sex = sex_from_roll(random.randf())
	setup(source_definition, source_level, generated_sex)


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
	runtime_copy.sex = sex
	runtime_copy.current_health = clampi(
		current_health,
		0,
		definition.max_health if definition != null else 0
	)
	runtime_copy.experience = maxi(experience, 0)
	runtime_copy._moves = runtime_copy._copy_limited_moves(_moves)
	return runtime_copy


func get_save_data() -> Dictionary:
	var move_ids: Array[String] = []
	for move: AstralMoveDefinition in _moves:
		if move != null:
			move_ids.append(String(move.move_id))
	return {
		"astral_id": String(definition.astral_id) if definition != null else "",
		"level": level,
		"current_health": current_health,
		"experience": experience,
		"sex": sex,
		"move_ids": move_ids,
	}


func load_save_data(
	data: Dictionary,
	source_definition: AstralDefinition,
	move_definitions: Dictionary[StringName, AstralMoveDefinition]
) -> bool:
	if source_definition == null:
		return false
	var saved_astral_id := _string_name_from_variant(
		data.get("astral_id", &"")
	)
	if (
		not saved_astral_id.is_empty()
		and saved_astral_id != source_definition.astral_id
	):
		return false

	var saved_sex := _validated_int(
		data.get("sex", Sex.MALE),
		Sex.MALE
	)
	if saved_sex != Sex.MALE and saved_sex != Sex.FEMALE:
		saved_sex = Sex.MALE
	setup(
		source_definition,
		clampi(
			_validated_int(data.get("level", 1), 1),
			1,
			MAX_LEVEL
		),
		saved_sex
	)
	current_health = clampi(
		_validated_int(
			data.get("current_health", source_definition.max_health),
			source_definition.max_health
		),
		0,
		source_definition.max_health
	)
	experience = clampi(
		_validated_int(data.get("experience", 0), 0),
		0,
		EXPERIENCE_PER_LEVEL - 1
	)

	var raw_moves: Variant = data.get("move_ids", null)
	if raw_moves is Array:
		var loaded_moves: Array[AstralMoveDefinition] = []
		for raw_move_id: Variant in raw_moves:
			var move_id := _string_name_from_variant(raw_move_id)
			if move_id.is_empty():
				continue
			var move := move_definitions.get(move_id) as AstralMoveDefinition
			if move == null or _contains_move(loaded_moves, move):
				continue
			loaded_moves.append(move)
			if loaded_moves.size() >= MAX_MOVE_COUNT:
				break
		if not loaded_moves.is_empty():
			_moves.assign(loaded_moves)
			moves_changed.emit()
	return true


static func sex_from_roll(roll: float) -> int:
	return Sex.MALE if roll < 0.5 else Sex.FEMALE


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


static func _validated_int(value: Variant, fallback: int) -> int:
	if value is int:
		return int(value)
	if value is float and is_finite(float(value)):
		return int(value)
	return fallback


static func _string_name_from_variant(value: Variant) -> StringName:
	if value is String or value is StringName:
		return StringName(value)
	return &""
