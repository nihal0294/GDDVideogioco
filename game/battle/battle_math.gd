class_name BattleMath
extends RefCounted

const STAB_MULTIPLIER: float = 1.5
const CRITICAL_HIT_CHANCE: float = 0.10
const CRITICAL_HIT_MULTIPLIER: int = 2
const RANDOM_ROLL_MINIMUM: int = 217
const RANDOM_ROLL_MAXIMUM: int = 255
const RANDOM_ROLL_DIVISOR: int = 255
const EFFECTIVE_ATTACK_SCALE_THRESHOLD: int = 255
const EFFECTIVE_STAT_SCALE_DIVISOR: int = 4
const NEUTRAL_ELEMENT: StringName = ElementChart.NEUTRAL_ELEMENT
const SUPPORTED_ELEMENTS: Array[StringName] = ElementChart.ELEMENT_IDS


## Contesto dei modificatori futuri. I valori sono neutri finche strumenti,
## meteo, abilita e variazioni delle statistiche non li valorizzeranno.
class DamageModifiers:
	var modifier_1: float = 1.0
	var modifier_2: float = 1.0
	var modifier_3: float = 1.0
	var attack_stat_modifier: float = 1.0
	var defense_stat_modifier: float = 1.0


class DamageResult:
	var damage: int = 0
	var is_critical_hit: bool = false
	var random_roll: int = RANDOM_ROLL_MAXIMUM
	var stab_applied: bool = false
	var type_1_multiplier: float = 1.0
	var type_2_multiplier: float = 1.0
	var effective_attack: int = 0
	var effective_defense: int = 0


## Formula attiva (con arrotondamento per difetto a ogni divisione):
## (((((((L * 2 / 5) + 2) * P * A / 50) / D) * Mod1 + 2)
## * CH * Mod2 * Random) * STAB * Tipo1 * Tipo2 * Mod3).
## Random e un intero uniforme tra 217 e 255, diviso per 255.
## STAB aggiunge floor(danno / 2), invece di usare un float intermedio.
static func calculate_damage(
	attacker: AstralInstance,
	defender: AstralInstance,
	move: AstralMoveDefinition,
	critical_hit: bool = false,
	random_roll: int = RANDOM_ROLL_MAXIMUM,
	modifiers: DamageModifiers = null
) -> int:
	return calculate_damage_result(
		attacker,
		defender,
		move,
		critical_hit,
		random_roll,
		modifiers
	).damage


## Esegue i due tiri casuali richiesti dal combattimento reale.
static func roll_damage(
	attacker: AstralInstance,
	defender: AstralInstance,
	move: AstralMoveDefinition,
	rng: RandomNumberGenerator,
	modifiers: DamageModifiers = null
) -> DamageResult:
	var active_rng := rng
	if active_rng == null:
		active_rng = RandomNumberGenerator.new()
		active_rng.randomize()
	var critical_hit := active_rng.randf() < CRITICAL_HIT_CHANCE
	var random_roll := active_rng.randi_range(
		RANDOM_ROLL_MINIMUM,
		RANDOM_ROLL_MAXIMUM
	)
	return calculate_damage_result(
		attacker,
		defender,
		move,
		critical_hit,
		random_roll,
		modifiers
	)


static func calculate_damage_result(
	attacker: AstralInstance,
	defender: AstralInstance,
	move: AstralMoveDefinition,
	critical_hit: bool = false,
	random_roll: int = RANDOM_ROLL_MAXIMUM,
	modifiers: DamageModifiers = null
) -> DamageResult:
	var result := DamageResult.new()
	result.is_critical_hit = critical_hit
	result.random_roll = clampi(
		random_roll,
		RANDOM_ROLL_MINIMUM,
		RANDOM_ROLL_MAXIMUM
	)
	if not _can_calculate_damage(attacker, defender, move):
		return result

	var active_modifiers := modifiers
	if active_modifiers == null:
		active_modifiers = DamageModifiers.new()
	var attack_stat_modifier := maxf(active_modifiers.attack_stat_modifier, 0.0)
	var defense_stat_modifier := maxf(active_modifiers.defense_stat_modifier, 0.0)
	if critical_hit:
		attack_stat_modifier = 1.0
		defense_stat_modifier = 1.0

	var effective_attack := maxi(
		1,
		floori(
			float(_get_offensive_stat(attacker.definition, move))
			* attack_stat_modifier
		)
	)
	var effective_defense := maxi(
		1,
		floori(
			float(_get_defensive_stat(defender.definition, move))
			* defense_stat_modifier
		)
	)
	if effective_attack > EFFECTIVE_ATTACK_SCALE_THRESHOLD:
		effective_attack = maxi(
			1,
			floori(float(effective_attack) / EFFECTIVE_STAT_SCALE_DIVISOR)
		)
		effective_defense = maxi(
			1,
			floori(float(effective_defense) / EFFECTIVE_STAT_SCALE_DIVISOR)
		)
	result.effective_attack = effective_attack
	result.effective_defense = effective_defense

	var level_factor := floori(float(maxi(attacker.level, 1) * 2) / 5.0) + 2
	var damage := floori(
		float(level_factor * move.power * effective_attack) / 50.0
	)
	damage = floori(float(damage) / float(effective_defense))
	damage = floori(float(damage) * maxf(active_modifiers.modifier_1, 0.0))
	damage += 2
	if critical_hit:
		damage *= CRITICAL_HIT_MULTIPLIER
	damage = floori(float(damage) * maxf(active_modifiers.modifier_2, 0.0))
	if damage != 1:
		damage = floori(
			float(damage * result.random_roll) / float(RANDOM_ROLL_DIVISOR)
		)

	var move_element := _normalized_element(move.element_id)
	result.stab_applied = attacker.definition.has_element(move_element)
	if result.stab_applied:
		damage += floori(float(damage) / 2.0)
	var type_multipliers := get_type_multipliers(move_element, defender.definition)
	result.type_1_multiplier = type_multipliers[0]
	result.type_2_multiplier = type_multipliers[1]
	if result.type_1_multiplier <= 0.0 or result.type_2_multiplier <= 0.0:
		result.damage = 0
		return result
	damage = floori(float(damage) * result.type_1_multiplier)
	damage = floori(float(damage) * result.type_2_multiplier)
	damage = floori(float(damage) * maxf(active_modifiers.modifier_3, 0.0))
	result.damage = maxi(damage, 1)
	return result


static func _can_calculate_damage(
	attacker: AstralInstance,
	defender: AstralInstance,
	move: AstralMoveDefinition
) -> bool:
	return (
		attacker != null
		and attacker.definition != null
		and defender != null
		and defender.definition != null
		and move != null
		and move.power > 0
	)


static func _get_offensive_stat(
	definition: AstralDefinition,
	move: AstralMoveDefinition
) -> int:
	if move.damage_class == AstralMoveDefinition.DamageClass.MAGICAL:
		return maxi(definition.magic_attack, 1)
	return maxi(definition.attack_power, 1)


static func _get_defensive_stat(
	definition: AstralDefinition,
	move: AstralMoveDefinition
) -> int:
	if move.damage_class == AstralMoveDefinition.DamageClass.MAGICAL:
		return maxi(definition.magic_defense, 1)
	return maxi(definition.physical_defense, 1)


static func calculate_experience_reward(defeated: AstralInstance) -> int:
	if defeated == null or defeated.definition == null:
		return 0
	return maxi(
		1,
		roundi(
			float(defeated.definition.experience_yield)
			* float(maxi(defeated.level, 1))
			/ 5.0
		)
	)


static func get_element_multiplier(
	attacking_element: StringName,
	defender: AstralDefinition
) -> float:
	var multipliers := get_type_multipliers(attacking_element, defender)
	return multipliers[0] * multipliers[1]


static func get_type_multipliers(
	attacking_element: StringName,
	defender: AstralDefinition
) -> Array[float]:
	var multipliers: Array[float] = [1.0, 1.0]
	if defender == null:
		return multipliers
	var normalized_attacker := _normalized_element(attacking_element)
	var defending_elements := defender.get_elements()
	if not defending_elements.is_empty():
		multipliers[0] = _get_single_element_multiplier(
			normalized_attacker,
			defending_elements[0]
		)
	if defending_elements.size() > 1:
		multipliers[1] = _get_single_element_multiplier(
			normalized_attacker,
			defending_elements[1]
		)
	return multipliers


static func _get_single_element_multiplier(
	attacking_element: StringName,
	defending_element: StringName
) -> float:
	return ElementChart.get_multiplier(attacking_element, defending_element)


static func _normalized_element(element_id: StringName) -> StringName:
	return ElementChart.normalize_element(element_id)
