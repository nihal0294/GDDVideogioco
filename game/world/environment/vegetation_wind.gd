class_name VegetationWind
extends Node

@export var target_root: Node3D
@export_range(5.0, 60.0, 1.0) var update_rate_hz: float = 20.0
@export_range(0.0, 2.0, 0.05) var base_strength: float = 0.75
@export_range(0.0, 2.0, 0.05) var minimum_gust: float = 0.25
@export_range(0.0, 2.0, 0.05) var maximum_gust: float = 1.0
@export_range(0.5, 15.0, 0.5) var minimum_gust_duration: float = 2.0
@export_range(0.5, 15.0, 0.5) var maximum_gust_duration: float = 6.0
@export var random_seed: int = 0


class WindTarget:
	extends RefCounted

	var instance: MultiMeshInstance3D
	var base_transforms: Array[Transform3D] = []
	var phases: PackedFloat32Array = PackedFloat32Array()
	var maximum_sway_radians: float = 0.0


var _targets: Array[WindTarget] = []
var _random := RandomNumberGenerator.new()
var _elapsed_time: float = 0.0
var _update_accumulator: float = 0.0
var _gust_time_remaining: float = 0.0
var _gust_strength: float = 0.5
var _target_gust_strength: float = 0.5
var _wind_angle: float = 0.0
var _target_wind_angle: float = 0.0


func _ready() -> void:
	if random_seed == 0:
		_random.randomize()
	else:
		_random.seed = random_seed
	_wind_angle = _random.randf_range(0.0, TAU)
	_target_wind_angle = _wind_angle
	_choose_next_gust()
	call_deferred("refresh_targets")


func _process(delta: float) -> void:
	_elapsed_time += delta
	_update_gust(delta)

	if _targets.is_empty():
		return

	_update_accumulator += delta
	var update_interval := 1.0 / maxf(update_rate_hz, 1.0)
	if _update_accumulator < update_interval:
		return
	_update_accumulator = fmod(_update_accumulator, update_interval)
	_apply_wind()


func refresh_targets() -> void:
	_targets.clear()
	if target_root == null:
		return

	for candidate: Node in target_root.find_children(
		"*",
		"MultiMeshInstance3D",
		true,
		false
	):
		var multimesh_instance := candidate as MultiMeshInstance3D
		if multimesh_instance == null or multimesh_instance.multimesh == null:
			continue
		var maximum_sway := _get_maximum_sway(multimesh_instance)
		if maximum_sway <= 0.0:
			continue
		_targets.append(_create_target(multimesh_instance, maximum_sway))


func _create_target(
	multimesh_instance: MultiMeshInstance3D,
	maximum_sway: float
) -> WindTarget:
	var target := WindTarget.new()
	target.instance = multimesh_instance
	target.maximum_sway_radians = maximum_sway
	var multimesh := multimesh_instance.multimesh
	target.phases.resize(multimesh.instance_count)
	for index: int in multimesh.instance_count:
		target.base_transforms.append(multimesh.get_instance_transform(index))
		target.phases[index] = _random.randf_range(0.0, TAU)
	return target


func _get_maximum_sway(multimesh_instance: MultiMeshInstance3D) -> float:
	var source_name := multimesh_instance.name.to_lower()
	var mesh := multimesh_instance.multimesh.mesh
	if mesh != null:
		source_name += " " + mesh.resource_path.to_lower()

	if source_name.contains("bush") or source_name.contains("shrub"):
		return deg_to_rad(1.8)
	if (
		source_name.contains("fern")
		or source_name.contains("plant")
		or source_name.contains("grass")
	):
		return deg_to_rad(2.4)
	if source_name.contains("tree") or source_name.contains("pine"):
		return deg_to_rad(0.45)
	return 0.0


func _update_gust(delta: float) -> void:
	_gust_time_remaining -= delta
	if _gust_time_remaining <= 0.0:
		_choose_next_gust()

	var gust_blend := 1.0 - exp(-delta * 0.9)
	_gust_strength = lerpf(_gust_strength, _target_gust_strength, gust_blend)
	var direction_blend := 1.0 - exp(-delta * 0.35)
	_wind_angle = lerp_angle(_wind_angle, _target_wind_angle, direction_blend)


func _choose_next_gust() -> void:
	var lower_strength := minf(minimum_gust, maximum_gust)
	var upper_strength := maxf(minimum_gust, maximum_gust)
	_target_gust_strength = _random.randf_range(lower_strength, upper_strength)
	_target_wind_angle = _wind_angle + _random.randf_range(-0.65, 0.65)
	var lower_duration := minf(minimum_gust_duration, maximum_gust_duration)
	var upper_duration := maxf(minimum_gust_duration, maximum_gust_duration)
	_gust_time_remaining = _random.randf_range(lower_duration, upper_duration)


func _apply_wind() -> void:
	var wind_direction := Vector3(cos(_wind_angle), 0.0, sin(_wind_angle))
	var bend_axis := Vector3(-wind_direction.z, 0.0, wind_direction.x).normalized()
	var slow_wave := 0.78 + sin(_elapsed_time * 0.55) * 0.22
	var effective_strength := base_strength * _gust_strength * slow_wave

	for target: WindTarget in _targets:
		if not is_instance_valid(target.instance) or target.instance.multimesh == null:
			continue
		var multimesh := target.instance.multimesh
		for index: int in target.base_transforms.size():
			var phase := target.phases[index]
			var wave := sin(_elapsed_time * 1.15 + phase)
			wave += sin(_elapsed_time * 2.35 + phase * 1.7) * 0.3
			var sway_angle := (
				wave
				* target.maximum_sway_radians
				* effective_strength
				/ 1.3
			)
			var animated_transform := target.base_transforms[index]
			animated_transform.basis = (
				Basis(bend_axis, sway_angle)
				* target.base_transforms[index].basis
			)
			multimesh.set_instance_transform(index, animated_transform)
