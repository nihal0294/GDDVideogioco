class_name BattleMath
extends RefCounted

const STAB_MULTIPLIER: float = 1.5
const NEUTRAL_ELEMENT: StringName = &"neutro"
const SUPPORTED_ELEMENTS: Array[StringName] = [
	&"neutro",
	&"fuoco",
	&"acqua",
	&"natura",
]

const ELEMENT_MULTIPLIERS: Dictionary = {
	&"fuoco": {
		&"fuoco": 0.5,
		&"acqua": 0.5,
		&"natura": 2.0,
	},
	&"acqua": {
		&"fuoco": 2.0,
		&"acqua": 0.5,
		&"natura": 0.5,
	},
	&"natura": {
		&"fuoco": 0.5,
		&"acqua": 2.0,
		&"natura": 0.5,
	},
}


## Formula deterministica:
## floor((power * attack / 10 + 2) * level_ratio * STAB * element),
## dove level_ratio = (attacker_level + 10) / (defender_level + 10).
## Un'immunita elementale restituisce zero; altrimenti il minimo e un danno.
static func calculate_damage(
	attacker: AstralInstance,
	defender: AstralInstance,
	move: AstralMoveDefinition
) -> int:
	if (
		attacker == null
		or attacker.definition == null
		or defender == null
		or defender.definition == null
		or move == null
		or move.power <= 0
	):
		return 0

	var attacker_level := maxi(attacker.level, 1)
	var defender_level := maxi(defender.level, 1)
	var level_ratio := (
		(float(attacker_level) + 10.0)
		/ (float(defender_level) + 10.0)
	)
	var base_damage := (
		float(move.power)
		* float(attacker.definition.attack_power)
		/ 10.0
		+ 2.0
	)
	var move_element := _normalized_element(move.element_id)
	var stab := (
		STAB_MULTIPLIER
		if attacker.definition.has_element(move_element)
		else 1.0
	)
	var element_multiplier := get_element_multiplier(
		move_element,
		defender.definition
	)
	if element_multiplier <= 0.0:
		return 0
	return maxi(
		1,
		floori(base_damage * level_ratio * stab * element_multiplier)
	)


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
	if defender == null:
		return 1.0
	var normalized_attacker := _normalized_element(attacking_element)
	var multiplier := 1.0
	for defending_element: StringName in SUPPORTED_ELEMENTS:
		if defender.has_element(defending_element):
			multiplier *= _get_single_element_multiplier(
				normalized_attacker,
				defending_element
			)
	return multiplier


static func _get_single_element_multiplier(
	attacking_element: StringName,
	defending_element: StringName
) -> float:
	var attack_matchups := ELEMENT_MULTIPLIERS.get(attacking_element, {}) as Dictionary
	return float(attack_matchups.get(defending_element, 1.0))


static func _normalized_element(element_id: StringName) -> StringName:
	return NEUTRAL_ELEMENT if element_id.is_empty() else element_id
