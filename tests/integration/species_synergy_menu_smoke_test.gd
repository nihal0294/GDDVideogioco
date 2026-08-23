extends SceneTree

const EXPECTED_TYPES: Dictionary[StringName, Array] = {
	&"venomquill": [&"acquatico", &"tossico"],
	&"flambore": [&"bestiale", &"caldo"],
	&"pyrobore": [&"bestiale", &"caldo"],
	&"fortessbore": [&"bestiale", &"sintetico"],
	&"vorix": [&"anfibio", &"acquatico"],
	&"saurolix": [&"anfibio", &"dinosauro"],
	&"phrynolix": [&"dinosauro", &"bestiale"],
	&"panthor": [&"acquatico", &"bestiale"],
	&"sharkra": [&"acquatico", &"bestiale"],
	&"fangoras": [&"oscuro", &"etereo"],
	&"silphy": [&"aero", &"fatato"],
	&"airdon": [&"aero", &"bestiale"],
	&"eldrakans": [&"aero", &"freddo"],
	&"pandalith": [&"bestiale", &"cristallo"],
	&"aikilith": [&"combattente", &"caldo"],
	&"frostalith": [&"freddo", &"sintetico"],
	&"mindlith": [&"natura", &"etereo"],
}

const EXPECTED_THRESHOLDS: Dictionary[StringName, Array] = {
	&"dinosauro": [2, 4, 6], &"anfibio": [2, 4, 6],
	&"acquatico": [2, 4, 6], &"terrestre": [3, 5],
	&"sintetico": [3, 5], &"bestiale": [2, 5],
	&"aero": [2, 4, 5], &"fatato": [3, 6],
	&"insetto": [2, 3, 5], &"freddo": [2, 4],
	&"caldo": [2, 5], &"etereo": [2, 4, 6],
	&"cristallo": [3, 6], &"drago": [3, 5, 6],
	&"fossile": [3, 4], &"lucente": [2, 5],
	&"oscuro": [3, 4, 6], &"epico": [2, 4],
	&"mitico": [2, 3], &"natura": [3, 4, 5],
	&"topo": [2, 3, 4], &"cosmico": [4, 5, 6],
	&"combattente": [2, 4], &"tossico": [2, 4, 5],
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_species_catalog()
	await _validate_ui()
	_finish()


func _validate_species_catalog() -> void:
	_expect(AstralSpecies.ALL_IDS.size() == 24, "Il catalogo non contiene tutte le 24 specie.")
	_expect(not AstralSpecies.ALL_IDS.has(&"leggendario"), "Leggendario non è stato sostituito da Mitico.")
	_expect(
		AstralSynergyCatalog.get_definitions().size() == AstralSpecies.ALL_IDS.size(),
		"Non tutte le specie possiedono una definizione di Sinergia."
	)
	var unique_ids: Dictionary[StringName, bool] = {}
	for species_id: StringName in AstralSpecies.ALL_IDS:
		_expect(AstralSpecies.is_valid(species_id), "Specie non valida: %s." % species_id)
		_expect(not unique_ids.has(species_id), "Specie duplicata: %s." % species_id)
		_expect(
			not AstralSpecies.get_display_name(species_id).is_empty(),
			"Nome visibile mancante per %s." % species_id
		)
		var thresholds: Array[int] = []
		for tier: Variant in AstralSynergyCatalog.get_tiers(species_id):
			var values := tier as Array
			thresholds.append(int(values[0]))
			_expect(not String(values[1]).is_empty(), "Descrizione mancante per %s." % species_id)
		_expect(
			Array(thresholds) == EXPECTED_THRESHOLDS.get(species_id, []),
			"Soglie errate per %s." % species_id
		)
		unique_ids[species_id] = true

	var definitions := AstralCatalog.load_ordered_definitions()
	_expect(
		definitions.size() == EXPECTED_TYPES.size(),
		"Il numero di Astral classificati non coincide con il catalogo corrente."
	)
	for definition: AstralDefinition in definitions:
		var species_types := definition.get_species_types()
		_expect(
			species_types.size() >= 1 and species_types.size() <= 2,
			"%s deve avere da una a due specie." % definition.display_name
		)
		for species_id: StringName in species_types:
			_expect(
				AstralSpecies.is_valid(species_id),
				"%s usa una specie sconosciuta: %s." % [definition.display_name, species_id]
			)
		var expected: Array = EXPECTED_TYPES.get(definition.astral_id, []) as Array
		_expect(
			Array(species_types) == expected,
			"Assegnazione specie inattesa per %s." % definition.display_name
		)


func _validate_ui() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "Scena Main non caricabile.")
	if main_scene == null:
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame

	var game_ui := main.get_node_or_null("GameUI") as GameUI
	var squad := main.get_node_or_null("GameUI/SquadScreen") as SquadScreen
	_expect(game_ui != null and squad != null, "GameUI o schermata Squadra mancanti.")
	if game_ui == null or squad == null:
		main.queue_free()
		await process_frame
		return

	squad.open()
	await process_frame
	var species_label := squad.get_node_or_null("%SpeciesTypesValue") as Label
	_expect(
		species_label != null and species_label.text.contains("Acquatico, Tossico"),
		"La scheda Squadra non mostra le specie dell'Astral selezionato."
	)
	squad.close()

	game_ui.pause_menu.open(false)
	game_ui.call("_sync_pause_state")
	var synergies_button := game_ui.pause_menu.get_node_or_null("%SynergiesButton") as Button
	_expect(synergies_button != null, "Il menu Esc non contiene il pulsante Sinergie.")
	if synergies_button != null:
		synergies_button.pressed.emit()
		await process_frame
		_expect(
			game_ui.synergy_screen.visible and not game_ui.pause_menu.visible,
			"Il pulsante Sinergie non apre la schermata dedicata."
		)
		var synergy_list := game_ui.synergy_screen.get_node_or_null("%SynergyList") as VBoxContainer
		_expect(
			synergy_list != null
			and synergy_list.get_child_count() == AstralSpecies.ALL_IDS.size(),
			"La schermata non mostra tutte le sinergie configurate."
		)
		var back_button := game_ui.synergy_screen.get_node_or_null("%BackButton") as Button
		_expect(back_button != null, "La schermata Sinergie non consente di tornare indietro.")
		if back_button != null:
			back_button.pressed.emit()
			await process_frame
			_expect(
				game_ui.pause_menu.visible and not game_ui.synergy_screen.visible,
				"Indietro non riporta al menu Esc."
			)

	game_ui.pause_menu.close()
	game_ui.call("_sync_pause_state")
	main.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Species and synergy menu smoke test: PASS")
		quit(0)
	else:
		print("Species and synergy menu smoke test: FAIL (%d errori)" % _failures.size())
		quit(1)
