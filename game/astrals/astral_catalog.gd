class_name AstralCatalog
extends RefCounted

const DATA_PATH := "res://data/astrals/species_catalog.json"
const WILD_BASE_IDS: Array[StringName] = [
	&"venomquill", &"flambore", &"vorix", &"panthor", &"silphy", &"pandalith",
]
const LEGACY_ASTRAL_ALIASES: Dictionary[StringName, StringName] = {
	&"player_placeholder": &"venomquill",
	&"wild_placeholder": &"flambore",
	&"wyrm_di_lava": &"flambore",
	&"topo_onda": &"vorix",
	&"orso_fatato": &"silphy",
	&"slime_arcobaleno": &"pandalith",
}

static var _definitions: Dictionary[StringName, AstralDefinition] = {}
static var _moves: Dictionary[StringName, AstralMoveDefinition] = {}
static var _ordered_ids: Array[StringName] = []


static func load_definitions() -> Dictionary[StringName, AstralDefinition]:
	_ensure_loaded()
	return _definitions.duplicate()


static func load_definition(astral_id: StringName) -> AstralDefinition:
	_ensure_loaded()
	return _definitions.get(normalize_astral_id(astral_id)) as AstralDefinition


static func load_ordered_definitions() -> Array[AstralDefinition]:
	_ensure_loaded()
	var result: Array[AstralDefinition] = []
	for astral_id: StringName in _ordered_ids:
		var definition := _definitions.get(astral_id) as AstralDefinition
		if definition != null:
			result.append(definition)
	return result


static func load_wild_base_definitions() -> Array[AstralDefinition]:
	_ensure_loaded()
	var result: Array[AstralDefinition] = []
	for astral_id: StringName in WILD_BASE_IDS:
		var definition := _definitions.get(astral_id) as AstralDefinition
		if definition != null:
			result.append(definition)
	return result


static func load_moves() -> Dictionary[StringName, AstralMoveDefinition]:
	_ensure_loaded()
	return _moves.duplicate()


static func normalize_astral_id(astral_id: StringName) -> StringName:
	return LEGACY_ASTRAL_ALIASES.get(astral_id, astral_id) as StringName


static func _ensure_loaded() -> void:
	if not _definitions.is_empty():
		return
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Catalogo Astral non disponibile: %s" % DATA_PATH)
		return
	var raw_data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (raw_data is Dictionary):
		push_error("Catalogo Astral non valido: %s" % DATA_PATH)
		return
	var data := raw_data as Dictionary
	_build_moves(data.get("moves", {}) as Dictionary)
	var rarities := data.get("rarities", {}) as Dictionary
	var raw_species: Variant = data.get("species", [])
	if not (raw_species is Array):
		return
	for raw_entry: Variant in raw_species as Array:
		if raw_entry is Dictionary:
			_build_definition(raw_entry as Dictionary, rarities)
	_resolve_inheritance(raw_species as Array)
	_resolve_evolutions(raw_species as Array)


static func _build_moves(raw_moves: Dictionary) -> void:
	for raw_id: Variant in raw_moves:
		var move_data: Variant = raw_moves[raw_id]
		if not (move_data is Dictionary):
			continue
		var values := move_data as Dictionary
		var move := AstralMoveDefinition.new()
		move.move_id = StringName(raw_id)
		move.display_name = String(values.get("name", raw_id))
		move.description = String(values.get("description", ""))
		move.element_id = StringName(values.get("element", "neutro"))
		move.power = maxi(int(values.get("power", 0)), 0)
		move.cooldown_turns = clampi(int(values.get("cost", 0)), 0, 5)
		match String(values.get("class", "physical")):
			"magical": move.damage_class = AstralMoveDefinition.DamageClass.MAGICAL
			"status": move.damage_class = AstralMoveDefinition.DamageClass.STATUS
			_: move.damage_class = AstralMoveDefinition.DamageClass.PHYSICAL
		_moves[move.move_id] = move


static func _build_definition(data: Dictionary, rarities: Dictionary) -> void:
	var astral_id := StringName(data.get("id", ""))
	if astral_id.is_empty():
		return
	var definition := AstralDefinition.new()
	definition.astral_id = astral_id
	definition.display_name = String(data.get("name", astral_id))
	definition.species_name = String(data.get("species", "Sconosciuta"))
	definition.description = String(data.get("description", ""))
	var elements: Array = data.get("elements", []) as Array
	if not elements.is_empty(): definition.primary_element = StringName(elements[0])
	if elements.size() > 1: definition.secondary_element = StringName(elements[1])
	var stats: Array = data.get("stats", []) as Array
	if stats.size() >= 6:
		definition.set_base_stats(
			int(stats[0]), int(stats[1]), int(stats[2]),
			int(stats[3]), int(stats[4]), int(stats[5])
		)
	definition.rarity = AstralDefinition.rarity_from_string(
		String(rarities.get(String(astral_id), data.get("rarity", "comune")))
	)
	definition.experience_yield = maxi(int(data.get("experience_yield", 25)), 0)
	definition.visual_color = Color.from_string(
		String(data.get("color", "73bfff")), Color(0.45, 0.75, 1.0, 1.0)
	)
	definition.model_path = String(data.get("model", ""))
	definition.model_scale_multiplier = maxf(float(data.get("model_scale", 1.0)), 0.01)
	var rotation: Array = data.get("model_rotation", []) as Array
	if rotation.size() >= 3:
		definition.model_rotation_degrees = Vector3(
			float(rotation[0]), float(rotation[1]), float(rotation[2])
		)
	definition.learnset = _build_learnset(data.get("learnset", []) as Array)
	_definitions[astral_id] = definition
	_ordered_ids.append(astral_id)


static func _build_learnset(raw_learnset: Array) -> Array[AstralLearnsetEntry]:
	var result: Array[AstralLearnsetEntry] = []
	for raw_entry: Variant in raw_learnset:
		if not (raw_entry is Array): continue
		var values := raw_entry as Array
		if values.size() < 2: continue
		var move := _moves.get(StringName(values[1])) as AstralMoveDefinition
		if move == null: continue
		var entry := AstralLearnsetEntry.new()
		entry.required_level = clampi(int(values[0]), 1, 100)
		entry.move = move
		result.append(entry)
	return result


static func _resolve_inheritance(raw_species: Array) -> void:
	# The catalog is ordered base -> evolution, so inheritance is deterministic.
	for raw_entry: Variant in raw_species:
		if not (raw_entry is Dictionary): continue
		var data := raw_entry as Dictionary
		var definition := _definitions.get(StringName(data.get("id", ""))) as AstralDefinition
		var parent := _definitions.get(StringName(data.get("inherits", ""))) as AstralDefinition
		if definition == null or parent == null: continue
		var inherited: Array[AstralLearnsetEntry] = []
		inherited.assign(parent.learnset)
		for entry: AstralLearnsetEntry in definition.learnset: inherited.append(entry)
		definition.learnset = inherited


static func _resolve_evolutions(raw_species: Array) -> void:
	for raw_entry: Variant in raw_species:
		if not (raw_entry is Dictionary): continue
		var data := raw_entry as Dictionary
		var definition := _definitions.get(StringName(data.get("id", ""))) as AstralDefinition
		if definition == null: continue
		var options: Array[AstralEvolutionOption] = []
		for raw_option: Variant in data.get("evolutions", []) as Array:
			if not (raw_option is Dictionary): continue
			var option_data := raw_option as Dictionary
			var target := _definitions.get(StringName(option_data.get("target", ""))) as AstralDefinition
			if target == null: continue
			var option := AstralEvolutionOption.new()
			option.target = target
			option.required_level = clampi(int(option_data.get("level", 1)), 1, 100)
			option.required_item_id = StringName(option_data.get("item", ""))
			option.method = (
				AstralEvolutionOption.Method.ITEM
				if not option.required_item_id.is_empty()
				else AstralEvolutionOption.Method.LEVEL
			)
			options.append(option)
		definition.evolution_options = options
