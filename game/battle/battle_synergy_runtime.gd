class_name BattleSynergyRuntime
extends RefCounted

const SMALL_DIRECT_DAMAGE_DIVISOR: int = 16
const MEDIUM_DIRECT_DAMAGE_DIVISOR: int = 8
const CONFUSION_SELF_HIT_CHANCE: float = 0.5

const STAT_ATTACK: StringName = &"attack"
const STAT_PHYSICAL_DEFENSE: StringName = &"physical_defense"
const STAT_MAGIC_ATTACK: StringName = &"magic_attack"
const STAT_MAGIC_DEFENSE: StringName = &"magic_defense"
const STAT_SPEED: StringName = &"speed"

const STATUS_INFESTED: StringName = &"infestato"
const STATUS_CHILLED: StringName = &"assiderato"
const STATUS_OVERHEATED: StringName = &"surriscaldato"
const STATUS_CONFUSED: StringName = &"confuso"
const STATUS_DISORIENTED: StringName = &"disorientato"
const STATUS_POISONED: StringName = &"avvelenato"
const STATUS_SEVERE_TOXIN: StringName = &"tossina_grave"

var _roster: AstralRoster = null
var _rng := RandomNumberGenerator.new()
var _counts: Dictionary[StringName, int] = {}
var _tiers: Dictionary[StringName, int] = {}
var _states: Dictionary = {}
var _party_members: Array[AstralInstance] = []
var _round_index: int = 0
var _fossil_revival_used: bool = false
var _mythical_retry_used: bool = false
var _mythical_immunity_used: bool = false
var _dark_hunt_used: bool = false
var _pending_epic_move: AstralMoveDefinition = null
var _pending_epic_move_is_unique: bool = false
var _temporary_nature_astral: AstralInstance = null


func setup(roster: AstralRoster, rng: RandomNumberGenerator = null) -> void:
	_roster = roster
	_rng = rng
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	_party_members = _roster.get_astrals() if _roster != null else []
	_rebuild_counts()
	_states.clear()
	_round_index = 0
	_fossil_revival_used = false
	_mythical_retry_used = false
	_mythical_immunity_used = false
	_dark_hunt_used = false
	_pending_epic_move = null
	_pending_epic_move_is_unique = false
	_temporary_nature_astral = null


func begin_battle() -> PackedStringArray:
	var messages: PackedStringArray = []
	if get_tier(AstralSpecies.NATURE) < 5 or _roster == null:
		return messages
	if _roster.get_astral_count() >= AstralRoster.MAX_PARTY_SIZE:
		return messages
	var source := _get_highest_level_member(AstralSpecies.NATURE)
	if source == null or source.definition == null:
		return messages
	var manifestation_definition := _create_nature_manifestation(source.definition)
	_temporary_nature_astral = AstralInstance.new()
	_temporary_nature_astral.setup(manifestation_definition, source.level, source.sex)
	if not _roster.add_temporary_party_astral(_temporary_nature_astral):
		_temporary_nature_astral = null
		return messages
	_party_members.append(_temporary_nature_astral)
	messages.append(
		"La sinergia Natura evoca una Manifestazione Naturale di livello %d."
		% source.level
	)
	return messages


func finish_battle() -> void:
	if _roster != null and _temporary_nature_astral != null:
		_roster.remove_temporary_party_astral(_temporary_nature_astral)
	_temporary_nature_astral = null
	for astral: AstralInstance in _party_members:
		clear_temporary_stages(astral)


func get_count(species_id: StringName) -> int:
	return int(_counts.get(species_id, 0))


func get_tier(species_id: StringName) -> int:
	return int(_tiers.get(species_id, 0))


func has_species(astral: AstralInstance, species_id: StringName) -> bool:
	return (
		astral != null
		and _party_members.has(astral)
		and astral.definition != null
		and astral.definition.has_species_type(species_id)
	)


func on_enter_field(astral: AstralInstance) -> PackedStringArray:
	var messages: PackedStringArray = []
	if astral == null or astral.definition == null:
		return messages
	var state := _get_state(astral)
	clear_temporary_stages(astral)
	state["field_turns"] = 0
	state["turns_without_hit"] = 0
	state["was_hit_this_round"] = false
	state["dragon_entry_repeat_used"] = false
	state["lucent_reflect_available"] = true
	state["lucent_stat_reflect_available"] = true
	state["entry_count"] = int(state.get("entry_count", 0)) + 1
	var first_entry := not bool(state.get("has_entered", false))
	state["has_entered"] = true
	if first_entry and has_species(astral, AstralSpecies.DINOSAUR) and get_tier(AstralSpecies.DINOSAUR) >= 2:
		add_stat_stage(astral, STAT_ATTACK, 1, 1)
		messages.append("%s ottiene +1 Atk dalla sinergia Dinosauro." % astral.definition.display_name)
	if first_entry and has_species(astral, AstralSpecies.TERRESTRIAL) and get_tier(AstralSpecies.TERRESTRIAL) >= 3:
		add_stat_stage(astral, STAT_PHYSICAL_DEFENSE, 1, 1)
		messages.append("%s ottiene +1 PDef dalla sinergia Terrestre." % astral.definition.display_name)
	if has_species(astral, AstralSpecies.COSMIC) and get_tier(AstralSpecies.COSMIC) >= 4:
		_apply_cosmic_entry_stages(astral)
		messages.append("La sinergia Cosmico potenzia le statistiche di %s." % astral.definition.display_name)
	if has_species(astral, AstralSpecies.EPIC) and _pending_epic_move != null:
		if not _pending_epic_move_is_unique or get_tier(AstralSpecies.EPIC) >= 4:
			state["inherited_move"] = _pending_epic_move
			state["inherited_move_persistent"] = get_tier(AstralSpecies.EPIC) >= 4
			messages.append("%s eredita temporaneamente %s." % [astral.definition.display_name, _pending_epic_move.display_name])
		_pending_epic_move = null
		_pending_epic_move_is_unique = false
	return messages


func on_exit_field(astral: AstralInstance) -> void:
	if astral == null:
		return
	var state := _get_state(astral)
	clear_temporary_stages(astral)
	state["field_turns"] = 0
	state["damage_turn_streak"] = 0
	state["hit_streak"] = 0
	state["physical_hit_streak"] = 0
	state["acted_first_streak"] = 0
	state["inherited_move"] = null
	state["inherited_move_persistent"] = false


func get_damage_modifiers(
	attacker: AstralInstance,
	defender: AstralInstance,
	move: AstralMoveDefinition
) -> BattleMath.DamageModifiers:
	var modifiers := BattleMath.DamageModifiers.new()
	if attacker == null or defender == null or move == null:
		return modifiers
	var attack_stat := (
		STAT_MAGIC_ATTACK
		if move.damage_class == AstralMoveDefinition.DamageClass.MAGICAL
		else STAT_ATTACK
	)
	var defense_stat := (
		STAT_MAGIC_DEFENSE
		if move.damage_class == AstralMoveDefinition.DamageClass.MAGICAL
		else STAT_PHYSICAL_DEFENSE
	)
	var attack_stage := get_stat_stage(attacker, attack_stat)
	var defense_stage := get_stat_stage(defender, defense_stat)
	if (
		has_species(attacker, AstralSpecies.DARK)
		and get_tier(AstralSpecies.DARK) >= 3
		and defender.current_health * 2 < defender.get_max_health()
		and defense_stage > 0
	):
		defense_stage = maxi(defense_stage - 1, 0)
	modifiers.attack_stat_modifier = stage_to_multiplier(attack_stage)
	modifiers.defense_stat_modifier = stage_to_multiplier(defense_stage)
	if should_neutralize_immunity(attacker, defender, move):
		modifiers.neutralize_immunity = true
	return modifiers


func get_effective_speed(astral: AstralInstance) -> int:
	if astral == null:
		return 0
	return maxi(1, floori(float(astral.get_speed()) * stage_to_multiplier(get_stat_stage(astral, STAT_SPEED))))


func must_act_last(astral: AstralInstance) -> bool:
	return astral != null and int(_get_state(astral).get("assiderato_turns", 0)) > 0


func record_acted_first(astral: AstralInstance, acted_first: bool) -> void:
	if astral == null:
		return
	var state := _get_state(astral)
	state["acted_first_streak"] = (
		int(state.get("acted_first_streak", 0)) + 1
		if acted_first
		else 0
	)


func get_hit_scales(astral: AstralInstance) -> Array[float]:
	var scales: Array[float] = [1.0]
	if not has_species(astral, AstralSpecies.MOUSE):
		return scales
	var tier := get_tier(AstralSpecies.MOUSE)
	var hit_count := 1
	if tier >= 4:
		hit_count = get_count(AstralSpecies.MOUSE)
	elif tier >= 3:
		hit_count = 3
	elif tier >= 2:
		hit_count = 2
	for hit_index: int in range(1, hit_count):
		scales.append(1.0 / pow(2.0, hit_index))
	return scales


func can_use_move(
	astral: AstralInstance,
	move: AstralMoveDefinition,
	remaining_cooldown: int
) -> bool:
	if astral == null or move == null:
		return false
	var state := _get_state(astral)
	if (
		int(state.get("assiderato_turns", 0)) > 0
		and bool(state.get("chilled_blocks_high_cost", false))
		and move.cooldown_turns >= 4
	):
		return false
	if (
		int(state.get("overheated_turns", 0)) > 0
		and state.get("last_move") == move
	):
		return false
	if remaining_cooldown <= 0:
		return true
	return int(state.get("cooldown_bypass", 0)) > 0


func get_move_block_reason(
	astral: AstralInstance,
	move: AstralMoveDefinition,
	remaining_cooldown: int
) -> String:
	if astral == null or move == null:
		return "Mossa non disponibile."
	var state := _get_state(astral)
	if (
		int(state.get("assiderato_turns", 0)) > 0
		and bool(state.get("chilled_blocks_high_cost", false))
		and move.cooldown_turns >= 4
	):
		return "%s è Assiderato e non può usare mosse di costo 4 o 5." % astral.definition.display_name
	if int(state.get("overheated_turns", 0)) > 0 and state.get("last_move") == move:
		return "%s è Surriscaldato e non può ripetere la stessa mossa." % astral.definition.display_name
	if remaining_cooldown > 0 and int(state.get("cooldown_bypass", 0)) <= 0:
		return "%s deve attendere ancora %d turni." % [move.display_name, remaining_cooldown]
	return ""


func consume_cooldown_bypass(astral: AstralInstance, remaining_cooldown: int) -> bool:
	if astral == null or remaining_cooldown <= 0:
		return false
	var state := _get_state(astral)
	var uses := int(state.get("cooldown_bypass", 0))
	if uses <= 0:
		return false
	state["cooldown_bypass"] = uses - 1
	return true


func consume_cooldown_reduction(
	astral: AstralInstance,
	move: AstralMoveDefinition
) -> int:
	if astral == null or move == null or move.cooldown_turns <= 0:
		return 0
	var reduction := 0
	var state := _get_state(astral)
	if bool(state.get("next_free_cooldown", false)):
		state["next_free_cooldown"] = false
		return move.cooldown_turns
	var next_reduction := int(state.get("next_cooldown_reduction", 0))
	if next_reduction > 0:
		reduction += 1
		state["next_cooldown_reduction"] = next_reduction - 1
	if has_species(astral, AstralSpecies.SYNTHETIC) and get_tier(AstralSpecies.SYNTHETIC) >= 3:
		reduction += 1
		if get_tier(AstralSpecies.SYNTHETIC) >= 5 and bool(state.get("synthetic_chain", false)):
			reduction += 1
		state["synthetic_chain"] = get_tier(AstralSpecies.SYNTHETIC) >= 5
	return mini(reduction, move.cooldown_turns)


func consume_move_priority(
	astral: AstralInstance,
	target: AstralInstance,
	move: AstralMoveDefinition
) -> bool:
	if astral == null or target == null or move == null or move.power <= 0:
		return false
	var state := _get_state(astral)
	if (
		has_species(astral, AstralSpecies.FIGHTER)
		and move.damage_class == AstralMoveDefinition.DamageClass.PHYSICAL
		and int(state.get("priority_uses", 0)) > 0
	):
		state["priority_uses"] = int(state["priority_uses"]) - 1
		return true
	if has_species(astral, AstralSpecies.DRAGON) and int(state.get("priority_uses", 0)) > 0:
		state["priority_uses"] = int(state["priority_uses"]) - 1
		return true
	if (
		has_species(astral, AstralSpecies.DARK)
		and get_tier(AstralSpecies.DARK) >= 4
		and target.current_health * 4 < target.get_max_health()
		and not bool(state.get("dark_priority_used", false))
	):
		state["dark_priority_used"] = true
		return true
	return false


func prepare_move(
	astral: AstralInstance,
	selected_move: AstralMoveDefinition
) -> Dictionary:
	var result := {
		"move": selected_move,
		"failed": false,
		"self_damage": 0,
		"message": "",
	}
	if astral == null or selected_move == null:
		return result
	var state := _get_state(astral)
	if int(state.get("disoriented_turns", 0)) > 0:
		var alternatives: Array[AstralMoveDefinition] = []
		for candidate: AstralMoveDefinition in astral.get_moves():
			if candidate != null and candidate != selected_move:
				alternatives.append(candidate)
		if not alternatives.is_empty():
			result["move"] = alternatives[_rng.randi_range(0, alternatives.size() - 1)]
			result["message"] = "%s è Disorientato: la mossa viene sostituita con %s." % [astral.definition.display_name, (result["move"] as AstralMoveDefinition).display_name]
		state["disoriented_turns"] = 0
	if int(state.get("confused_turns", 0)) > 0 and _rng.randf() < CONFUSION_SELF_HIT_CHANCE:
		result["failed"] = true
		var divisor := MEDIUM_DIRECT_DAMAGE_DIVISOR if int(state.get("confusion_tier", 0)) >= 4 else SMALL_DIRECT_DAMAGE_DIVISOR
		result["self_damage"] = maxi(1, floori(float(astral.get_max_health()) / float(divisor)))
		result["message"] = "%s è Confuso e si colpisce da solo." % astral.definition.display_name
	return result


func on_move_used(astral: AstralInstance, move: AstralMoveDefinition) -> int:
	if astral == null or move == null:
		return 0
	var state := _get_state(astral)
	state["last_move"] = move
	state["last_used_move"] = move
	var recoil := 0
	if int(state.get("overheated_turns", 0)) > 0 and move.power > 0:
		var divisor := 8 if move.cooldown_turns >= 4 else 16
		if int(state.get("overheated_tier", 0)) >= 5:
			recoil = maxi(1, floori(float(astral.get_max_health()) / float(divisor)))
	return recoil


func should_evade(defender: AstralInstance, offensive_move: bool = true) -> bool:
	if not offensive_move or not has_species(defender, AstralSpecies.FAIRY) or get_tier(AstralSpecies.FAIRY) < 3:
		return false
	var state := _get_state(defender)
	if not bool(state.get("fairy_veil", true)):
		return false
	state["fairy_veil"] = false
	state["turns_without_hit"] = 0
	return true


func should_reroll_critical(defender: AstralInstance, was_critical: bool) -> bool:
	if (
		not was_critical
		or _mythical_retry_used
		or not has_species(defender, AstralSpecies.MYTHICAL)
		or get_tier(AstralSpecies.MYTHICAL) < 2
	):
		return false
	_mythical_retry_used = true
	return true


func should_retry_failure(astral: AstralInstance) -> bool:
	if (
		_mythical_retry_used
		or not has_species(astral, AstralSpecies.MYTHICAL)
		or get_tier(AstralSpecies.MYTHICAL) < 2
	):
		return false
	_mythical_retry_used = true
	return true


func on_hit(
	attacker: AstralInstance,
	defender: AstralInstance,
	move: AstralMoveDefinition,
	applied_damage: int
) -> Dictionary:
	var result := {"messages": PackedStringArray(), "bonus_move": null, "repeat_move": false}
	if attacker == null or defender == null or move == null or applied_damage <= 0:
		return result
	var messages := result["messages"] as PackedStringArray
	var attacker_state := _get_state(attacker)
	var defender_state := _get_state(defender)
	defender_state["was_hit_this_round"] = true
	_track_bestial(attacker, attacker_state, messages)
	_track_insect(attacker, defender, defender_state, messages)
	_track_cold(attacker, defender, defender_state, messages)
	_track_hot(attacker, defender, defender_state, messages)
	_track_ethereal(attacker, defender, defender_state, messages)
	_track_toxic(attacker, defender, defender_state, messages)
	_track_dragon(attacker, attacker_state, messages, result)
	_track_fighter(attacker, move, attacker_state, messages, result)
	return result


func get_reflected_damage(
	defender: AstralInstance,
	applied_damage: int,
	neutral_damage: int = 0,
	was_super_effective: bool = false
) -> int:
	if not has_species(defender, AstralSpecies.CRYSTAL) or get_tier(AstralSpecies.CRYSTAL) < 3:
		return 0
	var base_damage := applied_damage
	var divisor := 8
	if get_tier(AstralSpecies.CRYSTAL) >= 6:
		divisor = 4
		if was_super_effective and neutral_damage > 0:
			base_damage = neutral_damage
	return maxi(1, floori(float(base_damage) / float(divisor)))


func try_survive_knockout(astral: AstralInstance) -> bool:
	if (
		astral == null
		or not astral.is_defeated()
		or not has_species(astral, AstralSpecies.DINOSAUR)
		or get_tier(AstralSpecies.DINOSAUR) < 6
	):
		return false
	var state := _get_state(astral)
	if bool(state.get("dinosaur_survival_used", false)):
		return false
	state["dinosaur_survival_used"] = true
	state["cooldown_bypass"] = int(state.get("cooldown_bypass", 0)) + 1
	astral.current_health = 1
	return true


func on_knockout(
	attacker: AstralInstance,
	defeated: AstralInstance,
	move: AstralMoveDefinition
) -> PackedStringArray:
	var messages: PackedStringArray = []
	if attacker != null:
		var attacker_state := _get_state(attacker)
		if has_species(attacker, AstralSpecies.DINOSAUR) and get_tier(AstralSpecies.DINOSAUR) >= 4:
			attacker_state["next_cooldown_reduction"] = int(attacker_state.get("next_cooldown_reduction", 0)) + 1
			messages.append("La prossima mossa a caricamento di %s sarà anticipata." % attacker.definition.display_name)
		if has_species(attacker, AstralSpecies.DRAGON) and get_tier(AstralSpecies.DRAGON) >= 5:
			attacker_state["next_free_cooldown"] = true
		if has_species(attacker, AstralSpecies.DARK) and get_tier(AstralSpecies.DARK) >= 6 and not _dark_hunt_used:
			_dark_hunt_used = true
			attacker_state["cooldown_bypass"] = int(attacker_state.get("cooldown_bypass", 0)) + 1
			messages.append("%s entra in Caccia." % attacker.definition.display_name)
	if defeated != null and has_species(defeated, AstralSpecies.EPIC) and get_tier(AstralSpecies.EPIC) >= 2:
		var defeated_state := _get_state(defeated)
		var inherited := defeated_state.get("last_used_move") as AstralMoveDefinition
		if inherited != null:
			_pending_epic_move = inherited
			_pending_epic_move_is_unique = inherited.is_unique
	return messages


func get_inherited_move(astral: AstralInstance) -> AstralMoveDefinition:
	if astral == null:
		return null
	return _get_state(astral).get("inherited_move") as AstralMoveDefinition


func consume_inherited_move(astral: AstralInstance, scored_knockout: bool) -> void:
	if astral == null:
		return
	var state := _get_state(astral)
	if not bool(state.get("inherited_move_persistent", false)) or not scored_knockout:
		state["inherited_move"] = null


func end_round(active_astral: AstralInstance, opponent: AstralInstance) -> PackedStringArray:
	_round_index += 1
	var messages: PackedStringArray = []
	if active_astral != null and not active_astral.is_defeated():
		var state := _get_state(active_astral)
		state["field_turns"] = int(state.get("field_turns", 0)) + 1
		_apply_field_turn_synergies(active_astral, state, messages)
		_apply_nature_regeneration(active_astral, state, messages)
		_update_fairy_veil(active_astral, state, messages)
	_apply_end_round_statuses(active_astral, messages)
	_apply_end_round_statuses(opponent, messages)
	_try_automatic_fossil_revival(messages)
	return messages


func get_fossil_revival_candidates() -> Array[AstralInstance]:
	var result: Array[AstralInstance] = []
	if (
		_fossil_revival_used
		or _roster == null
		or get_tier(AstralSpecies.FOSSIL) < 4
	):
		return result
	for astral: AstralInstance in _roster.get_astrals():
		if astral != null and astral.is_defeated():
			result.append(astral)
	return result


func revive_with_fossil(astral: AstralInstance) -> bool:
	if (
		astral == null
		or not get_fossil_revival_candidates().has(astral)
	):
		return false
	_fossil_revival_used = true
	astral.current_health = maxi(
		1,
		floori(float(astral.get_max_health()) / 2.0)
	)
	return true


func remove_one_negative_status(astral: AstralInstance) -> StringName:
	if astral == null:
		return &""
	var state := _get_state(astral)
	for status_id: StringName in [STATUS_INFESTED, STATUS_CHILLED, STATUS_OVERHEATED, STATUS_CONFUSED, STATUS_DISORIENTED, STATUS_POISONED, STATUS_SEVERE_TOXIN]:
		var key := String(status_id) + "_turns"
		if int(state.get(key, 0)) > 0:
			state[key] = 0
			return status_id
	return &""


func get_status_names(astral: AstralInstance) -> PackedStringArray:
	var result: PackedStringArray = []
	if astral == null:
		return result
	var state := _get_state(astral)
	var labels: Dictionary[StringName, String] = {
		STATUS_INFESTED: "Infestato", STATUS_CHILLED: "Assiderato",
		STATUS_OVERHEATED: "Surriscaldato", STATUS_CONFUSED: "Confuso",
		STATUS_DISORIENTED: "Disorientato", STATUS_POISONED: "Avvelenato",
		STATUS_SEVERE_TOXIN: "Tossina Grave",
	}
	for status_id: StringName in labels:
		if int(state.get(String(status_id) + "_turns", 0)) > 0:
			result.append(labels[status_id])
	return result


func apply_negative_status(
	source: AstralInstance,
	target: AstralInstance,
	status_id: StringName,
	turns: int
) -> AstralInstance:
	if target == null or turns <= 0:
		return target
	var resolved_target := target
	if has_species(target, AstralSpecies.LUCENT) and get_tier(AstralSpecies.LUCENT) >= 2:
		var target_state := _get_state(target)
		if bool(target_state.get("lucent_reflect_available", true)) and source != null:
			target_state["lucent_reflect_available"] = false
			resolved_target = source
	_get_state(resolved_target)[String(status_id) + "_turns"] = turns
	return resolved_target


func apply_stat_change(
	source: AstralInstance,
	target: AstralInstance,
	stat_id: StringName,
	amount: int
) -> AstralInstance:
	if target == null or amount == 0:
		return target
	var resolved_target := target
	if amount < 0 and has_species(target, AstralSpecies.LUCENT) and get_tier(AstralSpecies.LUCENT) >= 5:
		var target_state := _get_state(target)
		if bool(target_state.get("lucent_stat_reflect_available", true)) and source != null:
			target_state["lucent_stat_reflect_available"] = false
			resolved_target = source
	add_stat_stage(resolved_target, stat_id, amount)
	return resolved_target


func transfer_opponent_statuses(
	previous_astral: AstralInstance,
	new_astral: AstralInstance
) -> void:
	if (
		previous_astral == null
		or new_astral == null
		or get_tier(AstralSpecies.INSECT) < 5
	):
		return
	var previous_state := _get_state(previous_astral)
	var turns := int(previous_state.get("infestato_turns", 0))
	if turns <= 0:
		return
	previous_state["infestato_turns"] = 0
	_get_state(new_astral)["infestato_turns"] = turns


func add_stat_stage(
	astral: AstralInstance,
	stat_id: StringName,
	amount: int,
	maximum: int = 6
) -> int:
	if astral == null:
		return 0
	var state := _get_state(astral)
	var stages: Dictionary = state.get("stages", {})
	var updated := clampi(int(stages.get(stat_id, 0)) + amount, -6, maximum)
	stages[stat_id] = updated
	state["stages"] = stages
	return updated


func get_stat_stage(astral: AstralInstance, stat_id: StringName) -> int:
	if astral == null:
		return 0
	var stages: Dictionary = _get_state(astral).get("stages", {})
	return int(stages.get(stat_id, 0))


func clear_temporary_stages(astral: AstralInstance) -> void:
	if astral != null:
		_get_state(astral)["stages"] = {}


static func stage_to_multiplier(stage: int) -> float:
	if stage >= 0:
		return 1.0 + float(stage) * 0.5
	return 1.0 / (1.0 + float(-stage) * 0.5)


func _rebuild_counts() -> void:
	_counts.clear()
	_tiers.clear()
	for species_id: StringName in AstralSpecies.ALL_IDS:
		_counts[species_id] = 0
	for astral: AstralInstance in _party_members:
		if astral == null or astral.definition == null:
			continue
		for species_id: StringName in astral.definition.get_species_types():
			_counts[species_id] = int(_counts.get(species_id, 0)) + 1
	for species_id: StringName in AstralSpecies.ALL_IDS:
		_tiers[species_id] = AstralSynergyCatalog.get_active_tier(species_id, get_count(species_id))


func _get_state(astral: AstralInstance) -> Dictionary:
	var key := astral.get_instance_id()
	if not _states.has(key):
		_states[key] = {
			"stages": {}, "field_turns": 0, "entry_count": 0,
			"fairy_veil": true, "lucent_reflect_available": true,
			"lucent_stat_reflect_available": true,
			"last_damage_round": -2, "damage_turn_streak": 0,
			"hit_streak": 0, "physical_hit_streak": 0,
			"last_move": null, "last_used_move": null,
			"cooldown_bypass": 0, "toxin_tick": 0,
		}
	return _states[key] as Dictionary


func _apply_cosmic_entry_stages(astral: AstralInstance) -> void:
	var stats: Array[Dictionary] = [
		{"id": STAT_ATTACK, "value": astral.get_attack_power()},
		{"id": STAT_PHYSICAL_DEFENSE, "value": astral.get_physical_defense()},
		{"id": STAT_MAGIC_ATTACK, "value": astral.get_magic_attack()},
		{"id": STAT_MAGIC_DEFENSE, "value": astral.get_magic_defense()},
		{"id": STAT_SPEED, "value": astral.get_speed()},
	]
	stats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["value"]) > int(b["value"]))
	var amount := 1
	if get_tier(AstralSpecies.COSMIC) >= 5:
		amount = 2
	if get_tier(AstralSpecies.COSMIC) >= 6:
		amount = stats.size()
	for index: int in mini(amount, stats.size()):
		add_stat_stage(astral, StringName(stats[index]["id"]), 1, 1)


func _track_bestial(astral: AstralInstance, state: Dictionary, messages: PackedStringArray) -> void:
	if not has_species(astral, AstralSpecies.BEAST) or get_tier(AstralSpecies.BEAST) < 2:
		return
	if get_tier(AstralSpecies.BEAST) >= 5:
		state["hit_streak"] = int(state.get("hit_streak", 0)) + 1
		if int(state["hit_streak"]) % 2 == 0 and get_stat_stage(astral, STAT_ATTACK) < 2:
			add_stat_stage(astral, STAT_ATTACK, 1, 2)
			messages.append("%s ottiene +1 Atk dalla sinergia Bestiale." % astral.definition.display_name)
		return
	var last_round := int(state.get("last_damage_round", -2))
	if last_round != _round_index:
		state["damage_turn_streak"] = int(state.get("damage_turn_streak", 0)) + 1 if last_round == _round_index - 1 else 1
		state["last_damage_round"] = _round_index
	if int(state["damage_turn_streak"]) >= 2 and get_stat_stage(astral, STAT_ATTACK) < 1:
		add_stat_stage(astral, STAT_ATTACK, 1, 1)
		messages.append("%s ottiene +1 Atk dalla sinergia Bestiale." % astral.definition.display_name)


func _track_insect(attacker: AstralInstance, defender: AstralInstance, state: Dictionary, messages: PackedStringArray) -> void:
	if not has_species(attacker, AstralSpecies.INSECT) or get_tier(AstralSpecies.INSECT) < 2:
		return
	state["insect_hits"] = int(state.get("insect_hits", 0)) + 1
	var threshold := 2 if get_tier(AstralSpecies.INSECT) >= 3 else 3
	if int(state["insect_hits"]) >= threshold:
		state["insect_hits"] = 0
		state["infestato_turns"] = 3
		messages.append("%s è Infestato." % defender.definition.display_name)


func _track_cold(attacker: AstralInstance, defender: AstralInstance, state: Dictionary, messages: PackedStringArray) -> void:
	if not has_species(attacker, AstralSpecies.COLD) or get_tier(AstralSpecies.COLD) < 2:
		return
	state["cold_hits"] = int(state.get("cold_hits", 0)) + 1
	var threshold := 2 if get_tier(AstralSpecies.COLD) >= 4 else 3
	if int(state["cold_hits"]) >= threshold:
		state["cold_hits"] = 0
		state["assiderato_turns"] = 1
		state["chilled_blocks_high_cost"] = get_tier(AstralSpecies.COLD) >= 4
		messages.append("%s subisce Assideramento." % defender.definition.display_name)


func _track_hot(attacker: AstralInstance, defender: AstralInstance, state: Dictionary, messages: PackedStringArray) -> void:
	if not has_species(attacker, AstralSpecies.HOT) or get_tier(AstralSpecies.HOT) < 2:
		return
	var last_round := int(state.get("hot_last_round", -2))
	if last_round != _round_index:
		state["hot_streak"] = int(state.get("hot_streak", 0)) + 1 if last_round == _round_index - 1 else 1
		state["hot_last_round"] = _round_index
	if int(state["hot_streak"]) >= 2:
		state["surriscaldato_turns"] = 3
		state["overheated_tier"] = get_tier(AstralSpecies.HOT)
		messages.append("%s è Surriscaldato." % defender.definition.display_name)


func _track_ethereal(attacker: AstralInstance, defender: AstralInstance, state: Dictionary, messages: PackedStringArray) -> void:
	if not has_species(attacker, AstralSpecies.ETHEREAL) or get_tier(AstralSpecies.ETHEREAL) < 2:
		return
	state["ethereal_hits"] = int(state.get("ethereal_hits", 0)) + 1
	if int(state["ethereal_hits"]) >= 2:
		state["ethereal_hits"] = 0
		state["confuso_turns"] = 3 if get_tier(AstralSpecies.ETHEREAL) >= 4 else 2
		state["confusion_tier"] = get_tier(AstralSpecies.ETHEREAL)
		messages.append("%s entra in Confusione." % defender.definition.display_name)


func _track_toxic(attacker: AstralInstance, defender: AstralInstance, state: Dictionary, messages: PackedStringArray) -> void:
	if not has_species(attacker, AstralSpecies.TOXIC) or get_tier(AstralSpecies.TOXIC) < 2:
		return
	state["toxic_doses"] = int(state.get("toxic_doses", 0)) + 1
	var threshold := 2 if get_tier(AstralSpecies.TOXIC) >= 4 else 3
	if int(state["toxic_doses"]) >= threshold:
		state["toxic_doses"] = 0
		if get_tier(AstralSpecies.TOXIC) >= 5:
			state["tossina_grave_turns"] = 999
			state["toxin_tick"] = 0
			messages.append("%s subisce Tossina Grave." % defender.definition.display_name)
		else:
			state["avvelenato_turns"] = 999
			messages.append("%s viene Avvelenato." % defender.definition.display_name)


func _track_dragon(attacker: AstralInstance, state: Dictionary, messages: PackedStringArray, result: Dictionary) -> void:
	if not has_species(attacker, AstralSpecies.DRAGON) or get_tier(AstralSpecies.DRAGON) < 3:
		return
	var last_round := int(state.get("dragon_last_round", -2))
	if last_round != _round_index:
		state["dragon_turn_streak"] = int(state.get("dragon_turn_streak", 0)) + 1 if last_round == _round_index - 1 else 1
		state["dragon_last_round"] = _round_index
	if int(state["dragon_turn_streak"]) >= 2:
		state["priority_uses"] = int(state.get("priority_uses", 0)) + 1
		state["dragon_turn_streak"] = 0
		messages.append("%s entra in Furia." % attacker.definition.display_name)
	state["dragon_hits"] = int(state.get("dragon_hits", 0)) + 1
	if get_tier(AstralSpecies.DRAGON) >= 6 and int(state["dragon_hits"]) >= 3 and not bool(state.get("dragon_entry_repeat_used", false)):
		state["dragon_entry_repeat_used"] = true
		result["repeat_move"] = true


func _track_fighter(attacker: AstralInstance, move: AstralMoveDefinition, state: Dictionary, messages: PackedStringArray, result: Dictionary) -> void:
	if move.damage_class != AstralMoveDefinition.DamageClass.PHYSICAL or not has_species(attacker, AstralSpecies.FIGHTER) or get_tier(AstralSpecies.FIGHTER) < 2:
		return
	state["physical_hit_streak"] = int(state.get("physical_hit_streak", 0)) + 1
	if int(state["physical_hit_streak"]) == 2:
		state["priority_uses"] = int(state.get("priority_uses", 0)) + 1
		messages.append("La prossima mossa fisica di %s ottiene Priorità." % attacker.definition.display_name)
	if get_tier(AstralSpecies.FIGHTER) >= 4 and int(state["physical_hit_streak"]) >= 3:
		state["physical_hit_streak"] = 0
		var candidates: Array[AstralMoveDefinition] = []
		for candidate: AstralMoveDefinition in attacker.get_moves():
			if candidate != null and candidate.damage_class == AstralMoveDefinition.DamageClass.PHYSICAL and candidate.cooldown_turns == 0 and candidate.power > 0:
				candidates.append(candidate)
		if not candidates.is_empty():
			result["bonus_move"] = candidates[_rng.randi_range(0, candidates.size() - 1)]


func _apply_field_turn_synergies(astral: AstralInstance, state: Dictionary, messages: PackedStringArray) -> void:
	var field_turns := int(state.get("field_turns", 0))
	if has_species(astral, AstralSpecies.AMPHIBIAN) and get_tier(AstralSpecies.AMPHIBIAN) >= 2 and field_turns % 3 == 0:
		var divisor := 8 if get_tier(AstralSpecies.AMPHIBIAN) >= 4 else 16
		_heal_fraction(astral, divisor, messages, "Anfibio")
		if get_tier(AstralSpecies.AMPHIBIAN) >= 6:
			remove_one_negative_status(astral)
	if has_species(astral, AstralSpecies.TERRESTRIAL) and get_tier(AstralSpecies.TERRESTRIAL) >= 5 and field_turns == 3:
		add_stat_stage(astral, STAT_PHYSICAL_DEFENSE, 1, 2)
		messages.append("%s ottiene un ulteriore +1 PDef." % astral.definition.display_name)
	if has_species(astral, AstralSpecies.AERIAL) and get_tier(AstralSpecies.AERIAL) >= 2:
		var threshold := 1 if get_tier(AstralSpecies.AERIAL) >= 4 else 2
		if field_turns == threshold:
			add_stat_stage(astral, STAT_SPEED, 1, 2 if get_tier(AstralSpecies.AERIAL) >= 5 else 1)
			messages.append("%s ottiene +1 Spd dalla sinergia Aero." % astral.definition.display_name)
		if get_tier(AstralSpecies.AERIAL) >= 5:
			if int(state["acted_first_streak"]) == 3 and get_stat_stage(astral, STAT_SPEED) < 2:
				add_stat_stage(astral, STAT_SPEED, 1, 2)
	if has_species(astral, AstralSpecies.AQUATIC) and get_tier(AstralSpecies.AQUATIC) >= 2:
		var aquatic_tier := get_tier(AstralSpecies.AQUATIC)
		var interval := 2 if aquatic_tier >= 6 else (3 if aquatic_tier >= 4 else 4)
		var maximum := 3 if aquatic_tier >= 6 else (2 if aquatic_tier >= 4 else 1)
		if field_turns % interval == 0 and get_stat_stage(astral, STAT_SPEED) < maximum:
			add_stat_stage(astral, STAT_SPEED, 1, maximum)
			messages.append("%s ottiene +1 Spd dalla sinergia Acquatico." % astral.definition.display_name)


func _apply_nature_regeneration(astral: AstralInstance, state: Dictionary, messages: PackedStringArray) -> void:
	if get_tier(AstralSpecies.NATURE) < 3 or _round_index % 3 != 0:
		return
	var divisor := 8 if get_tier(AstralSpecies.NATURE) >= 4 else 16
	_heal_fraction(astral, divisor, messages, "Natura")
	state["nature_heal_count"] = int(state.get("nature_heal_count", 0)) + 1
	if get_tier(AstralSpecies.NATURE) >= 4 and int(state["nature_heal_count"]) % 2 == 0:
		remove_one_negative_status(astral)


func _update_fairy_veil(astral: AstralInstance, state: Dictionary, messages: PackedStringArray) -> void:
	if not has_species(astral, AstralSpecies.FAIRY) or get_tier(AstralSpecies.FAIRY) < 6 or bool(state.get("fairy_veil", false)):
		state["was_hit_this_round"] = false
		return
	if bool(state.get("was_hit_this_round", false)):
		state["turns_without_hit"] = 0
	else:
		state["turns_without_hit"] = int(state.get("turns_without_hit", 0)) + 1
	if int(state["turns_without_hit"]) >= 3:
		state["fairy_veil"] = true
		state["turns_without_hit"] = 0
		messages.append("Il Velo di %s si rigenera." % astral.definition.display_name)
	state["was_hit_this_round"] = false


func _apply_end_round_statuses(astral: AstralInstance, messages: PackedStringArray) -> void:
	if astral == null or astral.is_defeated():
		return
	var state := _get_state(astral)
	if int(state.get("infestato_turns", 0)) > 0:
		_apply_direct_damage(astral, SMALL_DIRECT_DAMAGE_DIVISOR, "Infestazione", messages)
		state["infestato_turns"] = int(state["infestato_turns"]) - 1
	if int(state.get("avvelenato_turns", 0)) > 0:
		_apply_direct_damage(astral, SMALL_DIRECT_DAMAGE_DIVISOR, "Veleno", messages)
	if int(state.get("tossina_grave_turns", 0)) > 0:
		state["toxin_tick"] = int(state.get("toxin_tick", 0)) + 1
		var damage := maxi(1, floori(float(astral.get_max_health() * int(state["toxin_tick"])) / 16.0))
		var applied := astral.take_damage(damage)
		messages.append("Tossina Grave infligge %d danni a %s." % [applied, astral.definition.display_name])
	for key: String in ["assiderato_turns", "surriscaldato_turns", "confuso_turns"]:
		if int(state.get(key, 0)) > 0:
			state[key] = int(state[key]) - 1
			if key == "confuso_turns" and int(state[key]) == 0 and int(state.get("confusion_tier", 0)) >= 6:
				state["disorientato_turns"] = 1


func _try_automatic_fossil_revival(messages: PackedStringArray) -> void:
	if (
		_fossil_revival_used
		or _roster == null
		or get_tier(AstralSpecies.FOSSIL) != 3
	):
		return
	var candidate: AstralInstance = null
	for astral: AstralInstance in _roster.get_astrals():
		if astral != null and astral.is_defeated() and has_species(astral, AstralSpecies.FOSSIL):
			candidate = astral
			break
	if candidate == null:
		return
	_fossil_revival_used = true
	candidate.current_health = maxi(1, floori(float(candidate.get_max_health()) / 4.0))
	messages.append("La sinergia Fossile riporta in vita %s con %d HP." % [candidate.definition.display_name, candidate.current_health])


func _heal_fraction(astral: AstralInstance, divisor: int, messages: PackedStringArray, source_name: String) -> void:
	var amount := maxi(1, floori(float(astral.get_max_health()) / float(divisor)))
	var previous := astral.current_health
	astral.current_health = mini(astral.current_health + amount, astral.get_max_health())
	var healed := astral.current_health - previous
	if healed > 0:
		messages.append("%s recupera %d HP grazie alla sinergia %s." % [astral.definition.display_name, healed, source_name])


func _apply_direct_damage(astral: AstralInstance, divisor: int, source_name: String, messages: PackedStringArray) -> void:
	var damage := maxi(1, floori(float(astral.get_max_health()) / float(divisor)))
	var applied := astral.take_damage(damage)
	messages.append("%s infligge %d danni a %s." % [source_name, applied, astral.definition.display_name])


func should_neutralize_immunity(
	attacker: AstralInstance,
	defender: AstralInstance,
	move: AstralMoveDefinition
) -> bool:
	if _mythical_immunity_used or not has_species(attacker, AstralSpecies.MYTHICAL) or get_tier(AstralSpecies.MYTHICAL) < 3:
		return false
	if BattleMath.get_element_multiplier(move.element_id, defender.definition) > 0.0:
		return false
	_mythical_immunity_used = true
	return true


func _get_highest_level_member(species_id: StringName) -> AstralInstance:
	var result: AstralInstance = null
	for astral: AstralInstance in _party_members:
		if has_species(astral, species_id) and (result == null or astral.level > result.level):
			result = astral
	return result


func _create_nature_manifestation(source: AstralDefinition) -> AstralDefinition:
	var definition := AstralDefinition.new()
	definition.astral_id = &"nature_manifestation"
	definition.display_name = "Manifestazione Naturale"
	definition.species_name = "Evocazione temporanea"
	definition.description = "Astral evocato esclusivamente dalla sinergia Natura."
	definition.primary_element = &"natura"
	definition.set_species_types([AstralSpecies.NATURE])
	definition.set_base_stats(source.max_health, source.attack_power, source.physical_defense, source.magic_attack, source.magic_defense, source.speed)
	definition.rarity = source.rarity
	definition.visual_color = source.visual_color
	definition.model_path = source.model_path
	definition.model_scale_multiplier = source.model_scale_multiplier
	definition.model_rotation_degrees = source.model_rotation_degrees
	definition.starting_moves.assign(source.get_all_moves())
	return definition
