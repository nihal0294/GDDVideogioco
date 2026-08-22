extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var venomquill := AstralCatalog.load_definition(&"venomquill")
	_expect(venomquill != null, "Venomquill non è disponibile nel catalogo.")
	if venomquill == null:
		_finish()
		return
	_expect(
		venomquill.rarity == AstralDefinition.Rarity.RARE,
		"Venomquill non ha la rarità assegnata."
	)
	_expect(
		venomquill.get_total_experience_for_level(20) == 9600
		and venomquill.get_experience_for_next_level(20) == 1513,
		"La curva EXP Raro non coincide con la tabella."
	)

	var astral := AstralInstance.new()
	astral.setup(venomquill, 5, AstralInstance.Sex.MALE)
	var previous_stats := astral.get_stat_snapshot(5)
	var level_up_signals: Array[int] = [0]
	astral.leveled_up.connect(
		func(_previous_level: int, _new_level: int) -> void: level_up_signals[0] += 1
	)
	_expect(
		astral.gain_experience(astral.get_experience_to_next_level()) == 1
		and astral.level == 6
		and astral.get_experience_progress_in_level() == 0
		and level_up_signals[0] == 1,
		"Il level-up a soglia esatta non funziona."
	)
	var new_stats := astral.get_stat_snapshot(6)
	_expect(
		int(new_stats.get(&"health", 0)) >= int(previous_stats.get(&"health", 0))
		and int(new_stats.get(&"magic_attack", 0))
		>= int(previous_stats.get(&"magic_attack", 0)),
		"Gli snapshot delle statistiche del level-up sono errati."
	)

	var summary_scene := load(
		"res://game/ui/level_up/level_up_summary.tscn"
	) as PackedScene
	var summary := summary_scene.instantiate() as LevelUpSummary
	root.add_child(summary)
	summary.display_duration = 0.2
	summary.enqueue_summary(astral, 5, 6)
	await process_frame
	await process_frame
	var stats_grid := summary.get_node_or_null("%StatsGrid") as GridContainer
	_expect(
		summary.visible
		and summary.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and stats_grid != null
		and stats_grid.get_child_count() == 28,
		"La tabella non interattiva non mostra intestazioni e sei righe."
	)
	summary.clear_summaries()
	await create_timer(0.22).timeout
	summary.queue_free()
	await process_frame

	var roster_scene := load("res://game/astrals/astral_roster.tscn") as PackedScene
	var roster := roster_scene.instantiate() as AstralRoster
	root.add_child(roster)
	await process_frame
	var squad_scene := load("res://game/ui/squad/squad_screen.tscn") as PackedScene
	var squad := squad_scene.instantiate() as SquadScreen
	root.add_child(squad)
	squad.setup(roster)
	squad.open()
	await process_frame
	await process_frame
	var portrait := squad.get_node_or_null("%PortraitPreview") as SubViewportContainer
	var portrait_viewport := squad.get_node_or_null("%PortraitViewport") as SubViewport
	var portrait_model := squad.get_node_or_null("%PortraitModel") as AstralModel3D
	var rarity_label := squad.get_node_or_null("%RarityValue") as Label
	var active_astral := roster.get_active_astral()
	_expect(
		active_astral != null
		and portrait != null
		and portrait.visible
		and portrait_viewport != null
		and portrait_viewport.render_target_update_mode == SubViewport.UPDATE_ONCE
		and portrait_model != null
		and portrait_model.displayed_definition == active_astral.definition,
		"Squadra non mostra il ritratto statico dell'Astral selezionato."
	)
	_expect(
		active_astral != null
		and rarity_label != null
		and active_astral.definition.get_rarity_name() in rarity_label.text,
		"Squadra non mostra la rarità dell'Astral selezionato."
	)
	squad.queue_free()
	roster.queue_free()
	await process_frame

	var flambore := AstralInstance.new()
	flambore.setup(
		AstralCatalog.load_definition(&"flambore"),
		12,
		AstralInstance.Sex.FEMALE
	)
	var evolution_signals: Array[int] = [0]
	flambore.evolution_available.connect(func() -> void: evolution_signals[0] += 1)
	var evolution_exp := (
		flambore.definition.get_total_experience_for_level(13)
		- flambore.experience
	)
	_expect(
		flambore.gain_experience(evolution_exp) == 1
		and flambore.level == 13
		and flambore.get_available_evolutions().size() == 1
		and evolution_signals[0] == 1,
		"La soglia di Flambore non rende disponibile l'evoluzione."
	)

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Progression UI smoke test: PASS")
		quit(0)
		return
	print("Progression UI smoke test: FAIL (%d errori)" % _failures.size())
	quit(1)
