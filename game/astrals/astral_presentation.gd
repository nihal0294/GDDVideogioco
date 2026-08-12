class_name AstralPresentation
extends RefCounted

const DEFAULT_ELEMENT: StringName = &"neutro"

const ELEMENT_SYMBOLS: Dictionary[StringName, String] = {
	&"natura": "🍃",
	&"fuoco": "🔥",
	&"acqua": "💧",
	&"neutro": "✦",
}

const ELEMENT_NAMES: Dictionary[StringName, String] = {
	&"natura": "Natura",
	&"fuoco": "Fuoco",
	&"acqua": "Acqua",
	&"neutro": "Neutro",
}


static func get_element_symbol(element_id: StringName) -> String:
	var normalized_element := (
		DEFAULT_ELEMENT if element_id.is_empty() else element_id
	)
	return ELEMENT_SYMBOLS.get(normalized_element, "✦")


static func get_element_name(element_id: StringName) -> String:
	var normalized_element := (
		DEFAULT_ELEMENT if element_id.is_empty() else element_id
	)
	return ELEMENT_NAMES.get(
		normalized_element,
		String(normalized_element).replace("_", " ").capitalize()
	)


static func format_element(element_id: StringName) -> String:
	return "%s %s" % [
		get_element_symbol(element_id),
		get_element_name(element_id),
	]


static func get_sex_symbol(sex: int) -> String:
	return "♀" if sex == AstralInstance.Sex.FEMALE else "♂"


static func get_sex_name(sex: int) -> String:
	return "Femmina" if sex == AstralInstance.Sex.FEMALE else "Maschio"


static func format_identity(astral: AstralInstance) -> String:
	if astral == null or astral.definition == null:
		return "Astral sconosciuto"
	return "%s %s %s" % [
		astral.definition.display_name,
		get_sex_symbol(astral.sex),
		get_element_symbol(astral.definition.primary_element),
	]
