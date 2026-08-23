class_name PlayerSession
extends Node

signal actor_changed(previous_actor: Node3D, current_actor: Node3D)

@export var session_id: StringName = &"local_player"
@export var peer_id: int = 1
@export var is_local: bool = true

var actor: CharacterBody3D = null
var inventory: Inventory = null
var astral_roster: AstralRoster = null
var grimoire: Grimoire = null
var profile: PlayerProfile = null
var save_manager: SaveManager = null
var economy: PlayerEconomyService = PlayerEconomyService.new()


func setup(
	player_actor: CharacterBody3D,
	player_inventory: Inventory,
	player_roster: AstralRoster,
	player_grimoire: Grimoire,
	player_profile: PlayerProfile,
	player_save_manager: SaveManager = null
) -> void:
	var previous_actor := actor
	actor = player_actor
	inventory = player_inventory
	astral_roster = player_roster
	grimoire = player_grimoire
	profile = player_profile
	save_manager = player_save_manager
	economy.setup(inventory, profile)
	if previous_actor != actor:
		actor_changed.emit(previous_actor, actor)


func set_authority_enabled(enabled: bool) -> void:
	economy.set_authority_enabled(enabled)


func owns_actor(candidate: Node) -> bool:
	if candidate == null or actor == null:
		return false
	return candidate == actor or actor.is_ancestor_of(candidate)


func is_ready_for_gameplay() -> bool:
	return (
		not session_id.is_empty()
		and actor != null
		and inventory != null
		and astral_roster != null
		and grimoire != null
		and profile != null
	)
