class_name ElementChart
extends RefCounted

const NEUTRAL_ELEMENT: StringName = &"neutro"
const STRONG_RESISTANCE: float = 0.25
const RESISTANCE: float = 0.5
const NEUTRAL: float = 1.0
const WEAKNESS: float = 2.0
const STRONG_WEAKNESS: float = 4.0

const ELEMENT_IDS: Array[StringName] = [
	&"neutro",
	&"fuoco",
	&"acqua",
	&"natura",
	&"aria",
	&"terra",
	&"elettro",
	&"luce",
	&"ombra",
	&"cosmico",
	&"insetto",
	&"sintetico",
	&"lotta",
	&"fatato",
	&"arcano",
	&"etereo",
	&"gelo",
	&"veleno",
]

const ELEMENT_NAMES: Dictionary = {
	&"neutro": "Neutro",
	&"fuoco": "Fuoco",
	&"acqua": "Acqua",
	&"natura": "Natura",
	&"aria": "Aria",
	&"terra": "Terra",
	&"elettro": "Elettro",
	&"luce": "Luce",
	&"ombra": "Ombra",
	&"cosmico": "Cosmico",
	&"insetto": "Insetto",
	&"sintetico": "Sintetico",
	&"lotta": "Lotta",
	&"fatato": "Fatato",
	&"arcano": "Arcano",
	&"etereo": "Etereo",
	&"gelo": "Gelo",
	&"veleno": "Veleno",
}

const ELEMENT_ALIASES: Dictionary = {
	&"acciaio": &"sintetico",
	&"spettro": &"etereo",
}

## Le liste sono organizzate per elemento difensivo. L'elemento contenuto
## nella lista e quello della mossa in arrivo.
const WEAKNESSES_BY_DEFENDER: Dictionary = {
	&"fuoco": [&"acqua", &"terra", &"gelo"],
	&"acqua": [&"natura", &"elettro"],
	&"natura": [&"fuoco", &"veleno", &"insetto", &"aria", &"gelo"],
	&"aria": [&"elettro", &"gelo", &"arcano", &"sintetico"],
	&"terra": [&"acqua", &"natura", &"lotta", &"gelo"],
	&"elettro": [&"terra"],
	&"luce": [&"ombra", &"cosmico"],
	&"ombra": [&"luce", &"fatato", &"insetto"],
	&"cosmico": [&"lotta", &"terra", &"arcano"],
	&"insetto": [&"fuoco", &"gelo", &"elettro", &"lotta"],
	&"sintetico": [&"elettro", &"natura", &"fuoco"],
	&"lotta": [&"aria", &"arcano"],
	&"fatato": [&"veleno", &"sintetico", &"etereo"],
	&"arcano": [&"ombra", &"etereo", &"sintetico"],
	&"etereo": [&"etereo", &"luce", &"fatato"],
	&"gelo": [&"fuoco", &"lotta"],
	&"veleno": [&"fuoco", &"terra", &"arcano"],
}

const RESISTANCES_BY_DEFENDER: Dictionary = {
	&"fuoco": [&"natura", &"insetto", &"fuoco"],
	&"acqua": [&"fuoco", &"gelo", &"sintetico", &"acqua", &"luce"],
	&"natura": [&"acqua", &"natura", &"terra", &"elettro", &"luce", &"sintetico"],
	&"aria": [&"natura", &"insetto", &"lotta", &"fatato"],
	&"terra": [&"luce", &"ombra", &"veleno", &"insetto", &"fuoco"],
	&"elettro": [&"aria", &"insetto", &"sintetico"],
	&"luce": [&"gelo", &"etereo", &"natura"],
	&"ombra": [&"etereo", &"cosmico"],
	&"cosmico": [&"insetto", &"fuoco", &"acqua", &"ombra"],
	&"insetto": [&"natura", &"acqua", &"aria"],
	&"sintetico": [&"fatato", &"arcano", &"gelo"],
	&"lotta": [&"veleno", &"cosmico"],
	&"fatato": [&"acqua", &"luce", &"terra"],
	&"arcano": [&"lotta", &"luce", &"arcano"],
	&"etereo": [&"ombra", &"cosmico", &"sintetico"],
	&"gelo": [&"luce", &"terra", &"aria"],
	&"veleno": [&"natura", &"fatato"],
}

## Le immunita descritte nel documento sono forte resistenza (1/4) nella
## tassonomia richiesta per la tabella corrente.
const STRONG_RESISTANCES_BY_DEFENDER: Dictionary = {
	&"natura": [&"fatato", &"ombra"],
	&"aria": [&"terra"],
	&"terra": [&"elettro"],
	&"luce": [&"elettro"],
	&"ombra": [&"arcano"],
	&"cosmico": [&"luce", &"aria"],
	&"insetto": [&"veleno"],
	&"sintetico": [&"veleno"],
	&"fatato": [&"natura"],
	&"arcano": [&"cosmico"],
	&"etereo": [&"lotta"],
	&"gelo": [&"acqua"],
	&"veleno": [&"etereo"],
}


static func get_multiplier(
	attacking_element: StringName,
	defending_element: StringName
) -> float:
	var attacker := normalize_element(attacking_element)
	var defender := normalize_element(defending_element)
	if _contains_match(STRONG_RESISTANCES_BY_DEFENDER, defender, attacker):
		return STRONG_RESISTANCE
	if _contains_match(RESISTANCES_BY_DEFENDER, defender, attacker):
		return RESISTANCE
	if _contains_match(WEAKNESSES_BY_DEFENDER, defender, attacker):
		return WEAKNESS
	return NEUTRAL


static func get_combined_multiplier(
	attacking_element: StringName,
	defending_elements: Array[StringName]
) -> float:
	var multiplier := NEUTRAL
	for defending_element: StringName in defending_elements:
		multiplier *= get_multiplier(attacking_element, defending_element)
	return multiplier


static func get_display_name(element_id: StringName) -> String:
	var normalized := normalize_element(element_id)
	return ELEMENT_NAMES.get(
		normalized,
		String(normalized).replace("_", " ").capitalize()
	)


static func get_multiplier_label(multiplier: float) -> String:
	if is_equal_approx(multiplier, STRONG_RESISTANCE):
		return "1/4"
	if is_equal_approx(multiplier, RESISTANCE):
		return "1/2"
	if is_equal_approx(multiplier, STRONG_WEAKNESS):
		return "4"
	if is_equal_approx(multiplier, WEAKNESS):
		return "2"
	return "1"


static func get_effectiveness_name(multiplier: float) -> String:
	if multiplier <= STRONG_RESISTANCE:
		return "Forte resistenza"
	if multiplier < NEUTRAL:
		return "Resistenza"
	if multiplier >= STRONG_WEAKNESS:
		return "Iperefficace"
	if multiplier > NEUTRAL:
		return "Superefficace"
	return "Neutrale"


static func normalize_element(element_id: StringName) -> StringName:
	if element_id.is_empty():
		return NEUTRAL_ELEMENT
	return ELEMENT_ALIASES.get(element_id, element_id) as StringName


static func _contains_match(
	table: Dictionary,
	defending_element: StringName,
	attacking_element: StringName
) -> bool:
	var matches: Array = table.get(defending_element, []) as Array
	return matches.has(attacking_element)
