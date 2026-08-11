extends SceneTree

const WATCHDOG_TIMEOUT_SECONDS := 45.0
const BATTLE_SCENE: PackedScene = preload("res://game/battle/battle.tscn")
const INVENTORY_SCENE: PackedScene = preload("res://game/inventory/inventory.tscn")
const ASTRAL_ROSTER_SCENE: PackedScene = preload(
	"res://game/astrals/astral_roster.tscn"
)
const WILD_ASTRAL: AstralDefinition = preload(
	"res://data/astrals/wild_placeholder.tres"
)
const PLAYER_ASTRAL: AstralDefinition = preload(
	"res://data/astrals/player_placeholder.tres"
)

var _failures: Array[String] = []
var _received_encounter: bool = false
var _received_encounter_zone_id: StringName = &""
var _received_encounter_actor: Node3D = null
var _battle_outcome: StringName = &""
var _captured_astral: AstralInstance = null
var _watchdog: Timer = null
var _test_finished: bool = false


func _initialize() -> void:
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
	_test_player_and_camera(main)
	_test_world_map(main)
	await _test_squad_screen(main)
	_test_astral_instance_progression()
	await _test_astral_roster()
	_test_battle_math()
	await _test_encounter_wiring(main)
	await _test_tall_grass_response(main)
	await _test_battle_fight()
	await _test_battle_ko_experience()
	await _test_battle_items()
	await _test_battle_capture()
	await _test_battle_flee()
	await _test_battle_switch()
	await _test_battle_forced_switch()
	_test_inventory_data()
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
	_expect(main.get_node_or_null("GameUI") != null, "GameUI mancante.")
	var sun := _find_first_node_of_type(main, "DirectionalLight3D")
	var world_environment := _find_first_node_of_type(main, "WorldEnvironment")
	_expect(sun != null, "Luce direzionale del sole mancante.")
	_expect(world_environment != null, "WorldEnvironment mancante.")


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
		_expect(starter.get_move_count() == 4, "Lo starter non possiede quattro mosse.")

	await _send_action(&"toggle_squad")
	_expect(squad_screen.visible, "I non apre la schermata Squadra.")
	_expect(paused, "La schermata Squadra non sospende il mondo.")
	_expect(not game_ui.pause_menu.visible, "Squadra lascia aperto il menu pausa.")
	_expect(
		not game_ui.inventory_screen.visible,
		"Squadra lascia aperto l'inventario."
	)
	var astral_list := squad_screen.get_node_or_null("%AstralList") as ItemList
	var level_value := squad_screen.get_node_or_null("%LevelValue") as Label
	var experience_value := squad_screen.get_node_or_null("%ExperienceValue") as Label
	_expect(astral_list != null, "Lista Astral mancante dalla schermata Squadra.")
	_expect(level_value != null, "Livello mancante dalla scheda Astral.")
	_expect(experience_value != null, "EXP mancante dalla scheda Astral.")
	if astral_list != null:
		_expect(
			astral_list.item_count == roster.get_astral_count(),
			"Squadra non mostra tutti gli Astral del roster."
		)
		_expect(
			astral_list.item_count > 0 and "Lv.5" in astral_list.get_item_text(0),
			"La lista Squadra non mostra il livello dello starter."
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
			"EXP 0 / 100" in experience_value.text,
			"La scheda non mostra EXP e soglia del prossimo livello."
		)
	for move_node_name: String in ["MoveOne", "MoveTwo", "MoveThree", "MoveFour"]:
		var move_label := squad_screen.get_node_or_null("%%%s" % move_node_name) as Label
		_expect(move_label != null, "Slot mossa mancante: %s." % move_node_name)
		if move_label != null:
			_expect(
				not "Slot libero" in move_label.text,
				"La scheda non mostra tutte e quattro le mosse dello starter."
			)

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
	_expect(instance.current_health == 40, "AstralInstance non ripristina gli HP.")
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
	_expect(
		threshold_instance.get_experience_to_next_level() == 100,
		"La soglia EXP non e 100."
	)
	_expect(threshold_instance.gain_experience(100) == 1, "100 EXP non danno un livello.")
	_expect(
		threshold_instance.level == 6 and threshold_instance.experience == 0,
		"La soglia EXP non azzera correttamente il progresso."
	)
	_expect(
		threshold_instance.current_health == threshold_health,
		"Guadagnare EXP modifica gli HP."
	)
	var overflow_instance := _make_test_astral_instance(definition, 5)
	_expect(overflow_instance.gain_experience(150) == 1, "L'overflow EXP non sale di livello.")
	_expect(
		overflow_instance.level == 6 and overflow_instance.experience == 50,
		"L'overflow EXP non viene conservato."
	)
	var multi_level_instance := _make_test_astral_instance(definition, 5)
	_expect(
		multi_level_instance.gain_experience(250) == 2,
		"250 EXP non assegnano due livelli."
	)
	_expect(
		multi_level_instance.level == 7 and multi_level_instance.experience == 50,
		"La progressione multi-level produce valori errati."
	)
	var unchanged_level := multi_level_instance.level
	var unchanged_experience := multi_level_instance.experience
	_expect(multi_level_instance.gain_experience(0) == 0, "Zero EXP modifica l'Astral.")
	_expect(
		multi_level_instance.level == unchanged_level
		and multi_level_instance.experience == unchanged_experience,
		"Un guadagno EXP nullo muta livello o esperienza."
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
	_expect(starter.current_health == starter.definition.max_health, "Starter senza HP pieni.")
	_expect(starter.get_move_count() == 4, "Starter senza quattro mosse.")
	var roster_copy := roster.get_astrals()
	roster_copy.clear()
	_expect(roster.get_astral_count() == 1, "get_astrals espone l'array interno.")

	var first_source := _make_test_astral_instance(WILD_ASTRAL, 3)
	first_source.current_health = 11
	first_source.experience = 77
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
			and first_captured.experience == 77,
			"La cattura non copia livello, HP o EXP."
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

	var second_source := _make_test_astral_instance(PLAYER_ASTRAL, 2)
	_expect(roster.capture_astral(second_source), "Seconda cattura valida rifiutata.")
	var second_captured: AstralInstance = roster.get_astral(2)
	_expect(second_captured != null, "Secondo Astral catturato mancante.")
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
	var third_source := _make_test_astral_instance(WILD_ASTRAL, 4)
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
	var nature_attacker := _make_test_astral_instance(nature_definition, 10)
	var fire_defender := _make_test_astral_instance(fire_definition, 5)
	var no_stab_attacker := _make_test_astral_instance(water_definition, 10)
	var lower_level_attacker := _make_test_astral_instance(nature_definition, 5)
	var higher_level_defender := _make_test_astral_instance(fire_definition, 10)
	_expect(
		BattleMath.calculate_damage(nature_attacker, fire_defender, nature_move) == 22,
		"BattleMath non applica correttamente livello, STAB e resistenza natura-fuoco."
	)
	_expect(
		BattleMath.calculate_damage(no_stab_attacker, fire_defender, nature_move) == 14,
		"BattleMath applica STAB a un elemento non posseduto."
	)
	_expect(
		BattleMath.calculate_damage(
			lower_level_attacker,
			higher_level_defender,
			nature_move
		) == 12,
		"BattleMath ignora il rapporto tra livello attaccante e difensore."
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
	var fire_attacker := _make_test_astral_instance(fire_definition, 10)
	var nature_defender := _make_test_astral_instance(nature_definition, 5)
	_expect(
		BattleMath.calculate_damage(fire_attacker, nature_defender, fire_move) == 88,
		"BattleMath non combina STAB e superefficacia."
	)
	var defeated_for_reward := _make_test_astral_instance(fire_definition, 7)
	_expect(
		BattleMath.calculate_experience_reward(defeated_for_reward) == 56,
		"BattleMath calcola una ricompensa EXP errata."
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

	_battle_outcome = &""
	_captured_astral = null
	battle.action_delay = 0.0
	battle.battle_finished.connect(_on_test_battle_finished)
	battle.setup(inventory, roster, WILD_ASTRAL)
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

	var player_move: AstralMoveDefinition = player_astral.get_move(0)
	var wild_move: AstralMoveDefinition = wild_astral.get_move(0)
	if player_move == null or wild_move == null:
		_fail("Mosse mancanti nel test Lotta.")
		await _cleanup_battle_fixture(fixture)
		return
	var initial_player_health := player_astral.current_health
	var initial_wild_health := wild_astral.current_health
	var initial_experience := player_astral.experience
	var expected_player_damage := BattleMath.calculate_damage(
		player_astral,
		wild_astral,
		player_move
	)
	var expected_counterattack := BattleMath.calculate_damage(
		wild_astral,
		player_astral,
		wild_move
	)
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
	player_astral.experience = 95
	var initial_level := player_astral.level
	var initial_health := player_astral.current_health
	wild_astral.current_health = 1
	var reward := BattleMath.calculate_experience_reward(wild_astral)
	var total_experience := player_astral.experience + reward
	var required_experience := player_astral.get_experience_to_next_level()
	var expected_levels := floori(
		float(total_experience) / float(required_experience)
	)
	var expected_experience := total_experience % required_experience

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
		player_astral.level == initial_level + expected_levels,
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
	var battle := fixture.get("battle") as BattleController
	if roster == null or battle == null:
		_fail("Fixture incompleta nel test Cattura.")
		await _cleanup_battle_fixture(fixture)
		return
	var player_astral: AstralInstance = battle.get_player_astral()
	if player_astral == null:
		_fail("Astral alleato mancante nel test Cattura.")
		await _cleanup_battle_fixture(fixture)
		return

	var initial_roster_count := roster.get_astral_count()
	var initial_experience := player_astral.experience
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
		player_astral.experience == initial_experience,
		"Catturare un selvatico assegna EXP senza un KO."
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

	var reserve_source := _make_test_astral_instance(PLAYER_ASTRAL, 3)
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
	var expected_counterattack := BattleMath.calculate_damage(
		wild_astral,
		reserve,
		wild_move
	)

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

	var reserve_source := _make_test_astral_instance(PLAYER_ASTRAL, 3)
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


func _test_inputs() -> void:
	_expect(InputMap.has_action("move_forward"), "Input move_forward mancante.")
	_expect(InputMap.has_action("move_backward"), "Input move_backward mancante.")
	_expect(InputMap.has_action("move_left"), "Input move_left mancante.")
	_expect(InputMap.has_action("move_right"), "Input move_right mancante.")
	_expect(InputMap.has_action("jump"), "Input jump mancante.")
	_expect(InputMap.has_action("interact"), "Input interact mancante.")
	_expect(InputMap.has_action("toggle_inventory"), "Input inventario mancante.")
	_expect(InputMap.has_action("toggle_menu"), "Input menu pausa mancante.")
	_expect(InputMap.has_action("toggle_squad"), "Input Squadra mancante.")
	_expect(
		_action_uses_physical_key(&"toggle_squad", KEY_I),
		"L'input Squadra non usa il tasto fisico I."
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
	element_id: StringName
) -> AstralMoveDefinition:
	var move := AstralMoveDefinition.new()
	move.move_id = move_id
	move.display_name = display_name
	move.description = "Mossa deterministica per lo smoke test."
	move.power = power
	move.element_id = element_id
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
	definition.max_health = max_health
	definition.attack_power = attack_power
	definition.speed = speed
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
