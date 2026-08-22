extends Node3D

const BATTLE_SCENE := preload("res://game/battle/battle.tscn")
const PRESENTATION := preload("res://game/astrals/astral_presentation.gd")
const MAP_SCENES: Dictionary[StringName, PackedScene] = {
	&"verdant_forest": preload(
		"res://game/world/maps/verdant_valley/verdant_valley.tscn"
	),
	&"large_island": preload(
		"res://game/world/maps/large_island/large_island.tscn"
	),
	&"merchant_house": preload(
		"res://game/world/maps/merchant_house/merchant_house.tscn"
	),
}
const BATTLE_PAUSE_LOCK: StringName = &"battle"
const TRAINER_MOVEMENT_LOCK: StringName = &"trainer_challenge"
const NPC_DIALOGUE_MOVEMENT_LOCK: StringName = &"npc_dialogue"
const MAP_TRANSITION_PAUSE_LOCK: StringName = &"map_transition"
const MAP_TRANSITION_MOVEMENT_LOCK: StringName = &"map_transition"

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
var _map_transitioning: bool = false
var _encounter_random := RandomNumberGenerator.new()
var _map_cache: Dictionary[StringName, Node3D] = {}


func _ready() -> void:
	_encounter_random.randomize()
	_connect_world_map_signals()
	_map_cache[get_current_map_id()] = world_map
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
	if not save_manager.map_change_requested.is_connected(
		_on_saved_map_change_requested
	):
		save_manager.map_change_requested.connect(
			_on_saved_map_change_requested
		)
	game_ui.setup(
		inventory,
		astral_roster,
		grimoire,
		player_profile,
		save_manager
	)
	if DisplayServer.get_name() != "headless":
		call_deferred("_warm_up_battle_models")


func _exit_tree() -> void:
	for cached_map: Node3D in _map_cache.values():
		if cached_map != null and not cached_map.is_inside_tree():
			cached_map.free()
	_map_cache.clear()


func get_current_map_id() -> StringName:
	if world_map != null and world_map.has_method("get_map_id"):
		return world_map.call("get_map_id") as StringName
	return &"verdant_forest"


func _connect_world_map_signals() -> void:
	_connect_world_map_signal(
		&"map_interactable_interacted",
		_on_map_interactable_interacted
	)
	_connect_world_map_signal(
		&"wild_encounter_requested",
		_on_wild_encounter_requested
	)
	_connect_world_map_signal(
		&"trainer_challenge_requested",
		_on_trainer_challenge_requested
	)
	_connect_world_map_signal(
		&"trainer_dialogue_requested",
		_on_trainer_dialogue_requested
	)
	_connect_world_map_signal(
		&"trainer_battle_requested",
		_on_trainer_battle_requested
	)
	_connect_world_map_signal(
		&"trainer_challenge_cancelled",
		_on_trainer_challenge_cancelled
	)
	_connect_world_map_signal(
		&"npc_interaction_started",
		_on_npc_interaction_started
	)
	_connect_world_map_signal(
		&"npc_interaction_finished",
		_on_npc_interaction_finished
	)
	_connect_world_map_signal(
		&"npc_florins_gift_requested",
		_on_npc_florins_gift_requested
	)
	_connect_world_map_signal(
		&"map_transition_requested",
		_on_map_transition_requested
	)
	_connect_world_map_signal(
		&"facility_action_requested",
		_on_facility_action_requested
	)


func _connect_world_map_signal(
	signal_name: StringName,
	callback: Callable
) -> void:
	if (
		world_map != null
		and world_map.has_signal(signal_name)
		and not world_map.is_connected(signal_name, callback)
	):
		world_map.connect(signal_name, callback)


func _on_map_transition_requested(
	destination_map_id: StringName,
	destination_spawn_id: StringName,
	actor: CharacterBody3D
) -> void:
	if (
		actor != player
		or _map_transitioning
		or _battle_transitioning
		or _active_battle != null
		or _active_trainer != null
		or _active_npc != null
	):
		return
	var normalized_map_id := _normalize_map_id(destination_map_id)
	if not MAP_SCENES.has(normalized_map_id):
		game_ui.show_notification("La destinazione del portale non è disponibile.")
		return
	_map_transitioning = true
	_set_map_transition_movement_locked(true)
	call_deferred(
		"_perform_map_transition",
		normalized_map_id,
		destination_spawn_id
	)


func _perform_map_transition(
	destination_map_id: StringName,
	destination_spawn_id: StringName
) -> void:
	game_ui.set_pause_lock(MAP_TRANSITION_PAUSE_LOCK, true)
	await game_ui.fade_to_black(battle_fade_duration)
	game_ui.set_loading_visible(true, "Caricamento ambiente...")
	await get_tree().create_timer(0.2, true).timeout
	var map_changed := _replace_world_map(
		destination_map_id,
		destination_spawn_id,
		true
	)
	await get_tree().process_frame
	game_ui.set_loading_visible(false)
	await game_ui.fade_from_black(battle_fade_duration)
	game_ui.set_pause_lock(MAP_TRANSITION_PAUSE_LOCK, false)
	_set_map_transition_movement_locked(false)
	_map_transitioning = false
	if map_changed:
		var location_name := String(destination_map_id)
		if world_map.has_method("get_location_name"):
			location_name = String(world_map.call("get_location_name"))
		game_ui.show_notification("Sei arrivato: %s." % location_name)
	else:
		game_ui.show_notification("Il portale non ha potuto completare il viaggio.")


func _on_facility_action_requested(
	action_id: StringName,
	actor: CharacterBody3D
) -> void:
	if actor != player or _map_transitioning or _active_battle != null:
		return
	match action_id:
		&"merchant":
			game_ui.open_shop()
		&"astral_exchange":
			game_ui.open_astral_exchange()
		&"healer":
			var healed := astral_roster.heal_party_to_full()
			game_ui.show_notification(
				"La squadra è già in piena forma."
				if healed == 0
				else "La guaritrice ha curato e rianimato tutta la squadra."
			)
		&"astral_box":
			game_ui.open_astral_box()
		&"coin_flip":
			game_ui.open_coin_flip()


func _replace_world_map(
	destination_map_id: StringName,
	destination_spawn_id: StringName = &"default",
	place_player_at_spawn: bool = true
) -> bool:
	var normalized_map_id := _normalize_map_id(destination_map_id)
	var packed_map: PackedScene = MAP_SCENES.get(normalized_map_id)
	if packed_map == null:
		return false
	if get_current_map_id() == normalized_map_id:
		if place_player_at_spawn:
			_place_player_at_map_spawn(destination_spawn_id)
		return true
	var new_world_map: Node3D = _map_cache.get(normalized_map_id)
	if new_world_map == null:
		new_world_map = packed_map.instantiate() as Node3D
	if new_world_map == null:
		return false
	var old_world_map := world_map
	var map_child_index := old_world_map.get_index() if old_world_map != null else 0
	if old_world_map != null:
		_map_cache[get_current_map_id()] = old_world_map
		remove_child(old_world_map)
	new_world_map.name = "WorldMap"
	add_child(new_world_map)
	move_child(new_world_map, mini(map_child_index, get_child_count() - 1))
	world_map = new_world_map
	_map_cache[normalized_map_id] = world_map
	_connect_world_map_signals()
	if save_manager != null:
		save_manager.set_world_map(world_map)
	if place_player_at_spawn:
		_place_player_at_map_spawn(destination_spawn_id)
	return true


func _place_player_at_map_spawn(spawn_id: StringName) -> void:
	if world_map == null or not world_map.has_method("get_spawn_position"):
		return
	player.global_position = world_map.call("get_spawn_position", spawn_id)
	player.velocity = Vector3.ZERO


func _on_saved_map_change_requested(map_id: StringName) -> void:
	_replace_world_map(_normalize_map_id(map_id), &"default", false)


func _normalize_map_id(map_id: StringName) -> StringName:
	if map_id == &"world_map" or map_id == &"verdant_valley":
		return &"verdant_forest"
	return map_id


func _on_wild_encounter_requested(
	_zone_id: StringName,
	_actor: Node3D
) -> void:
	if (
		_active_battle != null
		or _battle_transitioning
		or _map_transitioning
		or _active_npc != null
	):
		return
	_battle_transitioning = true
	call_deferred("_start_wild_battle")


func _start_wild_battle() -> void:
	var wild_definition := get_random_wild_astral_definition()
	if wild_definition == null:
		push_error("Nessun Astral selvatico configurato per l'incontro.")
		_battle_transitioning = false
		return
	var battle_definitions := _get_battle_model_definitions(wild_definition)
	_request_astral_models(battle_definitions)
	game_ui.set_pause_lock(BATTLE_PAUSE_LOCK, true)
	await game_ui.fade_to_black(battle_fade_duration)
	await _wait_for_astral_models(battle_definitions)

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
		or _map_transitioning
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
		or _map_transitioning
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
		or _map_transitioning
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
	for item_index: int in npc.gift_item_ids.size():
		var item_id := npc.gift_item_ids[item_index]
		var requested_amount := (
			npc.gift_item_amounts[item_index]
			if item_index < npc.gift_item_amounts.size()
			else 1
		)
		var added_amount := inventory.add_item(item_id, maxi(requested_amount, 0))
		var item := inventory.get_item_definition(item_id)
		if item != null and added_amount > 0:
			game_ui.show_notification(
				"%s ti ha regalato %d %s." % [
					npc.display_name,
					added_amount,
					item.display_name,
				],
				true
			)


func _start_trainer_battle() -> void:
	var trainer := _active_trainer
	if trainer == null or trainer.astral_definition == null:
		_cancel_active_trainer_challenge()
		_battle_transitioning = false
		return
	var battle_definitions := _get_battle_model_definitions(
		trainer.astral_definition
	)
	_request_astral_models(battle_definitions)
	game_ui.set_pause_lock(BATTLE_PAUSE_LOCK, true)
	await game_ui.fade_to_black(battle_fade_duration)
	await _wait_for_astral_models(battle_definitions)

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
	return AstralCatalog.load_wild_base_definitions()


func _warm_up_battle_models() -> void:
	var definitions := get_wild_astral_pool()
	for party_index: int in astral_roster.get_astral_count():
		var astral := astral_roster.get_astral(party_index)
		if (
			astral != null
			and astral.definition != null
			and not definitions.has(astral.definition)
		):
			definitions.append(astral.definition)
	_request_astral_models(definitions)
	await _wait_for_astral_models(definitions)


func _get_battle_model_definitions(
	opponent: AstralDefinition
) -> Array[AstralDefinition]:
	var definitions: Array[AstralDefinition] = []
	var active_astral := astral_roster.get_active_astral()
	if active_astral != null and active_astral.definition != null:
		definitions.append(active_astral.definition)
	if opponent != null and not definitions.has(opponent):
		definitions.append(opponent)
	return definitions


func _request_astral_models(definitions: Array[AstralDefinition]) -> void:
	for definition: AstralDefinition in definitions:
		if definition != null:
			definition.request_model_scene_load()


func _wait_for_astral_models(
	definitions: Array[AstralDefinition]
) -> void:
	if DisplayServer.get_name() == "headless":
		return
	while true:
		var loading := false
		for definition: AstralDefinition in definitions:
			if definition == null:
				continue
			var status := definition.poll_model_scene_load()
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				loading = true
		if not loading:
			return
		await get_tree().process_frame


func get_random_wild_astral_definition() -> AstralDefinition:
	var pool := get_wild_astral_pool()
	if pool.is_empty():
		return null
	return pool[
		_encounter_random.randi_range(0, pool.size() - 1)
	]


func set_encounter_random_seed(seed_value: int) -> void:
	_encounter_random.seed = seed_value


func _get_wild_astral_level() -> int:
	var leader := astral_roster.get_active_astral()
	var reference_level := leader.level if leader != null else 1
	var minimum_level := maxi(
		reference_level + wild_level_minimum_offset,
		5
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


func _set_map_transition_movement_locked(active: bool) -> void:
	if player.has_method("set_movement_lock"):
		player.call("set_movement_lock", MAP_TRANSITION_MOVEMENT_LOCK, active)


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
	interactor: Node3D
) -> void:
	if interactor != player or _map_transitioning:
		return
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
