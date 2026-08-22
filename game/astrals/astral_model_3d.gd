class_name AstralModel3D
extends Node3D

@export_range(0.25, 5.0, 0.05) var target_height: float = 2.4
@export_flags_3d_render var render_layers: int = 2

var displayed_definition: AstralDefinition = null
var _animation_root: Node3D = null
var _animation_tween: Tween = null
var _model: Node3D = null


func show_astral(astral: AstralInstance) -> void:
	show_definition(astral.definition if astral != null else null)


func show_definition(definition: AstralDefinition) -> void:
	_clear_model()
	displayed_definition = definition
	if definition == null:
		return
	# I test headless verificano dati e combattimento senza importare centinaia
	# di MB di mesh. Nel gioco reale viene sempre istanziato il GLB assegnato.
	if DisplayServer.get_name() == "headless":
		return
	_animation_root = Node3D.new()
	_animation_root.name = "AnimationRoot"
	add_child(_animation_root)
	var scene := definition.get_model_scene()
	if scene == null:
		_create_fallback(definition.visual_color)
		return
	_model = scene.instantiate() as Node3D
	if _model == null:
		_create_fallback(definition.visual_color)
		return
	_disable_normal_maps_without_tangents(_model)
	_animation_root.add_child(_model)
	_model.rotation_degrees = definition.model_rotation_degrees
	_set_render_layers(_model)
	_normalize_model(definition.model_scale_multiplier)


func play_entry_animation() -> Tween:
	if not _can_animate():
		return null
	var tween := _create_animation_tween()
	_animation_root.position = Vector3(0.0, 0.85, 0.0)
	_animation_root.rotation_degrees = Vector3(0.0, -18.0, -8.0)
	_animation_root.scale = Vector3(0.28, 0.08, 0.28)
	tween.tween_property(
		_animation_root, "position", Vector3.ZERO, 0.48
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		_animation_root, "rotation_degrees", Vector3.ZERO, 0.48
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		_animation_root, "scale", Vector3(1.08, 0.9, 1.08), 0.48
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		_animation_root, "scale", Vector3.ONE, 0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween


func play_attack_animation(target_global_position: Vector3) -> Tween:
	if not _can_animate():
		return null
	var local_direction := to_local(target_global_position)
	local_direction.y = 0.0
	if local_direction.length_squared() < 0.001:
		local_direction = Vector3.FORWARD
	local_direction = local_direction.normalized()
	var lunge_offset := local_direction * 0.82
	var recoil_offset := local_direction * -0.12
	var tilt := -6.0 * signf(local_direction.x)
	var tween := _create_animation_tween()
	tween.tween_property(
		_animation_root, "position", recoil_offset, 0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		_animation_root, "scale", Vector3(1.08, 0.78, 1.08), 0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		_animation_root, "position", lunge_offset + Vector3.UP * 0.12, 0.15
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(
		_animation_root, "scale", Vector3(0.92, 1.12, 0.92), 0.15
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(
		_animation_root, "rotation_degrees", Vector3(0.0, 0.0, tilt), 0.15
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(
		_animation_root, "position", Vector3.ZERO, 0.24
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		_animation_root, "scale", Vector3.ONE, 0.24
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		_animation_root, "rotation_degrees", Vector3.ZERO, 0.24
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween


func play_grimoire_animation() -> Tween:
	if not _can_animate():
		return null
	var tween := _create_animation_tween()
	tween.set_loops()
	tween.tween_property(
		_animation_root, "position", Vector3(0.0, 0.1, 0.0), 0.72
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		_animation_root, "rotation_degrees", Vector3(1.5, 7.0, 2.0), 0.72
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		_animation_root, "scale", Vector3(1.025, 0.975, 1.025), 0.72
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		_animation_root, "position", Vector3(0.0, 0.025, 0.0), 0.9
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		_animation_root, "rotation_degrees", Vector3(-1.0, -7.0, -2.0), 0.9
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		_animation_root, "scale", Vector3(0.99, 1.015, 0.99), 0.9
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		_animation_root, "position", Vector3.ZERO, 0.72
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		_animation_root, "rotation_degrees", Vector3.ZERO, 0.72
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		_animation_root, "scale", Vector3.ONE, 0.72
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


func stop_animation() -> void:
	if _animation_tween != null and _animation_tween.is_valid():
		_animation_tween.kill()
	_animation_tween = null
	_reset_animation_root()


func _normalize_model(scale_multiplier: float) -> void:
	if _model == null:
		return
	var combined_aabb := AABB()
	var has_bounds := false
	for candidate: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform := _model.global_transform.affine_inverse() * mesh_instance.global_transform
		var transformed_aabb: AABB = relative_transform * mesh_instance.get_aabb()
		combined_aabb = (
			combined_aabb.merge(transformed_aabb)
			if has_bounds
			else transformed_aabb
		)
		has_bounds = true
	if not has_bounds:
		return
	var source_height := maxf(combined_aabb.size.y, 0.001)
	var source_width := maxf(combined_aabb.size.x, combined_aabb.size.z)
	var height_scale := target_height / source_height
	var width_scale := 3.2 / maxf(source_width, 0.001)
	var uniform_scale := minf(height_scale, width_scale) * maxf(scale_multiplier, 0.01)
	_model.scale = Vector3.ONE * uniform_scale
	var center := combined_aabb.get_center()
	_model.position = Vector3(
		-center.x * uniform_scale,
		-combined_aabb.position.y * uniform_scale,
		-center.z * uniform_scale
	)


func _disable_normal_maps_without_tangents(root_node: Node) -> void:
	if root_node is MeshInstance3D:
		var mesh_instance := root_node as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh != null:
			for surface_index: int in mesh.get_surface_count():
				var surface_format: int = mesh.surface_get_format(surface_index)
				if surface_format & Mesh.ARRAY_FORMAT_TANGENT:
					continue
				var material := mesh_instance.get_surface_override_material(
					surface_index
				)
				if material == null:
					material = mesh.surface_get_material(surface_index)
				var base_material := material as BaseMaterial3D
				if base_material == null or not base_material.normal_enabled:
					continue
				var safe_material := base_material.duplicate() as BaseMaterial3D
				safe_material.normal_enabled = false
				mesh_instance.set_surface_override_material(
					surface_index,
					safe_material
				)
	for child: Node in root_node.get_children():
		_disable_normal_maps_without_tangents(child)


func _set_render_layers(root_node: Node) -> void:
	if root_node is VisualInstance3D:
		(root_node as VisualInstance3D).layers = render_layers
	for child: Node in root_node.get_children():
		_set_render_layers(child)


func _create_fallback(color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.65
	capsule.height = 2.2
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	capsule.material = material
	mesh_instance.mesh = capsule
	mesh_instance.position.y = 1.1
	mesh_instance.layers = render_layers
	_model = mesh_instance
	_animation_root.add_child(_model)


func _clear_model() -> void:
	stop_animation()
	if _animation_root != null and is_instance_valid(_animation_root):
		_animation_root.queue_free()
	_animation_root = null
	_model = null


func _can_animate() -> bool:
	return (
		displayed_definition != null
		and _animation_root != null
		and is_instance_valid(_animation_root)
	)


func _create_animation_tween() -> Tween:
	stop_animation()
	var tween := create_tween()
	_animation_tween = tween
	tween.finished.connect(_on_animation_finished.bind(tween), CONNECT_ONE_SHOT)
	return tween


func _on_animation_finished(finished_tween: Tween) -> void:
	if _animation_tween == finished_tween:
		_animation_tween = null


func _reset_animation_root() -> void:
	if _animation_root == null or not is_instance_valid(_animation_root):
		return
	_animation_root.position = Vector3.ZERO
	_animation_root.rotation_degrees = Vector3.ZERO
	_animation_root.scale = Vector3.ONE
