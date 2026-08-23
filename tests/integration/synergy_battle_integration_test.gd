extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var toxic_definition := _make_definition(
		&"toxic_test",
		AstralSpecies.TOXIC,
		[240, 45, 120, 30, 120, 180],
		_make_move(&"toxic_hit", 12, 0)
	)
	var roster := AstralRoster.new()
	roster.starter = toxic_definition
	roster.starter_level = 20
	roster.call("_ready")
	for _index: int in 3:
		roster.give_astral(toxic_definition, 20)

	var wild_definition := _make_definition(
		&"target_test",
		AstralSpecies.BEAST,
		[255, 20, 255, 20, 255, 10],
		_make_move(&"weak_hit", 1, 0)
	)
	var battle_scene := load("res://game/battle/battle.tscn") as PackedScene
	var battle := battle_scene.instantiate() as BattleController
	root.add_child(battle)
	battle.action_delay = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 9981
	battle.setup(null, roster, wild_definition, 20, rng)
	await battle.begin()
	_expect(
		battle.get_active_synergy_tier(AstralSpecies.TOXIC) == 4,
		"Il BattleController non attiva Tossico 4 con quattro membri."
	)
	for _turn: int in 2:
		if battle.get_state() != BattleController.BattleState.COMMAND:
			break
		battle.choose_fight()
		battle.choose_move(0)
		await _wait_for_state(battle, BattleController.BattleState.COMMAND, 180)
	_expect(
		battle.get_battle_statuses(battle.get_wild_astral()).has("Avvelenato"),
		"Due attacchi Tossico non applicano Veleno nel combattimento reale."
	)
	_expect(
		battle.get_wild_astral().current_health
		< battle.get_wild_astral().get_max_health(),
		"Il Veleno non infligge danno a fine turno."
	)
	battle.call("_finish_battle", &"fled")
	battle.queue_free()
	roster.free()
	await process_frame
	await _test_speed_order()
	await _test_fossil_selection()
	_finish()


func _test_speed_order() -> void:
	var slow_definition := _make_definition(
		&"slow_test",
		AstralSpecies.TERRESTRIAL,
		[5, 5, 5, 5, 5, 5],
		_make_move(&"slow_move", 1, 0)
	)
	var roster := AstralRoster.new()
	roster.starter = slow_definition
	roster.starter_level = 1
	roster.call("_ready")
	var fast_definition := _make_definition(
		&"fast_test",
		AstralSpecies.BEAST,
		[255, 255, 5, 5, 5, 255],
		_make_move(&"finisher", 999, 0)
	)
	var battle_scene := load("res://game/battle/battle.tscn") as PackedScene
	var battle := battle_scene.instantiate() as BattleController
	root.add_child(battle)
	battle.action_delay = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	battle.setup(null, roster, fast_definition, 100, rng)
	await battle.begin()
	battle.choose_fight()
	battle.choose_move(0)
	await _wait_for_state(battle, BattleController.BattleState.FINISHED, 180)
	_expect(
		battle.get_wild_turn_index() == 2
		and battle.get_player_turn_index() == 1,
		"La Speed non permette all'avversario più veloce di agire prima."
	)
	battle.queue_free()
	roster.free()
	await process_frame


func _test_fossil_selection() -> void:
	var fossil_definition := _make_definition(
		&"fossil_test",
		AstralSpecies.FOSSIL,
		[180, 25, 180, 25, 180, 200],
		_make_move(&"fossil_move", 1, 0)
	)
	var roster := AstralRoster.new()
	roster.starter = fossil_definition
	roster.starter_level = 10
	roster.call("_ready")
	for _index: int in 3:
		roster.give_astral(fossil_definition, 10)
	var defeated := roster.get_astral(1)
	defeated.current_health = 0
	var target_definition := _make_definition(
		&"fossil_target",
		AstralSpecies.BEAST,
		[255, 5, 255, 5, 255, 5],
		_make_move(&"fossil_target_move", 1, 0)
	)
	var battle_scene := load("res://game/battle/battle.tscn") as PackedScene
	var battle := battle_scene.instantiate() as BattleController
	root.add_child(battle)
	battle.action_delay = 0.0
	battle.setup(null, roster, target_definition, 10)
	await battle.begin()
	battle.choose_fight()
	battle.choose_move(0)
	await _wait_for_state(battle, BattleController.BattleState.FOSSIL_REVIVE, 180)
	_expect(
		battle.get_state() == BattleController.BattleState.FOSSIL_REVIVE,
		"Fossile 4 non apre la scelta di resurrezione a fine turno."
	)
	var choices := battle.get_node_or_null("%AstralsList") as VBoxContainer
	_expect(choices != null and choices.get_child_count() == 1, "La scelta Fossile non elenca l'alleato KO.")
	if choices != null and choices.get_child_count() > 0:
		(choices.get_child(0) as Button).pressed.emit()
		await _wait_for_state(battle, BattleController.BattleState.COMMAND, 60)
	_expect(
		defeated.current_health == floori(float(defeated.get_max_health()) / 2.0),
		"La selezione Fossile non riporta l'alleato a metà HP."
	)
	battle.call("_finish_battle", &"fled")
	battle.queue_free()
	roster.free()
	await process_frame


func _wait_for_state(
	battle: BattleController,
	target_state: int,
	maximum_frames: int
) -> void:
	for _frame: int in maximum_frames:
		if battle.get_state() == target_state or battle.get_state() == BattleController.BattleState.FINISHED:
			return
		await process_frame


func _make_definition(
	astral_id: StringName,
	species_id: StringName,
	stats: Array,
	move: AstralMoveDefinition
) -> AstralDefinition:
	var definition := AstralDefinition.new()
	definition.astral_id = astral_id
	definition.display_name = String(astral_id)
	definition.set_species_types([species_id])
	definition.set_base_stats(
		int(stats[0]), int(stats[1]), int(stats[2]),
		int(stats[3]), int(stats[4]), int(stats[5])
	)
	definition.starting_moves = [move]
	return definition


func _make_move(
	move_id: StringName,
	power: int,
	cooldown: int
) -> AstralMoveDefinition:
	var move := AstralMoveDefinition.new()
	move.move_id = move_id
	move.display_name = String(move_id)
	move.power = power
	move.cooldown_turns = cooldown
	return move


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Synergy battle integration test: PASS")
		quit(0)
	else:
		print("Synergy battle integration test: FAIL (%d errori)" % _failures.size())
		quit(1)
