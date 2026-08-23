class_name AstralSpecies
extends RefCounted

const DINOSAUR: StringName = &"dinosauro"
const AMPHIBIAN: StringName = &"anfibio"
const AQUATIC: StringName = &"acquatico"
const TERRESTRIAL: StringName = &"terrestre"
const SYNTHETIC: StringName = &"sintetico"
const BEAST: StringName = &"bestiale"
const AERIAL: StringName = &"aero"
const FAIRY: StringName = &"fatato"
const INSECT: StringName = &"insetto"
const COLD: StringName = &"freddo"
const HOT: StringName = &"caldo"
const ETHEREAL: StringName = &"etereo"
const CRYSTAL: StringName = &"cristallo"
const DRAGON: StringName = &"drago"
const FOSSIL: StringName = &"fossile"
const LUCENT: StringName = &"lucente"
const DARK: StringName = &"oscuro"
const EPIC: StringName = &"epico"
const MYTHICAL: StringName = &"mitico"
const NATURE: StringName = &"natura"
const MOUSE: StringName = &"topo"
const COSMIC: StringName = &"cosmico"
const FIGHTER: StringName = &"combattente"
const TOXIC: StringName = &"tossico"

const ALL_IDS: Array[StringName] = [
	DINOSAUR,
	AMPHIBIAN,
	AQUATIC,
	TERRESTRIAL,
	SYNTHETIC,
	BEAST,
	AERIAL,
	FAIRY,
	INSECT,
	COLD,
	HOT,
	ETHEREAL,
	CRYSTAL,
	DRAGON,
	FOSSIL,
	LUCENT,
	DARK,
	EPIC,
	MYTHICAL,
	NATURE,
	MOUSE,
	COSMIC,
	FIGHTER,
	TOXIC,
]

const DISPLAY_NAMES: Dictionary[StringName, String] = {
	DINOSAUR: "Dinosauro",
	AMPHIBIAN: "Anfibio",
	AQUATIC: "Acquatico",
	TERRESTRIAL: "Terrestre",
	SYNTHETIC: "Sintetico",
	BEAST: "Bestiale",
	AERIAL: "Aero",
	FAIRY: "Fatato",
	INSECT: "Insetto",
	COLD: "Freddo",
	HOT: "Caldo",
	ETHEREAL: "Etereo",
	CRYSTAL: "Cristallo",
	DRAGON: "Drago",
	FOSSIL: "Fossile",
	LUCENT: "Lucente",
	DARK: "Oscuro",
	EPIC: "Epico",
	MYTHICAL: "Mitico",
	NATURE: "Natura",
	MOUSE: "Topo",
	COSMIC: "Cosmico",
	FIGHTER: "Combattente",
	TOXIC: "Tossico",
}


static func is_valid(species_id: StringName) -> bool:
	return DISPLAY_NAMES.has(species_id)


static func get_display_name(species_id: StringName) -> String:
	return DISPLAY_NAMES.get(species_id, String(species_id).capitalize()) as String


static func normalize_types(raw_types: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not (raw_types is Array):
		return result
	for raw_type: Variant in raw_types as Array:
		var species_id := StringName(String(raw_type).strip_edges().to_lower())
		if not is_valid(species_id) or result.has(species_id):
			continue
		result.append(species_id)
		if result.size() == 2:
			break
	return result


static func format_types(species_types: Array[StringName]) -> String:
	var names: PackedStringArray = []
	for species_id: StringName in species_types:
		if is_valid(species_id):
			names.append(get_display_name(species_id))
	return ", ".join(names)
