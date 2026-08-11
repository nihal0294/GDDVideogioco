class_name TallGrassEncounterZone
extends Area3D

signal actor_entered(zone_id: StringName, actor: Node3D)
signal actor_exited(zone_id: StringName, actor: Node3D)
signal encounter_check_requested(zone_id: StringName, actor: Node3D)

@export var zone_id: StringName = &"tall_grass"
@export_range(0.25, 10.0, 0.25) var distance_per_encounter_check: float = 1.5

var _last_check_positions: Dictionary[int, Vector3] = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	add_to_group("wild_encounter_zones")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	for body: Node3D in get_overlapping_bodies():
		if not _is_player(body):
			continue
		var actor_id := body.get_instance_id()
		var last_position: Vector3 = _last_check_positions.get(
			actor_id,
			body.global_position
		)
		if body.global_position.distance_to(last_position) < distance_per_encounter_check:
			continue
		_last_check_positions[actor_id] = body.global_position
		encounter_check_requested.emit(zone_id, body)


func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	_last_check_positions[body.get_instance_id()] = body.global_position
	actor_entered.emit(zone_id, body)


func _on_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return
	_last_check_positions.erase(body.get_instance_id())
	actor_exited.emit(zone_id, body)


func _is_player(body: Node3D) -> bool:
	return (
		body is CharacterBody3D
		and (body.is_in_group("player") or body.name == "Player")
	)
