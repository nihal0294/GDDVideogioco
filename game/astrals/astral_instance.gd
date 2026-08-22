class_name AstralInstance
extends Resource

signal experience_changed(current_experience: int, required_experience: int)
signal leveled_up(previous_level: int, new_level: int)
signal moves_changed()
signal move_learned(move: AstralMoveDefinition)
signal move_learning_requested(move: AstralMoveDefinition)
signal evolution_available()
signal evolved(previous_definition: AstralDefinition, new_definition: AstralDefinition)

enum Sex {
	MALE,
	FEMALE,
}

const MAX_MOVE_COUNT: int = 4
const MAX_LEVEL: int = 100
const EXPERIENCE_SAVE_FORMAT: int = 2
const SHINY_ODDS: int = 10000

@export var definition: AstralDefinition
@export_range(1, 100, 1) var level: int = 1
@export var current_health: int = 0
@export_range(0, 9999999, 1) var experience: int = 0
@export_enum("Maschio", "Femmina") var sex: int = Sex.MALE
@export var is_shiny: bool = false
@export_group("Soul Core")
@export_range(0, 5, 1) var health_soul_core: int = 0
@export_range(0, 5, 1) var attack_soul_core: int = 0
@export_range(0, 5, 1) var physical_defense_soul_core: int = 0
@export_range(0, 5, 1) var magic_attack_soul_core: int = 0
@export_range(0, 5, 1) var magic_defense_soul_core: int = 0
@export_range(0, 5, 1) var speed_soul_core: int = 0

@export_storage var _moves: Array[AstralMoveDefinition] = []
@export_storage var _pending_moves: Array[AstralMoveDefinition] = []

var moves: Array[AstralMoveDefinition]:
	get:
		return _copy_limited_moves(_moves)


func setup(
	source_definition: AstralDefinition,
	source_level: int = 1,
	forced_sex: int = -1
) -> void:
	definition = source_definition
	is_shiny = false
	_pending_moves.clear()
	level = clampi(source_level, 1, MAX_LEVEL)
	experience = (
		definition.get_total_experience_for_level(level)
		if definition != null
		else 0
	)
	sex = (
		forced_sex
		if forced_sex == Sex.MALE or forced_sex == Sex.FEMALE
		else sex_from_roll(randf())
	)
	var starting_moves: Array[AstralMoveDefinition] = []
	if definition != null:
		starting_moves = definition.get_moves_available_at_level(level)
	_moves = _latest_limited_moves(starting_moves)
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
	current_health = get_max_health()


func get_max_health() -> int:
	return _calculate_max_health_at_level(level)


func get_attack_power() -> int:
	return _calculate_effective_stat(
		definition.attack_power if definition != null else 0,
		attack_soul_core
	)


func get_physical_defense() -> int:
	return _calculate_effective_stat(
		definition.physical_defense if definition != null else 0,
		physical_defense_soul_core
	)


func get_magic_attack() -> int:
	return _calculate_effective_stat(
		definition.magic_attack if definition != null else 0,
		magic_attack_soul_core
	)


func get_magic_defense() -> int:
	return _calculate_effective_stat(
		definition.magic_defense if definition != null else 0,
		magic_defense_soul_core
	)


func get_speed() -> int:
	return _calculate_effective_stat(
		definition.speed if definition != null else 0,
		speed_soul_core
	)


func take_damage(amount: int) -> int:
	if amount <= 0 or is_defeated():
		return 0
	var applied_damage := mini(amount, current_health)
	current_health -= applied_damage
	return applied_damage


func is_defeated() -> bool:
	return definition == null or current_health <= 0


func get_experience_to_next_level() -> int:
	if definition == null:
		return 0
	return definition.get_experience_for_next_level(level)


func get_experience_progress_in_level() -> int:
	if definition == null or level >= MAX_LEVEL:
		return 0
	return maxi(
		experience - definition.get_total_experience_for_level(level),
		0
	)


func get_experience_remaining_to_next_level() -> int:
	var required_experience := get_experience_to_next_level()
	if required_experience <= 0:
		return 0
	return maxi(required_experience - get_experience_progress_in_level(), 0)


func gain_experience(amount: int) -> int:
	if amount <= 0 or definition == null:
		return 0

	var maximum_experience := definition.get_total_experience_for_level(MAX_LEVEL)
	experience = clampi(experience + amount, 0, maximum_experience)
	var levels_gained := 0
	while (
		level < MAX_LEVEL
		and experience >= definition.get_total_experience_for_level(level + 1)
	):
		var previous_level := level
		level += 1
		levels_gained += 1
		_learn_moves_at_level(level)
		leveled_up.emit(previous_level, level)
		if (
			definition.get_available_evolutions(level).size()
			> definition.get_available_evolutions(previous_level).size()
		):
			evolution_available.emit()
	if level >= MAX_LEVEL:
		experience = maximum_experience
	experience_changed.emit(
		get_experience_progress_in_level(),
		get_experience_to_next_level()
	)
	return levels_gained


func get_stat_snapshot(target_level: int = -1) -> Dictionary[StringName, int]:
	var resolved_level := level if target_level < 1 else clampi(target_level, 1, MAX_LEVEL)
	return {
		&"health": _calculate_max_health_at_level(resolved_level),
		&"attack": _calculate_effective_stat_at_level(
			definition.attack_power if definition != null else 0,
			attack_soul_core,
			resolved_level
		),
		&"physical_defense": _calculate_effective_stat_at_level(
			definition.physical_defense if definition != null else 0,
			physical_defense_soul_core,
			resolved_level
		),
		&"magic_attack": _calculate_effective_stat_at_level(
			definition.magic_attack if definition != null else 0,
			magic_attack_soul_core,
			resolved_level
		),
		&"magic_defense": _calculate_effective_stat_at_level(
			definition.magic_defense if definition != null else 0,
			magic_defense_soul_core,
			resolved_level
		),
		&"speed": _calculate_effective_stat_at_level(
			definition.speed if definition != null else 0,
			speed_soul_core,
			resolved_level
		),
	}


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
	move_learned.emit(move)
	return true


func get_pending_moves() -> Array[AstralMoveDefinition]:
	var result: Array[AstralMoveDefinition] = []
	result.assign(_pending_moves)
	return result


func learn_pending_move_replacing(
	move: AstralMoveDefinition,
	replaced_index: int
) -> bool:
	if move == null or not _pending_moves.has(move):
		return false
	if not replace_move(replaced_index, move):
		return false
	_pending_moves.erase(move)
	move_learned.emit(move)
	return true


func decline_pending_move(move: AstralMoveDefinition) -> bool:
	if move == null or not _pending_moves.has(move):
		return false
	_pending_moves.erase(move)
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
	runtime_copy.is_shiny = is_shiny
	runtime_copy.health_soul_core = health_soul_core
	runtime_copy.attack_soul_core = attack_soul_core
	runtime_copy.physical_defense_soul_core = physical_defense_soul_core
	runtime_copy.magic_attack_soul_core = magic_attack_soul_core
	runtime_copy.magic_defense_soul_core = magic_defense_soul_core
	runtime_copy.speed_soul_core = speed_soul_core
	runtime_copy.current_health = clampi(
		current_health,
		0,
		runtime_copy.get_max_health()
	)
	runtime_copy.experience = maxi(experience, 0)
	runtime_copy._moves = runtime_copy._copy_limited_moves(_moves)
	runtime_copy._pending_moves.assign(_pending_moves)
	return runtime_copy


func get_save_data() -> Dictionary:
	var move_ids: Array[String] = []
	for move: AstralMoveDefinition in _moves:
		if move != null:
			move_ids.append(String(move.move_id))
	var pending_move_ids: Array[String] = []
	for move: AstralMoveDefinition in _pending_moves:
		if move != null:
			pending_move_ids.append(String(move.move_id))
	return {
		"astral_id": String(definition.astral_id) if definition != null else "",
		"level": level,
		"current_health": current_health,
		"experience": experience,
		"experience_format": EXPERIENCE_SAVE_FORMAT,
		"sex": sex,
		"is_shiny": is_shiny,
		"move_ids": move_ids,
		"pending_move_ids": pending_move_ids,
		"soul_core": [
			health_soul_core,
			attack_soul_core,
			physical_defense_soul_core,
			magic_attack_soul_core,
			magic_defense_soul_core,
			speed_soul_core,
		],
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
	var saved_level := clampi(
		_validated_int(data.get("level", 1), 1),
		1,
		MAX_LEVEL
	)
	var saved_experience := maxi(
		_validated_int(data.get("experience", 0), 0),
		0
	)
	var experience_format := _validated_int(
		data.get("experience_format", 1),
		1
	)
	if experience_format >= EXPERIENCE_SAVE_FORMAT:
		saved_experience = mini(
			saved_experience,
			source_definition.get_total_experience_for_level(MAX_LEVEL)
		)
		saved_level = source_definition.get_level_for_total_experience(
			saved_experience
		)
	else:
		var required_experience := source_definition.get_experience_for_next_level(
			saved_level
		)
		var legacy_progress := clampi(
			saved_experience,
			0,
			maxi(required_experience - 1, 0)
		)
		saved_experience = (
			source_definition.get_total_experience_for_level(saved_level)
			+ legacy_progress
		)
	setup(source_definition, saved_level, saved_sex)
	is_shiny = bool(data.get("is_shiny", false))
	var saved_health := _validated_int(
		data.get("current_health", get_max_health()),
		get_max_health()
	)
	experience = saved_experience
	var soul_core_value: Variant = data.get("soul_core", [])
	if soul_core_value is Array:
		var soul_core_values := soul_core_value as Array
		if soul_core_values.size() >= 6:
			health_soul_core = clampi(_validated_int(soul_core_values[0], 0), 0, 5)
			attack_soul_core = clampi(_validated_int(soul_core_values[1], 0), 0, 5)
			physical_defense_soul_core = clampi(_validated_int(soul_core_values[2], 0), 0, 5)
			magic_attack_soul_core = clampi(_validated_int(soul_core_values[3], 0), 0, 5)
			magic_defense_soul_core = clampi(_validated_int(soul_core_values[4], 0), 0, 5)
			speed_soul_core = clampi(_validated_int(soul_core_values[5], 0), 0, 5)
	current_health = clampi(saved_health, 0, get_max_health())

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
	var raw_pending_moves: Variant = data.get("pending_move_ids", [])
	if raw_pending_moves is Array:
		_pending_moves.clear()
		for raw_move_id: Variant in raw_pending_moves as Array:
			var move_id := _string_name_from_variant(raw_move_id)
			var move := move_definitions.get(move_id) as AstralMoveDefinition
			if (
				move == null
				or _contains_move(_moves, move)
				or _contains_move(_pending_moves, move)
			):
				continue
			_pending_moves.append(move)
	return true


func get_available_evolutions() -> Array[AstralEvolutionOption]:
	if definition == null:
		return []
	return definition.get_available_evolutions(level)


func can_evolve_with(option: AstralEvolutionOption) -> bool:
	return (
		option != null
		and definition != null
		and definition.evolution_options.has(option)
		and option.target != null
		and level >= option.required_level
	)


func evolve_with(option: AstralEvolutionOption) -> bool:
	if not can_evolve_with(option):
		return false
	var previous_definition := definition
	var previous_max_health := maxi(get_max_health(), 1)
	var health_ratio := float(current_health) / float(previous_max_health)
	definition = option.target
	_learn_moves_at_level(level)
	current_health = clampi(
		roundi(float(get_max_health()) * health_ratio),
		1 if current_health > 0 else 0,
		get_max_health()
	)
	evolved.emit(previous_definition, definition)
	return true


static func sex_from_roll(roll: float) -> int:
	return Sex.MALE if roll < 0.5 else Sex.FEMALE


func roll_shiny(
	random: RandomNumberGenerator = null,
	odds: int = SHINY_ODDS
) -> bool:
	var safe_odds := maxi(odds, 1)
	var roll := (
		random.randi_range(1, safe_odds)
		if random != null
		else randi_range(1, safe_odds)
	)
	is_shiny = roll == 1
	return is_shiny


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


func _latest_limited_moves(
	source_moves: Array[AstralMoveDefinition]
) -> Array[AstralMoveDefinition]:
	var unique_moves: Array[AstralMoveDefinition] = []
	for move: AstralMoveDefinition in source_moves:
		if move != null and not _contains_move(unique_moves, move):
			unique_moves.append(move)
	while unique_moves.size() > MAX_MOVE_COUNT:
		unique_moves.pop_front()
	return unique_moves


func _learn_moves_at_level(target_level: int) -> void:
	if definition == null:
		return
	for move: AstralMoveDefinition in definition.get_moves_learned_at_level(
		target_level
	):
		if (
			move == null
			or _contains_move(_moves, move)
			or _contains_move(_pending_moves, move)
		):
			continue
		if _moves.size() < MAX_MOVE_COUNT:
			learn_move(move)
		else:
			_pending_moves.append(move)
			move_learning_requested.emit(move)


func _calculate_effective_stat(base_stat: int, soul_core: int) -> int:
	return _calculate_effective_stat_at_level(base_stat, soul_core, level)


func _calculate_max_health_at_level(target_level: int) -> int:
	if definition == null:
		return 0
	return (
		floori(
			float(2 * definition.max_health + health_soul_core)
			* float(target_level)
			/ 100.0
		)
		+ target_level
		+ 10
	)


func _calculate_effective_stat_at_level(
	base_stat: int,
	soul_core: int,
	target_level: int
) -> int:
	if definition == null:
		return 0
	return (
		floori(
			float(2 * base_stat + clampi(soul_core, 0, 5))
			* float(target_level)
			/ 100.0
		)
		+ 5
	)


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
