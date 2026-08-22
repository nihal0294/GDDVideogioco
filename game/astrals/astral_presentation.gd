class_name AstralPresentation
extends RefCounted

const DEFAULT_ELEMENT: StringName = &"neutro"
const SHINY_SYMBOL: String = "⭐"

const ELEMENT_SYMBOLS: Dictionary[StringName, String] = {
	&"neutro": "✦",
	&"fuoco": "🔥",
	&"acqua": "💧",
	&"natura": "🍃",
	&"aria": "≋",
	&"terra": "◆",
	&"elettro": "⚡",
	&"luce": "☀",
	&"ombra": "◐",
	&"cosmico": "✺",
	&"insetto": "⬡",
	&"sintetico": "⚙",
	&"lotta": "✊",
	&"fatato": "✧",
	&"arcano": "◇",
	&"etereo": "☽",
	&"gelo": "❄",
	&"veleno": "☠",
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
	return ElementChart.get_display_name(normalized_element)


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
	return "%s%s %s %s" % [
		astral.definition.display_name,
		" %s" % SHINY_SYMBOL if astral.is_shiny else "",
		get_sex_symbol(astral.sex),
		get_element_symbol(astral.definition.primary_element),
	]
