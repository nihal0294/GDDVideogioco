extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "Scena Main non caricabile.")
	if main_scene == null:
		_finish()
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame

	var roster := main.get_node_or_null("AstralRoster") as AstralRoster
	var squad := main.get_node_or_null("GameUI/SquadScreen") as SquadScreen
	_expect(roster != null and squad != null, "Roster o schermata Squadra mancanti.")
	if roster == null or squad == null:
		main.queue_free()
		await process_frame
		_finish()
		return
	var astral := roster.get_active_astral()
	_expect(astral != null, "Astral attivo mancante.")
	if astral == null:
		main.queue_free()
		await process_frame
		_finish()
		return

	_expect(astral.affinity == AstralInstance.DEFAULT_AFFINITY, "Affinità iniziale non neutrale.")
	_expect(
		astral.change_affinity(150) == AstralInstance.MAX_AFFINITY,
		"Il limite positivo dell'affinità non viene applicato."
	)
	_expect(astral.get_affinity_state_name() == "Positiva", "Stato positivo errato.")
	_expect(
		astral.change_affinity(-250) == AstralInstance.MIN_AFFINITY,
		"Il limite negativo dell'affinità non viene applicato."
	)
	_expect(astral.get_affinity_state_name() == "Negativa", "Stato negativo errato.")
	astral.set_affinity(37)
	var runtime_copy := astral.duplicate_runtime()
	_expect(runtime_copy.affinity == 37, "La copia runtime perde l'affinità.")
	var saved_data := astral.get_save_data()
	_expect(int(saved_data.get("affinity", 0)) == 37, "Il salvataggio non contiene l'affinità.")
	var restored := AstralInstance.new()
	_expect(
		restored.load_save_data(
			saved_data,
			astral.definition,
			AstralCatalog.load_moves()
		)
		and restored.affinity == 37,
		"Il round-trip non conserva l'affinità."
	)
	var legacy_data := saved_data.duplicate(true)
	legacy_data.erase("affinity")
	var legacy := AstralInstance.new()
	_expect(
		legacy.load_save_data(
			legacy_data,
			astral.definition,
			AstralCatalog.load_moves()
		)
		and legacy.affinity == AstralInstance.DEFAULT_AFFINITY,
		"Un vecchio salvataggio non riceve affinità neutrale."
	)

	squad.open()
	await process_frame
	var tabs := squad.get_node_or_null("%DetailsTabs") as TabBar
	var affinity_panel := squad.get_node_or_null("%AffinityPanel") as VBoxContainer
	var affinity_value := squad.get_node_or_null("%AffinityValue") as Label
	var affinity_state := squad.get_node_or_null("%AffinityState") as Label
	var identity := squad.get_node_or_null(
		"OuterMargin/Layout/Content/DetailsPanel/DetailsMargin/Details/Identity"
	) as HBoxContainer
	_expect(
		tabs != null
		and tabs.tab_count == 2
		and tabs.get_tab_title(0) == "Statistiche"
		and tabs.get_tab_title(1) == "Affinità",
		"La schermata Squadra non espone le due schede richieste."
	)
	if tabs != null:
		tabs.current_tab = 1
		tabs.tab_changed.emit(1)
	await process_frame
	_expect(
		affinity_panel != null and affinity_panel.visible,
		"La seconda scheda Affinità non diventa visibile."
	)
	_expect(identity != null and not identity.visible, "Le statistiche restano visibili nella scheda Affinità.")
	astral.set_affinity(42)
	await process_frame
	_expect(
		affinity_value != null and affinity_value.text == "+42",
		"La scheda non aggiorna il valore dell'Astral selezionato."
	)
	_expect(
		affinity_state != null and affinity_state.text == "Positiva",
		"La scheda non aggiorna lo stato dell'affinità."
	)
	var battle_scene := load("res://game/battle/battle.tscn") as PackedScene
	var battle := battle_scene.instantiate() as BattleController
	root.add_child(battle)
	battle.setup(
		main.get_node("Inventory") as Inventory,
		roster,
		AstralCatalog.load_definition(&"flambore"),
		5
	)
	var affinity_before_battle := astral.affinity
	battle.call("_finish_battle", &"victory")
	_expect(
		astral.affinity
		== affinity_before_battle
		+ AstralInstance.BATTLE_PARTICIPATION_AFFINITY_GAIN,
		"Concludere un combattimento non aumenta l'affinità del partecipante."
	)
	battle.queue_free()
	await process_frame

	squad.close()
	main.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Affinity smoke test: PASS")
		quit(0)
	else:
		print("Affinity smoke test: FAIL (%d errori)" % _failures.size())
		quit(1)
