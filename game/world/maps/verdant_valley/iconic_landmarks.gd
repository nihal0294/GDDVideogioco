class_name IconicLandmarks
extends Node3D

signal wild_encounter_triggered(zone_id: StringName, actor: Node3D)

const ENCOUNTER_ZONE_SCRIPT := preload(
	"res://game/world/encounters/tall_grass_encounter_zone.gd"
)
const NATURE_ASSET_ROOT := "res://assets/maps/stylized_nature_megakit"
const RED_CLEARING_CENTER := Vector2(-36.0, -27.0)
const POND_CENTER := Vector2(38.0, -32.0)
const FALLEN_GROVE_CENTER := Vector2(-34.0, 37.0)
const ROAD_START := Vector2(3.0, 3.0)
const GRASS_CLUSTERS := [
	{"center": Vector2(-13.0, -14.0), "size": Vector2(15.0, 12.0)},
	{"center": Vector2(3.0, -14.0), "size": Vector2(15.0, 12.0)},
	{"center": Vector2(-5.0, -27.0), "size": Vector2(18.0, 12.0)},
	{"center": Vector2(-34.0, 40.0), "size": Vector2(15.0, 11.0)},
	{"center": Vector2(52.0, 8.0), "size": Vector2(12.0, 10.0)},
]


class GrassAsset:
	extends RefCounted

	var mesh: Mesh
	var source_transform := Transform3D.IDENTITY

@export_range(0.6, 2.0, 0.05) var tall_grass_spacing: float = 1.0
@export_range(8, 40, 1) var red_tree_count: int = 22
@export_range(20, 120, 1) var pond_flower_count: int = 64
@export var random_seed: int = 52041
@export_group("Wild Encounters")
@export_range(0.0, 1.0, 0.01) var encounter_probability: float = 0.12
@export_range(0.25, 10.0, 0.25) var encounter_check_distance: float = 1.5
@export_range(0.0, 30.0, 0.5) var encounter_cooldown: float = 5.0
@export_group("")

var _map_root: Node3D
var _vegetation_root: Node3D
var _landmark_collisions: StaticBody3D
var _random := RandomNumberGenerator.new()
var _trunk_material: StandardMaterial3D
var _red_foliage_material: StandardMaterial3D
var _road_material: StandardMaterial3D
var _water_material: StandardMaterial3D
var _shore_material: StandardMaterial3D
var _log_material: StandardMaterial3D
var _grass_material: StandardMaterial3D
var _flower_materials: Array[StandardMaterial3D] = []
var _removed_visual_positions: Array[Vector2] = []
var _removed_collidable_positions: Array[Vector2] = []


func _ready() -> void:
	_map_root = get_parent() as Node3D
	if _map_root == null:
		queue_free()
		return
	_vegetation_root = _map_root.get_node_or_null("Vegetation") as Node3D
	_random.seed = random_seed
	_create_materials()
	_create_collision_container()
	_clear_landmark_areas()
	call_deferred("_build_landmarks")


func _build_landmarks() -> void:
	await get_tree().physics_frame
	_build_road()
	_build_red_clearing()
	_build_fallen_grove()
	_build_tall_grass_fields()
	_build_pond_and_flowers()
	var wind_controller := _map_root.get_node_or_null("VegetationWind")
	if wind_controller != null and wind_controller.has_method("refresh_targets"):
		wind_controller.refresh_targets()


func _create_materials() -> void:
	_trunk_material = _make_material(Color("70462f"), 0.92)
	_red_foliage_material = _make_material(Color("b92f3d"), 0.82)
	_road_material = _make_material(Color("b9996a"), 1.0)
	_water_material = _make_material(Color(0.08, 0.42, 0.63, 0.82), 0.22)
	_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_material.metallic = 0.08
	_shore_material = _make_material(Color("82745c"), 1.0)
	_log_material = _make_material(Color("5b3929"), 1.0)
	_grass_material = _make_material(Color("557c38"), 0.95)
	for color: Color in [
		Color("f35b74"),
		Color("ffd45f"),
		Color("8d71df"),
		Color("f28bc4"),
		Color("f4f2e8"),
	]:
		_flower_materials.append(_make_material(color, 0.85))


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _create_collision_container() -> void:
	_landmark_collisions = StaticBody3D.new()
	_landmark_collisions.name = "LandmarkCollisions"
	_landmark_collisions.collision_layer = 1
	_landmark_collisions.collision_mask = 0
	add_child(_landmark_collisions)


func _clear_landmark_areas() -> void:
	_clear_multimesh_instances()
	_clear_collision_shapes()
	_clear_interactables()


func _clear_multimesh_instances() -> void:
	if _vegetation_root == null:
		return
	_removed_visual_positions.clear()
	_removed_collidable_positions.clear()
	for candidate: Node in _vegetation_root.find_children(
		"*",
		"MultiMeshInstance3D",
		true,
		false
	):
		var instance := candidate as MultiMeshInstance3D
		if instance == null or instance.multimesh == null:
			continue
		var represents_solid_prop := _multimesh_represents_solid_prop(instance)
		for index: int in instance.multimesh.instance_count:
			var item_transform := instance.multimesh.get_instance_transform(index)
			var local_position := _map_root.to_local(instance.to_global(item_transform.origin))
			if not _should_clear(Vector2(local_position.x, local_position.z)):
				continue
			var removed_position := Vector2(local_position.x, local_position.z)
			_removed_visual_positions.append(removed_position)
			if represents_solid_prop:
				_removed_collidable_positions.append(removed_position)
			item_transform.origin.y -= 200.0
			instance.multimesh.set_instance_transform(index, item_transform)


func _clear_collision_shapes() -> void:
	var collision_root := _map_root.get_node_or_null("PropCollisions")
	if collision_root == null:
		return
	for candidate: Node in collision_root.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		var local_position := _map_root.to_local(collision.global_position)
		if _has_position_near(
			Vector2(local_position.x, local_position.z),
			_removed_collidable_positions
		):
			collision.set_deferred("disabled", true)


func _clear_interactables() -> void:
	var interactables_root := _map_root.get_node_or_null("Interactables")
	if interactables_root == null:
		return
	for candidate: Node in interactables_root.get_children():
		var area := candidate as Area3D
		if area == null:
			continue
		var local_position := _map_root.to_local(area.global_position)
		if _has_position_near(
			Vector2(local_position.x, local_position.z),
			_removed_visual_positions
		):
			area.monitoring = false
			area.monitorable = false


func _multimesh_represents_solid_prop(instance: MultiMeshInstance3D) -> bool:
	var source_name := instance.name.to_lower()
	if instance.multimesh.mesh != null:
		source_name += " " + instance.multimesh.mesh.resource_path.to_lower()
	for marker: String in ["tree", "pine", "rock", "stone", "stump", "log"]:
		if source_name.contains(marker):
			return true
	return false


func _has_position_near(
	point: Vector2,
	positions: Array[Vector2],
	tolerance: float = 1.25
) -> bool:
	var tolerance_squared := tolerance * tolerance
	for removed_position: Vector2 in positions:
		if point.distance_squared_to(removed_position) <= tolerance_squared:
			return true
	return false


func _should_clear(point: Vector2) -> bool:
	if point.distance_to(RED_CLEARING_CENTER) < 19.0:
		return true
	if point.distance_to(POND_CENTER) < 15.0:
		return true
	if point.distance_to(FALLEN_GROVE_CENTER) < 18.0:
		return true
	for cluster: Dictionary in GRASS_CLUSTERS:
		var center: Vector2 = cluster["center"]
		var size: Vector2 = cluster["size"]
		var offset := point - center
		if absf(offset.x) <= size.x * 0.5 + 1.0 and absf(offset.y) <= size.y * 0.5 + 1.0:
			return true
	return _distance_to_segment(point, ROAD_START, POND_CENTER) < 3.4


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.001:
		return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / segment_length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * amount)


func _build_road() -> void:
	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(2.7, 0.08, 2.1)
	var control := Vector2(22.0, -4.0)
	var segment_count := 25
	for index: int in segment_count:
		var amount := float(index) / float(segment_count - 1)
		var point := _quadratic_curve(ROAD_START, control, POND_CENTER, amount)
		var next_point := _quadratic_curve(
			ROAD_START,
			control,
			POND_CENTER,
			minf(amount + 0.03, 1.0)
		)
		var tangent := (next_point - point).normalized()
		var ground_height := _ground_height(point)
		var road_piece := _create_mesh_instance(
			road_mesh,
			_road_material,
			Vector3(point.x, ground_height + 0.05, point.y),
			"Road_%02d" % index
		)
		road_piece.rotation.y = atan2(tangent.x, tangent.y)


func _quadratic_curve(
	start: Vector2,
	control: Vector2,
	end: Vector2,
	amount: float
) -> Vector2:
	var inverse := 1.0 - amount
	return inverse * inverse * start + 2.0 * inverse * amount * control + amount * amount * end


func _build_red_clearing() -> void:
	for index: int in red_tree_count:
		var angle := TAU * float(index) / float(red_tree_count)
		angle += _random.randf_range(-0.09, 0.09)
		var radius := _random.randf_range(13.0, 18.0)
		var point := RED_CLEARING_CENTER + Vector2(cos(angle), sin(angle)) * radius
		_create_red_tree(point, _random.randf_range(0.85, 1.2), index)


func _create_red_tree(point: Vector2, tree_scale: float, index: int) -> void:
	var ground_height := _ground_height(point)
	var tree := Node3D.new()
	tree.name = "RedTree_%02d" % index
	tree.position = Vector3(point.x, ground_height, point.y)
	tree.scale = Vector3.ONE * tree_scale
	add_child(tree)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.height = 3.8
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.38
	trunk_mesh.radial_segments = 8
	_create_mesh_instance(
		trunk_mesh,
		_trunk_material,
		Vector3(0.0, 1.9, 0.0),
		"Trunk",
		tree
	)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	for crown_data: Dictionary in [
		{"position": Vector3(0.0, 4.25, 0.0), "scale": Vector3(1.65, 1.35, 1.65)},
		{"position": Vector3(-0.8, 3.85, 0.2), "scale": Vector3(1.05, 1.0, 1.05)},
		{"position": Vector3(0.75, 3.95, -0.25), "scale": Vector3(1.0, 1.1, 1.0)},
	]:
		var crown_position: Vector3 = crown_data["position"]
		var crown_scale: Vector3 = crown_data["scale"]
		var crown := _create_mesh_instance(
			crown_mesh,
			_red_foliage_material,
			crown_position,
			"Crown",
			tree
		)
		crown.scale = crown_scale

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.42 * tree_scale
	shape.height = 3.8 * tree_scale
	collision.shape = shape
	collision.position = Vector3(point.x, ground_height + shape.height * 0.5, point.y)
	_landmark_collisions.add_child(collision)


func _build_fallen_grove() -> void:
	var log_mesh := CylinderMesh.new()
	log_mesh.height = 5.5
	log_mesh.top_radius = 0.42
	log_mesh.bottom_radius = 0.55
	log_mesh.radial_segments = 10
	for index: int in 7:
		var angle := _random.randf_range(0.0, TAU)
		var radius := _random.randf_range(3.0, 15.0)
		var point := FALLEN_GROVE_CENTER + Vector2(cos(angle), sin(angle)) * radius
		var ground_height := _ground_height(point)
		var fallen_log := _create_mesh_instance(
			log_mesh,
			_log_material,
			Vector3(point.x, ground_height + 0.55, point.y),
			"FallenTree_%02d" % index
		)
		fallen_log.rotation = Vector3(0.0, angle, PI * 0.5)

		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.5
		shape.height = 5.5
		collision.shape = shape
		collision.position = fallen_log.position
		collision.rotation = fallen_log.rotation
		_landmark_collisions.add_child(collision)


func _build_pond_and_flowers() -> void:
	var center_height := _ground_height(POND_CENTER)
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.16
	flower_mesh.height = 0.32
	var stem_mesh := CylinderMesh.new()
	stem_mesh.height = 0.36
	stem_mesh.top_radius = 0.025
	stem_mesh.bottom_radius = 0.035
	stem_mesh.radial_segments = 6
	for index: int in pond_flower_count:
		var angle := _random.randf_range(0.0, TAU)
		var radius := _random.randf_range(10.0, 13.2)
		var point := POND_CENTER + Vector2(cos(angle), sin(angle)) * radius
		var ground_height := _ground_height(point)
		var flower := Node3D.new()
		flower.name = "Flower_%02d" % index
		flower.position = Vector3(point.x, ground_height, point.y)
		add_child(flower)
		_create_mesh_instance(
			stem_mesh,
			_grass_material,
			Vector3(0.0, 0.18, 0.0),
			"Stem",
			flower
		)
		_create_mesh_instance(
			flower_mesh,
			_flower_materials[index % _flower_materials.size()],
			Vector3(0.0, 0.42, 0.0),
			"Bloom",
			flower
		)

	var shore_mesh := TorusMesh.new()
	shore_mesh.inner_radius = 8.8
	shore_mesh.outer_radius = 10.0
	shore_mesh.rings = 36
	shore_mesh.ring_segments = 10
	_create_mesh_instance(
		shore_mesh,
		_shore_material,
		Vector3(POND_CENTER.x, center_height + 0.02, POND_CENTER.y),
		"PondShore"
	)
	var water_mesh := CylinderMesh.new()
	water_mesh.height = 0.12
	water_mesh.top_radius = 8.9
	water_mesh.bottom_radius = 8.9
	water_mesh.radial_segments = 48
	_create_mesh_instance(
		water_mesh,
		_water_material,
		Vector3(POND_CENTER.x, center_height + 0.08, POND_CENTER.y),
		"PondWater"
	)

	var pond_collision := CollisionShape3D.new()
	var pond_shape := CylinderShape3D.new()
	pond_shape.radius = 8.7
	pond_shape.height = 1.5
	pond_collision.shape = pond_shape
	pond_collision.position = Vector3(
		POND_CENTER.x,
		center_height + pond_shape.height * 0.5,
		POND_CENTER.y
	)
	_landmark_collisions.add_child(pond_collision)


func _build_tall_grass_fields() -> void:
	var grass_asset := _find_tall_grass_asset()
	var using_fallback_mesh := grass_asset == null
	if grass_asset == null:
		var fallback_mesh := BoxMesh.new()
		fallback_mesh.size = Vector3(0.12, 1.0, 0.28)
		grass_asset = GrassAsset.new()
		grass_asset.mesh = fallback_mesh
	var mesh_bounds := _transformed_aabb(
		grass_asset.mesh.get_aabb(),
		grass_asset.source_transform
	)
	var normalization_scale := 1.0
	if mesh_bounds.size.y > 0.001:
		normalization_scale = clampf(1.15 / mesh_bounds.size.y, 0.08, 5.0)

	for cluster_index: int in GRASS_CLUSTERS.size():
		var cluster: Dictionary = GRASS_CLUSTERS[cluster_index]
		var center: Vector2 = cluster["center"]
		var size: Vector2 = cluster["size"]
		var columns := maxi(int(floor(size.x / tall_grass_spacing)), 1)
		var rows := maxi(int(floor(size.y / tall_grass_spacing)), 1)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = grass_asset.mesh
		multimesh.instance_count = columns * rows
		var instance_index := 0
		for column: int in columns:
			for row: int in rows:
				var point := center + Vector2(
					(float(column) + 0.5) * tall_grass_spacing - size.x * 0.5,
					(float(row) + 0.5) * tall_grass_spacing - size.y * 0.5
				)
				point += Vector2(
					_random.randf_range(-0.25, 0.25),
					_random.randf_range(-0.25, 0.25)
				)
				var individual_scale := normalization_scale * _random.randf_range(0.85, 1.18)
				var grass_basis := Basis(Vector3.UP, _random.randf_range(0.0, TAU))
				grass_basis = grass_basis.scaled(Vector3.ONE * individual_scale)
				var ground_height := _ground_height(point)
				var bottom_offset := mesh_bounds.position.y * individual_scale
				var placement_transform := Transform3D(
					grass_basis,
					Vector3(point.x, ground_height - bottom_offset, point.y)
				)
				multimesh.set_instance_transform(
					instance_index,
					placement_transform * grass_asset.source_transform
				)
				instance_index += 1

		var grass_instance := MultiMeshInstance3D.new()
		grass_instance.name = "TallGrass_%02d" % cluster_index
		grass_instance.multimesh = multimesh
		if using_fallback_mesh:
			grass_instance.material_override = _grass_material
		if _vegetation_root != null:
			_vegetation_root.add_child(grass_instance)
		else:
			add_child(grass_instance)
		_create_encounter_zone(cluster_index, center, size, grass_instance)


func _create_encounter_zone(
	cluster_index: int,
	center: Vector2,
	size: Vector2,
	grass_instance: MultiMeshInstance3D
) -> void:
	var area := ENCOUNTER_ZONE_SCRIPT.new()
	area.name = "TallGrassEncounter_%02d" % cluster_index
	area.zone_id = StringName("tall_grass_%02d" % cluster_index)
	area.grass_visual = grass_instance
	area.player = _find_player()
	area.encounter_probability = encounter_probability
	area.distance_per_encounter_check = encounter_check_distance
	area.encounter_cooldown = encounter_cooldown
	area.encounter_triggered.connect(_on_wild_encounter_triggered)
	var half_size := size * 0.5
	var sample_offsets: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(-half_size.x, half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, 0.0),
		Vector2(half_size.x, 0.0),
		Vector2(0.0, -half_size.y),
		Vector2(0.0, half_size.y),
	]
	var minimum_ground_height := _ground_height(center)
	var maximum_ground_height := minimum_ground_height
	for offset: Vector2 in sample_offsets:
		var sample_height := _ground_height(center + offset)
		minimum_ground_height = minf(minimum_ground_height, sample_height)
		maximum_ground_height = maxf(maximum_ground_height, sample_height)
	var collision_height := maxf(
		4.0,
		maximum_ground_height - minimum_ground_height + 4.0
	)
	area.position = Vector3(
		center.x,
		(minimum_ground_height + maximum_ground_height) * 0.5 + 1.5,
		center.y
	)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, collision_height, size.y)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)


func _find_player() -> CharacterBody3D:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	var named_player := scene_root.get_node_or_null("Player") as CharacterBody3D
	if named_player != null:
		return named_player
	var grouped_player := get_tree().get_first_node_in_group("player")
	if grouped_player is CharacterBody3D:
		return grouped_player as CharacterBody3D
	for candidate: Node in scene_root.find_children(
		"*",
		"CharacterBody3D",
		true,
		false
	):
		return candidate as CharacterBody3D
	return null


func _on_wild_encounter_triggered(zone_id: StringName, actor: Node3D) -> void:
	wild_encounter_triggered.emit(zone_id, actor)


func _find_tall_grass_asset() -> GrassAsset:
	var resource_path := _find_tall_grass_resource(NATURE_ASSET_ROOT)
	if resource_path.is_empty():
		return null
	var resource := load(resource_path)
	if resource is Mesh:
		var mesh_asset := GrassAsset.new()
		mesh_asset.mesh = resource as Mesh
		return mesh_asset
	if not (resource is PackedScene):
		return null
	var temporary := (resource as PackedScene).instantiate()
	var mesh_instance := temporary as MeshInstance3D
	if mesh_instance == null:
		var meshes := temporary.find_children("*", "MeshInstance3D", true, false)
		if not meshes.is_empty():
			mesh_instance = meshes.front() as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		temporary.free()
		return null
	var grass_asset := GrassAsset.new()
	grass_asset.mesh = mesh_instance.mesh
	grass_asset.source_transform = _transform_relative_to_root(mesh_instance, temporary)
	temporary.free()
	return grass_asset


func _transform_relative_to_root(node: Node3D, root: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	if root is Node3D:
		result = (root as Node3D).transform * result
	return result


func _transformed_aabb(source: AABB, transform_3d: Transform3D) -> AABB:
	var result := AABB()
	for corner_index: int in 8:
		var corner := source.position + Vector3(
			source.size.x if (corner_index & 1) != 0 else 0.0,
			source.size.y if (corner_index & 2) != 0 else 0.0,
			source.size.z if (corner_index & 4) != 0 else 0.0
		)
		var transformed_corner := transform_3d * corner
		if corner_index == 0:
			result = AABB(transformed_corner, Vector3.ZERO)
		else:
			result = result.expand(transformed_corner)
	return result


func _find_tall_grass_resource(directory_path: String) -> String:
	var candidates: Array[String] = []
	_collect_tall_grass_resources(directory_path, candidates)
	var best_path := ""
	var best_score := -1
	for candidate_path: String in candidates:
		var score := _grass_resource_score(candidate_path)
		if score > best_score:
			best_score = score
			best_path = candidate_path
	return best_path


func _collect_tall_grass_resources(
	directory_path: String,
	candidates: Array[String]
) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if not entry_name.begins_with("."):
			var entry_path := directory_path.path_join(entry_name)
			if directory.current_is_dir():
				_collect_tall_grass_resources(entry_path, candidates)
			else:
				var lowered_name := entry_name.to_lower()
				var extension := entry_name.get_extension().to_lower()
				var supported := extension in ["tscn", "scn", "glb", "gltf", "fbx"]
				var is_tall_grass := (
					lowered_name.contains("tall_grass")
					or lowered_name.contains("grass_tall")
					or (
						lowered_name.contains("tall")
						and lowered_name.contains("grass")
					)
				)
				if supported and is_tall_grass:
					candidates.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _grass_resource_score(resource_path: String) -> int:
	var extension := resource_path.get_extension().to_lower()
	var extension_scores := {
		"glb": 60,
		"gltf": 55,
		"tscn": 50,
		"scn": 45,
		"fbx": 10,
	}
	var score: int = extension_scores.get(extension, 0)
	var lowered_path := resource_path.replace("\\", "/").to_lower()
	if lowered_path.contains("/gltf/") or lowered_path.contains("/glb/"):
		score += 20
	if resource_path.get_file().get_basename().to_lower() == "grass_common_tall":
		score += 5
	return score


func _ground_height(point: Vector2) -> float:
	if _map_root != null and _map_root.has_method("get_terrain_height"):
		return float(
			_map_root.call("get_terrain_height", point.x, point.y)
		)
	if not is_inside_tree():
		return 0.0
	var from := _map_root.to_global(Vector3(point.x, 60.0, point.y))
	var to := _map_root.to_global(Vector3(point.x, -40.0, point.y))
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	var hit_position: Vector3 = hit["position"]
	return _map_root.to_local(hit_position).y


func _create_mesh_instance(
	mesh: Mesh,
	material: Material,
	local_position: Vector3,
	node_name: String,
	parent: Node3D = null
) -> MeshInstance3D:
	if parent == null:
		parent = self
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = local_position
	parent.add_child(instance)
	return instance
