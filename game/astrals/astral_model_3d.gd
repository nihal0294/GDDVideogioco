class_name AstralModel3D
extends Node3D

@export_range(0.25, 5.0, 0.05) var target_height: float = 2.4
@export_flags_3d_render var render_layers: int = 2

var displayed_definition: AstralDefinition = null
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
	var scene := definition.get_model_scene()
	if scene == null:
		_create_fallback(definition.visual_color)
		return
	_model = scene.instantiate() as Node3D
	if _model == null:
		_create_fallback(definition.visual_color)
		return
	_disable_normal_maps_without_tangents(_model)
	add_child(_model)
	_model.rotation_degrees = definition.model_rotation_degrees
	_set_render_layers(_model)
	_normalize_model(definition.model_scale_multiplier)


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
	add_child(_model)


func _clear_model() -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = null
