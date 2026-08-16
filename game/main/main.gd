extends Node3D

const BATTLE_SCENE := preload("res://game/battle/battle.tscn")
const PRESENTATION := preload("res://game/astrals/astral_presentation.gd")
const WILD_WYRM: AstralDefinition = preload(
	"res://data/astrals/wyrm_di_lava.tres"
)
const WILD_WAVE_MOUSE: AstralDefinition = preload(
	"res://data/astrals/topo_onda.tres"
)
const WILD_FAIRY_BEAR: AstralDefinition = preload(
	"res://data/astrals/orso_fatato.tres"
)
const WILD_RAINBOW_SLIME: AstralDefinition = preload(
	"res://data/astrals/slime_arcobaleno.tres"
)
const WILD_ASTRAL_POOL: Array[AstralDefinition] = [
	WILD_WYRM,
	WILD_WAVE_MOUSE,
	WILD_FAIRY_BEAR,
	WILD_RAINBOW_SLIME,
]
const BATTLE_PAUSE_LOCK: StringName = &"battle"
const TRAINER_MOVEMENT_LOCK: StringName = &"trainer_challenge"
const NPC_DIALOGUE_MOVEMENT_LOCK: StringName = &"npc_dialogue"

@export_range(0.0, 2.0, 0.05) var battle_fade_duration: float = 0.35
@export_range(-10, 0, 1) var wild_level_minimum_offset: int = -1
@export_range(0, 10, 1) var wild_level_maximum_offset: int = 1

const DROPS_BY_CATEGORY: Dictionary[StringName, StringName] = {
	&"palm": &"cocco",
	&"tent": &"stoffa",
	&"tree": &"legno",
	&"rock": &"pietra",
	&"mushroom": &"fungo",
	&"shrub": &"bacca",
}

@onready var world_map: Node3D = $WorldMap
@onready var player: CharacterBody3D = $Player
@onready var inventory: Inventory = $Inventory
@onready var astral_roster: AstralRoster = $AstralRoster
@onready var grimoire: Grimoire = $Grimoire
@onready var player_profile: PlayerProfile = $PlayerProfile
@onready var save_manager: SaveManager = $SaveManager
@onready var battle_host: Node = $BattleHost
@onready var game_ui: GameUI = $GameUI

var _active_battle: BattleController
var _active_trainer: TrainerNpc
var _active_npc: WorldNpc
var _battle_transitioning: bool = false
var _encounter_random := RandomNumberGenerator.new()


func _ready() -> void:
	_encounter_random.randomize()
	if world_map.has_signal("map_interactable_interacted"):
		world_map.connect(
			"map_interactable_interacted",
			_on_map_interactable_interacted
		)
	if world_map.has_signal("wild_encounter_requested"):
		world_map.connect(
			"wild_encounter_requested",
			_on_wild_encounter_requested
		)
	if world_map.has_signal("trainer_challenge_requested"):
		world_map.connect(
			"trainer_challenge_requested",
			_on_trainer_challenge_requested
		)
	if world_map.has_signal("trainer_dialogue_requested"):
		world_map.connect(
			"trainer_dialogue_requested",
			_on_trainer_dialogue_requested
		)
	if world_map.has_signal("trainer_battle_requested"):
		world_map.connect(
			"trainer_battle_requested",
			_on_trainer_battle_requested
		)
	if world_map.has_signal("trainer_challenge_cancelled"):
		world_map.connect(
			"trainer_challenge_cancelled",
			_on_trainer_challenge_cancelled
		)
	if world_map.has_signal("npc_interaction_started"):
		world_map.connect(
			"npc_interaction_started",
			_on_npc_interaction_started
		)
	if world_map.has_signal("npc_interaction_finished"):
		world_map.connect(
			"npc_interaction_finished",
			_on_npc_interaction_finished
		)
	if world_map.has_signal("npc_florins_gift_requested"):
		world_map.connect(
			"npc_florins_gift_requested",
			_on_npc_florins_gift_requested
		)
	if world_map.has_method("get_spawn_position"):
		player.global_position = world_map.call("get_spawn_position")
	grimoire.setup(astral_roster)
	player_profile.setup(astral_roster)
	save_manager.setup(
		player,
		inventory,
		astral_roster,
		grimoire,
		player_profile,
		world_map
	)
	game_ui.setup(
		inventory,
		astral_roster,
		grimoire,
		player_profile,
		save_manager
	)


func _on_wild_encounter_requested(
	_zone_id: StringName,
	_actor: Node3D
) -> void:
	if (
		_active_battle != null
		or _battle_transitioning
		or _active_npc != null
	):
		return
	_battle_transitioning = true
	call_deferred("_start_wild_battle")


func _start_wild_battle() -> void:
	game_ui.set_pause_lock(BATTLE_PAUSE_LOCK, true)
	await game_ui.fade_to_black(battle_fade_duration)

	var battle := BATTLE_SCENE.instantiate() as BattleController
	if battle == null:
		push_error("Impossibile istanziare la scena di combattimento.")
		await game_ui.fade_from_black(battle_fade_duration)
		game_ui.set_pause_lock(BATTLE_PAUSE_LOCK, false)
		_battle_transitioning = false
		return

	_active_battle = battle
	battle_host.add_child(battle)
	battle.battle_finished.connect(_on_battle_finished)
	var wild_definition := get_random_wild_astral_definition()
	if wild_definition == null:
		push_error("Nessun Astral selvatico configurato per l'incontro.")
		battle.queue_free()
		_active_battle = null
		await game_ui.fade_from_black(battle_fade_duration)
		game_ui.set_pause_lock(BATTLE_PAUSE_LOCK, false)
		_battle_transitioning = false
		return
	grimoire.register_seen(wild_definition)
	battle.setup(
		inventory,
		astral_roster,
		wild_definition,
		_get_wild_astral_level(),
		_encounter_random
	)
	await game_ui.fade_from_black(battle_fade_duration)
	_battle_transitioning = false
	battle.begin()


func _on_trainer_challenge_requested(
	trainer: TrainerNpc,
	actor: CharacterBody3D
) -> void:
	if (
		trainer == null
		or actor != player
		or trainer.defeated
		or _active_battle != null
		or _battle_transitioning
		or _active_trainer != null
		or _active_npc != null
	):
		if trainer != null:
			trainer.cancel_challenge()
		return
	_active_trainer = trainer
	_set_player_movement_locked(true)
	if not trainer.start_challenge(player):
		_active_trainer = null
		_set_player_movement_locked(false)


func _on_trainer_dialogue_requested(
	trainer: TrainerNpc,
	dialogue: String
) -> void:
	if trainer != _active_trainer:
		return
	game_ui.show_notification(dialogue)


func _on_trainer_battle_requested(trainer: TrainerNpc) -> void:
	if (
		trainer != _active_trainer
		or trainer.astral_definition == null
		or _active_battle != null
		or _battle_transitioning
	):
		return
	trainer.mark_battle_started()
	_battle_transitioning = true
	call_deferred("_start_trainer_battle")


func _on_trainer_challenge_cancelled(trainer: TrainerNpc) -> void:
	if trainer != _active_trainer or _active_battle != null:
		return
	_active_trainer = null
	_set_player_movement_locked(false)


func _on_npc_interaction_started(
	npc: WorldNpc,
	actor: CharacterBody3D,
	dialogue: String
) -> void:
	if (
		npc == null
		or actor != player
		or _active_npc != null
		or _active_trainer != null
		or _active_battle != null
		or _battle_transitioning
	):
		if npc != null:
			npc.cancel_interaction()
		return
	_active_npc = npc
	_set_npc_dialogue_movement_locked(true)
	game_ui.show_notification(dialogue)


func _on_npc_interaction_finished(
	npc: WorldNpc,
	actor: CharacterBody3D
) -> void:
	if npc != _active_npc or actor != player:
		return
	_active_npc = null
	_set_npc_dialogue_movement_locked(false)


func _on_npc_florins_gift_requested(
	npc: WorldNpc,
	actor: CharacterBody3D,
	amount: int
) -> void:
	if npc != _active_npc or actor != player or amount <= 0:
		return
	var previous_florins := player_profile.florins
	player_profile.add_florins(amount)
	var received_florins := player_profile.florins - previous_florins
	if received_florins > 0:
		game_ui.show_notification(
			"%s ti ha regalato %d %s." % [
				npc.display_name,
				received_florins,
				player_profile.currency_name,
			],
			true
		)
	else:
		game_ui.show_notification(
			"Non puoi portare altri %s: hai raggiunto il limite di %d." % [
				player_profile.currency_name,
				PlayerProfile.MAX_FLORINS,
			],
			true
		)


func _start_trainer_battle() -> void:
	var trainer := _active_trainer
	if trainer == null or trainer.astral_definition == null:
		_cancel_active_trainer_challenge()
		_battle_transitioning = false
		return
	game_ui.set_pause_lock(BATTLE_PAUSE_LOCK, true)
	await game_ui.fade_to_black(battle_fade_duration)

	var battle := BATTLE_SCENE.instantiate() as BattleController
	if battle == null:
		push_error("Impossibile istanziare la battaglia allenatore.")
		await game_ui.fade_from_black(battle_fade_duration)
		game_ui.set_pause_lock(BATTLE_PAUSE_LOCK, false)
		_cancel_active_trainer_challenge()
		_battle_transitioning = false
		return

	_active_battle = battle
	battle_host.add_child(battle)
	battle.battle_finished.connect(_on_battle_finished)
	battle.configure_trainer_battle(trainer.display_name)
	grimoire.register_seen(trainer.astral_definition)
	battle.setup(
		inventory,
		astral_roster,
		trainer.astral_definition,
		trainer.astral_level,
		_encounter_random
	)
	await game_ui.fade_from_black(battle_fade_duration)
	_battle_transitioning = false
	battle.begin()


func get_wild_astral_pool() -> Array[AstralDefinition]:
	var pool_copy: Array[AstralDefinition] = []
	pool_copy.assign(WILD_ASTRAL_POOL)
	return pool_copy


func get_random_wild_astral_definition() -> AstralDefinition:
	if WILD_ASTRAL_POOL.is_empty():
		return null
	return WILD_ASTRAL_POOL[
		_encounter_random.randi_range(0, WILD_ASTRAL_POOL.size() - 1)
	]


func set_encounter_random_seed(seed_value: int) -> void:
	_encounter_random.seed = seed_value


func _get_wild_astral_level() -> int:
	var leader := astral_roster.get_active_astral()
	var reference_level := leader.level if leader != null else 1
	var minimum_level := maxi(
		reference_level + wild_level_minimum_offset,
		1
	)
	var maximum_level := maxi(
		reference_level + wild_level_maximum_offset,
		minimum_level
	)
	return _encounter_random.randi_range(minimum_level, maximum_level)


func _on_battle_finished(
	outcome: StringName,
	captured_astral: AstralInstance
) -> void:
	if _battle_transitioning:
		return
	_battle_transitioning = true
	await game_ui.fade_to_black(battle_fade_duration)

	if _active_battle != null:
		_active_battle.queue_free()
		_active_battle = null
	var completed_trainer := _active_trainer
	var trainer_reward_items_received := 0
	if completed_trainer != null:
		var player_won := outcome == &"victory"
		completed_trainer.finish_battle(player_won)
		if player_won:
			trainer_reward_items_received = _grant_trainer_rewards(completed_trainer)
		_active_trainer = null

	await game_ui.fade_from_black(battle_fade_duration)
	game_ui.set_pause_lock(BATTLE_PAUSE_LOCK, false)
	_set_player_movement_locked(false)
	_battle_transitioning = false
	if completed_trainer != null:
		_show_trainer_battle_result(
			outcome,
			completed_trainer,
			trainer_reward_items_received
		)
	else:
		_show_battle_result(outcome, captured_astral)


func _grant_trainer_rewards(trainer: TrainerNpc) -> int:
	player_profile.add_florins(trainer.reward_florins)
	if trainer.reward_item_id.is_empty() or trainer.reward_item_amount <= 0:
		return 0
	return inventory.add_item(
		trainer.reward_item_id,
		trainer.reward_item_amount
	)


func _show_trainer_battle_result(
	outcome: StringName,
	trainer: TrainerNpc,
	received_item_amount: int
) -> void:
	if outcome != &"victory":
		game_ui.show_notification(
			"%s ha vinto la sfida." % trainer.display_name
		)
		return
	var reward_message := "Hai sconfitto %s: +%d %s" % [
		trainer.display_name,
		trainer.reward_florins,
		player_profile.currency_name,
	]
	var item := inventory.get_item_definition(trainer.reward_item_id)
	if item != null and received_item_amount > 0:
		reward_message += ", +%d %s" % [
				received_item_amount,
				item.display_name,
		]
	game_ui.show_notification(reward_message + ".")


func _cancel_active_trainer_challenge() -> void:
	if _active_trainer != null:
		_active_trainer.cancel_challenge()
	_active_trainer = null
	_set_player_movement_locked(false)


func _set_player_movement_locked(active: bool) -> void:
	if player.has_method("set_movement_lock"):
		player.call("set_movement_lock", TRAINER_MOVEMENT_LOCK, active)


func _set_npc_dialogue_movement_locked(active: bool) -> void:
	if player.has_method("set_movement_lock"):
		player.call("set_movement_lock", NPC_DIALOGUE_MOVEMENT_LOCK, active)


func _show_battle_result(
	outcome: StringName,
	captured_astral: AstralInstance
) -> void:
	match outcome:
		&"captured":
			var captured_name := "Astral selvatico"
			if captured_astral != null and captured_astral.definition != null:
				captured_name = PRESENTATION.format_identity(captured_astral)
			game_ui.show_notification(
				"Soulbind riuscito: %s e ora legato a te." % captured_name
			)
		&"victory":
			game_ui.show_notification("Hai vinto lo scontro selvatico.")
		&"defeat":
			game_ui.show_notification("Il tuo Astral non puo piu combattere.")
		&"fled":
			game_ui.show_notification("Sei fuggito dall'incontro.")


func _on_map_interactable_interacted(
	interactable: InteractableArea3D,
	_interactor: Node3D
) -> void:
	var item_id: StringName = DROPS_BY_CATEGORY.get(interactable.category, &"")
	if item_id.is_empty():
		return

	var item := inventory.get_item_definition(item_id)
	if item == null:
		return
	if interactable.remaining_item_count <= 0:
		game_ui.show_notification(
			"%s non contiene più oggetti da raccogliere." % interactable.display_name
		)
		return
	if not inventory.can_add_item(item_id):
		game_ui.show_notification(
			"Inventario pieno: non hai più spazio per %s." % item.display_name
		)
		return
	if not interactable.take_generated_item():
		return

	inventory.add_item(item_id)
	var current_quantity := inventory.get_quantity(item_id)
	game_ui.show_notification(
		"Hai raccolto %s (%d/%d)." % [
			item.display_name,
			current_quantity,
			item.max_quantity,
		]
	)
	if current_quantity >= item.max_quantity:
		game_ui.show_notification(
			"Inventario pieno: non hai più spazio per %s." % item.display_name,
			true
		)
