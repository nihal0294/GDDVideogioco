extends SceneTree

const WATCHDOG_TIMEOUT_SECONDS := 45.0
const BATTLE_TEST_RANDOM_SEED := 24680
const BATTLE_SCENE: PackedScene = preload("res://game/battle/battle.tscn")
const INVENTORY_SCENE: PackedScene = preload("res://game/inventory/inventory.tscn")
const ASTRAL_ROSTER_SCENE: PackedScene = preload(
	"res://game/astrals/astral_roster.tscn"
)
const ASTRAL_BOX_SCENE: PackedScene = preload(
	"res://game/ui/box/astral_box_screen.tscn"
)
const ASTRAL_PRESENTATION := preload(
	"res://game/astrals/astral_presentation.gd"
)

var _failures: Array[String] = []
var _received_encounter: bool = false
var _received_encounter_zone_id: StringName = &""
var _received_encounter_actor: Node3D = null
var _battle_outcome: StringName = &""
var _captured_astral: AstralInstance = null
var _watchdog: Timer = null
var _test_finished: bool = false
var _wild_astral: AstralDefinition = null
var _player_astral: AstralDefinition = null


func _initialize() -> void:
	_wild_astral = AstralCatalog.load_definition(&"flambore")
	_player_astral = AstralCatalog.load_definition(&"venomquill")
	_watchdog = Timer.new()
	_watchdog.name = "SmokeTestWatchdog"
	_watchdog.wait_time = WATCHDOG_TIMEOUT_SECONDS
	_watchdog.one_shot = true
	_watchdog.ignore_time_scale = true
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	_watchdog.timeout.connect(_on_watchdog_timeout)
	_watchdog.autostart = true
	root.add_child(_watchdog)
	call_deferred("_run")


func _run() -> void:
	var main_scene_path := str(
		ProjectSettings.get_setting("application/run/main_scene", "res://main.tscn")
	)
	if main_scene_path.is_empty():
		main_scene_path = "res://main.tscn"
	var packed_main := load(main_scene_path) as PackedScene
	if packed_main == null:
		_fail("Impossibile caricare la scena principale: %s" % main_scene_path)
		_test_finished = true
		_watchdog.stop()
		quit(1)
		return

	var main := packed_main.instantiate()
	root.add_child(main)
	for _frame_index: int in 4:
		await process_frame
		await physics_frame

	_test_main_structure(main)
	_test_wild_astral_pool(main)
	_test_base_stat_rules()
	_test_player_and_camera(main)
	_test_world_map(main)
	await _test_squad_screen(main)
	await _test_astral_box_screen(main)
	await _test_grimoire_and_player_profile(main)
	await _test_options_and_save_system(main)
	_test_astral_instance_progression()
	await _test_astral_catalog_and_evolution()
	_test_astral_sex_and_presentation()
	await _test_astral_roster()
	await _test_astral_box_storage()
	_test_element_chart_data()
	_test_battle_math()
	_test_move_damage_tiers()
	await _test_encounter_wiring(main)
	await _test_tall_grass_response(main)
	await _test_battle_fight()
	await _test_battle_cooldowns_and_presentation()
	await _test_battle_ko_experience()
	await _test_battle_items()
	await _test_battle_capture()
	await _test_battle_flee()
	await _test_battle_switch()
	await _test_battle_forced_switch()
	await _test_trainers(main)
	await _test_world_npcs(main)
	await _test_map_transpositions(main)
	_test_inventory_data()
	_test_grimoire_profile_inputs()
	_test_inputs()

	main.queue_free()
	await process_frame
	_test_finished = true
	_watchdog.stop()
	if _failures.is_empty():
		print("Main scene smoke test: PASS")
		quit(0)
		return
	print("Main scene smoke test: FAIL (%d errori)" % _failures.size())
	quit(1)


func _on_watchdog_timeout() -> void:
	if _test_finished:
		return
	_test_finished = true
	_fail("Smoke test interrotto: superati %.0f secondi." % WATCHDOG_TIMEOUT_SECONDS)
	quit(1)


func _test_main_structure(main: Node) -> void:
	_expect(main is Node3D, "La root della scena principale non è Node3D.")
	_expect(main.get_node_or_null("WorldMap") != null, "WorldMap mancante.")
	_expect(main.get_node_or_null("Player") != null, "Player mancante.")
	_expect(main.get_node_or_null("Inventory") != null, "Inventory mancante.")
	_expect(
		main.get_node_or_null("AstralRoster") is AstralRoster,
		"AstralRoster mancante."
	)
	_expect(main.get_node_or_null("BattleHost") != null, "BattleHost mancante.")
	_expect(main.get_node_or_null("Grimoire") is Grimoire, "Grimoire mancante.")
	_expect(
		main.get_node_or_null("PlayerProfile") is PlayerProfile,
		"PlayerProfile mancante."
	)
	_expect(main.get_node_or_null("GameUI") != null, "GameUI mancante.")
	_expect(main.get_node_or_null("SaveManager") is SaveManager, "SaveManager mancante.")
	var sun := _find_first_node_of_type(main, "DirectionalLight3D")
	var world_environment := _find_first_node_of_type(main, "WorldEnvironment")
	_expect(sun != null, "Luce direzionale del sole mancante.")
	_expect(world_environment != null, "WorldEnvironment mancante.")


func _test_grimoire_and_player_profile(main: Node) -> void:
	var game_ui := main.get_node_or_null("GameUI") as GameUI
	var grimoire := main.get_node_or_null("Grimoire") as Grimoire
	var profile := main.get_node_or_null("PlayerProfile") as PlayerProfile
	var roster := main.get_node_or_null("AstralRoster") as AstralRoster
	var grimoire_screen := main.get_node_or_null(
		"GameUI/GrimoireScreen"
	) as GrimoireScreen
	var profile_screen := main.get_node_or_null(
		"GameUI/PlayerProfileScreen"
	) as PlayerProfileScreen
	if (
		game_ui == null
		or grimoire == null
		or profile == null
		or roster == null
		or grimoire_screen == null
		or profile_screen == null
	):
		_fail("Impossibile verificare Grimorio e Profilo giocatore.")
		return

	var entries := grimoire.get_entries()
	_expect(entries.size() == 17, "Il Grimorio non contiene le diciassette forme Astral.")
	_expect(
		grimoire.is_captured(_player_astral.astral_id),
		"Lo starter posseduto non risulta catturato nel Grimorio."
	)
	_expect(
		grimoire.get_seen_species_count() == 1
		and grimoire.get_captured_species_count() == 1,
		"I contatori iniziali del Grimorio sono errati."
	)

	await _send_action(&"toggle_grimoire")
	_expect(grimoire_screen.visible, "O non apre il Grimorio.")
	_expect(paused, "Il Grimorio non sospende il mondo.")
	_expect(not game_ui.squad_screen.visible, "Il Grimorio lascia aperta Squadra.")
	var entry_list := grimoire_screen.get_node_or_null("%EntryList") as ItemList
	var progress_label := grimoire_screen.get_node_or_null("%ProgressLabel") as Label
	_expect(entry_list != null and entry_list.item_count == 17, "Indice Grimorio errato.")
	_expect(
		progress_label != null and "Visti 1/17" in progress_label.text,
		"Il Grimorio non mostra il progresso delle scoperte."
	)
	await _send_action(&"toggle_grimoire")
	_expect(not grimoire_screen.visible and not paused, "O non chiude il Grimorio.")

	var pool_value: Variant = main.call("get_wild_astral_pool")
	var pool := pool_value as Array
	var discovered_definition: AstralDefinition = null
	if pool != null:
		for candidate: Variant in pool:
			var definition := candidate as AstralDefinition
			if definition != null and not grimoire.is_captured(definition.astral_id):
				discovered_definition = definition
				break
	if discovered_definition == null:
		_fail("Nessuna specie disponibile per il test Grimorio.")
		return
	_expect(
		grimoire.register_seen(discovered_definition),
		"Avvistare una nuova specie non aggiorna il Grimorio."
	)
	_expect(
		grimoire.get_discovery_state(discovered_definition.astral_id)
		== Grimoire.DiscoveryState.SEEN,
		"La specie avvistata non resta nello stato SEEN."
	)

	var source := AstralInstance.new()
	source.setup(discovered_definition, 3, AstralInstance.Sex.FEMALE)
	var initial_capture_count := profile.captured_monster_count
	_expect(roster.capture_astral(source), "Cattura di test rifiutata dal roster.")
	_expect(
		grimoire.is_captured(discovered_definition.astral_id),
		"La cattura non completa la pagina del Grimorio."
	)
	_expect(
		profile.captured_monster_count == initial_capture_count + 1,
		"Il profilo non incrementa il numero di Astral catturati."
	)

	await _send_action(&"toggle_player_profile")
	_expect(profile_screen.visible, "P non apre il profilo giocatore.")
	_expect(paused, "Il profilo giocatore non sospende il mondo.")
	var currency_value := profile_screen.get_node_or_null("%CurrencyValue") as Label
	var captured_value := profile_screen.get_node_or_null("%CapturedValue") as Label
	var medals_summary := profile_screen.get_node_or_null("%MedalsSummary") as Label
	var medal_grid := profile_screen.get_node_or_null("%MedalGrid") as GridContainer
	var preview := profile_screen.get_node_or_null(
		"OuterMargin/Layout/Content/PortraitPanel/PortraitMargin/PortraitLayout/Preview/SubViewport/PlayerPreview/Body"
	) as MeshInstance3D
	_expect(currency_value != null and "0 Fiorini" in currency_value.text, "Valuta profilo errata.")
	_expect(
		captured_value != null
		and captured_value.text == str(profile.captured_monster_count),
		"Conteggio catture non aggiornato nella schermata profilo."
	)
	_expect(medals_summary != null and medals_summary.text == "0 / 8", "Riepilogo medaglie errato.")
	_expect(medal_grid != null and medal_grid.get_child_count() == 8, "Gli otto slot medaglia non sono presenti.")
	_expect(preview != null and preview.mesh is CapsuleMesh, "Il ritratto provvisorio non usa una pillola 3D.")

	_expect(profile.add_florins(125), "Impossibile aggiungere Fiorini al profilo.")
	_expect(profile.earn_medal(0), "Impossibile assegnare la prima medaglia.")
	_expect(currency_value.text == "125 Fiorini", "La UI non aggiorna i Fiorini.")
	_expect(medals_summary.text == "1 / 8", "La UI non aggiorna le medaglie.")

	await _send_action(&"toggle_grimoire")
	_expect(grimoire_screen.visible, "O non apre il Grimorio dal profilo.")
	_expect(not profile_screen.visible, "Aprire il Grimorio non chiude il profilo.")
	game_ui.set_pause_lock(&"battle", true)
	_expect(not grimoire_screen.visible, "Il battle lock non chiude il Grimorio.")
	await _send_action(&"toggle_player_profile")
	_expect(not profile_screen.visible, "P apre il profilo durante il battle lock.")
	game_ui.set_pause_lock(&"battle", false)
	_expect(not paused, "Rimuovere il battle lock lascia il mondo in pausa.")


func _test_options_and_save_system(main: Node) -> void:
	var game_ui := main.get_node_or_null("GameUI") as GameUI
	var save_manager := main.get_node_or_null("SaveManager") as SaveManager
	var player := main.get_node_or_null("Player") as CharacterBody3D
	var inventory := main.get_node_or_null("Inventory") as Inventory
	var roster := main.get_node_or_null("AstralRoster") as AstralRoster
	var grimoire := main.get_node_or_null("Grimoire") as Grimoire
	var profile := main.get_node_or_null("PlayerProfile") as PlayerProfile
	var world_map := main.get_node_or_null("WorldMap") as Node3D
	if (
		game_ui == null
		or save_manager == null
		or player == null
		or inventory == null
		or roster == null
		or grimoire == null
		or profile == null
		or world_map == null
	):
		_fail("Impossibile verificare Opzioni e salvataggi.")
		return

	var test_directory := "user://codex_main_scene_smoke_saves"
	_cleanup_test_save_directory(test_directory)
	_expect(
		save_manager.set_save_directory(test_directory),
		"SaveManager rifiuta una directory di test valida in user://."
	)
	_expect(
		save_manager.get_slot_summaries().size() == SaveManager.MAX_SAVE_SLOTS,
		"La pool non contiene esattamente dieci slot."
	)
	_expect(not save_manager.has_saves(), "Una pool vuota risulta occupata.")

	await _send_action(&"toggle_menu")
	_expect(game_ui.pause_menu.visible and paused, "Esc non apre e sospende il menu.")
	var continue_button := game_ui.pause_menu.get_node_or_null("%ContinueButton") as Button
	var options_button := game_ui.pause_menu.get_node_or_null("%OptionsButton") as Button
	var formulas_button := game_ui.pause_menu.get_node_or_null(
		"%DeveloperFormulasButton"
	) as Button
	var element_chart_button := game_ui.pause_menu.get_node_or_null(
		"%ElementChartButton"
	) as Button
	var save_button := game_ui.pause_menu.get_node_or_null("%SaveButton") as Button
	var load_button := game_ui.pause_menu.get_node_or_null("%LoadButton") as Button
	_expect(
		continue_button != null and continue_button.disabled,
		"Continua non è disabilitato senza salvataggi."
	)
	_expect(
		load_button != null and load_button.disabled,
		"Carica non è disabilitato senza salvataggi."
	)
	if (
		options_button == null
		or formulas_button == null
		or element_chart_button == null
		or save_button == null
	):
		_fail("Pulsanti Opzioni, Formule, Elementi o Salva mancanti dal menu.")
		_cleanup_test_save_directory(test_directory)
		return

	options_button.emit_signal("pressed")
	await process_frame
	_expect(game_ui.options_screen.visible, "Opzioni non apre la schermata dedicata.")
	_expect(not game_ui.pause_menu.visible and paused, "Opzioni interrompe la pausa.")
	var expected_categories: Array[String] = [
		"Impostazioni di gioco",
		"Impostazioni Grafica",
		"Impostazioni Video",
		"Impostazioni Audio",
		"Controlli",
		"Lingua",
		"Interfaccia",
	]
	var category_nodes: Array[String] = [
		"GameplayButton",
		"GraphicsButton",
		"VideoButton",
		"AudioButton",
		"ControlsButton",
		"LanguageButton",
		"InterfaceButton",
	]
	for category_index: int in expected_categories.size():
		var category_button := game_ui.options_screen.get_node_or_null(
			"%%%s" % category_nodes[category_index]
		) as Button
		_expect(
			category_button != null
			and category_button.text == expected_categories[category_index],
			"Categoria Opzioni mancante o fuori ordine: %s."
			% expected_categories[category_index]
		)
	var apply_button := game_ui.options_screen.get_node_or_null("%ApplyButton") as Button
	var options_back := game_ui.options_screen.get_node_or_null("%BackButton") as Button
	if apply_button != null:
		apply_button.emit_signal("pressed")
		await process_frame
		_expect(game_ui.options_screen.visible, "Applica chiude la schermata Opzioni.")
	else:
		_fail("Pulsante Applica mancante.")
	if options_back != null:
		options_back.emit_signal("pressed")
		await process_frame
		_expect(
			game_ui.pause_menu.visible and not game_ui.options_screen.visible,
			"Indietro non torna al menu principale."
		)
	else:
		_fail("Pulsante Indietro mancante nelle Opzioni.")

	formulas_button.emit_signal("pressed")
	await process_frame
	_expect(
		game_ui.developer_formulas_screen.visible
		and not game_ui.pause_menu.visible
		and paused,
		"Formule sviluppatori non apre una schermata modale in pausa."
	)
	var formula_text := game_ui.developer_formulas_screen.get_node_or_null(
		"%FormulaText"
	) as RichTextLabel
	_expect(
		formula_text != null
		and "217" in formula_text.text
		and "255" in formula_text.text
		and "10%" in formula_text.text
		and "Mod1" in formula_text.text,
		"Il riferimento sviluppatori non documenta la formula attiva."
	)
	var formulas_back := game_ui.developer_formulas_screen.get_node_or_null(
		"%BackButton"
	) as Button
	if formulas_back != null:
		formulas_back.emit_signal("pressed")
		await process_frame
		_expect(
			game_ui.pause_menu.visible
			and not game_ui.developer_formulas_screen.visible,
			"Indietro dalle formule non torna al menu principale."
		)
	else:
		_fail("Pulsante Indietro mancante nelle formule sviluppatori.")

	element_chart_button.emit_signal("pressed")
	await process_frame
	_expect(
		game_ui.element_chart_screen.visible
		and not game_ui.pause_menu.visible
		and paused,
		"Tabella elementi non apre una schermata modale in pausa."
	)
	var chart_grid := game_ui.element_chart_screen.get_node_or_null(
		"%ChartGrid"
	) as GridContainer
	_expect(
		chart_grid != null
		and chart_grid.columns == ElementChart.ELEMENT_IDS.size()
		and chart_grid.get_child_count()
		== ElementChart.ELEMENT_IDS.size() * ElementChart.ELEMENT_IDS.size(),
		"La tabella elementi non contiene l'intera matrice."
	)
	var fire_diagonal := game_ui.element_chart_screen.get_chart_cell(
		&"fuoco",
		&"fuoco"
	)
	_expect(
		fire_diagonal != null
		and bool(fire_diagonal.get_meta(&"is_diagonal", false)),
		"Il nome Fuoco non occupa la diagonale della tabella."
	)
	var nature_against_fire := game_ui.element_chart_screen.get_chart_cell(
		&"natura",
		&"fuoco"
	)
	_expect(
		nature_against_fire != null
		and is_equal_approx(
			float(nature_against_fire.get_meta(&"multiplier", 0.0)),
			0.5
		),
		"La cella Natura contro Fuoco non mostra la resistenza 1/2."
	)
	var chart_back := game_ui.element_chart_screen.get_node_or_null(
		"%BackButton"
	) as Button
	if chart_back != null:
		chart_back.emit_signal("pressed")
		await process_frame
		_expect(
			game_ui.pause_menu.visible
			and not game_ui.element_chart_screen.visible,
			"Indietro dalla tabella elementi non torna al menu principale."
		)
	else:
		_fail("Pulsante Indietro mancante nella tabella elementi.")

	var active_astral := roster.get_active_astral()
	if active_astral == null or active_astral.definition == null:
		_fail("Astral attivo mancante per il round-trip del salvataggio.")
		_cleanup_test_save_directory(test_directory)
		return
	player.global_position = Vector3(12.5, 7.25, -9.75)
	var player_visual := player.get_node_or_null("Visual") as Node3D
	if player_visual != null:
		player_visual.rotation.y = 0.73
	inventory.load_save_data({"cocco": 4, "legno": 3})
	active_astral.current_health = maxi(active_astral.get_max_health() - 3, 1)
	var saved_astral_experience := (
		active_astral.definition.get_total_experience_for_level(active_astral.level)
		+ 47
	)
	active_astral.experience = saved_astral_experience
	if active_astral.get_move_count() > 1:
		active_astral.reorder_move(0, active_astral.get_move_count() - 1)
	var saved_move_id := (
		active_astral.get_move(0).move_id
		if active_astral.get_move(0) != null
		else &""
	)
	profile.load_save_data({
		"player_name": "Avventuriero",
		"currency_name": "Fiorini",
		"florins": 4321,
		"captured_monster_count": 6,
		"earned_medals": [true, false, true, false, false, false, false, false],
		"adventure_summary": "Riepilogo persistente dello smoke test.",
	})
	var day_night := world_map.get_node_or_null("TimeOfDay") as DayNightCycle
	if day_night != null:
		day_night.load_save_data({"game_hour": 22.5, "elapsed_days": 7})
	var interactables: Array = []
	if world_map.has_method("get_interactables"):
		var raw_interactables: Variant = world_map.call("get_interactables")
		if raw_interactables is Array:
			interactables = raw_interactables
	var saved_interactable: InteractableArea3D = null
	if not interactables.is_empty():
		saved_interactable = interactables.front() as InteractableArea3D
	if saved_interactable != null:
		saved_interactable.set_remaining_item_count(0)

	save_button.emit_signal("pressed")
	await process_frame
	_expect(
		game_ui.save_slots_screen.visible
		and game_ui.save_slots_screen.get_mode() == SaveSlotsScreen.Mode.SAVE,
		"Salva non apre la schermata slot in modalità SAVE."
	)
	var slot_button_count := 0
	for slot_number: int in SaveSlotsScreen.MAX_SLOTS:
		var slot_button := game_ui.save_slots_screen.get_node_or_null(
			"%%Slot%02dButton" % (slot_number + 1)
		) as Button
		if slot_button != null:
			slot_button_count += 1
	_expect(slot_button_count == 10, "La schermata non mostra dieci slot.")
	var first_slot := game_ui.save_slots_screen.get_node_or_null("%Slot01Button") as Button
	if first_slot == null:
		_fail("Primo slot di salvataggio mancante.")
		_cleanup_test_save_directory(test_directory)
		return
	var primary_action_button := game_ui.save_slots_screen.get_node_or_null(
		"%PrimaryActionButton"
	) as Button
	var action_confirmation := game_ui.save_slots_screen.get_node_or_null(
		"ActionConfirmation"
	) as ConfirmationDialog
	_expect(
		primary_action_button != null and primary_action_button.disabled,
		"Salva è attivo senza alcuno slot selezionato."
	)
	first_slot.emit_signal("pressed")
	await process_frame
	_expect(
		primary_action_button != null and not primary_action_button.disabled,
		"Salva non si attiva selezionando uno slot."
	)
	_expect(
		not FileAccess.file_exists(save_manager.get_slot_path(0)),
		"Selezionare uno slot non deve salvare immediatamente."
	)
	primary_action_button.emit_signal("pressed")
	await process_frame
	_expect(
		action_confirmation != null and action_confirmation.visible,
		"La conferma di salvataggio non appare."
	)
	action_confirmation.confirmed.emit()
	await process_frame
	_expect(FileAccess.file_exists(save_manager.get_slot_path(0)), "Lo slot 1 non è persistito su disco.")
	_expect(save_manager.has_saves(), "SaveManager non rileva lo slot appena creato.")
	_expect(
		save_manager.get_latest_slot_index() == 0,
		"Lo slot appena creato non è il più recente."
	)
	if continue_button != null and load_button != null:
		_expect(
			not continue_button.disabled and not load_button.disabled,
			"Continua e Carica non si attivano dopo il primo salvataggio."
		)

	player.global_position = Vector3(-30.0, 2.0, 31.0)
	if player_visual != null:
		player_visual.rotation.y = -1.2
	inventory.load_save_data({})
	active_astral.current_health = 1
	active_astral.experience = 0
	profile.load_save_data({"florins": 0, "earned_medals": []})
	if day_night != null:
		day_night.load_save_data({"game_hour": 3.0, "elapsed_days": 0})
	if saved_interactable != null:
		saved_interactable.set_remaining_item_count(saved_interactable.max_generated_items)

	_expect(save_manager.load_save(0), "Caricamento dello slot 1 fallito.")
	_expect(
		player.global_position.is_equal_approx(Vector3(12.5, 7.25, -9.75)),
		"La posizione del giocatore non è stata ripristinata."
	)
	_expect(
		player_visual == null or is_equal_approx(player_visual.rotation.y, 0.73),
		"L'orientamento del giocatore non è stato ripristinato."
	)
	_expect(
		inventory.get_quantity(&"cocco") == 4
		and inventory.get_quantity(&"legno") == 3,
		"L'inventario non supera il round-trip."
	)
	var loaded_astral := roster.get_active_astral()
	_expect(
		loaded_astral != null
		and loaded_astral.current_health == maxi(loaded_astral.get_max_health() - 3, 1)
		and loaded_astral.experience == saved_astral_experience,
		"HP o EXP dell'Astral non sono stati ripristinati."
	)
	_expect(
		loaded_astral != null
		and loaded_astral.get_move(0) != null
		and loaded_astral.get_move(0).move_id == saved_move_id,
		"L'ordine delle mosse non è stato ripristinato."
	)
	_expect(
		profile.florins == 4321
		and profile.captured_monster_count == 6
		and profile.get_medal_count() == 2,
		"Il profilo giocatore non supera il round-trip."
	)
	if day_night != null:
		_expect(
			absf(day_night.game_hour - 22.5) < 0.05 and day_night.elapsed_days == 7,
			"Ora o giorno non sono stati ripristinati."
		)
	if saved_interactable != null:
		_expect(
			saved_interactable.remaining_item_count == 0,
			"Lo stock dell'oggetto di mappa non è stato ripristinato."
		)

	player.global_position = Vector3(24.0, 8.0, 15.0)
	_expect(save_manager.create_save(1), "Creazione del secondo slot fallita.")
	player.global_position = Vector3.ZERO

	_expect(
		save_manager.create_save(2),
		"Creazione del terzo slot per il test di eliminazione fallita."
	)
	var delete_slot_button := game_ui.save_slots_screen.get_node_or_null(
		"%Slot03Button"
	) as Button
	var delete_button := game_ui.save_slots_screen.get_node_or_null("%DeleteButton") as Button
	if delete_slot_button == null or delete_button == null or action_confirmation == null:
		_fail("Pulsanti di eliminazione slot mancanti.")
	else:
		_expect(delete_button.disabled, "Elimina è attivo senza alcuno slot selezionato.")
		delete_slot_button.emit_signal("pressed")
		await process_frame
		_expect(
			not delete_button.disabled,
			"Elimina non si attiva selezionando uno slot occupato."
		)
		delete_button.emit_signal("pressed")
		await process_frame
		_expect(action_confirmation.visible, "La conferma di eliminazione non appare.")
		action_confirmation.confirmed.emit()
		await process_frame
		_expect(
			not FileAccess.file_exists(save_manager.get_slot_path(2)),
			"Lo slot 3 non è stato eliminato."
		)
		var occupied_after_delete := 0
		for summary: Dictionary in save_manager.get_slot_summaries():
			if bool(summary.get("occupied", false)):
				occupied_after_delete += 1
		_expect(
			occupied_after_delete == 2,
			"L'eliminazione dello slot non aggiorna correttamente il conteggio degli slot occupati."
		)

	var slots_back := game_ui.save_slots_screen.get_node_or_null("%BackButton") as Button
	if slots_back != null:
		slots_back.emit_signal("pressed")
		await process_frame
	_expect(game_ui.pause_menu.visible, "Indietro dagli slot non torna al menu.")
	continue_button = game_ui.pause_menu.get_node_or_null("%ContinueButton") as Button
	if continue_button != null:
		continue_button.emit_signal("pressed")
		await process_frame
		_expect(
			is_equal_approx(player.global_position.x, 24.0)
			and is_equal_approx(player.global_position.z, 15.0),
			"Continua non carica il salvataggio più recente."
		)
		_expect(not paused, "Continua non restituisce il controllo al mondo.")
	else:
		_fail("Pulsante Continua mancante dopo il salvataggio.")
	_expect(
		save_manager.get_slot_path(SaveManager.MAX_SAVE_SLOTS).is_empty()
		and save_manager.get_slot_summaries().size() == SaveManager.MAX_SAVE_SLOTS,
		"SaveManager espone un undicesimo slot."
	)
	var occupied_slot_count := 0
	for summary: Dictionary in save_manager.get_slot_summaries():
		if bool(summary.get("occupied", false)):
			occupied_slot_count += 1
	_expect(
		occupied_slot_count == 2,
		"La pool non conserva esattamente i due slot creati."
	)

	_cleanup_test_save_directory(test_directory)
	save_manager.set_save_directory(SaveManager.DEFAULT_SAVE_DIRECTORY)


func _cleanup_test_save_directory(directory_path: String) -> void:
	if not directory_path.begins_with("user://codex_main_scene_smoke_saves"):
		return
	for slot_index: int in SaveManager.MAX_SAVE_SLOTS:
		var slot_path := "%s/save_%02d.json" % [directory_path, slot_index + 1]
		if FileAccess.file_exists(slot_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path))
	var absolute_directory := ProjectSettings.globalize_path(directory_path)
	if DirAccess.dir_exists_absolute(absolute_directory):
		DirAccess.remove_absolute(absolute_directory)


func _test_wild_astral_pool(main: Node) -> void:
	if not main.has_method("get_wild_astral_pool"):
		_fail("Main non espone il pool degli Astral selvatici.")
		return
	var raw_pool: Variant = main.call("get_wild_astral_pool")
	if not (raw_pool is Array):
		_fail("Il pool degli Astral selvatici non e un Array.")
		return
	var pool := raw_pool as Array
	_expect(pool.size() == 6, "Il pool selvatico non contiene le sei specie base.")
	var expected_bst: Dictionary[StringName, int] = {
		&"venomquill": 490,
		&"flambore": 260,
		&"vorix": 333,
		&"panthor": 333,
		&"silphy": 375,
		&"pandalith": 400,
	}
	var seen_ids: Dictionary[StringName, bool] = {}
	for candidate: Variant in pool:
		var definition := candidate as AstralDefinition
		if definition == null:
			_fail("Il pool selvatico contiene una definizione non valida.")
			continue
		_expect(
			not definition.astral_id.is_empty(),
			"Una specie selvatica non possiede astral_id."
		)
		_expect(
			not seen_ids.has(definition.astral_id),
			"Il pool selvatico contiene astral_id duplicati: %s."
			% definition.astral_id
		)
		seen_ids[definition.astral_id] = true
		_expect(
			expected_bst.has(definition.astral_id),
			"Specie base inattesa nel pool: %s." % definition.astral_id
		)
		_expect(
			definition.has_valid_base_stats(),
			"%s possiede statistiche base non valide." % definition.display_name
		)
		_expect(
			definition.get_base_stat_total()
			== expected_bst.get(definition.astral_id, -1),
			"%s non possiede il BST definitivo richiesto." % definition.display_name
		)
		_expect(
			not definition.model_path.is_empty()
			and FileAccess.file_exists(definition.model_path),
			"%s non possiede un modello 3D valido." % definition.display_name
		)
		var level_five_moves := definition.get_moves_available_at_level(5)
		_expect(
			not level_five_moves.is_empty()
			and level_five_moves.size() <= AstralInstance.MAX_MOVE_COUNT,
			"%s non possiede un set mosse iniziale valido." % definition.display_name
		)
		for move: AstralMoveDefinition in level_five_moves:
			if move == null:
				_fail("%s contiene una mossa null." % definition.display_name)
				continue
			_expect(
				move.cooldown_turns >= 0 and move.cooldown_turns <= 5,
				"%s possiede un costo fuori intervallo." % move.display_name
			)
	_expect(
		seen_ids.size() == expected_bst.size(),
		"Il pool non contiene una volta ciascuna le sei specie base."
	)
	if main.has_method("set_encounter_random_seed"):
		main.call("set_encounter_random_seed", 731)
	if main.has_method("get_random_wild_astral_definition"):
		var selected := main.call("get_random_wild_astral_definition") as AstralDefinition
		_expect(selected != null and pool.has(selected), "Main estrae una specie fuori dal pool.")
	else:
		_fail("Main non espone l'estrazione casuale dal pool selvatico.")


func _test_base_stat_rules() -> void:
	var definition := AstralDefinition.new()
	_expect(
		definition.set_base_stats(200, 200, 200, 200, 200, 200),
		"AstralDefinition rifiuta un BST valido di 1200."
	)
	_expect(
		definition.get_base_stat_total() == AstralDefinition.MAX_BASE_STAT_TOTAL,
		"Il BST massimo non è 1200."
	)
	_expect(
		not definition.set_base_stats(201, 200, 200, 200, 200, 200),
		"AstralDefinition accetta un BST superiore a 1200."
	)
	_expect(
		not definition.set_base_stats(4, 200, 200, 200, 200, 200),
		"AstralDefinition accetta una statistica inferiore a 5."
	)
	_expect(
		not definition.set_base_stats(256, 5, 5, 5, 5, 5),
		"AstralDefinition accetta una statistica superiore a 255."
	)
	definition.max_health = 255
	definition.attack_power = 255
	definition.physical_defense = 255
	definition.magic_attack = 255
	definition.magic_defense = 255
	definition.speed = 255
	_expect(
		definition.has_valid_base_stats()
		and definition.get_base_stat_total() <= AstralDefinition.MAX_BASE_STAT_TOTAL,
		"Le assegnazioni singole permettono di superare il BST massimo."
	)

	var starter := AstralCatalog.load_definition(&"venomquill")
	_expect(starter != null, "Definizione dello starter mancante per il test BST.")
	if starter != null:
		_expect(starter.has_valid_base_stats(), "Lo starter possiede statistiche non valide.")
		_expect(starter.get_base_stat_total() == 490, "Venomquill non possiede BST 490.")


func _test_player_and_camera(main: Node) -> void:
	var player := main.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		_fail("Player non è un CharacterBody3D.")
		return
	var camera_rig := player.get_node_or_null("CameraRig") as SpringArm3D
	_expect(camera_rig != null, "CameraRig mancante sul player.")
	if camera_rig == null:
		return
	var camera := camera_rig.get_node_or_null("Camera3D") as Camera3D
	_expect(camera != null, "Camera3D mancante sul CameraRig.")
	_expect(camera_rig.spring_length >= 8.0, "La telecamera è troppo vicina.")
	_expect(camera_rig.spring_length <= 10.0, "La telecamera è troppo lontana.")
	_expect(camera_rig.rotation.x <= deg_to_rad(-40.0), "Telecamera troppo orizzontale.")
	_expect(camera_rig.rotation.x >= deg_to_rad(-50.0), "Telecamera troppo verticale.")
	_expect(player.get_node_or_null("NightLantern") != null, "Lanterna notturna mancante.")


func _test_squad_screen(main: Node) -> void:
	var game_ui := main.get_node_or_null("GameUI") as GameUI
	var roster := main.get_node_or_null("AstralRoster") as AstralRoster
	var squad_screen := main.get_node_or_null(
		"GameUI/SquadScreen"
	) as SquadScreen
	if game_ui == null or roster == null or squad_screen == null:
		_fail("Impossibile verificare la schermata Squadra.")
		return
	var starter: AstralInstance = roster.get_active_astral()
	_expect(starter != null, "Starter Astral mancante.")
	if starter != null:
		_expect(starter.level == 5, "Lo starter non comincia al livello 5.")
		_expect(starter.get_move_count() == 2, "Venomquill non possiede le due mosse di livello 5.")

	await _send_action(&"toggle_squad")
	_expect(squad_screen.visible, "I non apre la schermata Squadra.")
	_expect(paused, "La schermata Squadra non sospende il mondo.")
	_expect(not game_ui.pause_menu.visible, "Squadra lascia aperto il menu pausa.")
	_expect(
		not game_ui.inventory_screen.visible,
		"Squadra lascia aperto l'inventario."
	)
	var astral_list := squad_screen.get_node_or_null("%AstralList") as ItemList
	var astral_name := squad_screen.get_node_or_null("%AstralName") as Label
	var elements_value := squad_screen.get_node_or_null("%ElementsValue") as Label
	var bst_value := squad_screen.get_node_or_null("%BstValue") as Label
	var physical_defense_value := squad_screen.get_node_or_null(
		"%PhysicalDefenseValue"
	) as Label
	var magic_attack_value := squad_screen.get_node_or_null(
		"%MagicAttackValue"
	) as Label
	var magic_defense_value := squad_screen.get_node_or_null(
		"%MagicDefenseValue"
	) as Label
	var level_value := squad_screen.get_node_or_null("%LevelValue") as Label
	var experience_value := squad_screen.get_node_or_null("%ExperienceValue") as Label
	var rarity_value := squad_screen.get_node_or_null("%RarityValue") as Label
	var portrait_preview := squad_screen.get_node_or_null(
		"%PortraitPreview"
	) as SubViewportContainer
	var portrait_model := squad_screen.get_node_or_null("%PortraitModel") as AstralModel3D
	_expect(astral_list != null, "Lista Astral mancante dalla schermata Squadra.")
	_expect(astral_name != null, "Nome Astral mancante dalla schermata Squadra.")
	_expect(elements_value != null, "Elemento Astral mancante dalla schermata Squadra.")
	_expect(bst_value != null, "BST mancante dalla scheda Astral.")
	_expect(physical_defense_value != null, "PDef mancante dalla scheda Astral.")
	_expect(magic_attack_value != null, "Atkm mancante dalla scheda Astral.")
	_expect(magic_defense_value != null, "MDef mancante dalla scheda Astral.")
	_expect(level_value != null, "Livello mancante dalla scheda Astral.")
	_expect(experience_value != null, "EXP mancante dalla scheda Astral.")
	_expect(rarity_value != null, "Rarità mancante dalla scheda Astral.")
	_expect(portrait_preview != null, "Ritratto statico mancante dalla scheda Astral.")
	if astral_list != null:
		_expect(
			astral_list.item_count == roster.get_astral_count(),
			"Squadra non mostra tutti gli Astral del roster."
		)
		_expect(
			astral_list.item_count > 0 and "Lv.5" in astral_list.get_item_text(0),
			"La lista Squadra non mostra il livello dello starter."
		)
		if starter != null and starter.definition != null and astral_list.item_count > 0:
			var list_identity := astral_list.get_item_text(0)
			_expect(
				ASTRAL_PRESENTATION.get_sex_symbol(starter.sex) in list_identity,
				"La lista Squadra non mostra il simbolo del sesso."
			)
			_expect(
				ASTRAL_PRESENTATION.get_element_symbol(
					starter.definition.primary_element
				) in list_identity,
				"La lista Squadra non mostra il simbolo elementale."
			)
		var focus_owner: Control = root.gui_get_focus_owner()
		_expect(
			focus_owner == astral_list,
			"La lista Astral non riceve il focus all'apertura."
		)
	if level_value != null:
		_expect(level_value.text == "5", "La scheda mostra un livello errato.")
	if experience_value != null:
		_expect(
			starter != null
			and "EXP 0 / %d" % starter.get_experience_to_next_level()
			in experience_value.text,
			"La scheda non mostra EXP e soglia del prossimo livello."
		)
	if starter != null and starter.definition != null:
		_expect(
			rarity_value != null
			and starter.definition.get_rarity_name() in rarity_value.text,
			"La scheda Squadra non mostra la rarità dell'Astral."
		)
		_expect(
			portrait_preview != null
			and portrait_preview.visible
			and portrait_model != null
			and portrait_model.displayed_definition == starter.definition,
			"La scheda Squadra non mostra il modello statico selezionato."
		)
		var expected_identity := ASTRAL_PRESENTATION.format_identity(starter)
		if bst_value != null:
			_expect(
				bst_value.text.begins_with(
					str(starter.definition.get_base_stat_total())
				),
				"La scheda Squadra mostra un BST errato."
			)
		if physical_defense_value != null:
			_expect(
				physical_defense_value.text == str(starter.get_physical_defense()),
				"La scheda Squadra mostra una PDef errata."
			)
		if magic_attack_value != null:
			_expect(
				magic_attack_value.text == str(starter.get_magic_attack()),
				"La scheda Squadra mostra un Atkm errato."
			)
		if magic_defense_value != null:
			_expect(
				magic_defense_value.text == str(starter.get_magic_defense()),
				"La scheda Squadra mostra una MDef errata."
			)
		if astral_name != null:
			_expect(
				astral_name.text == expected_identity,
				"La scheda Squadra non mostra nome, sesso ed elemento insieme."
			)
		if elements_value != null:
			_expect(
				ASTRAL_PRESENTATION.format_element(
					starter.definition.primary_element
				) in elements_value.text,
				"La scheda Squadra non presenta simbolo e nome dell'elemento."
			)
	var move_node_names: Array[String] = [
		"MoveOne", "MoveTwo", "MoveThree", "MoveFour"
	]
	for move_index: int in move_node_names.size():
		var move_node_name := move_node_names[move_index]
		var move_label := squad_screen.get_node_or_null("%%%s" % move_node_name) as Label
		_expect(move_label != null, "Slot mossa mancante: %s." % move_node_name)
		if move_label != null:
			if starter != null and move_index < starter.get_move_count():
				var move := starter.get_move(move_index)
				_expect(
					move != null and "CD %d" % move.cooldown_turns in move_label.text,
					"La scheda Squadra non mostra la mossa %d." % (move_index + 1)
				)
			else:
				_expect(
					"Slot libero" in move_label.text,
					"Uno slot mossa non appreso non risulta libero."
				)
	_expect(
		squad_screen.get_node_or_null("%HealPartyButton") == null,
		"Il vecchio pulsante di cura manuale è ancora presente."
	)
	var level_up_summary := main.get_node_or_null(
		"GameUI/LevelUpSummary"
	) as LevelUpSummary
	_expect(level_up_summary != null, "Tabella globale del level-up mancante.")
	if starter != null and level_up_summary != null:
		var original_level := starter.level
		var original_experience := starter.experience
		var original_health := starter.current_health
		level_up_summary.display_duration = 3.0
		_expect(
			starter.gain_experience(starter.get_experience_to_next_level()) == 1,
			"Impossibile attivare il riepilogo del level-up."
		)
		await process_frame
		await process_frame
		var summary_title := level_up_summary.get_node_or_null(
			"%TitleLabel"
		) as Label
		var summary_grid := level_up_summary.get_node_or_null("%StatsGrid") as GridContainer
		_expect(
			level_up_summary.visible
			and summary_title != null
			and starter.definition.display_name in summary_title.text
			and summary_grid != null
			and summary_grid.get_child_count() == 28,
			"La tabella non mostra le sei statistiche ottenute durante il level-up "
			+ "(visibile=%s, titolo=%s, celle=%d)." % [
				level_up_summary.visible,
				summary_title.text if summary_title != null else "mancante",
				summary_grid.get_child_count() if summary_grid != null else -1,
			]
		)
		starter.level = original_level
		starter.experience = original_experience
		starter.current_health = original_health
		level_up_summary.clear_summaries()

	await _send_action(&"toggle_inventory")
	_expect(not squad_screen.visible, "Tab non chiude Squadra.")
	_expect(game_ui.inventory_screen.visible, "Tab non apre l'inventario da Squadra.")
	_expect(paused, "Il passaggio Squadra-Inventario rimuove la pausa.")
	await _send_action(&"toggle_squad")
	_expect(squad_screen.visible, "I non riapre Squadra dall'inventario.")
	_expect(
		not game_ui.inventory_screen.visible,
		"Aprire Squadra non chiude l'inventario."
	)
	await _send_action(&"toggle_menu")
	_expect(not squad_screen.visible, "Esc non chiude Squadra.")
	_expect(game_ui.pause_menu.visible, "Esc non apre il menu da Squadra.")
	await _send_action(&"toggle_menu")
	_expect(not paused, "Chiudere il menu dopo Squadra lascia il mondo in pausa.")

	await _send_action(&"toggle_squad")
	game_ui.set_pause_lock(&"battle", true)
	_expect(not squad_screen.visible, "Il battle lock non chiude Squadra.")
	_expect(paused, "Il battle lock non mantiene il mondo in pausa.")
	await _send_action(&"toggle_squad")
	_expect(not squad_screen.visible, "I apre Squadra durante il battle lock.")
	game_ui.set_pause_lock(&"battle", false)
	_expect(not paused, "Rimuovere il battle lock lascia il mondo in pausa.")

	await _send_action(&"toggle_squad")
	_expect(squad_screen.visible, "I non apre Squadra dopo il battle lock.")
	await _send_action(&"toggle_squad")
	_expect(not squad_screen.visible, "I non chiude Squadra.")
	_expect(not paused, "Chiudere Squadra non ripristina il mondo.")


func _test_astral_box_screen(main: Node) -> void:
	var game_ui := main.get_node_or_null("GameUI") as GameUI
	var box_screen := main.get_node_or_null(
		"GameUI/AstralBoxScreen"
	) as AstralBoxScreen
	if game_ui == null or box_screen == null:
		_fail("Impossibile verificare la schermata Box Astral.")
		return

	await _send_action(&"toggle_astral_box")
	_expect(box_screen.visible, "B non apre il Box Astral.")
	_expect(paused, "Il Box Astral non sospende il mondo.")
	_expect(not game_ui.squad_screen.visible, "Il Box lascia aperta Squadra.")
	var party_list := box_screen.get_node_or_null("%PartyList") as ItemList
	var box_list := box_screen.get_node_or_null("%BoxList") as ItemList
	var box_label := box_screen.get_node_or_null("%BoxLabel") as Label
	var equip_button := box_screen.get_node_or_null("%EquipButton") as Button
	var release_dialog := box_screen.get_node_or_null(
		"ReleaseConfirmation"
	) as ConfirmationDialog
	_expect(
		party_list != null and party_list.item_count == AstralRoster.MAX_PARTY_SIZE,
		"Il Box non mostra i sei slot della squadra."
	)
	_expect(
		box_list != null and box_list.item_count == AstralRoster.BOX_CAPACITY,
		"Il Box non mostra trenta slot per pagina."
	)
	_expect(
		box_label != null and "01 / 50" in box_label.text,
		"Il Box non mostra le cinquanta pagine numerate."
	)
	_expect(
		equip_button != null and equip_button.disabled,
		"Equipaggia non resta un placeholder disabilitato."
	)
	_expect(release_dialog != null, "Manca la conferma per liberare un Astral.")
	_expect(
		party_list != null and root.gui_get_focus_owner() == party_list,
		"La squadra del Box non riceve il focus all'apertura."
	)

	box_screen.select_box(49)
	_expect(
		box_screen.get_current_box_index() == 49
		and box_label != null
		and "50 / 50" in box_label.text,
		"Non ci si può spostare liberamente fino al Box 50."
	)
	await _send_action(&"toggle_astral_box")
	_expect(not box_screen.visible, "B non chiude il Box Astral.")
	_expect(not paused, "Chiudere il Box non ripristina il mondo.")

	await _send_action(&"toggle_astral_box")
	game_ui.set_pause_lock(&"battle", true)
	_expect(not box_screen.visible, "Il battle lock non chiude il Box Astral.")
	await _send_action(&"toggle_astral_box")
	_expect(not box_screen.visible, "B apre il Box durante il battle lock.")
	game_ui.set_pause_lock(&"battle", false)
	_expect(not paused, "Rimuovere il battle lock lascia il Box in pausa.")


func _test_astral_instance_progression() -> void:
	var move_one := _make_test_move(&"test_one", "Test One", 5, &"neutro")
	var move_two := _make_test_move(&"test_two", "Test Two", 6, &"natura")
	var move_three := _make_test_move(&"test_three", "Test Three", 7, &"acqua")
	var move_four := _make_test_move(&"test_four", "Test Four", 8, &"fuoco")
	var move_five := _make_test_move(&"test_five", "Test Five", 9, &"neutro")
	var starting_moves: Array[AstralMoveDefinition] = [
		move_one,
		move_two,
		move_three,
		move_four,
	]
	var definition := _make_test_astral_definition(
		&"instance_test",
		"Instance Test",
		40,
		10,
		7,
		&"natura",
		&"",
		25,
		starting_moves
	)
	var instance := _make_test_astral_instance(definition, 5)
	_expect(instance.level == 5, "AstralInstance non conserva il livello iniziale.")
	_expect(instance.current_health == instance.get_max_health(), "AstralInstance non ripristina gli HP.")
	_expect(instance.get_move_count() == 4, "AstralInstance non inizializza quattro mosse.")
	for move_index: int in 4:
		_expect(
			instance.get_move(move_index) == starting_moves[move_index],
			"AstralInstance modifica l'ordine delle mosse iniziali."
		)
	_expect(instance.get_move(-1) == null, "Indice mossa negativo non restituisce null.")
	_expect(instance.get_move(4) == null, "Indice mossa fuori limite non restituisce null.")
	var move_copy := instance.get_moves()
	move_copy.clear()
	_expect(
		instance.get_move_count() == 4,
		"get_moves espone l'array interno mutabile."
	)
	_expect(not instance.learn_move(null), "AstralInstance accetta una mossa null.")
	_expect(not instance.learn_move(move_five), "AstralInstance supera il limite di quattro mosse.")

	var partial_moves: Array[AstralMoveDefinition] = [move_one, move_two]
	var partial_definition := _make_test_astral_definition(
		&"move_rules",
		"Move Rules",
		30,
		8,
		5,
		&"neutro",
		&"",
		20,
		partial_moves
	)
	var move_rules := _make_test_astral_instance(partial_definition, 2)
	var duplicate_id := _make_test_move(
		move_one.move_id,
		"Duplicate ID",
		99,
		&"fuoco"
	)
	_expect(not move_rules.learn_move(move_one), "learn_move accetta la stessa Resource.")
	_expect(not move_rules.learn_move(duplicate_id), "learn_move accetta un move_id duplicato.")
	_expect(move_rules.learn_move(move_three), "learn_move rifiuta una nuova mossa valida.")
	_expect(
		not move_rules.replace_move(0, move_three),
		"replace_move crea una mossa duplicata."
	)
	_expect(move_rules.replace_move(0, move_four), "replace_move rifiuta una mossa valida.")
	_expect(move_rules.reorder_move(0, 1), "reorder_move rifiuta indici validi.")
	_expect(
		move_rules.get_move(0) == move_two and move_rules.get_move(1) == move_four,
		"reorder_move non conserva l'ordine atteso."
	)
	_expect(not move_rules.reorder_move(-1, 0), "reorder_move accetta un indice invalido.")

	var threshold_instance := _make_test_astral_instance(definition, 5)
	var threshold_health := threshold_instance.current_health
	var threshold_required := definition.get_experience_for_next_level(5)
	_expect(
		threshold_instance.experience == definition.get_total_experience_for_level(5)
		and threshold_instance.get_experience_to_next_level() == threshold_required,
		"L'EXP iniziale o la soglia per rarità sono errate."
	)
	_expect(
		threshold_instance.gain_experience(threshold_required) == 1,
		"La soglia EXP non assegna un livello."
	)
	_expect(
		threshold_instance.level == 6
		and threshold_instance.experience
		== definition.get_total_experience_for_level(6)
		and threshold_instance.get_experience_progress_in_level() == 0,
		"La soglia EXP cumulativa non produce il livello atteso."
	)
	_expect(
		threshold_instance.current_health == threshold_health,
		"Guadagnare EXP modifica gli HP."
	)
	var overflow_instance := _make_test_astral_instance(definition, 5)
	_expect(
		overflow_instance.gain_experience(threshold_required + 50) == 1,
		"L'overflow EXP non sale di livello."
	)
	_expect(
		overflow_instance.level == 6
		and overflow_instance.get_experience_progress_in_level() == 50,
		"L'overflow EXP non viene conservato."
	)
	var multi_level_instance := _make_test_astral_instance(definition, 5)
	var experience_to_level_seven := (
		definition.get_total_experience_for_level(7)
		- definition.get_total_experience_for_level(5)
	)
	_expect(
		multi_level_instance.gain_experience(experience_to_level_seven + 50) == 2,
		"La soglia cumulativa non assegna due livelli."
	)
	_expect(
		multi_level_instance.level == 7
		and multi_level_instance.get_experience_progress_in_level() == 50,
		"La progressione multi-level produce valori errati."
	)
	var rare_curve := AstralDefinition.new()
	rare_curve.rarity = AstralDefinition.Rarity.RARE
	_expect(
		rare_curve.get_total_experience_for_level(20) == 9600
		and rare_curve.get_experience_for_next_level(20) == 1513,
		"La curva EXP Raro non rispetta la tabella allegata."
	)
	var epic_curve := AstralDefinition.new()
	epic_curve.rarity = AstralDefinition.Rarity.EPIC
	var mythic_curve := AstralDefinition.new()
	mythic_curve.rarity = AstralDefinition.Rarity.MYTHIC
	_expect(
		epic_curve.get_total_experience_for_level(100) == 1500000
		and mythic_curve.get_total_experience_for_level(100) == 2000000,
		"Le curve EXP Epico o Mitico non sono implementate."
	)
	var legacy_instance := AstralInstance.new()
	_expect(
		legacy_instance.load_save_data(
			{
				"astral_id": String(definition.astral_id),
				"level": 5,
				"experience": 50,
			},
			definition,
			{}
		)
		and legacy_instance.level == 5
		and legacy_instance.experience
		== definition.get_total_experience_for_level(5) + 50,
		"La migrazione dei vecchi salvataggi EXP non conserva il progresso."
	)
	var unchanged_level := multi_level_instance.level
	var unchanged_experience := multi_level_instance.experience
	_expect(multi_level_instance.gain_experience(0) == 0, "Zero EXP modifica l'Astral.")
	_expect(
		multi_level_instance.level == unchanged_level
		and multi_level_instance.experience == unchanged_experience,
		"Un guadagno EXP nullo muta livello o esperienza."
	)


func _test_astral_catalog_and_evolution() -> void:
	var definitions := AstralCatalog.load_ordered_definitions()
	var expected_bst: Dictionary[StringName, int] = {
		&"venomquill": 490,
		&"flambore": 260,
		&"pyrobore": 410,
		&"fortessbore": 525,
		&"vorix": 333,
		&"saurolix": 444,
		&"phrynolix": 555,
		&"panthor": 333,
		&"sharkra": 444,
		&"fangoras": 555,
		&"silphy": 375,
		&"airdon": 425,
		&"eldrakans": 495,
		&"pandalith": 400,
		&"aikilith": 500,
		&"frostalith": 500,
		&"mindlith": 500,
	}
	_expect(definitions.size() == 17, "Il catalogo non contiene le 17 forme richieste.")
	var rarity_counts: Array[int] = [0, 0, 0, 0, 0]
	for definition: AstralDefinition in definitions:
		if definition == null:
			_fail("Il catalogo contiene una definizione Astral nulla.")
			continue
		_expect(
			expected_bst.has(definition.astral_id)
			and definition.get_base_stat_total()
			== expected_bst.get(definition.astral_id, -1),
			"BST errato per %s." % definition.display_name
		)
		_expect(
			definition.has_valid_base_stats(),
			"Statistiche fuori limite per %s." % definition.display_name
		)
		_expect(
			not definition.model_path.is_empty()
			and FileAccess.file_exists(definition.model_path),
			"Modello GLB mancante per %s." % definition.display_name
		)
		rarity_counts[definition.rarity] += 1
	_expect(
		rarity_counts[AstralDefinition.Rarity.COMMON] > 0
		and rarity_counts[AstralDefinition.Rarity.UNCOMMON] > 0
		and rarity_counts[AstralDefinition.Rarity.RARE] > 0
		and rarity_counts[AstralDefinition.Rarity.EPIC] == 0
		and rarity_counts[AstralDefinition.Rarity.MYTHIC] == 0,
		"Le rarità del catalogo non rispettano l'assegnazione richiesta."
	)

	var inventory := INVENTORY_SCENE.instantiate() as Inventory
	var roster := ASTRAL_ROSTER_SCENE.instantiate() as AstralRoster
	root.add_child(inventory)
	root.add_child(roster)
	await process_frame
	var flambore := AstralInstance.new()
	flambore.setup(
		AstralCatalog.load_definition(&"flambore"),
		12,
		AstralInstance.Sex.MALE
	)
	var evolution_signal_count: Array[int] = [0]
	flambore.evolution_available.connect(
		func() -> void: evolution_signal_count[0] += 1
	)
	var exp_to_evolution := (
		flambore.definition.get_total_experience_for_level(13)
		- flambore.experience
	)
	_expect(
		flambore.gain_experience(exp_to_evolution) == 1
		and flambore.level == 13
		and evolution_signal_count[0] == 1,
		"Raggiungere il livello evolutivo non segnala l'evoluzione."
	)
	_expect(roster.capture_astral(flambore), "Impossibile preparare Flambore per l'evoluzione.")
	var evolving_boar := roster.get_last_captured_astral()
	var first_options := roster.get_available_evolutions(evolving_boar, inventory)
	_expect(first_options.size() == 1, "Flambore non propone Pyrobore al livello 13.")
	var squad_scene := load("res://game/ui/squad/squad_screen.tscn") as PackedScene
	var evolution_screen := squad_scene.instantiate() as SquadScreen
	root.add_child(evolution_screen)
	evolution_screen.setup(roster, inventory)
	evolution_screen.open()
	await process_frame
	var evolving_index := roster.get_astrals().find(evolving_boar)
	var evolution_list := evolution_screen.get_node_or_null("%AstralList") as ItemList
	var evolution_button := evolution_screen.get_node_or_null("%EvolveButton") as Button
	if evolution_list != null and evolving_index >= 0:
		evolution_list.select(evolving_index)
		evolution_list.item_selected.emit(evolving_index)
	_expect(
		evolution_button != null
		and evolution_button.visible
		and not evolution_button.disabled,
		"Squadra non mostra l'opzione Evolvi quando il livello e sufficiente."
	)
	evolution_screen.queue_free()
	await process_frame
	if not first_options.is_empty():
		_expect(
			roster.evolve_astral(evolving_boar, first_options.front(), inventory),
			"L'evoluzione Flambore -> Pyrobore fallisce."
		)
		_expect(
			evolving_boar.definition.astral_id == &"pyrobore"
			and evolving_boar.level == 13
			and evolving_boar.sex == AstralInstance.Sex.MALE,
			"Pyrobore non conserva livello e sesso."
		)
		evolving_boar.level = 27
		var second_options := roster.get_available_evolutions(evolving_boar, inventory)
		_expect(second_options.size() == 1, "Pyrobore non propone Fortessbore al livello 27.")
		if not second_options.is_empty():
			_expect(
				roster.evolve_astral(evolving_boar, second_options.front(), inventory),
				"L'evoluzione Pyrobore -> Fortessbore fallisce."
			)
			_expect(
				evolving_boar.definition.astral_id == &"fortessbore",
				"La seconda forma della linea Boar e errata."
			)

	var pandalith := AstralInstance.new()
	pandalith.setup(
		AstralCatalog.load_definition(&"pandalith"),
		30,
		AstralInstance.Sex.FEMALE
	)
	_expect(roster.capture_astral(pandalith), "Impossibile preparare Pandalith.")
	var stored_pandalith := roster.get_last_captured_astral()
	var pandalith_party_index := roster.get_astrals().find(stored_pandalith)
	_expect(
		pandalith_party_index >= 0
		and roster.deposit_astral(pandalith_party_index, 0, 0),
		"Pandalith non viene depositato nel Box per il test."
	)
	for stone_id: StringName in [&"pietrafuoco", &"pietragelo", &"pietranatura"]:
		_expect(
			inventory.add_item(stone_id, 1) == 1,
			"La pietra evolutiva %s non entra nell'inventario." % stone_id
		)
	var stone_options := roster.get_available_evolutions(stored_pandalith, inventory)
	_expect(stone_options.size() == 3, "Pandalith non propone le tre evoluzioni ramificate.")
	var box_screen := ASTRAL_BOX_SCENE.instantiate() as AstralBoxScreen
	root.add_child(box_screen)
	box_screen.setup(roster, inventory)
	box_screen.open()
	await process_frame
	var box_list := box_screen.get_node_or_null("%BoxList") as ItemList
	var box_evolve_button := box_screen.get_node_or_null("%EvolveButton") as Button
	if box_list != null:
		box_list.select(0)
		box_list.item_selected.emit(0)
	_expect(
		box_evolve_button != null
		and box_evolve_button.visible
		and not box_evolve_button.disabled,
		"Il Box non permette di evolvere un Pandalith idoneo."
	)
	box_screen.queue_free()
	await process_frame
	var ice_option: AstralEvolutionOption = null
	for option: AstralEvolutionOption in stone_options:
		if option.required_item_id == &"pietragelo":
			ice_option = option
			break
	var ice_quantity := inventory.get_quantity(&"pietragelo")
	_expect(ice_option != null, "L'opzione Pietragelo non e disponibile.")
	if ice_option != null:
		_expect(
			roster.evolve_astral(stored_pandalith, ice_option, inventory),
			"L'evoluzione dal Box con Pietragelo fallisce."
		)
		_expect(
			stored_pandalith.definition.astral_id == &"frostalith"
			and stored_pandalith.sex == AstralInstance.Sex.FEMALE,
			"Pandalith non diventa Frostalith o perde il sesso."
		)
		_expect(
			inventory.get_quantity(&"pietragelo") == ice_quantity - 1,
			"L'evoluzione non consuma esattamente una Pietragelo."
		)

	roster.queue_free()
	inventory.queue_free()
	await process_frame


func _test_astral_sex_and_presentation() -> void:
	_expect(
		AstralInstance.sex_from_roll(0.0) == AstralInstance.Sex.MALE,
		"Il limite inferiore non genera un Astral maschio."
	)
	_expect(
		AstralInstance.sex_from_roll(0.499999) == AstralInstance.Sex.MALE,
		"Un roll sotto il 50% non genera un Astral maschio."
	)
	_expect(
		AstralInstance.sex_from_roll(0.5) == AstralInstance.Sex.FEMALE,
		"La soglia del 50% non passa al sesso femminile."
	)
	_expect(
		AstralInstance.sex_from_roll(1.0) == AstralInstance.Sex.FEMALE,
		"Il limite superiore non genera un Astral femmina."
	)

	var female := AstralInstance.new()
	female.setup(_player_astral, 5, AstralInstance.Sex.FEMALE)
	var female_copy := female.duplicate_runtime()
	_expect(female.sex == AstralInstance.Sex.FEMALE, "setup ignora il sesso forzato.")
	_expect(
		female_copy != female and female_copy.sex == female.sex,
		"duplicate_runtime non conserva il sesso dell'Astral."
	)
	_expect(
		ASTRAL_PRESENTATION.format_identity(female)
		== "%s %s %s" % [
			_player_astral.display_name,
			ASTRAL_PRESENTATION.get_sex_symbol(AstralInstance.Sex.FEMALE),
			ASTRAL_PRESENTATION.get_element_symbol(_player_astral.primary_element),
		],
		"L'identita Astral non combina nome, sesso ed elemento."
	)
	var expected_symbols: Dictionary[StringName, String] = {
		&"neutro": "✦",
		&"fuoco": "🔥",
		&"acqua": "💧",
		&"natura": "🍃",
	}
	for element_id: StringName in expected_symbols:
		_expect(
			ASTRAL_PRESENTATION.get_element_symbol(element_id)
			== expected_symbols[element_id],
			"Simbolo errato per l'elemento %s." % element_id
		)
	_expect(
		ASTRAL_PRESENTATION.get_sex_symbol(AstralInstance.Sex.MALE) == "♂"
		and ASTRAL_PRESENTATION.get_sex_symbol(AstralInstance.Sex.FEMALE) == "♀",
		"I simboli maschio/femmina non corrispondono ai sessi."
	)


func _test_astral_roster() -> void:
	var roster := ASTRAL_ROSTER_SCENE.instantiate() as AstralRoster
	if roster == null:
		_fail("Impossibile istanziare AstralRoster per il test.")
		return
	root.add_child(roster)
	await process_frame
	var starter: AstralInstance = roster.get_active_astral()
	_expect(starter != null, "AstralRoster non crea lo starter.")
	if starter == null:
		roster.queue_free()
		await process_frame
		return
	_expect(starter.level == 5, "AstralRoster non crea lo starter al livello 5.")
	_expect(starter.current_health == starter.get_max_health(), "Starter senza HP pieni.")
	_expect(starter.get_move_count() == 2, "Venomquill non possiede le due mosse iniziali.")
	var roster_copy := roster.get_astrals()
	roster_copy.clear()
	_expect(roster.get_astral_count() == 1, "get_astrals espone l'array interno.")

	var first_source := _make_test_astral_instance(_wild_astral, 3)
	first_source.sex = AstralInstance.Sex.FEMALE
	first_source.current_health = 11
	first_source.experience = (
		first_source.definition.get_total_experience_for_level(first_source.level)
		+ 77
	)
	var first_source_experience := first_source.experience
	var original_first_move: AstralMoveDefinition = first_source.get_move(0)
	var original_second_move: AstralMoveDefinition = first_source.get_move(1)
	_expect(roster.capture_astral(first_source), "AstralRoster rifiuta una cattura valida.")
	var first_captured: AstralInstance = roster.get_astral(1)
	_expect(first_captured != null, "Astral catturato mancante dal roster.")
	if first_captured != null:
		_expect(first_captured != first_source, "La cattura conserva l'istanza sorgente.")
		_expect(
			first_captured.level == 3
			and first_captured.current_health == 11
			and first_captured.experience == first_source_experience,
			"La cattura non copia livello, HP o EXP."
		)
		_expect(
			first_captured.sex == AstralInstance.Sex.FEMALE,
			"La cattura nel roster non conserva il sesso."
		)
		_expect(
			first_captured.get_move(0) == original_first_move
			and first_captured.get_move(1) == original_second_move,
			"La cattura non copia l'ordine delle mosse."
		)
		first_source.reorder_move(0, 1)
		_expect(
			first_captured.get_move(0) == original_first_move,
			"La cattura condivide l'array mosse con la sorgente."
		)

	var second_source := _make_test_astral_instance(_player_astral, 2)
	_expect(roster.capture_astral(second_source), "Seconda cattura valida rifiutata.")
	var second_captured: AstralInstance = roster.get_astral(2)
	_expect(second_captured != null, "Secondo Astral catturato mancante.")
	for party_astral: AstralInstance in roster.get_astrals():
		party_astral.current_health = maxi(party_astral.get_max_health() - 1, 0)
	_expect(
		roster.heal_party_to_full() == roster.get_astral_count(),
		"La cura rapida non include tutti gli Astral della squadra."
	)
	for party_astral: AstralInstance in roster.get_astrals():
		_expect(
			party_astral.current_health == party_astral.get_max_health(),
			"Un Astral della squadra non viene curato al massimo."
		)
	_expect(
		roster.get_active_astral() == starter,
		"Catturare un Astral modifica il primo combattente."
	)
	_expect(roster.move_astral(2, 1), "move_astral rifiuta un riordino valido.")
	_expect(
		roster.get_astral(0) == starter
		and roster.get_astral(1) == second_captured
		and roster.get_astral(2) == first_captured,
		"move_astral produce un ordine errato."
	)
	_expect(roster.set_active_astral(2), "set_active_astral rifiuta un indice valido.")
	_expect(
		roster.get_active_astral() == first_captured
		and roster.get_astral(1) == starter
		and roster.get_astral(2) == second_captured,
		"set_active_astral non preserva l'ordine relativo."
	)
	var order_before_invalid := roster.get_astrals()
	_expect(not roster.move_astral(-1, 0), "move_astral accetta un indice invalido.")
	_expect(not roster.set_active_astral(99), "set_active_astral accetta un indice invalido.")
	_expect(
		roster.get_astrals() == order_before_invalid,
		"Un riordino invalido modifica il roster."
	)
	var active_before_capture: AstralInstance = roster.get_active_astral()
	var third_source := _make_test_astral_instance(_wild_astral, 4)
	_expect(roster.capture_astral(third_source), "Terza cattura valida rifiutata.")
	_expect(
		roster.get_active_astral() == active_before_capture,
		"Una cattura successiva modifica il primo combattente."
	)
	_expect(not roster.capture_astral(null), "AstralRoster cattura un'istanza null.")
	var invalid_source := AstralInstance.new()
	_expect(
		not roster.capture_astral(invalid_source),
		"AstralRoster cattura un'istanza senza definizione."
	)
	roster.queue_free()
	await process_frame


func _test_astral_box_storage() -> void:
	var roster := ASTRAL_ROSTER_SCENE.instantiate() as AstralRoster
	if roster == null:
		_fail("Impossibile istanziare il roster per il test Box.")
		return
	root.add_child(roster)
	await process_frame
	_expect(roster.get_box_count() == 50, "Il roster non crea cinquanta Box.")
	_expect(roster.get_box_capacity() == 30, "Ogni Box non possiede trenta slot.")

	for capture_index: int in 7:
		var source := _make_test_astral_instance(_wild_astral, capture_index + 2)
		_expect(roster.capture_astral(source), "Il Box rifiuta una cattura valida.")
	_expect(
		roster.get_astral_count() == AstralRoster.MAX_PARTY_SIZE,
		"Le catture superano il limite di sei Astral in squadra."
	)
	_expect(
		roster.get_total_astral_count() == 8,
		"Il conteggio totale non include gli Astral conservati nei Box."
	)
	_expect(
		roster.get_box_astral(0, 0) != null
		and roster.get_box_astral(0, 1) != null,
		"Le catture oltre il sesto slot non finiscono nel primo Box."
	)
	_expect(
		roster.get_last_captured_astral() == roster.get_box_astral(0, 1),
		"La cattura nel Box non espone l'istanza archiviata."
	)
	_expect(
		not roster.withdraw_astral(0, 0),
		"Il Box ritira un Astral quando la squadra è piena."
	)

	var deposited := roster.get_astral(5)
	_expect(roster.deposit_astral(5, 0), "Deposito nel Box fallito.")
	_expect(
		roster.get_astral_count() == 5
		and roster.get_box_astral(0, 2) == deposited,
		"Il deposito non conserva l'istanza nello slot libero."
	)
	var withdrawn := roster.get_box_astral(0, 0)
	_expect(roster.withdraw_astral(0, 0), "Ritiro dal Box fallito.")
	_expect(
		roster.get_astral_count() == 6 and roster.get_astral(5) == withdrawn,
		"Il ritiro non aggiunge l'Astral in coda alla squadra."
	)

	var previous_lead := roster.get_active_astral()
	var stored_swap := roster.get_box_astral(0, 1)
	_expect(
		roster.swap_party_with_box(0, 0, 1),
		"Lo scambio diretto squadra/Box fallisce."
	)
	_expect(
		roster.get_active_astral() == stored_swap
		and roster.get_box_astral(0, 1) == previous_lead,
		"Lo scambio squadra/Box non conserva le due istanze."
	)

	var moved_astral := roster.get_box_astral(0, 2)
	_expect(
		roster.move_box_astral(0, 2, 49, 29),
		"Non si può spostare un Astral fra Box distanti."
	)
	_expect(
		roster.get_box_astral(0, 2) == null
		and roster.get_box_astral(49, 29) == moved_astral,
		"Lo spostamento fra Box usa uno slot errato."
	)
	_expect(
		roster.release_box_astral(49, 29),
		"Liberare un Astral dal Box fallisce."
	)
	_expect(
		roster.get_box_astral(49, 29) == null
		and roster.get_total_astral_count() == 7,
		"Liberare dal Box non rimuove definitivamente l'Astral."
	)
	_expect(
		roster.release_party_astral(5),
		"Liberare un Astral dalla squadra fallisce."
	)
	_expect(
		roster.get_astral_count() == 5
		and roster.get_total_astral_count() == 6,
		"Liberare dalla squadra non aggiorna i conteggi."
	)

	var saved_data := roster.get_save_data()
	_expect(
		int(saved_data.get("format_version", 0)) == 2,
		"Il salvataggio Box non espone il formato versionato."
	)
	var restored := ASTRAL_ROSTER_SCENE.instantiate() as AstralRoster
	root.add_child(restored)
	await process_frame
	_expect(restored.load_save_data(saved_data), "Ripristino dei Box fallito.")
	_expect(
		restored.get_astral_count() == roster.get_astral_count()
		and restored.get_total_astral_count() == roster.get_total_astral_count(),
		"Il round-trip non conserva squadra e archivio."
	)
	_expect(
		restored.get_box_astral(0, 1) != null
		and restored.get_box_astral(0, 1).definition.astral_id
		== roster.get_box_astral(0, 1).definition.astral_id,
		"Il round-trip non conserva la posizione nel Box."
	)
	while restored.get_astral_count() > 1:
		_expect(restored.release_party_astral(1), "Liberazione squadra valida rifiutata.")
	_expect(
		not restored.release_party_astral(0),
		"Il sistema permette di liberare l'ultimo Astral della squadra."
	)

	var legacy := ASTRAL_ROSTER_SCENE.instantiate() as AstralRoster
	root.add_child(legacy)
	await process_frame
	_expect(
		legacy.load_save_data([roster.get_active_astral().get_save_data()]),
		"Il nuovo roster non carica il formato salvataggio legacy."
	)
	_expect(
		legacy.get_astral_count() == 1 and legacy.get_total_astral_count() == 1,
		"La migrazione legacy produce Astral aggiuntivi."
	)

	roster.queue_free()
	restored.queue_free()
	legacy.queue_free()
	await process_frame


func _test_element_chart_data() -> void:
	_expect(
		ElementChart.ELEMENT_IDS.size() == 18,
		"La tabella non contiene tutti i 18 elementi documentati."
	)
	var unique_ids: Dictionary[StringName, bool] = {}
	var allowed_values: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0]
	for attacking_element: StringName in ElementChart.ELEMENT_IDS:
		_expect(
			not unique_ids.has(attacking_element),
			"Elemento duplicato nella tabella: %s." % attacking_element
		)
		unique_ids[attacking_element] = true
		for defending_element: StringName in ElementChart.ELEMENT_IDS:
			var multiplier := ElementChart.get_multiplier(
				attacking_element,
				defending_element
			)
			_expect(
				allowed_values.has(multiplier),
				"Moltiplicatore non supportato: %s contro %s = %s."
				% [attacking_element, defending_element, multiplier]
			)
	_expect(
		is_equal_approx(ElementChart.get_multiplier(&"acqua", &"fuoco"), 2.0)
		and is_equal_approx(ElementChart.get_multiplier(&"natura", &"fuoco"), 0.5),
		"Debolezza e resistenza base di Fuoco sono errate."
	)
	_expect(
		is_equal_approx(ElementChart.get_multiplier(&"gelo", &"fuoco"), 2.0)
		and is_equal_approx(ElementChart.get_multiplier(&"fuoco", &"gelo"), 2.0),
		"La normalizzazione documentale Fuoco/Gelo e errata."
	)
	_expect(
		is_equal_approx(ElementChart.get_multiplier(&"fatato", &"natura"), 0.25)
		and is_equal_approx(ElementChart.get_multiplier(&"terra", &"aria"), 0.25),
		"Le immunita documentate non sono rese come forte resistenza 1/4."
	)
	var dual_defense: Array[StringName] = [&"fuoco", &"terra"]
	_expect(
		is_equal_approx(
			ElementChart.get_combined_multiplier(&"acqua", dual_defense),
			4.0
		),
		"Due debolezze non producono l'iperefficacia 4."
	)
	_expect(
		ElementChart.get_multiplier_label(0.25) == "1/4"
		and ElementChart.get_multiplier_label(0.5) == "1/2"
		and ElementChart.get_multiplier_label(1.0) == "1"
		and ElementChart.get_multiplier_label(2.0) == "2"
		and ElementChart.get_multiplier_label(4.0) == "4",
		"Le etichette della legenda elementi sono errate."
	)


func _test_battle_math() -> void:
	var nature_move := _make_test_move(&"nature_math", "Nature Math", 10, &"natura")
	var fire_move := _make_test_move(&"fire_math", "Fire Math", 10, &"fuoco")
	var moves: Array[AstralMoveDefinition] = [nature_move, fire_move]
	var nature_definition := _make_test_astral_definition(
		&"nature_attacker",
		"Nature Attacker",
		100,
		20,
		10,
		&"natura",
		&"",
		30,
		moves
	)
	var fire_definition := _make_test_astral_definition(
		&"fire_defender",
		"Fire Defender",
		100,
		20,
		10,
		&"fuoco",
		&"",
		40,
		moves
	)
	var water_definition := _make_test_astral_definition(
		&"water_attacker",
		"Water Attacker",
		100,
		20,
		10,
		&"acqua",
		&"",
		30,
		moves
	)
	nature_definition.set_base_stats(100, 80, 50, 20, 50, 30)
	fire_definition.set_base_stats(100, 20, 40, 60, 60, 30)
	water_definition.set_base_stats(100, 80, 50, 20, 50, 30)
	var nature_attacker := _make_test_astral_instance(nature_definition, 10)
	var fire_defender := _make_test_astral_instance(fire_definition, 5)
	var no_stab_attacker := _make_test_astral_instance(water_definition, 10)
	var lower_level_attacker := _make_test_astral_instance(nature_definition, 5)
	var higher_level_attacker := _make_test_astral_instance(nature_definition, 30)
	_expect(
		BattleMath.calculate_damage(nature_attacker, fire_defender, nature_move) == 3,
		"BattleMath non applica la formula fisica con STAB e resistenza."
	)
	_expect(
		BattleMath.calculate_damage(no_stab_attacker, fire_defender, nature_move) == 2,
		"BattleMath applica STAB a un elemento non posseduto."
	)
	_expect(
		BattleMath.calculate_damage(
			higher_level_attacker,
			fire_defender,
			nature_move
		) > BattleMath.calculate_damage(
			lower_level_attacker,
			fire_defender,
			nature_move
		),
		"Il livello dell'attaccante non aumenta il danno."
	)
	_expect(
		is_equal_approx(
			BattleMath.get_element_multiplier(&"natura", fire_definition),
			0.5
		),
		"La natura non e resistente contro il fuoco come previsto."
	)
	_expect(
		is_equal_approx(
			BattleMath.get_element_multiplier(&"fuoco", nature_definition),
			2.0
		),
		"Il fuoco non e superefficace contro la natura."
	)
	_expect(
		is_equal_approx(
			BattleMath.get_element_multiplier(&"acqua", fire_definition),
			2.0
		),
		"L'acqua non e superefficace contro il fuoco."
	)
	_expect(
		is_equal_approx(
			BattleMath.get_element_multiplier(&"natura", water_definition),
			2.0
		),
		"La natura non e superefficace contro l'acqua."
	)
	for neutral_defender: AstralDefinition in [
		fire_definition,
		water_definition,
		nature_definition,
	]:
		_expect(
			is_equal_approx(
				BattleMath.get_element_multiplier(&"neutro", neutral_defender),
				1.0
			),
			"L'elemento neutro applica un moltiplicatore diverso da 1."
		)
	var fire_attacker := _make_test_astral_instance(fire_definition, 10)
	var nature_defender := _make_test_astral_instance(nature_definition, 5)
	_expect(
		BattleMath.calculate_damage(fire_attacker, nature_defender, fire_move) == 8,
		"BattleMath non combina STAB e superefficacia."
	)

	var physical_move := _make_test_move(
		&"physical_math",
		"Physical Math",
		20,
		&"neutro",
		AstralMoveDefinition.DamageClass.PHYSICAL
	)
	var magical_move := _make_test_move(
		&"magical_math",
		"Magical Math",
		20,
		&"neutro",
		AstralMoveDefinition.DamageClass.MAGICAL
	)
	var mixed_moves: Array[AstralMoveDefinition] = [physical_move, magical_move]
	var mixed_attacker_definition := _make_test_astral_definition(
		&"mixed_attacker",
		"Mixed Attacker",
		100,
		20,
		30,
		&"acqua",
		&"",
		20,
		mixed_moves
	)
	var mixed_defender_definition := _make_test_astral_definition(
		&"mixed_defender",
		"Mixed Defender",
		100,
		20,
		30,
		&"natura",
		&"",
		20,
		mixed_moves
	)
	mixed_attacker_definition.set_base_stats(100, 20, 40, 100, 40, 30)
	mixed_defender_definition.set_base_stats(100, 40, 100, 40, 20, 30)
	var mixed_attacker := _make_test_astral_instance(mixed_attacker_definition, 10)
	var mixed_defender := _make_test_astral_instance(mixed_defender_definition, 10)
	_expect(
		BattleMath.calculate_damage(mixed_attacker, mixed_defender, physical_move) == 2,
		"La mossa fisica non usa Atk e PDef."
	)
	_expect(
		BattleMath.calculate_damage(mixed_attacker, mixed_defender, magical_move) == 8,
		"La mossa magica non usa Atkm e MDef."
	)

	var scaling_modifiers := BattleMath.DamageModifiers.new()
	scaling_modifiers.attack_stat_modifier = 12.0
	var scaled_result := BattleMath.calculate_damage_result(
		mixed_attacker,
		mixed_defender,
		magical_move,
		false,
		BattleMath.RANDOM_ROLL_MAXIMUM,
		scaling_modifiers
	)
	_expect(
		scaled_result.effective_attack == 75
		and scaled_result.effective_defense == 2,
		"A > 255 non divide A e D per quattro con floor."
	)
	var critical_result := BattleMath.calculate_damage_result(
		mixed_attacker,
		mixed_defender,
		magical_move,
		true,
		BattleMath.RANDOM_ROLL_MAXIMUM,
		scaling_modifiers
	)
	_expect(
		critical_result.effective_attack == 25
		and critical_result.effective_defense == 9
		and critical_result.is_critical_hit,
		"Il brutto colpo non ignora i modificatori delle statistiche."
	)
	var one_damage_modifiers := BattleMath.DamageModifiers.new()
	one_damage_modifiers.modifier_2 = 0.5
	_expect(
		BattleMath.calculate_damage(
			mixed_attacker,
			mixed_defender,
			physical_move,
			false,
			BattleMath.RANDOM_ROLL_MINIMUM,
			one_damage_modifiers
		) == 1,
		"Random riduce un danno pre-Random pari a uno."
	)
	_expect(
		is_equal_approx(BattleMath.CRITICAL_HIT_CHANCE, 0.10),
		"La probabilita base di brutto colpo non e il 10%."
	)
	var damage_rng := RandomNumberGenerator.new()
	damage_rng.seed = 97531
	var observed_critical := false
	var observed_normal := false
	for _roll_index: int in 200:
		var rolled_result := BattleMath.roll_damage(
			mixed_attacker,
			mixed_defender,
			magical_move,
			damage_rng
		)
		_expect(
			rolled_result.random_roll >= BattleMath.RANDOM_ROLL_MINIMUM
			and rolled_result.random_roll <= BattleMath.RANDOM_ROLL_MAXIMUM,
			"Il tiro casuale del danno esce dall'intervallo 217-255."
		)
		observed_critical = observed_critical or rolled_result.is_critical_hit
		observed_normal = observed_normal or not rolled_result.is_critical_hit
	_expect(
		observed_critical and observed_normal,
		"Il tiro deterministico non copre esiti critici e normali."
	)
	var defeated_for_reward := _make_test_astral_instance(fire_definition, 7)
	_expect(
		BattleMath.calculate_experience_reward(defeated_for_reward) == 56,
		"BattleMath calcola una ricompensa EXP errata."
	)


func _test_move_damage_tiers() -> void:
	var tier_moves: Array[AstralMoveDefinition] = [
		load("res://data/moves/impatto_astrale.tres") as AstralMoveDefinition,
		load("res://data/moves/frusta_di_liane.tres") as AstralMoveDefinition,
		load("res://data/moves/lamafoglia.tres") as AstralMoveDefinition,
		load("res://data/moves/assalto_radice.tres") as AstralMoveDefinition,
	]
	var attacker_definition := _make_test_astral_definition(
		&"damage_tier_attacker",
		"Damage Tier Attacker",
		100,
		50,
		50,
		&"natura",
		&"",
		10,
		tier_moves
	)
	var defender_definition := _make_test_astral_definition(
		&"damage_tier_defender",
		"Damage Tier Defender",
		100,
		50,
		50,
		&"neutro",
		&"",
		10,
		tier_moves
	)
	var attacker := _make_test_astral_instance(attacker_definition, 5)
	var defender := _make_test_astral_instance(defender_definition, 5)
	var expected_ranges: Array[Vector2i] = [
		Vector2i(20, 35),
		Vector2i(30, 50),
		Vector2i(45, 65),
		Vector2i(60, 80),
	]
	for move_index: int in tier_moves.size():
		var move := tier_moves[move_index]
		_expect(move != null, "Mossa bilanciamento mancante all'indice %d." % move_index)
		if move == null:
			continue
		var minimum_damage := BattleMath.calculate_damage(
			attacker,
			defender,
			move,
			false,
			BattleMath.RANDOM_ROLL_MINIMUM
		)
		var maximum_damage := BattleMath.calculate_damage(
			attacker,
			defender,
			move,
			false,
			BattleMath.RANDOM_ROLL_MAXIMUM
		)
		var expected_range := expected_ranges[move_index]
		_expect(
			minimum_damage >= expected_range.x
			and maximum_damage <= expected_range.y,
			"La fascia CD %d produce %d-%d danni invece di %d-%d." % [
				move.cooldown_turns,
				minimum_damage,
				maximum_damage,
				expected_range.x,
				expected_range.y,
			]
		)


func _test_world_map(main: Node) -> void:
	var world_map := main.get_node_or_null("WorldMap") as Node3D
	if world_map == null:
		_fail("WorldMap non è un Node3D.")
		return
	var vegetation := world_map.get_node_or_null("Vegetation") as Node3D
	var prop_collisions := world_map.get_node_or_null("PropCollisions") as Node
	var boundary_collisions := world_map.get_node_or_null(
		"BoundaryVegetationCollisions"
	) as Node
	var landmarks := world_map.get_node_or_null("IconicLandmarks") as Node3D
	var wind := world_map.get_node_or_null("VegetationWind") as Node
	var time_of_day := world_map.get_node_or_null("TimeOfDay") as Node

	_expect(vegetation != null, "Contenitore Vegetation mancante.")
	_expect(prop_collisions != null, "PropCollisions mancante.")
	_expect(boundary_collisions != null, "Collisioni del confine vegetale mancanti.")
	_expect(landmarks != null, "IconicLandmarks mancante.")
	_expect(wind != null, "VegetationWind mancante.")
	_expect(time_of_day != null, "TimeOfDay mancante.")
	if time_of_day != null:
		var clock_label := time_of_day.get_node_or_null(
			"ClockCanvas/ClockPanel/ClockLabel"
		) as Label
		_expect(clock_label != null, "Orologio di gioco mancante.")
		if clock_label != null:
			_expect(not clock_label.text.is_empty(), "Orologio senza testo.")

	if boundary_collisions != null:
		_expect(
			boundary_collisions.get_child_count() >= 400,
			"Confine vegetale non sufficientemente chiuso."
		)
	if prop_collisions != null:
		var enabled_prop_collisions := _count_enabled_collision_shapes(prop_collisions)
		_expect(enabled_prop_collisions > 0, "Tutte le collisioni dei props sono disabilitate.")

	_test_landmarks(landmarks)
	_test_tall_grass(vegetation)


func _test_landmarks(landmarks: Node3D) -> void:
	if landmarks == null:
		return
	_expect(landmarks.get_node_or_null("PondWater") != null, "Laghetto mancante.")
	_expect(landmarks.get_node_or_null("PondShore") != null, "Riva del laghetto mancante.")
	_expect(landmarks.get_node_or_null("LandmarkCollisions") != null, "Collisioni landmark mancanti.")
	var red_tree_count := 0
	var fallen_tree_count := 0
	for child: Node in landmarks.get_children():
		if child.name.begins_with("RedTree_"):
			red_tree_count += 1
		if child.name.begins_with("FallenTree_"):
			fallen_tree_count += 1
	_expect(red_tree_count >= 20, "Radura degli alberi rossi incompleta.")
	_expect(fallen_tree_count >= 5, "Zona degli alberi caduti incompleta.")
	var encounter_zones := get_nodes_in_group("wild_encounter_zones")
	_expect(encounter_zones.size() >= 5, "Zone di incontro nell'erba alta mancanti.")


func _test_tall_grass(vegetation: Node3D) -> void:
	if vegetation == null:
		return
	var field_count := 0
	var grass_instance_count := 0
	for candidate: Node in vegetation.find_children(
		"TallGrass_*",
		"MultiMeshInstance3D",
		true,
		false
	):
		var grass := candidate as MultiMeshInstance3D
		if grass == null or grass.multimesh == null:
			continue
		field_count += 1
		grass_instance_count += grass.multimesh.instance_count
	_expect(field_count >= 5, "Blocchi visuali di erba alta mancanti.")
	_expect(grass_instance_count >= 400, "Erba alta troppo rada.")


func _test_encounter_wiring(main: Node) -> void:
	var world_map := main.get_node_or_null("WorldMap") as Node3D
	var player := main.get_node_or_null("Player") as CharacterBody3D
	var inventory := main.get_node_or_null("Inventory") as Inventory
	var roster := main.get_node_or_null("AstralRoster") as AstralRoster
	var battle_host := main.get_node_or_null("BattleHost")
	var game_ui := main.get_node_or_null("GameUI") as GameUI
	if (
		world_map == null
		or player == null
		or inventory == null
		or roster == null
		or battle_host == null
		or game_ui == null
	):
		_fail("Impossibile verificare il wiring degli incontri selvatici.")
		return
	if not world_map.has_signal("wild_encounter_requested"):
		_fail("Segnale wild_encounter_requested mancante dalla mappa.")
		return

	var encounter_zone: TallGrassEncounterZone = null
	for candidate: Node in get_nodes_in_group("wild_encounter_zones"):
		if candidate is TallGrassEncounterZone and main.is_ancestor_of(candidate):
			encounter_zone = candidate as TallGrassEncounterZone
			break
	if encounter_zone == null:
		_fail("Nessuna TallGrassEncounterZone disponibile per il test del segnale.")
		return
	_expect(
		encounter_zone.player == null or encounter_zone.player == player,
		"La zona di incontro usa un CharacterBody3D diverso dal player."
	)
	_expect(
		encounter_zone.grass_visual != null,
		"La zona di incontro non e collegata al proprio blocco di erba."
	)
	_expect(
		(encounter_zone.collision_mask & player.collision_layer) != 0,
		"La zona di incontro non rileva il collision layer del player."
	)
	main.set("battle_fade_duration", 0.0)
	var expected_world_map: Node = main.get("world_map")
	var expected_player: Node = main.get("player")
	var expected_inventory: Node = main.get("inventory")
	var expected_roster: Node = main.get("astral_roster")
	var expected_battle_host: Node = main.get("battle_host")

	_received_encounter = false
	_received_encounter_zone_id = &""
	_received_encounter_actor = null
	var callback := Callable(self, "_on_test_wild_encounter_requested")
	world_map.connect("wild_encounter_requested", callback)
	encounter_zone.encounter_triggered.emit(encounter_zone.zone_id, player)

	_expect(_received_encounter, "Il segnale encounter non raggiunge VerdantValley.")
	_expect(
		_received_encounter_zone_id == encounter_zone.zone_id,
		"Il wiring encounter modifica lo zone_id."
	)
	_expect(
		_received_encounter_actor == player,
		"Il wiring encounter modifica il riferimento al player."
	)
	var battle := await _wait_for_battle(battle_host)
	_expect(battle != null, "L'incontro nell'erba non apre BattleController.")
	_expect(paused, "L'apertura della battaglia non sospende il mondo.")
	_expect(
		game_ui.has_pause_lock(&"battle"),
		"Il pause lock della battaglia non viene attivato."
	)
	if battle != null:
		battle.action_delay = 0.0
		var command_ready := await _wait_for_battle_state(
			battle,
			BattleController.BattleState.COMMAND
		)
		_expect(command_ready, "BattleController non raggiunge lo stato COMMAND.")
		if command_ready:
			battle.choose_flee()
		var battle_closed := await _wait_for_battle_close(battle_host, game_ui)
		_expect(battle_closed, "Fuggi non chiude la battaglia avviata da Main.")
	else:
		game_ui.set_pause_lock(&"battle", false)

	_expect(not paused, "Il mondo resta sospeso dopo la fuga.")
	_expect(
		not game_ui.has_pause_lock(&"battle"),
		"Il pause lock resta attivo dopo la fuga."
	)
	_expect(main.get("world_map") == expected_world_map, "Main perde WorldMap.")
	_expect(main.get("player") == expected_player, "Main perde Player.")
	_expect(main.get("inventory") == expected_inventory, "Main perde Inventory.")
	_expect(main.get("astral_roster") == expected_roster, "Main perde AstralRoster.")
	_expect(main.get("battle_host") == expected_battle_host, "Main perde BattleHost.")
	world_map.disconnect("wild_encounter_requested", callback)


func _on_test_wild_encounter_requested(
	zone_id: StringName,
	actor: Node3D
) -> void:
	_received_encounter = true
	_received_encounter_zone_id = zone_id
	_received_encounter_actor = actor


func _wait_for_battle(
	battle_host: Node,
	maximum_frames: int = 30
) -> BattleController:
	for _frame_index: int in maximum_frames:
		for child: Node in battle_host.get_children():
			if child is BattleController:
				return child as BattleController
		await process_frame
	return null


func _wait_for_battle_state(
	battle: BattleController,
	expected_state: int,
	maximum_frames: int = 60
) -> bool:
	for _frame_index: int in maximum_frames:
		if not is_instance_valid(battle):
			return false
		if battle.get_state() == expected_state:
			return true
		await process_frame
	return is_instance_valid(battle) and battle.get_state() == expected_state


func _wait_for_battle_close(
	battle_host: Node,
	game_ui: GameUI,
	maximum_frames: int = 60
) -> bool:
	for _frame_index: int in maximum_frames:
		if (
			battle_host.get_child_count() == 0
			and not game_ui.has_pause_lock(&"battle")
			and not paused
		):
			return true
		await process_frame
	return (
		battle_host.get_child_count() == 0
		and not game_ui.has_pause_lock(&"battle")
		and not paused
	)


func _create_battle_fixture() -> Dictionary:
	var fixture_root := Node.new()
	fixture_root.name = "BattleTestFixture"
	fixture_root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(fixture_root)

	var inventory := INVENTORY_SCENE.instantiate() as Inventory
	var roster := ASTRAL_ROSTER_SCENE.instantiate() as AstralRoster
	var battle := BATTLE_SCENE.instantiate() as BattleController
	fixture_root.add_child(inventory)
	fixture_root.add_child(roster)
	fixture_root.add_child(battle)

	var battle_moves: Array[AstralMoveDefinition] = []
	for cooldown: int in 4:
		var move := _make_test_move(
			StringName("fixture_move_%d" % cooldown),
			"Mossa Fixture %d" % cooldown,
			35 + cooldown * 15,
			&"neutro"
		)
		move.cooldown_turns = cooldown
		battle_moves.append(move)
	var player_definition := _make_test_astral_definition(
		&"fixture_player",
		"Astral alleato",
		120,
		85,
		55,
		&"neutro",
		&"",
		25,
		battle_moves
	)
	var wild_definition := _make_test_astral_definition(
		&"fixture_wild",
		"Astral selvatico",
		120,
		80,
		50,
		&"neutro",
		&"",
		40,
		battle_moves
	)
	var active_astral := roster.get_active_astral()
	if active_astral != null:
		active_astral.setup(
			player_definition,
			10,
			AstralInstance.Sex.MALE
		)

	_battle_outcome = &""
	_captured_astral = null
	battle.action_delay = 0.0
	battle.battle_finished.connect(_on_test_battle_finished)
	battle.setup(inventory, roster, wild_definition, 10)
	battle.set_damage_random_seed(BATTLE_TEST_RANDOM_SEED)
	battle.begin()
	var command_ready := await _wait_for_battle_state(
		battle,
		BattleController.BattleState.COMMAND
	)
	_expect(command_ready, "La fixture Battle non raggiunge lo stato COMMAND.")
	return {
		"root": fixture_root,
		"inventory": inventory,
		"roster": roster,
		"battle": battle,
	}


func _cleanup_battle_fixture(fixture: Dictionary) -> void:
	var fixture_root := fixture.get("root") as Node
	if is_instance_valid(fixture_root):
		fixture_root.queue_free()
	await process_frame


func _find_battle_move_button(
	battle: BattleController,
	move_index: int
) -> Button:
	if battle == null:
		return null
	for child: Node in battle.moves_grid.get_children():
		var move_button := child as Button
		if (
			move_button != null
			and move_button.has_meta(&"move_index")
			and int(move_button.get_meta(&"move_index")) == move_index
		):
			return move_button
	return null


func _on_test_battle_finished(
	outcome: StringName,
	captured_astral: AstralInstance
) -> void:
	_battle_outcome = outcome
	_captured_astral = captured_astral


func _test_battle_fight() -> void:
	var fixture := await _create_battle_fixture()
	var battle := fixture.get("battle") as BattleController
	if battle == null:
		_fail("Fixture Battle mancante nel test Lotta.")
		await _cleanup_battle_fixture(fixture)
		return
	var player_astral: AstralInstance = battle.get_player_astral()
	var wild_astral: AstralInstance = battle.get_wild_astral()
	if player_astral == null or wild_astral == null:
		_fail("Astral mancanti nel test Lotta.")
		await _cleanup_battle_fixture(fixture)
		return
	var player_forward := -battle.player_visual.global_transform.basis.z.normalized()
	var opponent_forward := -battle.wild_visual.global_transform.basis.z.normalized()
	_expect(
		player_forward.dot(Vector3.RIGHT) > 0.99,
		"L'Astral della squadra non guarda verso destra."
	)
	_expect(
		opponent_forward.dot(Vector3.LEFT) > 0.99,
		"L'Astral avversario non guarda verso sinistra."
	)

	var player_move: AstralMoveDefinition = player_astral.get_move(0)
	var wild_move: AstralMoveDefinition = wild_astral.get_move(0)
	if player_move == null or wild_move == null:
		_fail("Mosse mancanti nel test Lotta.")
		await _cleanup_battle_fixture(fixture)
		return
	var initial_player_health := player_astral.current_health
	var initial_wild_health := wild_astral.current_health
	var initial_experience := player_astral.experience
	var expected_damage_rng := RandomNumberGenerator.new()
	expected_damage_rng.seed = BATTLE_TEST_RANDOM_SEED
	var expected_player_damage := BattleMath.roll_damage(
		player_astral,
		wild_astral,
		player_move,
		expected_damage_rng
	).damage
	var expected_counterattack := BattleMath.roll_damage(
		wild_astral,
		player_astral,
		wild_move,
		expected_damage_rng
	).damage
	battle.choose_fight()
	_expect(
		battle.get_state() == BattleController.BattleState.MOVES,
		"Lotta non apre la selezione MOVES."
	)
	var visible_move_buttons := 0
	for child: Node in battle.moves_grid.get_children():
		if child is Button:
			visible_move_buttons += 1
	_expect(visible_move_buttons == 4, "Lotta non mostra quattro mosse selezionabili.")
	battle.choose_move(0)
	var command_restored := await _wait_for_battle_state(
		battle,
		BattleController.BattleState.COMMAND
	)
	_expect(command_restored, "Lotta non restituisce il controllo al giocatore.")
	_expect(
		wild_astral.current_health
		== maxi(initial_wild_health - expected_player_damage, 0),
		"Lotta non applica il danno dell'Astral alleato."
	)
	_expect(
		player_astral.current_health
		== maxi(initial_player_health - expected_counterattack, 0),
		"Lotta non applica il contrattacco selvatico."
	)
	_expect(
		player_astral.experience == initial_experience,
		"Un attacco non letale assegna EXP."
	)
	_expect(_battle_outcome.is_empty(), "Lotta termina prematuramente la battaglia.")
	await _cleanup_battle_fixture(fixture)


func _test_battle_cooldowns_and_presentation() -> void:
	var fixture := await _create_battle_fixture()
	var inventory := fixture.get("inventory") as Inventory
	var battle := fixture.get("battle") as BattleController
	if inventory == null or battle == null:
		_fail("Fixture incompleta nel test cooldown Battle.")
		await _cleanup_battle_fixture(fixture)
		return
	var player_astral := battle.get_player_astral()
	var wild_astral := battle.get_wild_astral()
	if player_astral == null or wild_astral == null:
		_fail("Astral mancanti nel test cooldown Battle.")
		await _cleanup_battle_fixture(fixture)
		return

	var player_identity := ASTRAL_PRESENTATION.format_identity(player_astral)
	var wild_identity := ASTRAL_PRESENTATION.format_identity(wild_astral)
	_expect(
		player_identity in battle.player_name_label.text,
		"Lo status Battle non mostra nome, sesso ed elemento dell'alleato."
	)
	_expect(
		wild_identity in battle.wild_name_label.text,
		"Lo status Battle non mostra nome, sesso ed elemento del selvatico."
	)

	battle.choose_fight()
	_expect(
		battle.get_state() == BattleController.BattleState.MOVES,
		"Il test cooldown non raggiunge MOVES."
	)
	var cooldown_indices: Dictionary[int, int] = {}
	for child: Node in battle.moves_grid.get_children():
		var move_button := child as Button
		if move_button == null or not move_button.has_meta(&"move_index"):
			continue
		var move_index := int(move_button.get_meta(&"move_index"))
		var base_cooldown := int(move_button.get_meta(&"cooldown_turns", -1))
		cooldown_indices[base_cooldown] = move_index
		_expect(
			"CD %d" % base_cooldown in move_button.text,
			"Il pulsante mossa non mostra il cooldown base %d." % base_cooldown
		)
		_expect(
			int(move_button.get_meta(&"cooldown_remaining", -1)) == 0,
			"Una mossa parte gia in cooldown."
		)
	_expect(
		cooldown_indices.size() == 4
		and cooldown_indices.has(0)
		and cooldown_indices.has(1)
		and cooldown_indices.has(2)
		and cooldown_indices.has(3),
		"Battle non espone una mossa per ciascun cooldown da 0 a 3."
	)
	if not cooldown_indices.has(3) or not cooldown_indices.has(0):
		await _cleanup_battle_fixture(fixture)
		return

	var cooldown_three_index := cooldown_indices[3]
	var cooldown_zero_index := cooldown_indices[0]
	player_astral.current_health = 999
	wild_astral.current_health = 999
	battle.choose_move(cooldown_three_index)
	_expect(
		battle.get_player_turn_index() == 2,
		"Usare una mossa CD3 non consuma esattamente un turno alleato."
	)
	_expect(
		battle.get_player_move_cooldown_remaining(cooldown_three_index) == 3,
		"La mossa CD3 non entra in attesa per tre turni."
	)
	var command_restored := await _wait_for_battle_state(
		battle,
		BattleController.BattleState.COMMAND
	)
	_expect(command_restored, "La mossa CD3 non restituisce i comandi.")

	battle.choose_fight()
	var locked_button := _find_battle_move_button(battle, cooldown_three_index)
	_expect(locked_button != null, "Il pulsante CD3 scompare durante l'attesa.")
	if locked_button != null:
		_expect(locked_button.disabled, "Una mossa in cooldown resta selezionabile.")
		_expect(
			int(locked_button.get_meta(&"cooldown_remaining", -1)) == 3
			and "Attesa 3" in locked_button.text,
			"Il pulsante CD3 non mostra il contatore iniziale."
		)
	var turn_before_locked_call := battle.get_player_turn_index()
	var player_health_before_locked_call := player_astral.current_health
	var wild_health_before_locked_call := wild_astral.current_health
	battle.choose_move(cooldown_three_index)
	_expect(
		battle.get_state() == BattleController.BattleState.MOVES,
		"Una chiamata a una mossa bloccata esce da MOVES."
	)
	_expect(
		battle.get_player_turn_index() == turn_before_locked_call,
		"Una mossa bloccata consuma il turno alleato."
	)
	_expect(
		player_astral.current_health == player_health_before_locked_call
		and wild_astral.current_health == wild_health_before_locked_call,
		"Una mossa bloccata modifica gli HP."
	)
	battle.call("_show_commands")

	inventory.add_item(&"bacca", 3)
	var expected_remaining_values: Array[int] = [2, 1, 0]
	for expected_remaining: int in expected_remaining_values:
		battle.choose_items()
		_expect(
			battle.get_state() == BattleController.BattleState.ITEMS,
			"Un turno valido di ricarica non raggiunge ITEMS."
		)
		battle.use_item(&"bacca")
		command_restored = await _wait_for_battle_state(
			battle,
			BattleController.BattleState.COMMAND
		)
		_expect(command_restored, "Un turno valido non restituisce i comandi.")
		_expect(
			battle.get_player_move_cooldown_remaining(cooldown_three_index)
			== expected_remaining,
			"Il contatore CD3 non scende a %d dopo un turno valido."
			% expected_remaining
		)
	_expect(
		battle.get_player_turn_index() == 5,
		"La mossa CD3 non torna pronta al quarto turno successivo."
	)

	battle.choose_fight()
	var ready_button := _find_battle_move_button(battle, cooldown_three_index)
	_expect(ready_button != null, "Il pulsante CD3 pronto non viene ricreato.")
	if ready_button != null:
		_expect(not ready_button.disabled, "La mossa CD3 resta bloccata al turno 5.")
		_expect(
			int(ready_button.get_meta(&"cooldown_remaining", -1)) == 0,
			"Il contatore CD3 pronto non torna a zero."
		)
	battle.choose_move(cooldown_zero_index)
	command_restored = await _wait_for_battle_state(
		battle,
		BattleController.BattleState.COMMAND
	)
	_expect(command_restored, "La mossa CD0 non conclude il turno normalmente.")
	_expect(
		battle.get_player_move_cooldown_remaining(cooldown_zero_index) == 0,
		"Una mossa CD0 entra impropriamente in cooldown."
	)
	battle.choose_fight()
	var zero_button := _find_battle_move_button(battle, cooldown_zero_index)
	_expect(
		zero_button != null and not zero_button.disabled,
		"La mossa CD0 non resta disponibile nel turno successivo."
	)
	await _cleanup_battle_fixture(fixture)


func _test_battle_ko_experience() -> void:
	var fixture := await _create_battle_fixture()
	var battle := fixture.get("battle") as BattleController
	if battle == null:
		_fail("Fixture Battle mancante nel test EXP da KO.")
		await _cleanup_battle_fixture(fixture)
		return
	var player_astral: AstralInstance = battle.get_player_astral()
	var wild_astral: AstralInstance = battle.get_wild_astral()
	if player_astral == null or wild_astral == null:
		_fail("Astral mancanti nel test EXP da KO.")
		await _cleanup_battle_fixture(fixture)
		return
	var player_move: AstralMoveDefinition = player_astral.get_move(0)
	if player_move == null:
		_fail("Mossa alleata mancante nel test EXP da KO.")
		await _cleanup_battle_fixture(fixture)
		return
	player_astral.experience = (
		player_astral.definition.get_total_experience_for_level(player_astral.level)
		+ 95
	)
	var initial_level := player_astral.level
	var initial_health := player_astral.current_health
	wild_astral.current_health = 1
	var reward := BattleMath.calculate_experience_reward(wild_astral)
	var total_experience := player_astral.experience + reward
	var expected_level := player_astral.definition.get_level_for_total_experience(
		total_experience
	)
	var expected_experience := mini(
		total_experience,
		player_astral.definition.get_total_experience_for_level(
			AstralInstance.MAX_LEVEL
		)
	)

	battle.choose_fight()
	_expect(
		battle.get_state() == BattleController.BattleState.MOVES,
		"Il test KO non raggiunge MOVES."
	)
	battle.choose_move(0)
	var battle_finished := await _wait_for_battle_state(
		battle,
		BattleController.BattleState.FINISHED
	)
	_expect(battle_finished, "Mettere KO il selvatico non termina la battaglia.")
	_expect(_battle_outcome == &"victory", "Il KO non emette outcome victory.")
	_expect(
		player_astral.level == expected_level,
		"Il KO non assegna i livelli EXP previsti."
	)
	_expect(
		player_astral.experience == expected_experience,
		"Il KO non conserva correttamente l'overflow EXP."
	)
	_expect(
		player_astral.current_health == initial_health,
		"Il selvatico contrattacca dopo essere stato messo KO."
	)
	await _cleanup_battle_fixture(fixture)


func _test_battle_items() -> void:
	var fixture := await _create_battle_fixture()
	var inventory := fixture.get("inventory") as Inventory
	var battle := fixture.get("battle") as BattleController
	if inventory == null or battle == null:
		_fail("Fixture incompleta nel test Strumenti.")
		await _cleanup_battle_fixture(fixture)
		return
	var player_astral: AstralInstance = battle.get_player_astral()
	if player_astral == null:
		_fail("Astral alleato mancante nel test Strumenti.")
		await _cleanup_battle_fixture(fixture)
		return

	inventory.add_item(&"bacca", 2)
	var initial_experience := player_astral.experience
	battle.choose_items()
	_expect(
		battle.get_state() == BattleController.BattleState.ITEMS,
		"Strumenti non apre lo stato ITEMS."
	)
	var bacca_listed := false
	for child: Node in battle.items_list.get_children():
		var item_button := child as Button
		if item_button != null and "Bacca" in item_button.text and "x2" in item_button.text:
			bacca_listed = true
			break
	_expect(bacca_listed, "La bacca consumabile non appare in Strumenti.")

	var initial_quantity := inventory.get_quantity(&"bacca")
	battle.use_item(&"bacca")
	var command_restored := await _wait_for_battle_state(
		battle,
		BattleController.BattleState.COMMAND
	)
	_expect(command_restored, "Usare uno strumento non conclude il turno.")
	_expect(
		inventory.get_quantity(&"bacca") == initial_quantity - 1,
		"Usare una bacca non ne consuma esattamente una."
	)
	_expect(
		player_astral.experience == initial_experience,
		"Usare uno strumento assegna EXP senza un KO."
	)
	_expect(_battle_outcome.is_empty(), "Strumenti termina prematuramente la battaglia.")
	await _cleanup_battle_fixture(fixture)


func _test_battle_capture() -> void:
	var fixture := await _create_battle_fixture()
	var roster := fixture.get("roster") as AstralRoster
	var inventory := fixture.get("inventory") as Inventory
	var battle := fixture.get("battle") as BattleController
	if roster == null or inventory == null or battle == null:
		_fail("Fixture incompleta nel test Cattura.")
		await _cleanup_battle_fixture(fixture)
		return
	var player_astral: AstralInstance = battle.get_player_astral()
	var wild_astral: AstralInstance = battle.get_wild_astral()
	if player_astral == null or wild_astral == null:
		_fail("Astral alleato o selvatico mancante nel test Cattura.")
		await _cleanup_battle_fixture(fixture)
		return

	var initial_roster_count := roster.get_astral_count()
	var initial_experience := player_astral.experience
	var wild_sex := wild_astral.sex
	_expect(
		inventory.add_item(&"runa_base", 1) == 1,
		"Impossibile preparare la Runa Base per il test Cattura."
	)
	battle.choose_capture()
	var battle_finished := await _wait_for_battle_state(
		battle,
		BattleController.BattleState.FINISHED
	)
	_expect(battle_finished, "Cattura non termina la battaglia.")
	_expect(_battle_outcome == &"captured", "Cattura emette un outcome errato.")
	_expect(
		roster.get_astral_count() == initial_roster_count + 1,
		"Cattura non aggiunge l'Astral al roster."
	)
	_expect(_captured_astral != null, "Cattura non restituisce l'Astral catturato.")
	if _captured_astral != null:
		_expect(
			roster.get_astral(initial_roster_count) == _captured_astral,
			"L'Astral restituito non coincide con quello aggiunto al roster."
		)
		_expect(
			_captured_astral.sex == wild_sex,
			"Catturare un selvatico non conserva il suo sesso."
		)
	_expect(
		player_astral.experience == initial_experience,
		"Catturare un selvatico assegna EXP senza un KO."
	)
	_expect(
		inventory.get_quantity(&"runa_base") == 0,
		"Il tentativo di cattura non consuma esattamente una Runa Base."
	)
	await _cleanup_battle_fixture(fixture)


func _test_battle_flee() -> void:
	var fixture := await _create_battle_fixture()
	var inventory := fixture.get("inventory") as Inventory
	var roster := fixture.get("roster") as AstralRoster
	var battle := fixture.get("battle") as BattleController
	if inventory == null or roster == null or battle == null:
		_fail("Fixture incompleta nel test Fuggi.")
		await _cleanup_battle_fixture(fixture)
		return

	inventory.add_item(&"bacca", 1)
	var player_astral := battle.get_player_astral()
	var wild_astral := battle.get_wild_astral()
	var initial_quantity := inventory.get_quantity(&"bacca")
	var initial_roster_count := roster.get_astral_count()
	var initial_player_health := player_astral.current_health
	var initial_wild_health := wild_astral.current_health
	var initial_experience := player_astral.experience
	battle.choose_flee()
	_expect(
		battle.get_state() == BattleController.BattleState.FINISHED,
		"Fuggi non termina immediatamente la battaglia."
	)
	_expect(_battle_outcome == &"fled", "Fuggi emette un outcome errato.")
	_expect(_captured_astral == null, "Fuggi restituisce un Astral catturato.")
	_expect(
		inventory.get_quantity(&"bacca") == initial_quantity,
		"Fuggi modifica l'inventario."
	)
	_expect(
		roster.get_astral_count() == initial_roster_count,
		"Fuggi modifica il roster."
	)
	_expect(
		player_astral.current_health == initial_player_health,
		"Fuggi modifica la salute dell'Astral alleato."
	)
	_expect(
		wild_astral.current_health == initial_wild_health,
		"Fuggi modifica la salute dell'Astral selvatico."
	)
	_expect(
		player_astral.experience == initial_experience,
		"Fuggi assegna EXP senza un KO."
	)
	await _cleanup_battle_fixture(fixture)


func _test_battle_switch() -> void:
	var fixture := await _create_battle_fixture()
	var roster := fixture.get("roster") as AstralRoster
	var battle := fixture.get("battle") as BattleController
	if roster == null or battle == null:
		_fail("Fixture incompleta nel test Scambia.")
		await _cleanup_battle_fixture(fixture)
		return
	var previous_active: AstralInstance = battle.get_player_astral()
	var wild_astral: AstralInstance = battle.get_wild_astral()
	if previous_active == null or wild_astral == null:
		_fail("Astral mancanti nel test Scambia.")
		await _cleanup_battle_fixture(fixture)
		return

	var reserve_source := _make_test_astral_instance(_player_astral, 5)
	reserve_source.experience = 41
	_expect(roster.capture_astral(reserve_source), "Scambia non prepara la riserva.")
	var reserve: AstralInstance = roster.get_astral(1)
	var wild_move: AstralMoveDefinition = wild_astral.get_move(0)
	if reserve == null or wild_move == null:
		_fail("Riserva o mossa selvatica mancante nel test Scambia.")
		await _cleanup_battle_fixture(fixture)
		return
	var previous_health := previous_active.current_health
	var reserve_health := reserve.current_health
	var reserve_experience := reserve.experience
	var expected_damage_rng := RandomNumberGenerator.new()
	expected_damage_rng.seed = BATTLE_TEST_RANDOM_SEED
	var expected_counterattack := BattleMath.roll_damage(
		wild_astral,
		reserve,
		wild_move,
		expected_damage_rng
	).damage

	battle.choose_switch()
	_expect(
		battle.get_state() == BattleController.BattleState.ASTRALS,
		"Scambia non apre la selezione ASTRALS."
	)
	battle.switch_astral(1)
	var command_restored := await _wait_for_battle_state(
		battle,
		BattleController.BattleState.COMMAND
	)
	_expect(command_restored, "Lo scambio volontario non conclude il turno.")
	_expect(roster.get_active_astral() == reserve, "Scambia non rende attiva la riserva.")
	_expect(battle.get_player_astral() == reserve, "Battle non usa l'Astral selezionato.")
	_expect(
		reserve.current_health == maxi(reserve_health - expected_counterattack, 0),
		"Lo scambio volontario non consuma il turno avversario."
	)
	_expect(
		previous_active.current_health == previous_health,
		"Il contrattacco colpisce l'Astral ritirato."
	)
	_expect(
		reserve.experience == reserve_experience,
		"Scambiare Astral assegna EXP senza un KO."
	)
	_expect(_battle_outcome.is_empty(), "Scambia termina prematuramente la battaglia.")
	await _cleanup_battle_fixture(fixture)


func _test_battle_forced_switch() -> void:
	var fixture := await _create_battle_fixture()
	var roster := fixture.get("roster") as AstralRoster
	var battle := fixture.get("battle") as BattleController
	if roster == null or battle == null:
		_fail("Fixture incompleta nel test cambio forzato.")
		await _cleanup_battle_fixture(fixture)
		return
	var defeated_astral: AstralInstance = battle.get_player_astral()
	var wild_astral: AstralInstance = battle.get_wild_astral()
	if defeated_astral == null or wild_astral == null:
		_fail("Astral mancanti nel test cambio forzato.")
		await _cleanup_battle_fixture(fixture)
		return

	var reserve_source := _make_test_astral_instance(_player_astral, 5)
	reserve_source.experience = 29
	_expect(
		roster.capture_astral(reserve_source),
		"Il cambio forzato non prepara la riserva."
	)
	var reserve: AstralInstance = roster.get_astral(1)
	var player_move: AstralMoveDefinition = defeated_astral.get_move(0)
	if reserve == null or player_move == null:
		_fail("Riserva o mossa alleata mancante nel test cambio forzato.")
		await _cleanup_battle_fixture(fixture)
		return
	var reserve_health := reserve.current_health
	var reserve_experience := reserve.experience
	var defeated_experience := defeated_astral.experience
	defeated_astral.current_health = 1

	battle.choose_fight()
	_expect(
		battle.get_state() == BattleController.BattleState.MOVES,
		"Il cambio forzato non raggiunge MOVES."
	)
	battle.choose_move(0)
	var switch_required := await _wait_for_battle_state(
		battle,
		BattleController.BattleState.FORCED_SWITCH
	)
	_expect(switch_required, "Il KO alleato non richiede un cambio forzato.")
	_expect(defeated_astral.is_defeated(), "Il contrattacco non mette KO l'Astral attivo.")
	_expect(_battle_outcome.is_empty(), "Il KO alleato termina la lotta con una riserva valida.")

	if switch_required:
		battle.switch_astral(1)
		var command_restored := await _wait_for_battle_state(
			battle,
			BattleController.BattleState.COMMAND
		)
		_expect(command_restored, "Il cambio forzato non restituisce i comandi.")
		_expect(roster.get_active_astral() == reserve, "Il cambio forzato non aggiorna il lead.")
		_expect(battle.get_player_astral() == reserve, "Battle non usa la riserva forzata.")
		_expect(
			reserve.current_health == reserve_health,
			"Il cambio forzato concede un contrattacco aggiuntivo."
		)
	_expect(
		defeated_astral.experience == defeated_experience
		and reserve.experience == reserve_experience,
		"Il KO alleato o il cambio forzato assegna EXP."
	)
	await _cleanup_battle_fixture(fixture)


func _test_trainers(main: Node) -> void:
	var world_map := main.get_node_or_null("WorldMap") as VerdantValley
	var player := main.get_node_or_null("Player") as CharacterBody3D
	var inventory := main.get_node_or_null("Inventory") as Inventory
	var profile := main.get_node_or_null("PlayerProfile") as PlayerProfile
	var battle_host := main.get_node_or_null("BattleHost") as Node
	var game_ui := main.get_node_or_null("GameUI") as GameUI
	if (
		world_map == null
		or player == null
		or inventory == null
		or profile == null
		or battle_host == null
		or game_ui == null
	):
		_fail("Impossibile verificare gli allenatori nella scena Main.")
		return
	var trainers := world_map.get_trainers()
	_expect(trainers.size() == 4, "La Valle non contiene quattro allenatori.")
	if trainers.size() != 4:
		return
	var expected_lines: Array[String] = [
		"Magliettina di Prada. Leggera.. mica tarocca eh! Originale!",
		"Te dovevi vedere l'altra sera! Avevo fumato ero di un in botta che tu non puoi capire! Uno Svarione! Ma un fuorismo Ganjalf!",
		"Sta zitto marylin Manson.. Sbaraccati fuori dai coglioni e va a mangiare un pipistrello in camera tua!!",
		"Dovevo ascoltare mio nonno, me l'aveva anche detto lui di non andare.. E io invece.. Sempre dietro come un Coglione!",
	]
	var trainer_ids: Dictionary[StringName, bool] = {}
	var trainer_positions: Array[Vector2] = []
	for trainer_index: int in trainers.size():
		var trainer := trainers[trainer_index]
		_expect(trainer is NpcCharacter, "TrainerNpc non deriva da NpcCharacter.")
		_expect(
			trainer.challenge_line == expected_lines[trainer_index],
			"Frase errata per l'allenatore %d." % (trainer_index + 1)
		)
		_expect(
			trainer.astral_definition != null and trainer.astral_level == 5,
			"L'allenatore %d non possiede un Astral di livello 5."
			% (trainer_index + 1)
		)
		_expect(
			not trainer_ids.has(trainer.npc_id),
			"Due allenatori condividono lo stesso npc_id."
		)
		trainer_ids[trainer.npc_id] = true
		var position_2d := Vector2(trainer.position.x, trainer.position.z)
		trainer_positions.append(position_2d)
		_expect(
			absf(trainer.position.x - world_map.get_path_center_x(trainer.position.z))
			<= 1.4,
			"Un allenatore non si trova nella fascia libera del sentiero."
		)
		_expect(
			absf(
				trainer.position.y
				- world_map.get_terrain_height(trainer.position.x, trainer.position.z)
				- 0.08
			) < 0.2,
			"Un allenatore non poggia correttamente sul terreno."
		)
		_expect(
			trainer.get_node_or_null("CollisionShape3D") is CollisionShape3D,
			"Un allenatore non possiede collisione fisica."
		)
	for first_index: int in trainer_positions.size():
		for second_index: int in range(first_index + 1, trainer_positions.size()):
			_expect(
				trainer_positions[first_index].distance_to(
					trainer_positions[second_index]
				) > 6.0,
				"Due allenatori sono stati generati troppo vicini."
			)

	var trainer: TrainerNpc = trainers.front() as TrainerNpc
	trainer.dialogue_duration = 0.05
	trainer.movement_speed = 10.0
	var forward: Vector3 = -trainer.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var challenge_position: Vector3 = trainer.global_position + forward * 3.0
	challenge_position.y = world_map.get_terrain_height(
		challenge_position.x,
		challenge_position.z
	) + 1.15
	player.global_position = challenge_position
	player.velocity = Vector3.ZERO
	await physics_frame
	_expect(
		not trainer.can_see_player(),
		"L'allenatore ingaggia un giocatore immobile."
	)
	player.velocity = forward
	_expect(
		trainer.can_see_player(),
		"Campo visivo o raycast non rileva il giocatore in movimento."
	)
	var previous_fade_duration := float(main.get("battle_fade_duration"))
	main.set("battle_fade_duration", 0.0)
	var initial_florins := profile.florins
	var initial_item_quantity := inventory.get_quantity(trainer.reward_item_id)
	var reward_item := inventory.get_item_definition(trainer.reward_item_id)
	var expected_received_items := 0
	if reward_item != null:
		expected_received_items = mini(
			trainer.reward_item_amount,
			reward_item.max_quantity - initial_item_quantity
		)
	await physics_frame
	_expect(
		player.has_method("has_movement_lock")
		and bool(player.call("has_movement_lock", &"trainer_challenge")),
		"La sfida non blocca immediatamente il movimento del giocatore."
	)
	var dialogue_seen := false
	for _frame_index: int in 180:
		if trainer.challenge_line == game_ui.notification_toast.current_message:
			dialogue_seen = true
		if battle_host.get_child_count() > 0:
			break
		await process_frame
		await physics_frame
	_expect(dialogue_seen, "La frase dell'allenatore non viene mostrata.")
	var battle := await _wait_for_battle(battle_host, 180)
	_expect(battle != null, "La sfida allenatore non avvia BattleController.")
	if battle != null:
		battle.action_delay = 0.0
		var command_ready := await _wait_for_battle_state(
			battle,
			BattleController.BattleState.COMMAND,
			120
		)
		_expect(command_ready, "La battaglia allenatore non raggiunge COMMAND.")
		_expect(battle.is_trainer_battle(), "Battle non riconosce la sfida allenatore.")
		var opponent := battle.get_wild_astral()
		_expect(
			opponent != null
			and opponent.definition == trainer.astral_definition
			and opponent.level == 5,
			"La battaglia usa un Astral allenatore errato."
		)
		_expect(
			battle.capture_button.disabled and battle.flee_button.disabled,
			"Cattura o Fuggi sono disponibili contro un allenatore."
		)
		var roster: AstralRoster = main.get_node("AstralRoster") as AstralRoster
		var roster_count: int = roster.get_astral_count()
		battle.choose_capture()
		battle.choose_flee()
		_expect(
			battle.get_state() == BattleController.BattleState.COMMAND
			and roster.get_astral_count() == roster_count,
			"Una sfida allenatore permette cattura o fuga via API."
		)
		if opponent != null:
			opponent.current_health = 1
		battle.choose_fight()
		battle.choose_move(0)
		var battle_closed := await _wait_for_battle_close(
			battle_host,
			game_ui,
			180
		)
		_expect(battle_closed, "La vittoria non chiude la sfida allenatore.")
	else:
		main.call("_set_player_movement_locked", false)
		game_ui.set_pause_lock(&"battle", false)
	_expect(trainer.defeated, "L'allenatore sconfitto resta sfidabile.")
	_expect(
		profile.florins == initial_florins + trainer.reward_florins,
		"La vittoria non assegna i Fiorini previsti."
	)
	_expect(
		inventory.get_quantity(trainer.reward_item_id)
		== initial_item_quantity + expected_received_items,
		"La vittoria non assegna correttamente l'oggetto premio."
	)
	_expect(
		not bool(player.call("has_movement_lock", &"trainer_challenge")),
		"Il movimento resta bloccato dopo la battaglia."
	)
	var trainer_save_data := world_map.get_trainer_save_data()
	_expect(
		bool(
			(trainer_save_data.get(String(trainer.npc_id), {}) as Dictionary).get(
				"defeated",
				false
			)
		),
		"La sconfitta dell'allenatore non entra nei dati di salvataggio."
	)
	trainer.load_save_data({"defeated": false})
	world_map.load_trainer_save_data(trainer_save_data)
	_expect(trainer.defeated, "Il salvataggio non ripristina l'allenatore sconfitto.")
	main.set("battle_fade_duration", previous_fade_duration)
	player.velocity = Vector3.ZERO
	player.global_position = world_map.get_spawn_position()


func _test_world_npcs(main: Node) -> void:
	var world_map := main.get_node_or_null("WorldMap") as VerdantValley
	var player := main.get_node_or_null("Player") as CharacterBody3D
	var profile := main.get_node_or_null("PlayerProfile") as PlayerProfile
	var inventory := main.get_node_or_null("Inventory") as Inventory
	var game_ui := main.get_node_or_null("GameUI") as GameUI
	if (
		world_map == null
		or player == null
		or profile == null
		or inventory == null
		or game_ui == null
	):
		_fail("Impossibile verificare gli NPC della Valle Verde.")
		return
	var npcs: Array[WorldNpc] = world_map.get_world_npcs()
	_expect(npcs.size() == 2, "La Valle non contiene esattamente due NPC statici.")
	if npcs.size() != 2:
		return
	var first_npc: WorldNpc = npcs[0]
	var gift_npc: WorldNpc = npcs[1]
	_expect(
		first_npc is NpcCharacter,
		"Il primo abitante non usa la gerarchia NPC corretta."
	)
	_expect(
		gift_npc is NpcCharacter,
		"Il secondo abitante non usa la gerarchia NPC corretta."
	)
	_expect(
		first_npc.global_position.distance_to(gift_npc.global_position) < 3.0,
		"I due NPC non sono stati collocati uno accanto all'altro."
	)
	_expect(
		"Ai miei tempi" in first_npc.dialogue_line,
		"Il primo NPC non possiede il dialogo nostalgico richiesto."
	)
	_expect(
		gift_npc.florins_gift == 200,
		"Il secondo NPC non offre 200 Fiorini."
	)
	_expect(
		gift_npc.gift_item_ids
		== [&"pietrafuoco", &"pietragelo", &"pietranatura"],
		"L'NPC benefattore non offre le tre pietre evolutive."
	)
	for npc: WorldNpc in npcs:
		_expect(
			npc.get_node_or_null("CollisionShape3D") is CollisionShape3D,
			"Un NPC non possiede una collisione fisica."
		)
		_expect(
			npc.interaction_area.collision_layer == 4,
			"Un NPC non usa il layer delle interazioni."
		)
		npc.dialogue_duration = 0.05

	var detector := player.get_node_or_null(
		"InteractionDetector"
	) as PlayerInteractionDetector
	_expect(detector != null, "PlayerInteractionDetector mancante per gli NPC.")
	if detector == null:
		return
	var first_interaction_position := first_npc.global_position + Vector3.LEFT * 1.35
	first_interaction_position.y = world_map.get_terrain_height(
		first_interaction_position.x,
		first_interaction_position.z
	) + 1.15
	player.global_position = first_interaction_position
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	_expect(
		detector.current_target == first_npc.interaction_area,
		"Il player non rileva il primo NPC come bersaglio interagibile."
	)
	_expect(detector.try_interact(), "Interazione con il primo NPC non riuscita.")
	_expect(
		player.has_movement_lock(&"npc_dialogue"),
		"Il dialogo NPC non blocca il movimento del giocatore."
	)
	_expect(
		game_ui.notification_toast.current_message == first_npc.dialogue_line,
		"Il riquadro non mostra il dialogo del primo NPC."
	)
	for _frame_index: int in 8:
		await physics_frame
	_expect(
		not player.has_movement_lock(&"npc_dialogue"),
		"Il movimento resta bloccato dopo la fine del dialogo NPC."
	)

	var gift_interaction_position := gift_npc.global_position + Vector3.RIGHT * 1.35
	gift_interaction_position.y = world_map.get_terrain_height(
		gift_interaction_position.x,
		gift_interaction_position.z
	) + 1.15
	player.global_position = gift_interaction_position
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	_expect(
		detector.current_target == gift_npc.interaction_area,
		"Il player non rileva il secondo NPC come bersaglio interagibile."
	)
	var initial_florins := profile.florins
	var initial_stones: Dictionary[StringName, int] = {}
	for stone_id: StringName in gift_npc.gift_item_ids:
		initial_stones[stone_id] = inventory.get_quantity(stone_id)
	_expect(detector.try_interact(), "Interazione con l'NPC benefattore non riuscita.")
	_expect(
		profile.florins == mini(
			initial_florins + 200,
			PlayerProfile.MAX_FLORINS
		),
		"Il dono dell'NPC non rispetta quantità o limite dei Fiorini."
	)
	_expect(
		game_ui.notification_toast.has_pending_message("200 Fiorini"),
		"Il dono di Fiorini non viene comunicato al giocatore."
	)
	for stone_id: StringName in gift_npc.gift_item_ids:
		_expect(
			inventory.get_quantity(stone_id)
			== mini(initial_stones[stone_id] + 1, 10),
			"L'NPC non regala correttamente %s." % stone_id
		)
	var florins_after_gift := profile.florins
	var stones_after_gift: Dictionary[StringName, int] = {}
	for stone_id: StringName in gift_npc.gift_item_ids:
		stones_after_gift[stone_id] = inventory.get_quantity(stone_id)
	for _frame_index: int in 8:
		await physics_frame
	_expect(detector.try_interact(), "Il secondo dialogo con l'NPC non riesce.")
	_expect(
		profile.florins == florins_after_gift,
		"L'NPC regala più volte gli stessi Fiorini."
	)
	for stone_id: StringName in gift_npc.gift_item_ids:
		_expect(
			inventory.get_quantity(stone_id) == stones_after_gift[stone_id],
			"L'NPC regala più volte %s." % stone_id
		)
	for _frame_index: int in 8:
		await physics_frame

	var npc_save_data := world_map.get_npc_save_data()
	gift_npc.load_save_data({"gift_claimed": false})
	_expect(not gift_npc.gift_claimed, "Reset fixture NPC non riuscito.")
	world_map.load_npc_save_data(npc_save_data)
	_expect(
		gift_npc.gift_claimed,
		"Lo stato del dono NPC non viene ripristinato dal salvataggio."
	)
	var capped_profile := PlayerProfile.new()
	capped_profile.florins = PlayerProfile.MAX_FLORINS - 50
	_expect(capped_profile.add_florins(200), "Il profilo rifiuta un dono parziale.")
	_expect(
		capped_profile.florins == PlayerProfile.MAX_FLORINS,
		"Il cap dei Fiorini non è 999999."
	)
	capped_profile.free()
	player.global_position = world_map.get_spawn_position()
	player.velocity = Vector3.ZERO
	await physics_frame


func _test_map_transpositions(main: Node) -> void:
	var player := main.get_node_or_null("Player") as CharacterBody3D
	var detector: PlayerInteractionDetector = null
	if player != null:
		detector = player.get_node_or_null(
			"InteractionDetector"
		) as PlayerInteractionDetector
	var initial_map := main.get_node_or_null("WorldMap") as VerdantValley
	var save_manager := main.get_node_or_null("SaveManager") as SaveManager
	if player == null or detector == null or initial_map == null or save_manager == null:
		_fail("Impossibile preparare il test delle transposizioni.")
		return
	var persistent_nodes: Array[Node] = [
		player,
		main.get_node("Inventory"),
		main.get_node("AstralRoster"),
		main.get_node("Grimoire"),
		main.get_node("PlayerProfile"),
		save_manager,
		main.get_node("GameUI"),
	]
	_expect(
		main.call("get_current_map_id") == &"verdant_forest",
		"La mappa iniziale non espone l'ID verdant_forest."
	)
	var forest_portal := initial_map.get_node_or_null(
		"TransitionPortal"
	) as MapTransitionPortal
	_expect(forest_portal != null, "Portale della foresta mancante.")
	if forest_portal == null:
		return
	_expect(
		forest_portal.destination_map_id == &"large_island",
		"Il portale della foresta non punta alla Grande Isola."
	)
	var previous_fade_duration := float(main.get("battle_fade_duration"))
	main.set("battle_fade_duration", 0.0)
	var forest_interaction_position := forest_portal.global_position + Vector3.FORWARD * 2.0
	forest_interaction_position.y = initial_map.get_terrain_height(
		forest_interaction_position.x,
		forest_interaction_position.z
	) + 1.15
	player.global_position = forest_interaction_position
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	_expect(
		detector.current_target == forest_portal.interaction_area,
		"Il portale della foresta non viene rilevato dall'interazione E."
	)
	_expect(detector.try_interact(), "Interazione col portale della foresta fallita.")
	_expect(
		player.has_movement_lock(&"map_transition"),
		"La transposizione non blocca subito il movimento."
	)
	var reached_island := false
	for _frame_index: int in 240:
		await process_frame
		if (
			main.call("get_current_map_id") == &"large_island"
			and not player.has_movement_lock(&"map_transition")
		):
			reached_island = true
			break
	_expect(reached_island, "Il portale non raggiunge large_island.")
	if not reached_island:
		main.set("battle_fade_duration", previous_fade_duration)
		return
	var island_map := main.get_node_or_null("WorldMap") as LargeIsland
	if island_map != null:
		_expect(
			island_map.map_size.is_equal_approx(Vector2(150.0, 150.0)),
			"La Grande Isola non e stata ridotta del 50% lineare."
		)
		_expect(
			island_map.palm_count == 11
			and island_map.rock_count == 7
			and island_map.driftwood_count == 4,
			"La densita dell'isola ridotta non e stata riequilibrata."
		)
	_expect(island_map != null, "WorldMap non è diventata LargeIsland.")
	_expect(
		main.get("world_map") == island_map,
		"Main conserva un riferimento obsoleto dopo la transposizione."
	)
	_expect(
		save_manager.get_current_map_id() == &"large_island",
		"SaveManager non segue la mappa corrente."
	)
	for persistent_node: Node in persistent_nodes:
		_expect(
			is_instance_valid(persistent_node) and persistent_node.get_parent() == main,
			"La transposizione ha ricreato o rimosso uno stato globale di Main."
		)
	if island_map == null:
		main.set("battle_fade_duration", previous_fade_duration)
		return
	var island_spawn := island_map.get_spawn_position(&"from_verdant_forest")
	_expect(
		Vector2(player.global_position.x, player.global_position.z).distance_to(
			Vector2(island_spawn.x, island_spawn.z)
		) < 0.2,
		"Il player non arriva allo spawn del portale sull'isola."
	)
	var island_portal := island_map.get_node_or_null(
		"TransitionPortal"
	) as MapTransitionPortal
	_expect(island_portal != null, "Portale di ritorno dell'isola mancante.")
	if island_portal == null:
		main.set("battle_fade_duration", previous_fade_duration)
		return
	_expect(
		island_portal.destination_map_id == &"verdant_forest",
		"Il portale dell'isola non punta alla foresta."
	)
	var island_interaction_position := island_portal.global_position + Vector3.BACK * 2.0
	island_interaction_position.y = island_map.get_terrain_height(
		island_interaction_position.x,
		island_interaction_position.z
	) + 1.15
	player.global_position = island_interaction_position
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	_expect(
		detector.current_target == island_portal.interaction_area,
		"Il portale dell'isola non viene rilevato dall'interazione E."
	)
	_expect(detector.try_interact(), "Interazione col portale dell'isola fallita.")
	var returned_to_forest := false
	for _frame_index: int in 240:
		await process_frame
		if (
			main.call("get_current_map_id") == &"verdant_forest"
			and not player.has_movement_lock(&"map_transition")
		):
			returned_to_forest = true
			break
	_expect(returned_to_forest, "Il portale dell'isola non riporta alla foresta.")
	var returned_map := main.get_node_or_null("WorldMap") as VerdantValley
	_expect(returned_map != null, "Il ritorno non ricrea VerdantValley.")
	if returned_map != null:
		_expect(
			returned_map == initial_map,
			"Il ritorno ricrea la foresta e perde il suo stato runtime."
		)
		var returned_trainers := returned_map.get_trainers()
		var returned_npcs := returned_map.get_world_npcs()
		_expect(
			not returned_trainers.is_empty() and returned_trainers[0].defeated,
			"La transposizione resetta gli allenatori sconfitti."
		)
		_expect(
			returned_npcs.size() > 1 and returned_npcs[1].gift_claimed,
			"La transposizione resetta i doni già riscossi dagli NPC."
		)
		var forest_spawn := returned_map.get_spawn_position(&"from_large_island")
		_expect(
			Vector2(player.global_position.x, player.global_position.z).distance_to(
				Vector2(forest_spawn.x, forest_spawn.z)
			) < 0.2,
			"Il player non arriva allo spawn di ritorno nella foresta."
		)
	_expect(not paused, "Il mondo resta in pausa dopo la transposizione.")
	_expect(
		save_manager.get_current_map_id() == &"verdant_forest",
		"SaveManager non torna all'ID della foresta."
	)
	main.set("battle_fade_duration", previous_fade_duration)


func _test_tall_grass_response(main: Node) -> void:
	var test_player := CharacterBody3D.new()
	test_player.name = "TallGrassResponseTestPlayer"
	test_player.collision_layer = 2
	test_player.collision_mask = 0
	var player_collision := CollisionShape3D.new()
	player_collision.name = "CollisionShape3D"
	player_collision.position = Vector3(0.0, 0.9, 0.0)
	var player_shape := CapsuleShape3D.new()
	player_shape.radius = 0.45
	player_shape.height = 1.8
	player_collision.shape = player_shape
	test_player.add_child(player_collision)
	main.add_child(test_player)

	var test_multimesh := MultiMesh.new()
	test_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	test_multimesh.mesh = BoxMesh.new()
	test_multimesh.instance_count = 1
	test_multimesh.set_instance_transform(0, Transform3D.IDENTITY)
	var test_grass := MultiMeshInstance3D.new()
	test_grass.name = "TallGrassResponseTestVisual"
	test_grass.multimesh = test_multimesh
	main.add_child(test_grass)

	var test_zone := TallGrassEncounterZone.new()
	test_zone.name = "TallGrassResponseTestZone"
	test_zone.zone_id = &"tall_grass_response_test"
	test_zone.player = test_player
	test_zone.grass_visual = test_grass
	test_zone.encounter_probability = 1.0
	test_zone.distance_per_encounter_check = 0.25
	test_zone.encounter_cooldown = 0.0
	test_zone.grass_response_radius = 2.0
	test_zone.grass_response_speed = 20.0
	test_zone.maximum_bend_degrees = 15.0
	test_zone.encounter_triggered.connect(_on_test_wild_encounter_requested)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.0, 6.0, 6.0)
	collision.shape = shape
	test_zone.add_child(collision)
	main.add_child(test_zone)

	await physics_frame
	await physics_frame
	var bend_amounts: PackedFloat32Array = test_zone.get("_grass_bend_amounts")
	_expect(
		bend_amounts.size() == 1 and bend_amounts[0] > 0.0,
		"L'erba alta non si piega quando il player è vicino."
	)

	_received_encounter = false
	_received_encounter_zone_id = &""
	_received_encounter_actor = null
	test_zone.call("_update_encounter_check", test_player)
	test_player.global_position = Vector3(0.5, 0.0, 0.0)
	test_zone.call("_physics_process", 1.0 / 60.0)
	_expect(
		_received_encounter,
		"Il movimento nell'erba alta non attiva il controllo incontro."
	)
	_expect(
		_received_encounter_zone_id == test_zone.zone_id,
		"Il controllo incontro emette uno zone_id errato."
	)
	_expect(
		_received_encounter_actor == test_player,
		"Il controllo incontro emette un actor errato."
	)

	test_player.global_position = Vector3(20.0, 20.0, 20.0)
	for _frame_index: int in 12:
		await physics_frame
	bend_amounts = test_zone.get("_grass_bend_amounts")
	_expect(
		bend_amounts.size() == 1 and is_zero_approx(bend_amounts[0]),
		"L'erba alta non torna allo stato iniziale."
	)

	test_zone.queue_free()
	test_grass.queue_free()
	test_player.queue_free()
	await process_frame


func _test_inventory_data() -> void:
	var expected_consumability := {
		"cocco": true,
		"stoffa": false,
		"legno": false,
		"pietra": false,
		"fungo": true,
		"bacca": true,
		"pietrafuoco": true,
		"pietragelo": true,
		"pietranatura": true,
	}
	for item_id: String in expected_consumability:
		var resource_path := "res://data/items/%s.tres" % item_id
		var definition := load(resource_path)
		_expect(definition != null, "Definizione oggetto mancante: %s." % item_id)
		if definition == null:
			continue
		var description := str(definition.get("description")).strip_edges()
		_expect(not description.is_empty(), "Descrizione mancante: %s." % item_id)
		var expected_value: bool = expected_consumability[item_id]
		var actual_value := bool(definition.get("consumable"))
		_expect(actual_value == expected_value, "Consumabilità errata: %s." % item_id)
		if item_id.begins_with("pietra") and item_id != "pietra":
			_expect(
				bool(definition.get("requires_astral_target")),
				"La pietra evolutiva %s non richiede un Astral bersaglio." % item_id
			)


func _test_inputs() -> void:
	_expect(InputMap.has_action("move_forward"), "Input move_forward mancante.")
	_expect(InputMap.has_action("move_backward"), "Input move_backward mancante.")
	_expect(InputMap.has_action("move_left"), "Input move_left mancante.")
	_expect(InputMap.has_action("move_right"), "Input move_right mancante.")
	_expect(InputMap.has_action("jump"), "Input jump mancante.")
	_expect(InputMap.has_action("interact"), "Input interact mancante.")
	_expect(
		_action_uses_physical_key(&"interact", KEY_E),
		"L'interazione con gli NPC non usa il tasto fisico E."
	)
	_expect(InputMap.has_action("toggle_inventory"), "Input inventario mancante.")
	_expect(InputMap.has_action("toggle_menu"), "Input menu pausa mancante.")
	_expect(InputMap.has_action("toggle_squad"), "Input Squadra mancante.")
	_expect(
		_action_uses_physical_key(&"toggle_squad", KEY_I),
		"L'input Squadra non usa il tasto fisico I."
	)
	_expect(InputMap.has_action("toggle_astral_box"), "Input Box Astral mancante.")
	_expect(
		_action_uses_physical_key(&"toggle_astral_box", KEY_B),
		"L'input Box Astral non usa il tasto fisico B."
	)


func _action_uses_physical_key(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.physical_keycode == key:
			return true
	return false


func _make_test_move(
	move_id: StringName,
	display_name: String,
	power: int,
	element_id: StringName,
	damage_class: int = AstralMoveDefinition.DamageClass.PHYSICAL
) -> AstralMoveDefinition:
	var move := AstralMoveDefinition.new()
	move.move_id = move_id
	move.display_name = display_name
	move.description = "Mossa deterministica per lo smoke test."
	move.power = power
	move.element_id = element_id
	move.damage_class = damage_class
	return move


func _make_test_astral_definition(
	astral_id: StringName,
	display_name: String,
	max_health: int,
	attack_power: int,
	speed: int,
	primary_element: StringName,
	secondary_element: StringName,
	experience_yield: int,
	starting_moves: Array[AstralMoveDefinition]
) -> AstralDefinition:
	var definition := AstralDefinition.new()
	definition.astral_id = astral_id
	definition.display_name = display_name
	definition.description = "Astral deterministico per lo smoke test."
	definition.set_base_stats(
		max_health,
		attack_power,
		50,
		attack_power,
		50,
		speed
	)
	definition.primary_element = primary_element
	definition.secondary_element = secondary_element
	definition.experience_yield = experience_yield
	definition.starting_moves.assign(starting_moves)
	return definition


func _make_test_astral_instance(
	definition: AstralDefinition,
	level: int
) -> AstralInstance:
	var instance := AstralInstance.new()
	instance.setup(definition, level)
	return instance


func _send_action(action: StringName) -> void:
	var press_event := InputEventAction.new()
	press_event.action = action
	press_event.pressed = true
	root.push_input(press_event)
	await process_frame
	var release_event := InputEventAction.new()
	release_event.action = action
	release_event.pressed = false
	root.push_input(release_event)
	await process_frame


func _count_enabled_collision_shapes(root_node: Node) -> int:
	var enabled_count := 0
	for candidate: Node in root_node.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		if collision != null and not collision.disabled and collision.shape != null:
			enabled_count += 1
	return enabled_count


func _find_first_node_of_type(root_node: Node, type_name: String) -> Node:
	var nodes := root_node.find_children("*", type_name, true, false)
	if nodes.is_empty():
		return null
	return nodes.front()


func _test_grimoire_profile_inputs() -> void:
	var bindings: Dictionary[StringName, int] = {
		&"toggle_grimoire": KEY_O,
		&"toggle_player_profile": KEY_P,
	}
	for action_name: StringName in bindings:
		_expect(
			InputMap.has_action(action_name),
			"Input action mancante: %s." % action_name
		)
		var expected_key: int = bindings[action_name]
		var has_expected_key := false
		for event: InputEvent in InputMap.action_get_events(action_name):
			var key_event := event as InputEventKey
			if key_event != null and key_event.physical_keycode == expected_key:
				has_expected_key = true
				break
		_expect(
			has_expected_key,
			"%s non usa il tasto fisico richiesto." % action_name
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
