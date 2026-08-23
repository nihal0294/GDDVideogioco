extends SceneTree

var _failures: Array[String] = []
var _serial: int = 0
var _owned_rosters: Array[AstralRoster] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_stat_stages_and_survival()
	_test_field_turn_effects()
	_test_cooldown_and_multi_hit()
	_test_combat_statuses_and_defenses()
	_test_inheritance_reflection_and_priority()
	_test_nature_summon_and_fossil_revival()
	_finish()


func _test_stat_stages_and_survival() -> void:
	var fixture := _make_fixture(AstralSpecies.DINOSAUR, 6)
	var runtime := fixture["runtime"] as BattleSynergyRuntime
	var active := fixture["active"] as AstralInstance
	runtime.on_enter_field(active)
	_expect(
		runtime.get_stat_stage(active, BattleSynergyRuntime.STAT_ATTACK) == 1,
		"Dinosauro 2 non applica +1 Atk al primo ingresso."
	)
	active.current_health = 0
	_expect(
		runtime.try_survive_knockout(active) and active.current_health == 1,
		"Dinosauro 6 non impedisce il primo KO."
	)
	_expect(
		not runtime.try_survive_knockout(active),
		"Dinosauro 6 si attiva più di una volta."
	)

	fixture = _make_fixture(AstralSpecies.COSMIC, 6)
	runtime = fixture["runtime"] as BattleSynergyRuntime
	active = fixture["active"] as AstralInstance
	runtime.on_enter_field(active)
	for stat_id: StringName in [
		BattleSynergyRuntime.STAT_ATTACK,
		BattleSynergyRuntime.STAT_PHYSICAL_DEFENSE,
		BattleSynergyRuntime.STAT_MAGIC_ATTACK,
		BattleSynergyRuntime.STAT_MAGIC_DEFENSE,
		BattleSynergyRuntime.STAT_SPEED,
	]:
		_expect(
			runtime.get_stat_stage(active, stat_id) == 1,
			"Cosmico 6 non potenzia tutte le statistiche non-HP."
		)


func _test_field_turn_effects() -> void:
	var fixture := _make_fixture(AstralSpecies.AQUATIC, 6)
	var runtime := fixture["runtime"] as BattleSynergyRuntime
	var active := fixture["active"] as AstralInstance
	var opponent := _make_astral(AstralSpecies.BEAST)
	runtime.on_enter_field(active)
	for _turn: int in 6:
		runtime.end_round(active, opponent)
	_expect(
		runtime.get_stat_stage(active, BattleSynergyRuntime.STAT_SPEED) == 3,
		"Acquatico 6 non raggiunge +3 Spd ogni 2 turni."
	)

	fixture = _make_fixture(AstralSpecies.AMPHIBIAN, 6)
	runtime = fixture["runtime"] as BattleSynergyRuntime
	active = fixture["active"] as AstralInstance
	active.current_health = 1
	runtime.on_enter_field(active)
	for _turn: int in 3:
		runtime.end_round(active, opponent)
	_expect(active.current_health > 1, "Anfibio non rigenera HP al terzo turno.")


func _test_cooldown_and_multi_hit() -> void:
	var fixture := _make_fixture(AstralSpecies.SYNTHETIC, 5)
	var runtime := fixture["runtime"] as BattleSynergyRuntime
	var active := fixture["active"] as AstralInstance
	var move := _make_move(80, 5)
	_expect(
		runtime.consume_cooldown_reduction(active, move) == 1,
		"Sintetico 3 non riduce il primo caricamento."
	)
	_expect(
		runtime.consume_cooldown_reduction(active, move) == 2,
		"Sintetico 5 non riduce ulteriormente il caricamento successivo."
	)

	fixture = _make_fixture(AstralSpecies.MOUSE, 4)
	runtime = fixture["runtime"] as BattleSynergyRuntime
	active = fixture["active"] as AstralInstance
	_expect(
		runtime.get_hit_scales(active) == [1.0, 0.5, 0.25, 0.125],
		"Topo 4 non genera la corretta progressione di quattro colpi."
	)


func _test_combat_statuses_and_defenses() -> void:
	var fixture := _make_fixture(AstralSpecies.TOXIC, 5)
	var runtime := fixture["runtime"] as BattleSynergyRuntime
	var active := fixture["active"] as AstralInstance
	var opponent := _make_astral(AstralSpecies.BEAST)
	var move := _make_move(40, 0)
	runtime.on_hit(active, opponent, move, 10)
	runtime.on_hit(active, opponent, move, 10)
	_expect(
		runtime.get_status_names(opponent).has("Tossina Grave"),
		"Tossico 5 non applica Tossina Grave dopo due Dosi."
	)

	fixture = _make_fixture(AstralSpecies.ETHEREAL, 4)
	runtime = fixture["runtime"] as BattleSynergyRuntime
	active = fixture["active"] as AstralInstance
	opponent = _make_astral(AstralSpecies.BEAST)
	runtime.on_hit(active, opponent, move, 10)
	runtime.on_hit(active, opponent, move, 10)
	_expect(
		runtime.get_status_names(opponent).has("Confuso"),
		"Etereo non applica Confusione dopo due colpi."
	)

	fixture = _make_fixture(AstralSpecies.FAIRY, 3)
	runtime = fixture["runtime"] as BattleSynergyRuntime
	active = fixture["active"] as AstralInstance
	_expect(runtime.should_evade(active), "Fatato 3 non attiva il primo Velo.")
	_expect(not runtime.should_evade(active), "Il Velo Fatato si attiva due volte senza rigenerarsi.")

	fixture = _make_fixture(AstralSpecies.CRYSTAL, 3)
	runtime = fixture["runtime"] as BattleSynergyRuntime
	active = fixture["active"] as AstralInstance
	_expect(
		runtime.get_reflected_damage(active, 80) == 10,
		"Cristallo 3 non riflette 1/8 del danno."
	)


func _test_nature_summon_and_fossil_revival() -> void:
	var fixture := _make_fixture(AstralSpecies.NATURE, 5)
	var runtime := fixture["runtime"] as BattleSynergyRuntime
	var roster := fixture["roster"] as AstralRoster
	_expect(roster.get_astral_count() == 5, "Fixture Natura non valida.")
	runtime.begin_battle()
	_expect(
		roster.get_astral_count() == 6
		and roster.get_astral(5).definition.astral_id == &"nature_manifestation",
		"Natura 5 non evoca la Manifestazione temporanea."
	)
	runtime.finish_battle()
	_expect(roster.get_astral_count() == 5, "L'evocazione Natura persiste oltre la battaglia.")

	fixture = _make_fixture(AstralSpecies.FOSSIL, 4)
	runtime = fixture["runtime"] as BattleSynergyRuntime
	roster = fixture["roster"] as AstralRoster
	var active := fixture["active"] as AstralInstance
	var defeated := roster.get_astral(1)
	defeated.current_health = 0
	runtime.end_round(active, _make_astral(AstralSpecies.BEAST))
	_expect(
		runtime.get_fossil_revival_candidates().has(defeated),
		"Fossile 4 non propone gli alleati KO."
	)
	runtime.revive_with_fossil(defeated)
	_expect(
		defeated.current_health == floori(float(defeated.get_max_health()) / 2.0),
		"Fossile 4 non riporta un alleato KO a metà HP."
	)


func _test_inheritance_reflection_and_priority() -> void:
	var fixture := _make_fixture(AstralSpecies.EPIC, 2)
	var runtime := fixture["runtime"] as BattleSynergyRuntime
	var roster := fixture["roster"] as AstralRoster
	var active := fixture["active"] as AstralInstance
	var move := active.get_move(0)
	runtime.on_enter_field(active)
	runtime.on_move_used(active, move)
	active.current_health = 0
	runtime.on_knockout(_make_astral(AstralSpecies.BEAST), active, move)
	var successor := roster.get_astral(1)
	runtime.on_enter_field(successor)
	_expect(
		runtime.get_inherited_move(successor) == move,
		"Epico 2 non trasferisce l'ultima mossa generica."
	)
	runtime.consume_inherited_move(successor, false)
	_expect(runtime.get_inherited_move(successor) == null, "La mossa Epica non si consuma dopo l'uso.")

	fixture = _make_fixture(AstralSpecies.LUCENT, 5)
	runtime = fixture["runtime"] as BattleSynergyRuntime
	active = fixture["active"] as AstralInstance
	var opponent := _make_astral(AstralSpecies.BEAST)
	runtime.on_enter_field(active)
	_expect(
		runtime.apply_negative_status(opponent, active, BattleSynergyRuntime.STATUS_CONFUSED, 2) == opponent
		and runtime.get_status_names(opponent).has("Confuso"),
		"Lucente 2 non riflette la prima alterazione negativa."
	)
	_expect(
		runtime.apply_stat_change(opponent, active, BattleSynergyRuntime.STAT_ATTACK, -1) == opponent
		and runtime.get_stat_stage(opponent, BattleSynergyRuntime.STAT_ATTACK) == -1,
		"Lucente 5 non riflette la prima riduzione di statistica."
	)

	fixture = _make_fixture(AstralSpecies.FIGHTER, 2)
	runtime = fixture["runtime"] as BattleSynergyRuntime
	active = fixture["active"] as AstralInstance
	opponent = _make_astral(AstralSpecies.BEAST)
	move = active.get_move(0)
	runtime.on_hit(active, opponent, move, 10)
	runtime.on_hit(active, opponent, move, 10)
	_expect(
		runtime.consume_move_priority(active, opponent, move),
		"Combattente 2 non assegna Priorità dopo due mosse fisiche."
	)


func _make_fixture(species_id: StringName, count: int) -> Dictionary:
	var definition := _make_definition(species_id)
	var roster := AstralRoster.new()
	_owned_rosters.append(roster)
	roster.starter = definition
	roster.starter_level = 5
	roster.call("_ready")
	for _index: int in range(1, count):
		roster.give_astral(definition, 5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var runtime := BattleSynergyRuntime.new()
	runtime.setup(roster, rng)
	return {"runtime": runtime, "roster": roster, "active": roster.get_active_astral()}


func _make_astral(species_id: StringName) -> AstralInstance:
	var astral := AstralInstance.new()
	astral.setup(_make_definition(species_id), 5)
	return astral


func _make_definition(species_id: StringName) -> AstralDefinition:
	_serial += 1
	var definition := AstralDefinition.new()
	definition.astral_id = StringName("synergy_test_%d" % _serial)
	definition.display_name = "Test %s" % AstralSpecies.get_display_name(species_id)
	definition.set_species_types([species_id])
	definition.set_base_stats(100, 90, 80, 70, 60, 50)
	definition.starting_moves = [_make_move(40, 0)]
	return definition


func _make_move(power: int, cooldown: int) -> AstralMoveDefinition:
	var move := AstralMoveDefinition.new()
	move.move_id = StringName("test_move_%d_%d" % [power, cooldown])
	move.display_name = "Mossa Test"
	move.power = power
	move.cooldown_turns = cooldown
	return move


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	for roster: AstralRoster in _owned_rosters:
		roster.free()
	_owned_rosters.clear()
	if _failures.is_empty():
		print("Synergy runtime smoke test: PASS")
		quit(0)
	else:
		print("Synergy runtime smoke test: FAIL (%d errori)" % _failures.size())
		quit(1)
