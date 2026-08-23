class_name BattleController
extends Node

signal battle_finished(outcome: StringName, captured_astral: AstralInstance)
signal fossil_revival_completed

const PRESENTATION := preload("res://game/astrals/astral_presentation.gd")

enum BattleState {
	SETUP,
	INTRO,
	COMMAND,
	MOVES,
	ITEMS,
	ASTRALS,
	FORCED_SWITCH,
	FOSSIL_REVIVE,
	RESOLVING,
	FINISHED,
}

@export_range(0.0, 2.0, 0.05) var action_delay: float = 0.35

@onready var player_visual: AstralModel3D = %PlayerMonster
@onready var wild_visual: AstralModel3D = %WildMonster
@onready var battle_camera: Camera3D = %BattleCamera
@onready var player_name_label: Label = %PlayerName
@onready var wild_name_label: Label = %WildName
@onready var player_health_label: Label = %PlayerHealth
@onready var wild_health_label: Label = %WildHealth
@onready var player_health_bar: ProgressBar = %PlayerHealthBar
@onready var wild_health_bar: ProgressBar = %WildHealthBar
@onready var message_label: Label = %MessageLabel
@onready var command_panel: PanelContainer = %CommandPanel
@onready var move_panel: PanelContainer = %MovePanel
@onready var moves_grid: GridContainer = %MovesGrid
@onready var item_panel: PanelContainer = %ItemPanel
@onready var items_list: VBoxContainer = %ItemsList
@onready var astral_panel: PanelContainer = %AstralPanel
@onready var astrals_list: VBoxContainer = %AstralsList
@onready var fight_button: Button = %FightButton
@onready var items_button: Button = %ItemsButton
@onready var switch_button: Button = %SwitchButton
@onready var capture_button: Button = %CaptureButton
@onready var flee_button: Button = %FleeButton
@onready var move_back_button: Button = %MoveBackButton
@onready var item_back_button: Button = %ItemBackButton
@onready var astral_back_button: Button = %AstralBackButton

var _inventory: Inventory
var _roster: AstralRoster
var _player_astral: AstralInstance
var _wild_astral: AstralInstance
var _state: BattleState = BattleState.SETUP
var _previous_camera: Camera3D
var _wild_move_index: int = 0
var _wild_ko_experience_awarded: bool = false
var _player_turn_index: int = 1
var _wild_turn_index: int = 1
var _move_ready_turns: Dictionary = {}
var _damage_random := RandomNumberGenerator.new()
var _trainer_battle: bool = false
var _opponent_name: String = ""
var _battle_participants: Array[AstralInstance] = []
var _synergies := BattleSynergyRuntime.new()
var _synergy_intro_messages: PackedStringArray = []
var _wild_acted_first_this_round: bool = false
var _pending_action_message: String = ""


func _ready() -> void:
	_previous_camera = get_viewport().get_camera_3d()
	battle_camera.make_current()
	fight_button.pressed.connect(choose_fight)
	items_button.pressed.connect(choose_items)
	switch_button.pressed.connect(choose_switch)
	capture_button.pressed.connect(choose_capture)
	flee_button.pressed.connect(choose_flee)
	move_back_button.pressed.connect(_show_commands)
	item_back_button.pressed.connect(_show_commands)
	astral_back_button.pressed.connect(_show_commands)
	command_panel.hide()
	move_panel.hide()
	item_panel.hide()
	astral_panel.hide()


func _exit_tree() -> void:
	_synergies.finish_battle()
	if is_instance_valid(_previous_camera):
		_previous_camera.make_current()


func setup(
	source_inventory: Inventory,
	source_roster: AstralRoster,
	wild_definition: AstralDefinition,
	wild_level: int = 1,
	encounter_random: RandomNumberGenerator = null
) -> void:
	_inventory = source_inventory
	_roster = source_roster
	_player_astral = (
		_roster.get_active_astral()
		if _roster != null
		else null
	)
	_select_initial_usable_astral()
	_battle_participants.clear()
	_register_battle_participant(_player_astral)

	if wild_definition != null:
		_wild_astral = AstralInstance.new()
		if encounter_random != null:
			_wild_astral.setup_with_random(
				wild_definition,
				maxi(wild_level, 1),
				encounter_random
			)
		else:
			_wild_astral.setup(wild_definition, maxi(wild_level, 1))
		if not _trainer_battle:
			_wild_astral.roll_shiny(encounter_random)

	if (
		_inventory != null
		and not _inventory.item_quantity_changed.is_connected(
			_on_item_quantity_changed
		)
	):
		_inventory.item_quantity_changed.connect(_on_item_quantity_changed)
	_wild_move_index = 0
	_wild_ko_experience_awarded = false
	_player_turn_index = 1
	_wild_turn_index = 1
	_wild_acted_first_this_round = false
	_pending_action_message = ""
	_move_ready_turns.clear()
	if encounter_random != null:
		_damage_random = encounter_random
	else:
		_damage_random = RandomNumberGenerator.new()
		_damage_random.randomize()
	_synergies.setup(_roster, _damage_random)
	_synergy_intro_messages = _synergies.begin_battle()
	_synergy_intro_messages.append_array(
		_synergies.on_enter_field(_player_astral)
	)
	_apply_astral_visual(player_visual, _player_astral)
	_apply_astral_visual(wild_visual, _wild_astral)
	_refresh_status()
	message_label.text = "Preparati allo scontro."


func begin() -> void:
	if (
		_player_astral == null
		or _player_astral.definition == null
		or _player_astral.is_defeated()
	):
		message_label.text = "Nessun Astral alleato disponibile."
		_finish_battle(&"defeat")
		return
	if _wild_astral == null or _wild_astral.definition == null:
		message_label.text = "Nessun Astral selvatico disponibile."
		_finish_battle(&"fled")
		return

	_state = BattleState.INTRO
	message_label.text = (
		"%s manda in campo %s!" % [
			_opponent_name,
			PRESENTATION.format_identity(_wild_astral),
		]
		if _trainer_battle
		else "%s appare dall'erba alta!" % (
			PRESENTATION.format_identity(_wild_astral)
		)
	)
	await _play_entry_animations()
	if _state != BattleState.INTRO:
		return
	if not _synergy_intro_messages.is_empty():
		await _show_synergy_messages(_synergy_intro_messages)
		if _state != BattleState.INTRO:
			return
	await _wait_for_action()
	if _state == BattleState.INTRO:
		_show_commands()


func choose_fight() -> void:
	if _state != BattleState.COMMAND:
		return
	_state = BattleState.MOVES
	command_panel.hide()
	move_panel.show()
	message_label.text = "Scegli una mossa."
	_rebuild_move_buttons()


func choose_move(move_index: int) -> void:
	if _state != BattleState.MOVES or _player_astral == null:
		return
	var move := _get_battle_move(_player_astral, move_index)
	if move == null:
		message_label.text = "Questa mossa non e disponibile."
		_rebuild_move_buttons()
		return
	var cooldown_remaining := get_player_move_cooldown_remaining(move_index)
	if not _synergies.can_use_move(_player_astral, move, cooldown_remaining):
		message_label.text = _synergies.get_move_block_reason(
			_player_astral,
			move,
			cooldown_remaining
		)
		_rebuild_move_buttons()
		return
	_synergies.consume_cooldown_bypass(_player_astral, cooldown_remaining)
	var preparation := _synergies.prepare_move(_player_astral, move)
	move = preparation.get("move") as AstralMoveDefinition
	if (
		bool(preparation.get("failed", false))
		and _synergies.should_retry_failure(_player_astral)
	):
		preparation["failed"] = false
		preparation["self_damage"] = 0
		preparation["message"] = "%s ritenta l'evento grazie alla sinergia Mitico." % _player_astral.definition.display_name
	_pending_action_message = (
		String(preparation.get("message", ""))
		if not bool(preparation.get("failed", false))
		else ""
	)
	var resolved_index := _get_battle_move_index(_player_astral, move)
	var has_priority := _synergies.consume_move_priority(
		_player_astral,
		_wild_astral,
		move
	)
	_state = BattleState.RESOLVING
	move_panel.hide()
	_set_command_buttons_disabled(true)
	var player_acts_first := (
		has_priority
		or _synergies.must_act_last(_wild_astral)
		or _synergies.get_effective_speed(_player_astral)
		>= _synergies.get_effective_speed(_wild_astral)
	)
	_synergies.record_acted_first(_player_astral, player_acts_first)
	if player_acts_first:
		if bool(preparation.get("failed", false)):
			_resolve_failed_player_move(
				preparation,
				resolved_index if resolved_index >= 0 else move_index
			)
		else:
			_resolve_player_move(move)
	else:
		_resolve_wild_first_then_player(
			move,
			preparation if bool(preparation.get("failed", false)) else {},
			resolved_index if resolved_index >= 0 else move_index
		)


func use_move(move_index: int) -> void:
	choose_move(move_index)


func choose_items() -> void:
	if _state != BattleState.COMMAND:
		return
	_state = BattleState.ITEMS
	command_panel.hide()
	item_panel.show()
	message_label.text = "Scegli un consumabile."
	_rebuild_item_buttons()


func choose_switch() -> void:
	if _state != BattleState.COMMAND:
		return
	_show_astral_choices(false)


func choose_capture() -> void:
	if _state != BattleState.COMMAND:
		return
	if _trainer_battle:
		message_label.text = "Non puoi catturare l'Astral di un allenatore."
		return
	if _inventory == null or _inventory.get_quantity(&"runa_base") <= 0:
		message_label.text = "Ti serve una Runa Base per tentare il soulbind."
		return
	_resolve_capture()


func choose_flee() -> void:
	if _state != BattleState.COMMAND:
		return
	if _trainer_battle:
		message_label.text = "Non puoi fuggire da una sfida tra allenatori."
		return
	message_label.text = "Ti allontani dal combattimento."
	_finish_battle(&"fled")


func use_item(item_id: StringName) -> void:
	if _state != BattleState.ITEMS or _inventory == null:
		return
	var definition: ItemDefinition = null
	definition = _inventory.get_item_definition(item_id)
	if (
		definition == null
		or not definition.consumable
		or _inventory.get_quantity(item_id) <= 0
	):
		message_label.text = "Questo oggetto non puo essere usato."
		_rebuild_item_buttons()
		return
	if not _inventory.consume_item(item_id):
		message_label.text = "Non e stato possibile usare l'oggetto."
		_rebuild_item_buttons()
		return

	_commit_player_turn()
	_state = BattleState.RESOLVING
	item_panel.hide()
	message_label.text = "Hai usato %s." % definition.display_name
	await _wait_for_action()
	if _state != BattleState.RESOLVING:
		return
	await _resolve_wild_counterattack()


func switch_astral(roster_index: int) -> void:
	if (
		_state != BattleState.ASTRALS
		and _state != BattleState.FORCED_SWITCH
	):
		return
	if _roster == null:
		return
	var was_forced := _state == BattleState.FORCED_SWITCH
	var astrals := _roster.get_astrals()
	if roster_index < 0 or roster_index >= astrals.size():
		return
	var candidate: AstralInstance = null
	candidate = astrals[roster_index]
	if (
		candidate == null
		or candidate == _player_astral
		or candidate.definition == null
		or candidate.is_defeated()
	):
		message_label.text = "Questo Astral non puo entrare in campo."
		_rebuild_astral_buttons(was_forced)
		return
	var previous_astral := _player_astral
	if not _roster.set_active_astral(roster_index):
		message_label.text = "Non e stato possibile cambiare Astral."
		_rebuild_astral_buttons(was_forced)
		return

	if not was_forced:
		_commit_player_turn()
	_synergies.on_exit_field(previous_astral)
	_player_astral = _roster.get_active_astral()
	_register_battle_participant(_player_astral)
	_state = BattleState.RESOLVING
	astral_panel.hide()
	_apply_astral_visual(player_visual, _player_astral)
	_refresh_status()
	message_label.text = "Entra in campo %s!" % (
		_player_astral.definition.display_name
	)
	var entry_messages := _synergies.on_enter_field(_player_astral)
	if not entry_messages.is_empty():
		message_label.text += " " + " ".join(entry_messages)
	await _wait_for_action()
	if _state != BattleState.RESOLVING:
		return
	if was_forced:
		_show_commands()
		return
	await _resolve_wild_counterattack()


func get_player_astral() -> AstralInstance:
	return _player_astral


func get_wild_astral() -> AstralInstance:
	return _wild_astral


func get_state() -> BattleState:
	return _state


func configure_trainer_battle(trainer_name: String) -> void:
	_trainer_battle = true
	_opponent_name = trainer_name.strip_edges()
	if _opponent_name.is_empty():
		_opponent_name = "Allenatore"
	if is_node_ready():
		_set_command_buttons_disabled(_state != BattleState.COMMAND)
		capture_button.tooltip_text = "Gli Astral degli allenatori non possono essere catturati."
		flee_button.tooltip_text = "Una sfida tra allenatori deve essere conclusa."


func is_trainer_battle() -> bool:
	return _trainer_battle


func get_player_turn_index() -> int:
	return _player_turn_index


func get_wild_turn_index() -> int:
	return _wild_turn_index


func get_active_synergy_tier(species_id: StringName) -> int:
	return _synergies.get_tier(species_id)


func get_battle_stat_stage(
	astral: AstralInstance,
	stat_id: StringName
) -> int:
	return _synergies.get_stat_stage(astral, stat_id)


func get_battle_statuses(astral: AstralInstance) -> PackedStringArray:
	return _synergies.get_status_names(astral)


func get_player_move_cooldown_remaining(move_index: int) -> int:
	return _get_move_cooldown_remaining(
		_player_astral,
		move_index,
		_player_turn_index
	)


func get_wild_move_cooldown_remaining(move_index: int) -> int:
	return _get_move_cooldown_remaining(
		_wild_astral,
		move_index,
		_wild_turn_index
	)


func set_damage_random_seed(seed_value: int) -> void:
	_damage_random.seed = seed_value


func _select_initial_usable_astral() -> void:
	if (
		_roster == null
		or _player_astral == null
		or not _player_astral.is_defeated()
	):
		return
	var usable_indices := _roster.get_usable_astral_indices(true)
	if usable_indices.is_empty():
		return
	if _roster.set_active_astral(usable_indices.front()):
		_player_astral = _roster.get_active_astral()


func _resolve_player_move(move: AstralMoveDefinition) -> void:
	if (
		_state != BattleState.RESOLVING
		or _player_astral == null
		or _wild_astral == null
	):
		return
	var move_index := _get_battle_move_index(_player_astral, move)
	if move_index >= 0:
		_commit_player_move(move_index)
	await _play_attack_animation(player_visual, wild_visual)
	if _state != BattleState.RESOLVING:
		return
	var resolution := _apply_damage_hits(
		_player_astral,
		_wild_astral,
		move
	)
	var applied_damage := int(resolution.get("damage", 0))
	message_label.text = "%s usa %s e infligge %d danni." % [
		_player_astral.definition.display_name,
		move.display_name,
		applied_damage,
	]
	if bool(resolution.get("critical", false)):
		message_label.text += " Brutto colpo!"
	if not _pending_action_message.is_empty():
		message_label.text += " " + _pending_action_message
		_pending_action_message = ""
	_append_resolution_messages(resolution)
	var recoil := _synergies.on_move_used(_player_astral, move)
	if recoil > 0:
		var applied_recoil := _player_astral.take_damage(recoil)
		message_label.text += " Il Surriscaldamento infligge %d danni a %s." % [applied_recoil, _player_astral.definition.display_name]
		if _synergies.try_survive_knockout(_player_astral):
			message_label.text += " La sinergia Dinosauro lo mantiene a 1 HP."
	if not _wild_astral.is_defeated():
		var bonus_move := resolution.get("bonus_move") as AstralMoveDefinition
		if bonus_move != null:
			await _play_attack_animation(player_visual, wild_visual)
			var bonus_resolution := _apply_damage_hits(_player_astral, _wild_astral, bonus_move, 0.5, false)
			message_label.text += " Combattente usa %s e infligge %d danni aggiuntivi." % [bonus_move.display_name, int(bonus_resolution.get("damage", 0))]
			_append_resolution_messages(bonus_resolution)
	if not _wild_astral.is_defeated() and bool(resolution.get("repeat_move", false)):
		await _play_attack_animation(player_visual, wild_visual)
		var repeat_resolution := _apply_damage_hits(_player_astral, _wild_astral, move, 1.0, false)
		message_label.text += " Drago ripete %s e infligge %d danni." % [move.display_name, int(repeat_resolution.get("damage", 0))]
		_append_resolution_messages(repeat_resolution)
	_refresh_status()
	await _wait_for_action()
	if _state != BattleState.RESOLVING:
		return
	if _wild_astral.is_defeated():
		var knockout_messages := _synergies.on_knockout(_player_astral, _wild_astral, move)
		if not knockout_messages.is_empty():
			await _show_synergy_messages(knockout_messages)
		_synergies.consume_inherited_move(_player_astral, true)
		await _resolve_wild_ko()
		return
	_synergies.consume_inherited_move(_player_astral, false)
	if _player_astral.is_defeated():
		if _wild_acted_first_this_round:
			_wild_acted_first_this_round = false
			await _complete_round()
		await _handle_player_knockout()
		return
	if _wild_acted_first_this_round:
		_wild_acted_first_this_round = false
		await _complete_round()
		if _wild_astral.is_defeated():
			_synergies.on_knockout(_player_astral, _wild_astral, move)
			await _resolve_wild_ko()
		elif _player_astral.is_defeated():
			await _handle_player_knockout()
		else:
			_show_commands()
		return
	await _resolve_wild_counterattack()


func _resolve_failed_player_move(
	preparation: Dictionary,
	move_index: int
) -> void:
	var move := preparation.get("move") as AstralMoveDefinition
	if move_index >= 0:
		_commit_player_move(move_index)
	var self_damage := int(preparation.get("self_damage", 0))
	if self_damage > 0:
		_player_astral.take_damage(self_damage)
	if move != null:
		var recoil := _synergies.on_move_used(_player_astral, move)
		if recoil > 0:
			_player_astral.take_damage(recoil)
	message_label.text = String(preparation.get("message", "La mossa fallisce."))
	_pending_action_message = ""
	if _synergies.try_survive_knockout(_player_astral):
		message_label.text += " La sinergia Dinosauro lo mantiene a 1 HP."
	_refresh_status()
	await _wait_for_action()
	if _player_astral.is_defeated():
		if _wild_acted_first_this_round:
			_wild_acted_first_this_round = false
			await _complete_round()
		await _handle_player_knockout()
		return
	if _wild_acted_first_this_round:
		_wild_acted_first_this_round = false
		await _complete_round()
		if _wild_astral.is_defeated():
			await _resolve_wild_ko()
		elif _player_astral.is_defeated():
			await _handle_player_knockout()
		else:
			_show_commands()
		return
	await _resolve_wild_counterattack()


func _resolve_wild_ko() -> void:
	if _state != BattleState.RESOLVING:
		return
	var reward := 0
	var levels_gained := 0
	if not _wild_ko_experience_awarded:
		_wild_ko_experience_awarded = true
		reward = BattleMath.calculate_experience_reward(_wild_astral)
		levels_gained = _player_astral.gain_experience(reward)
	_refresh_status()
	if levels_gained > 0:
		message_label.text = (
			"%s e stato sconfitto. %s ottiene %d EXP e raggiunge il livello %d!"
			% [
				_wild_astral.definition.display_name,
				_player_astral.definition.display_name,
				reward,
				_player_astral.level,
			]
		)
	else:
		message_label.text = "%s e stato sconfitto. %s ottiene %d EXP." % [
			_wild_astral.definition.display_name,
			_player_astral.definition.display_name,
			reward,
		]
	await _wait_for_action()
	if _state == BattleState.RESOLVING:
		_finish_battle(&"victory")


func _resolve_wild_first_then_player(
	player_move: AstralMoveDefinition,
	failed_preparation: Dictionary = {},
	player_move_index: int = -1
) -> void:
	if _state != BattleState.RESOLVING:
		return
	var wild_move_index := _get_next_wild_move_index()
	var wild_move := _get_battle_move(_wild_astral, wild_move_index)
	if wild_move == null:
		_commit_wild_turn()
		await _resolve_pending_player_action(
			player_move,
			failed_preparation,
			player_move_index
		)
		return
	var preparation := _synergies.prepare_move(_wild_astral, wild_move)
	wild_move = preparation.get("move") as AstralMoveDefinition
	var resolved_index := _get_battle_move_index(_wild_astral, wild_move)
	_commit_wild_move(
		resolved_index if resolved_index >= 0 else wild_move_index
	)
	if bool(preparation.get("failed", false)):
		var self_damage := int(preparation.get("self_damage", 0))
		if self_damage > 0:
			_wild_astral.take_damage(self_damage)
		var failed_recoil := _synergies.on_move_used(_wild_astral, wild_move)
		if failed_recoil > 0:
			_wild_astral.take_damage(failed_recoil)
		message_label.text = String(
			preparation.get("message", "La mossa avversaria fallisce.")
		)
		_refresh_status()
		await _wait_for_action()
		if _wild_astral.is_defeated():
			_synergies.on_knockout(_player_astral, _wild_astral, wild_move)
			await _resolve_wild_ko()
			return
		await _resolve_pending_player_action(
			player_move,
			failed_preparation,
			player_move_index
		)
		return
	await _play_attack_animation(wild_visual, player_visual)
	if _state != BattleState.RESOLVING:
		return
	var resolution := _apply_damage_hits(
		_wild_astral,
		_player_astral,
		wild_move
	)
	if bool(resolution.get("evaded", false)):
		message_label.text = "%s usa %s, ma il Velo di %s annulla l'attacco." % [
			_wild_astral.definition.display_name,
			wild_move.display_name,
			_player_astral.definition.display_name,
		]
	else:
		message_label.text = "%s agisce per primo con %s e infligge %d danni." % [
			_wild_astral.definition.display_name,
			wild_move.display_name,
			int(resolution.get("damage", 0)),
		]
	_append_resolution_messages(resolution)
	var recoil := _synergies.on_move_used(_wild_astral, wild_move)
	if recoil > 0:
		_wild_astral.take_damage(recoil)
	_refresh_status()
	await _wait_for_action()
	if _wild_astral.is_defeated():
		_synergies.on_knockout(_player_astral, _wild_astral, wild_move)
		await _resolve_wild_ko()
		return
	if _player_astral.is_defeated():
		_synergies.on_knockout(_wild_astral, _player_astral, wild_move)
		await _complete_round()
		await _handle_player_knockout()
		return
	await _resolve_pending_player_action(
		player_move,
		failed_preparation,
		player_move_index
	)


func _resolve_pending_player_action(
	player_move: AstralMoveDefinition,
	failed_preparation: Dictionary,
	player_move_index: int
) -> void:
	_wild_acted_first_this_round = true
	if failed_preparation.is_empty():
		await _resolve_player_move(player_move)
	else:
		await _resolve_failed_player_move(
			failed_preparation,
			player_move_index
		)


func _resolve_wild_counterattack() -> void:
	if _state != BattleState.RESOLVING:
		return
	var move_index := _get_next_wild_move_index()
	var move := _get_battle_move(_wild_astral, move_index)
	if move == null:
		_commit_wild_turn()
		message_label.text = "%s attende che le sue mosse si ricarichino." % (
			_wild_astral.definition.display_name
		)
		await _wait_for_action()
		await _complete_round()
		if _wild_astral.is_defeated():
			await _resolve_wild_ko()
		elif _player_astral.is_defeated():
			await _handle_player_knockout()
		elif _state == BattleState.RESOLVING:
			_show_commands()
		return

	var preparation := _synergies.prepare_move(_wild_astral, move)
	move = preparation.get("move") as AstralMoveDefinition
	var resolved_index := _get_battle_move_index(_wild_astral, move)
	_commit_wild_move(resolved_index if resolved_index >= 0 else move_index)
	if bool(preparation.get("failed", false)):
		var self_damage := int(preparation.get("self_damage", 0))
		if self_damage > 0:
			_wild_astral.take_damage(self_damage)
		var failed_recoil := _synergies.on_move_used(_wild_astral, move)
		if failed_recoil > 0:
			_wild_astral.take_damage(failed_recoil)
		message_label.text = String(preparation.get("message", "La mossa avversaria fallisce."))
		_refresh_status()
		await _wait_for_action()
		await _complete_round()
		if _wild_astral.is_defeated():
			_synergies.on_knockout(_player_astral, _wild_astral, move)
			await _resolve_wild_ko()
		elif _player_astral.is_defeated():
			await _handle_player_knockout()
		else:
			_show_commands()
		return
	await _play_attack_animation(wild_visual, player_visual)
	if _state != BattleState.RESOLVING:
		return
	var resolution := _apply_damage_hits(_wild_astral, _player_astral, move)
	if bool(resolution.get("evaded", false)):
		message_label.text = "%s usa %s, ma il Velo di %s annulla l'attacco." % [_wild_astral.definition.display_name, move.display_name, _player_astral.definition.display_name]
	else:
		message_label.text = "%s usa %s e infligge %d danni." % [_wild_astral.definition.display_name, move.display_name, int(resolution.get("damage", 0))]
		if bool(resolution.get("critical", false)):
			message_label.text += " Brutto colpo!"
	_append_resolution_messages(resolution)
	var recoil := _synergies.on_move_used(_wild_astral, move)
	if recoil > 0:
		_wild_astral.take_damage(recoil)
	_refresh_status()
	await _wait_for_action()
	if _state != BattleState.RESOLVING:
		return
	await _complete_round()
	if _wild_astral.is_defeated():
		_synergies.on_knockout(_player_astral, _wild_astral, move)
		await _resolve_wild_ko()
		return
	if _player_astral.is_defeated():
		_synergies.on_knockout(_wild_astral, _player_astral, move)
		await _handle_player_knockout()
		return
	_show_commands()


func _get_next_wild_move_index() -> int:
	if _wild_astral == null:
		return -1
	var moves := _wild_astral.get_moves()
	if moves.is_empty():
		return -1
	for offset: int in moves.size():
		var candidate_index := (_wild_move_index + offset) % moves.size()
		var candidate: AstralMoveDefinition = null
		candidate = moves[candidate_index]
		if candidate == null:
			continue
		var cooldown_remaining := get_wild_move_cooldown_remaining(candidate_index)
		if not _synergies.can_use_move(_wild_astral, candidate, cooldown_remaining):
			continue
		_wild_move_index = (candidate_index + 1) % moves.size()
		return candidate_index
	return -1


func _apply_damage_hits(
	attacker: AstralInstance,
	defender: AstralInstance,
	move: AstralMoveDefinition,
	power_scale: float = 1.0,
	track_followups: bool = true
) -> Dictionary:
	var result := {
		"damage": 0,
		"critical": false,
		"evaded": false,
		"messages": PackedStringArray(),
		"bonus_move": null,
		"repeat_move": false,
	}
	if attacker == null or defender == null or move == null:
		return result
	if move.power > 0 and _synergies.should_evade(defender):
		result["evaded"] = true
		return result
	var modifiers := _synergies.get_damage_modifiers(attacker, defender, move)
	modifiers.modifier_3 *= maxf(power_scale, 0.0)
	var damage_result := BattleMath.roll_damage(
		attacker,
		defender,
		move,
		_damage_random,
		modifiers
	)
	if _synergies.should_reroll_critical(defender, damage_result.is_critical_hit):
		damage_result = BattleMath.roll_damage(
			attacker,
			defender,
			move,
			_damage_random,
			modifiers
		)
		(result["messages"] as PackedStringArray).append(
			"La sinergia Mitico ritira il brutto colpo."
		)
	result["critical"] = damage_result.is_critical_hit
	var total_damage := 0
	var messages := result["messages"] as PackedStringArray
	for hit_scale: float in _synergies.get_hit_scales(attacker):
		if defender.is_defeated() or attacker.is_defeated():
			break
		var scaled_damage := 0
		if damage_result.damage > 0:
			scaled_damage = maxi(1, floori(float(damage_result.damage) * hit_scale))
		var applied_damage := defender.take_damage(scaled_damage)
		total_damage += applied_damage
		if applied_damage > 0:
			var hit_result := _synergies.on_hit(attacker, defender, move, applied_damage)
			messages.append_array(hit_result.get("messages", PackedStringArray()) as PackedStringArray)
			if track_followups:
				if hit_result.get("bonus_move") is AstralMoveDefinition:
					result["bonus_move"] = hit_result.get("bonus_move")
				if bool(hit_result.get("repeat_move", false)):
					result["repeat_move"] = true
		if defender.is_defeated() and _synergies.try_survive_knockout(defender):
			messages.append("La sinergia Dinosauro mantiene %s a 1 HP." % defender.definition.display_name)
	var element_multiplier := BattleMath.get_element_multiplier(
		move.element_id,
		defender.definition
	)
	var neutral_damage := total_damage
	if element_multiplier > 0.0:
		neutral_damage = maxi(1, roundi(float(total_damage) / element_multiplier))
	var reflected := _synergies.get_reflected_damage(
		defender,
		total_damage,
		neutral_damage,
		element_multiplier > 1.0
	)
	if reflected > 0:
		var applied_reflection := attacker.take_damage(reflected)
		messages.append("Cristallo riflette %d danni a %s." % [applied_reflection, attacker.definition.display_name])
	result["damage"] = total_damage
	result["messages"] = messages
	return result


func _append_resolution_messages(resolution: Dictionary) -> void:
	var messages := resolution.get("messages", PackedStringArray()) as PackedStringArray
	if not messages.is_empty():
		message_label.text += " " + " ".join(messages)


func _complete_round() -> void:
	if _state != BattleState.RESOLVING:
		return
	var messages := _synergies.end_round(_player_astral, _wild_astral)
	_refresh_status()
	if not messages.is_empty():
		await _show_synergy_messages(messages)
	var revival_candidates := _synergies.get_fossil_revival_candidates()
	if not revival_candidates.is_empty():
		_show_fossil_revival_choices(revival_candidates)
		await fossil_revival_completed


func _show_fossil_revival_choices(
	candidates: Array[AstralInstance]
) -> void:
	_state = BattleState.FOSSIL_REVIVE
	command_panel.hide()
	move_panel.hide()
	item_panel.hide()
	astral_panel.show()
	astral_back_button.hide()
	_clear_dynamic_children(astrals_list)
	message_label.text = "Scegli l'Astral da riportare in vita con la sinergia Fossile."
	var first_button: Button = null
	for astral: AstralInstance in candidates:
		if astral == null or astral.definition == null:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 46.0)
		button.text = "%s  Lv.%d  [KO → 1/2 HP]" % [
			PRESENTATION.format_identity(astral),
			astral.level,
		]
		button.pressed.connect(_select_fossil_revival.bind(astral))
		astrals_list.add_child(button)
		if first_button == null:
			first_button = button
	if first_button != null:
		first_button.grab_focus()


func _select_fossil_revival(astral: AstralInstance) -> void:
	if _state != BattleState.FOSSIL_REVIVE:
		return
	if not _synergies.revive_with_fossil(astral):
		return
	astral_panel.hide()
	_state = BattleState.RESOLVING
	message_label.text = "La sinergia Fossile riporta in vita %s con %d HP." % [
		astral.definition.display_name,
		astral.current_health,
	]
	_refresh_status()
	fossil_revival_completed.emit()


func _handle_player_knockout() -> void:
	if _player_astral == null or not _player_astral.is_defeated():
		if _state == BattleState.RESOLVING:
			_show_commands()
		return
	message_label.text = "%s non puo piu combattere." % _player_astral.definition.display_name
	await _wait_for_action()
	if _state != BattleState.RESOLVING:
		return
	if _roster != null and _roster.has_usable_astral(true):
		_show_astral_choices(true)
	else:
		_finish_battle(&"defeat")


func _show_synergy_messages(messages: PackedStringArray) -> void:
	if messages.is_empty():
		return
	message_label.text = " ".join(messages)
	_refresh_status()
	await _wait_for_action()


func _get_battle_move(
	astral: AstralInstance,
	move_index: int
) -> AstralMoveDefinition:
	if astral == null or move_index < 0:
		return null
	var move := astral.get_move(move_index)
	if move != null:
		return move
	if astral == _player_astral and move_index == astral.get_move_count():
		return _synergies.get_inherited_move(astral)
	return null


func _get_battle_move_index(
	astral: AstralInstance,
	move: AstralMoveDefinition
) -> int:
	if astral == null or move == null:
		return -1
	for move_index: int in astral.get_move_count():
		if astral.get_move(move_index) == move:
			return move_index
	if astral == _player_astral and _synergies.get_inherited_move(astral) == move:
		return astral.get_move_count()
	return -1


func _resolve_capture() -> void:
	if _inventory == null or _inventory.spend_item(&"runa_base", 1) != 1:
		message_label.text = "Non hai una Runa Base disponibile."
		_show_commands()
		return
	_state = BattleState.RESOLVING
	_set_command_buttons_disabled(true)
	message_label.text = "La runa del soulbind avvolge %s..." % (
		_wild_astral.definition.display_name
	)
	await _wait_for_action()
	if _state != BattleState.RESOLVING:
		return

	var captured_astral: AstralInstance = null
	if _roster != null:
		if _roster.capture_astral(_wild_astral):
			captured_astral = _roster.get_last_captured_astral()
	if captured_astral == null:
		message_label.text = "Il soulbind non e riuscito."
		await _wait_for_action()
		_show_commands()
		return

	message_label.text = "%s e stato catturato." % (
		_wild_astral.definition.display_name
	)
	await _wait_for_action()
	_finish_battle(&"captured", captured_astral)


func _show_commands() -> void:
	if (
		_state == BattleState.FINISHED
		or _state == BattleState.FORCED_SWITCH
	):
		return
	_wild_acted_first_this_round = false
	_state = BattleState.COMMAND
	_hide_selection_panels()
	command_panel.show()
	_set_command_buttons_disabled(false)
	message_label.text = "Scegli la prossima azione."
	fight_button.grab_focus()


func _show_astral_choices(forced: bool) -> void:
	if _roster == null:
		if forced:
			_finish_battle(&"defeat")
		return
	var usable_indices := _roster.get_usable_astral_indices(true)
	if usable_indices.is_empty():
		if forced:
			_finish_battle(&"defeat")
		else:
			message_label.text = "Non hai altri Astral in grado di combattere."
		return
	_state = (
		BattleState.FORCED_SWITCH
		if forced
		else BattleState.ASTRALS
	)
	command_panel.hide()
	move_panel.hide()
	item_panel.hide()
	astral_panel.show()
	astral_back_button.visible = not forced
	astral_back_button.disabled = forced
	message_label.text = (
		"Scegli un Astral per continuare."
		if forced
		else "Scegli l'Astral da mandare in campo."
	)
	_rebuild_astral_buttons(forced)


func _rebuild_move_buttons() -> void:
	_clear_dynamic_children(moves_grid)
	var first_available_button: Button = null
	var has_move_buttons := false
	if _player_astral != null:
		var moves := _player_astral.get_moves()
		var visible_move_count := mini(moves.size(), 4)
		for move_index: int in visible_move_count:
			var move: AstralMoveDefinition = null
			move = moves[move_index]
			if move == null:
				continue
			has_move_buttons = true
			var cooldown_remaining := get_player_move_cooldown_remaining(
				move_index
			)
			var move_button := Button.new()
			move_button.custom_minimum_size = Vector2(300.0, 54.0)
			move_button.text = "%s  [POT %d | %s | %s | CD %d%s]" % [
				move.display_name,
				move.power,
				PRESENTATION.format_element(move.element_id),
				move.get_damage_class_name(),
				move.cooldown_turns,
				(
					" | Attesa %d" % cooldown_remaining
					if cooldown_remaining > 0
					else ""
				),
			]
			move_button.set_meta(&"move_index", move_index)
			move_button.set_meta(&"cooldown_turns", move.cooldown_turns)
			move_button.set_meta(&"cooldown_remaining", cooldown_remaining)
			move_button.tooltip_text = "%s\nCooldown dopo l'uso: %s." % [
				move.description,
				_format_turn_count(move.cooldown_turns),
			]
			move_button.disabled = not _synergies.can_use_move(
				_player_astral,
				move,
				cooldown_remaining
			)
			var block_reason := _synergies.get_move_block_reason(
				_player_astral,
				move,
				cooldown_remaining
			)
			if not block_reason.is_empty():
				move_button.tooltip_text += "\n" + block_reason
			move_button.pressed.connect(choose_move.bind(move_index))
			moves_grid.add_child(move_button)
			if first_available_button == null and not move_button.disabled:
				first_available_button = move_button
		var inherited_move := _synergies.get_inherited_move(_player_astral)
		if inherited_move != null:
			has_move_buttons = true
			var inherited_index := _player_astral.get_move_count()
			var inherited_cooldown := get_player_move_cooldown_remaining(
				inherited_index
			)
			var inherited_button := Button.new()
			inherited_button.custom_minimum_size = Vector2(300.0, 54.0)
			inherited_button.text = "%s  [EREDITATA | POT %d | CD %d]" % [
				inherited_move.display_name,
				inherited_move.power,
				inherited_move.cooldown_turns,
			]
			inherited_button.disabled = not _synergies.can_use_move(
				_player_astral,
				inherited_move,
				inherited_cooldown
			)
			inherited_button.pressed.connect(choose_move.bind(inherited_index))
			moves_grid.add_child(inherited_button)
			if first_available_button == null and not inherited_button.disabled:
				first_available_button = inherited_button
	if not has_move_buttons:
		var empty_label := Label.new()
		empty_label.text = "Nessuna mossa disponibile."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		moves_grid.add_child(empty_label)
		move_back_button.grab_focus()
		return
	if first_available_button != null:
		first_available_button.grab_focus()
	else:
		move_back_button.grab_focus()


func _commit_player_move(move_index: int) -> void:
	_mark_move_used(
		_player_astral,
		move_index,
		_player_turn_index
	)
	_commit_player_turn()


func _commit_player_turn() -> void:
	_player_turn_index += 1


func _commit_wild_move(move_index: int) -> void:
	_mark_move_used(
		_wild_astral,
		move_index,
		_wild_turn_index
	)
	_commit_wild_turn()


func _commit_wild_turn() -> void:
	_wild_turn_index += 1


func _mark_move_used(
	astral: AstralInstance,
	move_index: int,
	current_turn: int
) -> void:
	if astral == null:
		return
	var move := _get_battle_move(astral, move_index)
	if move == null:
		return
	var cooldown_reduction := _synergies.consume_cooldown_reduction(
		astral,
		move
	)
	var astral_key := astral.get_instance_id()
	var ready_turns: Dictionary = _move_ready_turns.get(astral_key, {})
	ready_turns[move_index] = (
		current_turn
		+ maxi(move.cooldown_turns - cooldown_reduction, 0)
		+ 1
	)
	_move_ready_turns[astral_key] = ready_turns


func _get_move_cooldown_remaining(
	astral: AstralInstance,
	move_index: int,
	current_turn: int
) -> int:
	if astral == null or _get_battle_move(astral, move_index) == null:
		return 0
	var astral_key := astral.get_instance_id()
	var ready_turns: Dictionary = _move_ready_turns.get(astral_key, {})
	var ready_turn := int(ready_turns.get(move_index, current_turn))
	return maxi(ready_turn - current_turn, 0)


func _rebuild_item_buttons() -> void:
	_clear_dynamic_children(items_list)
	var first_button: Button = null
	if _inventory != null:
		for definition: ItemDefinition in _inventory.get_items_in_category(&"object"):
			var quantity := _inventory.get_quantity(definition.item_id)
			if not definition.consumable or quantity <= 0:
				continue
			var item_button := Button.new()
			item_button.custom_minimum_size = Vector2(0.0, 44.0)
			item_button.text = "%s x%d" % [definition.display_name, quantity]
			item_button.tooltip_text = definition.description
			item_button.pressed.connect(use_item.bind(definition.item_id))
			items_list.add_child(item_button)
			if first_button == null:
				first_button = item_button

	if first_button == null:
		var empty_label := Label.new()
		empty_label.text = "Nessun consumabile disponibile."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_list.add_child(empty_label)
		item_back_button.grab_focus()
		return
	first_button.grab_focus()


func _rebuild_astral_buttons(forced: bool) -> void:
	_clear_dynamic_children(astrals_list)
	var first_button: Button = null
	if _roster != null:
		var astrals := _roster.get_astrals()
		for roster_index: int in _roster.get_usable_astral_indices(true):
			if roster_index < 0 or roster_index >= astrals.size():
				continue
			var astral: AstralInstance = null
			astral = astrals[roster_index]
			if astral == null or astral.definition == null:
				continue
			var astral_button := Button.new()
			astral_button.custom_minimum_size = Vector2(0.0, 46.0)
			astral_button.text = "%s  Lv.%d  HP %d/%d" % [
				PRESENTATION.format_identity(astral),
				astral.level,
				astral.current_health,
				astral.get_max_health(),
			]
			astral_button.pressed.connect(switch_astral.bind(roster_index))
			astrals_list.add_child(astral_button)
			if first_button == null:
				first_button = astral_button
	if first_button == null:
		var empty_label := Label.new()
		empty_label.text = "Nessun altro Astral disponibile."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		astrals_list.add_child(empty_label)
		if not forced:
			astral_back_button.grab_focus()
		return
	first_button.grab_focus()


func _clear_dynamic_children(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _format_turn_count(turn_count: int) -> String:
	return "%d %s" % [
		turn_count,
		"turno" if turn_count == 1 else "turni",
	]


func _hide_selection_panels() -> void:
	move_panel.hide()
	item_panel.hide()
	astral_panel.hide()


func _refresh_status() -> void:
	_refresh_astral_status(
		_player_astral,
		player_name_label,
		player_health_label,
		player_health_bar
	)
	_refresh_astral_status(
		_wild_astral,
		wild_name_label,
		wild_health_label,
		wild_health_bar
	)


func _refresh_astral_status(
	astral: AstralInstance,
	name_label: Label,
	health_label: Label,
	health_bar: ProgressBar
) -> void:
	if astral == null or astral.definition == null:
		name_label.text = "Nessun Astral"
		health_label.text = "HP 0/0"
		health_bar.max_value = 1.0
		health_bar.value = 0.0
		return
	name_label.text = "%s  Lv.%d" % [
		PRESENTATION.format_identity(astral),
		astral.level,
	]
	var statuses := _synergies.get_status_names(astral)
	if not statuses.is_empty():
		name_label.text += "  [%s]" % ", ".join(statuses)
	health_label.text = "HP %d/%d" % [
		astral.current_health,
		astral.get_max_health(),
	]
	health_bar.max_value = astral.get_max_health()
	health_bar.value = astral.current_health


func _apply_astral_visual(
	visual: AstralModel3D,
	astral: AstralInstance
) -> void:
	if visual == null:
		return
	visual.show_astral(astral)


func _play_entry_animations() -> void:
	var player_tween := player_visual.play_entry_animation()
	var wild_tween := wild_visual.play_entry_animation()
	await _wait_for_visual_tween(player_tween)
	await _wait_for_visual_tween(wild_tween)


func _play_attack_animation(
	attacker: AstralModel3D,
	target: AstralModel3D
) -> void:
	if attacker == null or target == null:
		return
	var tween := attacker.play_attack_animation(target.global_position)
	await _wait_for_visual_tween(tween)


func _wait_for_visual_tween(tween: Tween) -> void:
	if tween == null or not tween.is_valid() or not tween.is_running():
		return
	await tween.finished


func _set_command_buttons_disabled(disabled: bool) -> void:
	fight_button.disabled = disabled
	items_button.disabled = disabled
	switch_button.disabled = disabled
	var has_capture_rune := (
		_inventory != null and _inventory.get_quantity(&"runa_base") > 0
	)
	capture_button.disabled = disabled or _trainer_battle or not has_capture_rune
	flee_button.disabled = disabled or _trainer_battle
	if not _trainer_battle:
		capture_button.tooltip_text = (
			""
			if has_capture_rune
			else "Serve una Runa Base per tentare il soulbind."
		)


func _wait_for_action() -> void:
	if action_delay <= 0.0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(
		action_delay,
		true,
		false,
		true
	).timeout


func _finish_battle(
	outcome: StringName,
	captured_astral: AstralInstance = null
) -> void:
	if _state == BattleState.FINISHED:
		return
	_state = BattleState.FINISHED
	command_panel.hide()
	_hide_selection_panels()
	_set_command_buttons_disabled(true)
	if outcome != &"fled":
		for participant: AstralInstance in _battle_participants:
			if participant != null:
				participant.change_affinity(
					AstralInstance.BATTLE_PARTICIPATION_AFFINITY_GAIN
				)
	_synergies.finish_battle()
	if _roster != null:
		_roster.heal_party_to_full()
	battle_finished.emit(outcome, captured_astral)


func _register_battle_participant(astral: AstralInstance) -> void:
	if astral != null and not _battle_participants.has(astral):
		_battle_participants.append(astral)


func _on_item_quantity_changed(
	_item: ItemDefinition,
	_quantity: int
) -> void:
	if _state == BattleState.ITEMS:
		_rebuild_item_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if _state == BattleState.FORCED_SWITCH:
		return
	if (
		_state == BattleState.MOVES
		or _state == BattleState.ITEMS
		or _state == BattleState.ASTRALS
	):
		if event.is_action_pressed("ui_cancel"):
			_show_commands()
			get_viewport().set_input_as_handled()
