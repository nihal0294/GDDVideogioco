class_name TallGrassEncounterZone
extends Area3D

signal actor_entered(zone_id: StringName, actor: Node3D)
signal actor_exited(zone_id: StringName, actor: Node3D)
signal encounter_check_requested(zone_id: StringName, actor: Node3D)
signal encounter_triggered(zone_id: StringName, actor: Node3D)

@export var zone_id: StringName = &"tall_grass"
@export_range(0.25, 10.0, 0.25) var distance_per_encounter_check: float = 1.5
@export_range(0.0, 1.0, 0.01) var encounter_probability: float = 0.12
@export_range(0.0, 30.0, 0.5) var encounter_cooldown: float = 5.0
@export_range(1, 20, 1) var maximum_failed_checks: int = 6
@export_range(0.5, 4.0, 0.1) var grass_response_radius: float = 2.2
@export_range(1.0, 20.0, 0.5) var grass_response_speed: float = 9.0
@export_range(1.0, 25.0, 0.5) var maximum_bend_degrees: float = 20.0

var grass_visual: MultiMeshInstance3D
var player: CharacterBody3D

var _last_check_positions: Dictionary[int, Vector3] = {}
var _base_grass_transforms: Array[Transform3D] = []
var _grass_bend_amounts := PackedFloat32Array()
var _grass_bend_axes: Array[Vector3] = []
var _random := RandomNumberGenerator.new()
var _cooldown_remaining: float = 0.0
var _grass_needs_recovery: bool = false
var _failed_checks: int = 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0xFFFFFFFF
	if player != null and player.collision_layer != 0:
		collision_mask = player.collision_layer
	monitoring = true
	monitorable = false
	add_to_group("wild_encounter_zones")
	_random.randomize()
	_cache_grass_transforms()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	var active_player := _get_overlapping_player()
	if active_player != null:
		_update_grass_response(active_player, delta)
		_update_encounter_check(active_player)
		return
	if _grass_needs_recovery:
		_restore_grass(delta)


func _update_encounter_check(actor: Node3D) -> void:
	var actor_id := actor.get_instance_id()
	if not _last_check_positions.has(actor_id):
		_last_check_positions[actor_id] = actor.global_position
		return
	var last_position: Vector3 = _last_check_positions[actor_id]
	if actor.global_position.distance_to(last_position) < distance_per_encounter_check:
		return
	_last_check_positions[actor_id] = actor.global_position
	encounter_check_requested.emit(zone_id, actor)
	if _cooldown_remaining > 0.0:
		return
	if encounter_probability <= 0.0:
		_failed_checks = 0
		return
	var encounter_succeeded := _random.randf() < encounter_probability
	if not encounter_succeeded:
		_failed_checks += 1
	if not encounter_succeeded and _failed_checks < maximum_failed_checks:
		return
	_failed_checks = 0
	_cooldown_remaining = encounter_cooldown
	encounter_triggered.emit(zone_id, actor)


func _get_overlapping_player() -> Node3D:
	for body: Node3D in get_overlapping_bodies():
		if _is_player(body):
			return body
	if player != null and _contains_player_position(player):
		return player
	return null


func _contains_player_position(actor: Node3D) -> bool:
	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.disabled:
		return false
	var box_shape := collision_shape.shape as BoxShape3D
	if box_shape == null:
		return false
	var local_position := collision_shape.to_local(actor.global_position)
	var half_size := box_shape.size * 0.5
	return (
		absf(local_position.x) <= half_size.x
		and absf(local_position.z) <= half_size.z
		and absf(local_position.y) <= half_size.y + 2.0
	)


func _cache_grass_transforms() -> void:
	_base_grass_transforms.clear()
	_grass_bend_amounts = PackedFloat32Array()
	_grass_bend_axes.clear()
	if grass_visual == null or grass_visual.multimesh == null:
		return
	_grass_bend_amounts.resize(grass_visual.multimesh.instance_count)
	for index: int in grass_visual.multimesh.instance_count:
		_base_grass_transforms.append(
			grass_visual.multimesh.get_instance_transform(index)
		)
		_grass_bend_amounts[index] = 0.0
		_grass_bend_axes.append(Vector3.RIGHT)


func _update_grass_response(actor: Node3D, delta: float) -> void:
	if grass_visual == null or grass_visual.multimesh == null:
		return
	var instance_count := grass_visual.multimesh.instance_count
	if (
		_base_grass_transforms.size() != instance_count
		or _grass_bend_amounts.size() != instance_count
		or _grass_bend_axes.size() != instance_count
	):
		_cache_grass_transforms()
	var actor_position := grass_visual.to_local(actor.global_position)
	var maximum_bend := deg_to_rad(maximum_bend_degrees)
	var maximum_change := maximum_bend * grass_response_speed * delta
	var has_bent_grass := false
	for index: int in _base_grass_transforms.size():
		var base_transform := _base_grass_transforms[index]
		var offset := base_transform.origin - actor_position
		var flat_offset := Vector2(offset.x, offset.z)
		var distance := flat_offset.length()
		var target_bend := 0.0
		if distance < grass_response_radius:
			var weight := 1.0 - smoothstep(0.0, grass_response_radius, distance)
			var away_direction := Vector3(offset.x, 0.0, offset.z).normalized()
			if away_direction.length_squared() <= 0.001:
				away_direction = Vector3.FORWARD
			_grass_bend_axes[index] = Vector3(
				-away_direction.z,
				0.0,
				away_direction.x
			).normalized()
			target_bend = maximum_bend * weight
		_grass_bend_amounts[index] = move_toward(
			_grass_bend_amounts[index],
			target_bend,
			maximum_change
		)
		var animated_transform := base_transform
		if _grass_bend_amounts[index] > 0.0001:
			animated_transform.basis = (
				Basis(_grass_bend_axes[index], _grass_bend_amounts[index])
					* base_transform.basis
			)
			var bend_direction := Vector3(
				_grass_bend_axes[index].z,
				0.0,
				-_grass_bend_axes[index].x
			)
			animated_transform.origin += bend_direction * (
				0.18 * _grass_bend_amounts[index]
				/ maxf(maximum_bend, 0.0001)
			)
			has_bent_grass = true
		grass_visual.multimesh.set_instance_transform(index, animated_transform)
	_grass_needs_recovery = has_bent_grass


func _restore_grass(delta: float) -> void:
	if grass_visual == null or grass_visual.multimesh == null:
		_grass_needs_recovery = false
		return
	var maximum_bend := deg_to_rad(maximum_bend_degrees)
	var maximum_change := maximum_bend * grass_response_speed * delta
	var still_recovering := false
	for index: int in _base_grass_transforms.size():
		var base_transform := _base_grass_transforms[index]
		_grass_bend_amounts[index] = move_toward(
			_grass_bend_amounts[index],
			0.0,
			maximum_change
		)
		var animated_transform := base_transform
		if _grass_bend_amounts[index] > 0.0001:
			animated_transform.basis = (
				Basis(_grass_bend_axes[index], _grass_bend_amounts[index])
					* base_transform.basis
			)
			var bend_direction := Vector3(
				_grass_bend_axes[index].z,
				0.0,
				-_grass_bend_axes[index].x
			)
			animated_transform.origin += bend_direction * (
				0.18 * _grass_bend_amounts[index]
				/ maxf(maximum_bend, 0.0001)
			)
			still_recovering = true
		grass_visual.multimesh.set_instance_transform(index, animated_transform)
	_grass_needs_recovery = still_recovering


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
	if player != null:
		return body == player
	return body is CharacterBody3D
