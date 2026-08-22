extends SceneTree

const BATTLE_SCENE := preload("res://game/battle/battle.tscn")
const ROSTER_SCENE := preload("res://game/astrals/astral_roster.tscn")
const MOVE_PROMPT_SCENE := preload(
	"res://game/ui/move_learning/move_learn_prompt.tscn"
)
const PRESENTATION := preload("res://game/astrals/astral_presentation.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_automatic_move_learning()
	await _test_move_replacement_prompt()
	_test_shiny_state()
	await _test_post_battle_healing()
	_finish()


func _test_automatic_move_learning() -> void:
	var venomquill := AstralCatalog.load_definition(&"venomquill")
	var astral := AstralInstance.new()
	astral.setup(venomquill, 11, AstralInstance.Sex.MALE)
	var learned_moves: Array[AstralMoveDefinition] = []
	astral.move_learned.connect(
		func(move: AstralMoveDefinition) -> void: learned_moves.append(move)
	)
	_expect(astral.get_move_count() == 2, "Venomquill livello 11 dovrebbe avere due mosse.")
	_expect(
		astral.gain_experience(astral.get_experience_to_next_level()) == 1,
		"Venomquill non raggiunge il livello 12."
	)
	_expect(
		astral.get_move_count() == 3
		and astral.get_move(2) != null
		and astral.get_move(2).move_id == &"caustic_mist"
		and learned_moves.size() == 1
		and learned_moves.front().move_id == &"caustic_mist",
		"La mossa di livello 12 non viene appresa automaticamente."
	)


func _test_move_replacement_prompt() -> void:
	var pandalith := AstralInstance.new()
	pandalith.setup(
		AstralCatalog.load_definition(&"pandalith"),
		27,
		AstralInstance.Sex.FEMALE
	)
	var original_moves := pandalith.get_moves()
	var requested_moves: Array[AstralMoveDefinition] = []
	pandalith.move_learning_requested.connect(
		func(move: AstralMoveDefinition) -> void: requested_moves.append(move)
	)
	_expect(pandalith.get_move_count() == 4, "Pandalith non parte con quattro mosse.")
	pandalith.gain_experience(pandalith.get_experience_to_next_level())
	_expect(
		requested_moves.size() == 1
		and requested_moves.front().move_id == &"carapace_crash"
		and pandalith.get_pending_moves().size() == 1
		and pandalith.get_moves() == original_moves,
		"La quinta mossa non viene messa in attesa senza sostituzioni automatiche."
	)

	var pending_save := pandalith.get_save_data()
	var restored := AstralInstance.new()
	_expect(
		restored.load_save_data(
			pending_save,
			pandalith.definition,
			AstralCatalog.load_moves()
		)
		and restored.get_pending_moves().size() == 1
		and restored.get_pending_moves().front().move_id == &"carapace_crash",
		"La mossa in attesa non sopravvive al salvataggio."
	)

	var prompt := MOVE_PROMPT_SCENE.instantiate() as MoveLearnPrompt
	root.add_child(prompt)
	prompt.replacement_confirmed.connect(
		func(
			astral: AstralInstance,
			move: AstralMoveDefinition,
			index: int
		) -> void:
			astral.learn_pending_move_replacing(move, index)
	)
	prompt.learning_declined.connect(
		func(astral: AstralInstance, move: AstralMoveDefinition) -> void:
			astral.decline_pending_move(move)
	)
	prompt.enqueue_request(pandalith, requested_moves.front())
	await process_frame
	await process_frame
	_expect(
		prompt.visible
		and prompt.has_active_request()
		and prompt.get_current_move() == requested_moves.front(),
		"Il prompt di sostituzione non appare."
	)

	var first_button := prompt.get_node_or_null("%MoveOneButton") as Button
	var confirmation := prompt.get_node_or_null("%Confirmation") as ConfirmationDialog
	first_button.pressed.emit()
	await process_frame
	_expect(
		confirmation.visible
		and original_moves.front().display_name in confirmation.dialog_text
		and requested_moves.front().display_name in confirmation.dialog_text,
		"La scelta non richiede la conferma della sostituzione."
	)
	confirmation.hide()
	await process_frame
	_expect(
		prompt.has_active_request()
		and pandalith.get_pending_moves().size() == 1,
		"Annullare la conferma applica comunque la sostituzione."
	)
	first_button.pressed.emit()
	await process_frame
	confirmation.confirmed.emit()
	await process_frame
	await process_frame
	_expect(
		pandalith.get_pending_moves().is_empty()
		and pandalith.get_move(0).move_id == &"carapace_crash"
		and not pandalith.get_moves().has(original_moves.front()),
		"Confermare non sostituisce la mossa selezionata."
	)
	prompt.queue_free()
	await process_frame


func _test_shiny_state() -> void:
	var shiny := AstralInstance.new()
	shiny.setup(
		AstralCatalog.load_definition(&"flambore"),
		5,
		AstralInstance.Sex.MALE
	)
	var random := RandomNumberGenerator.new()
	random.seed = 4431
	_expect(
		AstralInstance.SHINY_ODDS == 10000
		and shiny.roll_shiny(random, 1)
		and shiny.is_shiny,
		"Il tiro shiny non rispetta la probabilità configurata."
	)
	_expect(
		PRESENTATION.SHINY_SYMBOL in PRESENTATION.format_identity(shiny),
		"L'identità shiny non mostra la stella dorata."
	)
	var shiny_copy := shiny.duplicate_runtime()
	_expect(shiny_copy.is_shiny, "La cattura/duplicazione perde lo stato shiny.")
	var restored := AstralInstance.new()
	_expect(
		restored.load_save_data(
			shiny.get_save_data(),
			shiny.definition,
			AstralCatalog.load_moves()
		)
		and restored.is_shiny,
		"Il salvataggio perde lo stato shiny."
	)


func _test_post_battle_healing() -> void:
	var roster := ROSTER_SCENE.instantiate() as AstralRoster
	root.add_child(roster)
	await process_frame
	var reserve_source := AstralInstance.new()
	reserve_source.setup(
		AstralCatalog.load_definition(&"flambore"),
		5,
		AstralInstance.Sex.FEMALE
	)
	_expect(roster.capture_astral(reserve_source), "Impossibile aggiungere la riserva al roster.")
	var active := roster.get_active_astral()
	var reserve := roster.get_astral(1)
	active.current_health = 0
	reserve.current_health = 1

	var battle := BATTLE_SCENE.instantiate() as BattleController
	root.add_child(battle)
	var random := RandomNumberGenerator.new()
	random.seed = 991
	battle.setup(
		null,
		roster,
		AstralCatalog.load_definition(&"vorix"),
		5,
		random
	)
	battle.call("_finish_battle", &"defeat", null)
	_expect(
		active.current_health == active.get_max_health()
		and reserve.current_health == reserve.get_max_health(),
		"La fine del combattimento non cura o rianima tutta la squadra."
	)
	battle.queue_free()
	roster.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Battle, moves and shiny smoke test: PASS")
		quit(0)
		return
	print("Battle, moves and shiny smoke test: FAIL (%d errori)" % _failures.size())
	quit(1)
