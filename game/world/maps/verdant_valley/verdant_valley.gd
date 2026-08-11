class_name VerdantValley
extends Node3D

@warning_ignore_start("shadowed_variable_base_class")

signal wild_encounter_requested(zone_id: StringName, actor: Node3D)

const VEGETATION_WIND_SCRIPT := preload(
	"res://game/world/environment/vegetation_wind.gd"
)
const DAY_NIGHT_CYCLE_SCRIPT := preload(
	"res://game/world/environment/day_night_cycle.gd"
)
const ICONIC_LANDMARKS_SCRIPT := preload(
	"res://game/world/maps/verdant_valley/iconic_landmarks.gd"
)

@export_group("Wind")
@export_range(0.0, 2.0, 0.05) var wind_strength: float = 1.0
@export_range(5.0, 60.0, 1.0) var wind_update_rate_hz: float = 20.0
@export_range(0.5, 15.0, 0.5) var minimum_gust_duration: float = 2.0
@export_range(0.5, 15.0, 0.5) var maximum_gust_duration: float = 6.0
@export_group("")

@export_group("Time of Day")
@export_range(0.0, 23.99, 0.25) var starting_game_hour: float = 8.0
@export_range(1.0, 600.0, 1.0) var real_seconds_per_game_hour: float = 60.0
@export_group("")

@export_group("Wild Encounters")
@export_range(0.0, 1.0, 0.01) var wild_encounter_probability: float = 0.12
@export_range(0.25, 10.0, 0.25) var wild_encounter_check_distance: float = 1.5
@export_range(0.0, 30.0, 0.5) var wild_encounter_cooldown: float = 5.0
@export_group("")

signal generation_finished
signal map_object_interacted(
	object_id: StringName,
	category: StringName,
	interactor: Node3D
)
signal map_interactable_interacted(
	interactable: InteractableArea3D,
	interactor: Node3D
)

const KIT_PATH := "res://assets/maps/stylized_nature_megakit/glTF/"
const INTERACTABLE_SCENE: PackedScene = preload(
	"res://game/interaction/interactable_area_3d.tscn"
)
const INVALID_POSITION := Vector3(0.0, -10000.0, 0.0)
const MAX_PLACEMENT_ATTEMPTS := 120

const COMMON_TREES: Array[String] = [
	KIT_PATH + "CommonTree_1.gltf",
	KIT_PATH + "CommonTree_2.gltf",
	KIT_PATH + "CommonTree_3.gltf",
	KIT_PATH + "CommonTree_4.gltf",
	KIT_PATH + "CommonTree_5.gltf",
]
const PINES: Array[String] = [
	KIT_PATH + "Pine_1.gltf",
	KIT_PATH + "Pine_2.gltf",
	KIT_PATH + "Pine_3.gltf",
	KIT_PATH + "Pine_4.gltf",
	KIT_PATH + "Pine_5.gltf",
]
const TWISTED_TREES: Array[String] = [
	KIT_PATH + "TwistedTree_1.gltf",
	KIT_PATH + "TwistedTree_2.gltf",
	KIT_PATH + "TwistedTree_3.gltf",
	KIT_PATH + "TwistedTree_4.gltf",
	KIT_PATH + "TwistedTree_5.gltf",
]
const DEAD_TREES: Array[String] = [
	KIT_PATH + "DeadTree_1.gltf",
	KIT_PATH + "DeadTree_2.gltf",
	KIT_PATH + "DeadTree_3.gltf",
]
const ROCKS: Array[String] = [
	KIT_PATH + "Rock_Medium_1.gltf",
	KIT_PATH + "Rock_Medium_2.gltf",
	KIT_PATH + "Rock_Medium_3.gltf",
]
const BERRY_BUSHES: Array[String] = [
	KIT_PATH + "Bush_Common.gltf",
	KIT_PATH + "Bush_Common_Flowers.gltf",
]
const UNDERGROWTH: Array[String] = [
	KIT_PATH + "Fern_1.gltf",
	KIT_PATH + "Plant_1_Big.gltf",
	KIT_PATH + "Plant_7_Big.gltf",
]
const GROUND_COVER: Array[String] = [
	KIT_PATH + "Grass_Common_Short.gltf",
	KIT_PATH + "Grass_Common_Tall.gltf",
	KIT_PATH + "Grass_Wispy_Short.gltf",
	KIT_PATH + "Grass_Wispy_Tall.gltf",
	KIT_PATH + "Clover_1.gltf",
	KIT_PATH + "Clover_2.gltf",
	KIT_PATH + "Flower_3_Group.gltf",
	KIT_PATH + "Flower_4_Group.gltf",
	KIT_PATH + "Plant_1.gltf",
	KIT_PATH + "Plant_7.gltf",
]
const MUSHROOMS: Array[String] = [
	KIT_PATH + "Mushroom_Common.gltf",
	KIT_PATH + "Mushroom_Laetiporus.gltf",
]
const PATH_STONES: Array[String] = [
	KIT_PATH + "Pebble_Round_1.gltf",
	KIT_PATH + "Pebble_Round_2.gltf",
	KIT_PATH + "Pebble_Round_3.gltf",
	KIT_PATH + "Pebble_Round_4.gltf",
	KIT_PATH + "Pebble_Round_5.gltf",
	KIT_PATH + "RockPath_Round_Small_1.gltf",
	KIT_PATH + "RockPath_Round_Small_2.gltf",
	KIT_PATH + "RockPath_Round_Small_3.gltf",
]

const DIRT_COLOR := Color("b89a61")
const GRASS_COLOR := Color("72ad4d")
const DARK_GRASS_COLOR := Color("426f3d")
const MEADOW_COLOR := Color("91c955")

@export_group("Dimensioni")
@export var map_size := Vector2(150.0, 150.0)
@export_range(25.0, 75.0, 1.0) var chunk_size: float = 50.0
@export_range(1.0, 5.0, 0.5) var vertex_spacing: float = 2.0

@export_group("Generazione")
@export var generation_seed: int = 73129
@export_range(0, 300, 1) var tree_count: int = 155
@export_range(0, 300, 1) var shrub_count: int = 95
@export_range(0, 300, 1) var undergrowth_count: int = 70
@export_range(0, 1200, 10) var ground_cover_count: int = 650
@export_range(0, 150, 1) var rock_count: int = 45
@export_range(0, 150, 1) var mushroom_count: int = 55
@export_range(2.5, 10.0, 0.25) var minimum_tree_spacing: float = 4.75

@onready var terrain_container: Node3D = $GeneratedTerrain
@onready var vegetation_container: Node3D = $Vegetation
@onready var prop_collisions: StaticBody3D = $PropCollisions
@onready var boundary_collisions: StaticBody3D = $BoundaryVegetationCollisions
@onready var interactables_container: Node3D = $Interactables

var _height_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _distribution_noise := FastNoiseLite.new()
var _random := RandomNumberGenerator.new()
var _terrain_material := StandardMaterial3D.new()
var _model_transforms: Dictionary = {}
var _tree_positions: Array[Vector2] = []
var _rock_positions: Array[Vector2] = []


func _ready() -> void:
	_configure_generation()
	_generate_terrain()
	_scatter_nature()
	_setup_iconic_landmarks()
	_setup_vegetation_wind()
	_setup_day_night_cycle()
	_build_multimeshes()
	generation_finished.emit()


func get_spawn_position() -> Vector3:
	var spawn_z := map_size.y * 0.5 - 13.0
	var spawn_x := get_path_center_x(spawn_z)
	return Vector3(
		spawn_x,
		get_terrain_height(spawn_x, spawn_z) + 1.15,
		spawn_z
	)


func get_path_center_x(world_z: float) -> float:
	return sin(world_z * 0.058) * 8.0 + sin(world_z * 0.021 + 1.4) * 4.5


func get_terrain_height(world_x: float, world_z: float) -> float:
	var broad_height := _height_noise.get_noise_2d(world_x, world_z) * 3.6
	var detail_height := _detail_noise.get_noise_2d(world_x, world_z) * 1.15
	var height := broad_height + detail_height
	height += _get_landform_height(
		Vector2(world_x, world_z),
		Vector2(-43.0, -24.0),
		34.0,
		8.5
	)
	height += _get_landform_height(
		Vector2(world_x, world_z),
		Vector2(42.0, 31.0),
		30.0,
		6.0
	)
	height += _get_landform_height(
		Vector2(world_x, world_z),
		Vector2(49.0, -51.0),
		23.0,
		4.0
	)

	var half_size := map_size * 0.5
	var edge_distance := minf(
		half_size.x - absf(world_x),
		half_size.y - absf(world_z)
	)
	var edge_rise := 1.0 - smoothstep(2.0, 15.0, edge_distance)
	height += edge_rise * 5.5

	var path_distance := absf(world_x - get_path_center_x(world_z))
	var path_weight := 1.0 - smoothstep(2.4, 6.8, path_distance)
	var path_height := (
		0.35
		+ _height_noise.get_noise_2d(0.0, world_z * 0.42) * 1.15
	)
	height = lerpf(height, path_height, path_weight * 0.9)

	var clearing_weight := 1.0 - smoothstep(
		7.0,
		16.0,
		Vector2(world_x + 3.0, world_z + 5.0).length()
	)
	return lerpf(height, 1.2, clearing_weight * 0.82)


func get_generated_visual_count() -> int:
	var count := 0
	for transforms in _model_transforms.values():
		count += (transforms as Array).size()
	return count


func _setup_iconic_landmarks() -> void:
	var landmarks := ICONIC_LANDMARKS_SCRIPT.new()
	landmarks.name = "IconicLandmarks"
	landmarks.encounter_probability = wild_encounter_probability
	landmarks.encounter_check_distance = wild_encounter_check_distance
	landmarks.encounter_cooldown = wild_encounter_cooldown
	landmarks.wild_encounter_triggered.connect(_on_wild_encounter_triggered)
	add_child(landmarks)


func _on_wild_encounter_triggered(zone_id: StringName, actor: Node3D) -> void:
	wild_encounter_requested.emit(zone_id, actor)


func _setup_vegetation_wind() -> void:
	var vegetation_root := get_node_or_null("Vegetation") as Node3D
	if vegetation_root == null:
		return
	var wind_controller := VEGETATION_WIND_SCRIPT.new()
	wind_controller.name = "VegetationWind"
	wind_controller.target_root = vegetation_root
	wind_controller.base_strength = wind_strength
	wind_controller.update_rate_hz = wind_update_rate_hz
	wind_controller.minimum_gust_duration = minimum_gust_duration
	wind_controller.maximum_gust_duration = maximum_gust_duration
	add_child(wind_controller)


func _setup_day_night_cycle() -> void:
	var scene_root := get_parent()
	if scene_root == null or get_node_or_null("TimeOfDay") != null:
		return

	var sun: DirectionalLight3D
	var sun_nodes := scene_root.find_children("*", "DirectionalLight3D", true, false)
	if not sun_nodes.is_empty():
		sun = sun_nodes.front() as DirectionalLight3D
	var world_environment: WorldEnvironment
	var environment_nodes := scene_root.find_children("*", "WorldEnvironment", true, false)
	if not environment_nodes.is_empty():
		world_environment = environment_nodes.front() as WorldEnvironment
	var player := scene_root.get_node_or_null("Player") as Node3D
	if player == null:
		var player_nodes := scene_root.find_children("*", "CharacterBody3D", true, false)
		if not player_nodes.is_empty():
			player = player_nodes.front() as Node3D

	var day_night_cycle := DAY_NIGHT_CYCLE_SCRIPT.new()
	day_night_cycle.name = "TimeOfDay"
	day_night_cycle.sun = sun
	day_night_cycle.world_environment = world_environment
	day_night_cycle.player = player
	day_night_cycle.starting_hour = starting_game_hour
	day_night_cycle.real_seconds_per_game_hour = real_seconds_per_game_hour
	add_child(day_night_cycle)


func get_interactables() -> Array[InteractableArea3D]:
	var result: Array[InteractableArea3D] = []
	for child in interactables_container.get_children():
		var interactable := child as InteractableArea3D
		if interactable != null:
			result.append(interactable)
	return result


func _configure_generation() -> void:
	map_size.x = maxf(map_size.x, chunk_size)
	map_size.y = maxf(map_size.y, chunk_size)
	vertex_spacing = minf(vertex_spacing, chunk_size)
	_random.seed = generation_seed

	_height_noise.seed = generation_seed
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.frequency = 0.015
	_height_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_height_noise.fractal_octaves = 4

	_detail_noise.seed = generation_seed + 211
	_detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_detail_noise.frequency = 0.055
	_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail_noise.fractal_octaves = 2

	_distribution_noise.seed = generation_seed + 607
	_distribution_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_distribution_noise.frequency = 0.027
	_distribution_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_distribution_noise.fractal_octaves = 3

	_terrain_material.vertex_color_use_as_albedo = true
	_terrain_material.roughness = 0.94
	_terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _generate_terrain() -> void:
	var chunks_x := ceili(map_size.x / chunk_size)
	var chunks_z := ceili(map_size.y / chunk_size)
	var map_start := -map_size * 0.5

	for chunk_z in range(chunks_z):
		for chunk_x in range(chunks_x):
			var origin := Vector2(
				map_start.x + chunk_x * chunk_size,
				map_start.y + chunk_z * chunk_size
			)
			var size := Vector2(
				minf(chunk_size, map_size.x - chunk_x * chunk_size),
				minf(chunk_size, map_size.y - chunk_z * chunk_size)
			)
			_create_terrain_chunk(chunk_x, chunk_z, origin, size)


func _create_terrain_chunk(
	chunk_x: int,
	chunk_z: int,
	origin: Vector2,
	size: Vector2
) -> void:
	var segments_x := maxi(1, ceili(size.x / vertex_spacing))
	var segments_z := maxi(1, ceili(size.y / vertex_spacing))
	var step_x := size.x / segments_x
	var step_z := size.y / segments_z
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.set_material(_terrain_material)

	for z_index in range(segments_z + 1):
		for x_index in range(segments_x + 1):
			var local_x := x_index * step_x
			var local_z := z_index * step_z
			var world_x := origin.x + local_x
			var world_z := origin.y + local_z
			var height := get_terrain_height(world_x, world_z)
			surface_tool.set_normal(_get_terrain_normal(world_x, world_z))
			surface_tool.set_color(_get_terrain_color(height, world_x, world_z))
			surface_tool.set_uv(Vector2(
				(world_x + map_size.x * 0.5) / map_size.x,
				(world_z + map_size.y * 0.5) / map_size.y
			))
			surface_tool.add_vertex(Vector3(local_x, height, local_z))

	var row_width := segments_x + 1
	for z_index in range(segments_z):
		for x_index in range(segments_x):
			var top_left := z_index * row_width + x_index
			var top_right := top_left + 1
			var bottom_left := (z_index + 1) * row_width + x_index
			var bottom_right := bottom_left + 1
			surface_tool.add_index(top_left)
			surface_tool.add_index(top_right)
			surface_tool.add_index(bottom_left)
			surface_tool.add_index(top_right)
			surface_tool.add_index(bottom_right)
			surface_tool.add_index(bottom_left)

	var mesh := surface_tool.commit()
	if mesh == null:
		push_error("Impossibile generare il chunk naturale %d,%d." % [chunk_x, chunk_z])
		return

	var chunk := Node3D.new()
	chunk.name = "Chunk_%02d_%02d" % [chunk_x, chunk_z]
	chunk.position = Vector3(origin.x, 0.0, origin.y)
	terrain_container.add_child(chunk)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	chunk.add_child(mesh_instance)

	var static_body := StaticBody3D.new()
	static_body.name = "StaticBody3D"
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	chunk.add_child(static_body)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)


func _get_terrain_normal(world_x: float, world_z: float) -> Vector3:
	var offset := maxf(vertex_spacing, 1.0)
	return Vector3(
		get_terrain_height(world_x - offset, world_z)
		- get_terrain_height(world_x + offset, world_z),
		2.0 * offset,
		get_terrain_height(world_x, world_z - offset)
		- get_terrain_height(world_x, world_z + offset)
	).normalized()


func _get_terrain_color(height: float, world_x: float, world_z: float) -> Color:
	var path_distance := absf(world_x - get_path_center_x(world_z))
	var path_weight := 1.0 - smoothstep(2.5, 5.2, path_distance)
	var highland_weight := smoothstep(4.5, 10.0, height)
	var meadow_weight := 1.0 - smoothstep(
		12.0,
		28.0,
		Vector2(world_x + 3.0, world_z + 5.0).length()
	)
	var color := GRASS_COLOR.lerp(DARK_GRASS_COLOR, highland_weight)
	color = color.lerp(MEADOW_COLOR, meadow_weight * 0.55)
	color = color.lerp(DIRT_COLOR, path_weight * 0.92)
	var variation := _detail_noise.get_noise_2d(world_x, world_z) * 0.025
	return Color(
		clampf(color.r + variation, 0.0, 1.0),
		clampf(color.g + variation, 0.0, 1.0),
		clampf(color.b + variation, 0.0, 1.0),
		1.0
	)


func _get_landform_height(
	position_2d: Vector2,
	center: Vector2,
	radius: float,
	elevation: float
) -> float:
	var weight := clampf(1.0 - position_2d.distance_to(center) / radius, 0.0, 1.0)
	var smooth_weight := weight * weight * (3.0 - 2.0 * weight)
	return smooth_weight * elevation


func _scatter_boundary_vegetation() -> void:
	var half_size := map_size * 0.5
	var tree_step := 4.4
	var bush_step := 1.75
	var coordinate := -half_size.x + 2.0
	while coordinate <= half_size.x - 2.0:
		_place_boundary_tree(Vector2(coordinate, -half_size.y + 0.9))
		_place_boundary_tree(Vector2(coordinate, half_size.y - 0.9))
		coordinate += tree_step

	coordinate = -half_size.y + tree_step
	while coordinate <= half_size.y - tree_step:
		_place_boundary_tree(Vector2(-half_size.x + 0.9, coordinate))
		_place_boundary_tree(Vector2(half_size.x - 0.9, coordinate))
		coordinate += tree_step

	coordinate = -half_size.x + 1.0
	while coordinate <= half_size.x - 1.0:
		_place_boundary_bush(Vector2(coordinate, -half_size.y + 2.2))
		_place_boundary_bush(Vector2(coordinate, half_size.y - 2.2))
		coordinate += bush_step

	coordinate = -half_size.y + 1.0
	while coordinate <= half_size.y - 1.0:
		_place_boundary_bush(Vector2(-half_size.x + 2.2, coordinate))
		_place_boundary_bush(Vector2(half_size.x - 2.2, coordinate))
		coordinate += bush_step


func _place_boundary_tree(position_2d: Vector2) -> void:
	var placement := Vector3(
		position_2d.x,
		get_terrain_height(position_2d.x, position_2d.y),
		position_2d.y
	)
	var family := PINES if _random.randf() < 0.45 else COMMON_TREES
	var model_path := family[_random.randi_range(0, family.size() - 1)]
	var uniform_scale := _random.randf_range(0.9, 1.16)
	_append_model_transform(model_path, placement, uniform_scale)
	_add_boundary_tree_collision(placement, uniform_scale)


func _place_boundary_bush(position_2d: Vector2) -> void:
	var placement := Vector3(
		position_2d.x,
		get_terrain_height(position_2d.x, position_2d.y),
		position_2d.y
	)
	var model_path := BERRY_BUSHES[
		_random.randi_range(0, BERRY_BUSHES.size() - 1)
	]
	var uniform_scale := _random.randf_range(0.95, 1.2)
	_append_model_transform(model_path, placement, uniform_scale)
	_add_boundary_bush_collision(placement, uniform_scale)


func _add_boundary_tree_collision(
	placement: Vector3,
	uniform_scale: float
) -> void:
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.62 * uniform_scale
	cylinder.height = 6.0 * uniform_scale
	var collision_shape := CollisionShape3D.new()
	collision_shape.position = placement + Vector3(0.0, cylinder.height * 0.5, 0.0)
	collision_shape.shape = cylinder
	boundary_collisions.add_child(collision_shape)


func _add_boundary_bush_collision(
	placement: Vector3,
	uniform_scale: float
) -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(2.25, 1.6, 2.25) * uniform_scale
	var collision_shape := CollisionShape3D.new()
	collision_shape.position = placement + Vector3(0.0, box.size.y * 0.5, 0.0)
	collision_shape.shape = box
	boundary_collisions.add_child(collision_shape)


func _scatter_nature() -> void:
	_model_transforms.clear()
	_tree_positions.clear()
	_rock_positions.clear()
	_scatter_trees()
	_scatter_rocks()
	_scatter_shrubs()
	_scatter_undergrowth()
	_scatter_ground_cover()
	_scatter_mushrooms()
	_scatter_path_stones()
	_scatter_boundary_vegetation()


func _scatter_trees() -> void:
	for tree_index in range(tree_count):
		var placement := _find_nature_position(6.3, 9.0, 0.25, true)
		if placement == INVALID_POSITION:
			push_warning("Impossibile posizionare l'albero %d." % (tree_index + 1))
			continue
		var position_2d := Vector2(placement.x, placement.z)
		var family := _choose_tree_family(position_2d)
		var model_path := family[_random.randi_range(0, family.size() - 1)]
		var uniform_scale := _random.randf_range(0.86, 1.12)
		if family == TWISTED_TREES:
			uniform_scale *= 0.82
		_append_model_transform(model_path, placement, uniform_scale)
		_tree_positions.append(position_2d)

		var trunk_radius := 0.52
		var trunk_height := 5.6
		if family == PINES:
			trunk_radius = 0.45
			trunk_height = 6.2
		elif family == TWISTED_TREES:
			trunk_radius = 0.72
			trunk_height = 7.5
		elif family == DEAD_TREES:
			trunk_radius = 0.58
			trunk_height = 6.5
		_add_tree_collision(placement, trunk_radius, trunk_height, uniform_scale)
		_add_harvest_interactable(
			&"tree",
			"Albero",
			tree_index + 1,
			placement,
			1.2,
			1.6
		)


func _choose_tree_family(position_2d: Vector2) -> Array[String]:
	var biome_noise := _distribution_noise.get_noise_2d(position_2d.x, position_2d.y)
	if position_2d.x < -18.0 and biome_noise > -0.35:
		return PINES
	if position_2d.x > 28.0 and position_2d.y < 20.0:
		return TWISTED_TREES
	if biome_noise < -0.68:
		return DEAD_TREES
	return COMMON_TREES


func _scatter_rocks() -> void:
	for rock_index in range(rock_count):
		var placement := _find_nature_position(3.8, 7.0, 0.38, false)
		if placement == INVALID_POSITION:
			continue
		var position_2d := Vector2(placement.x, placement.z)
		if not _is_far_from_positions(position_2d, _rock_positions, 3.4):
			continue
		var model_path := ROCKS[_random.randi_range(0, ROCKS.size() - 1)]
		var uniform_scale := _random.randf_range(0.72, 1.35)
		_append_model_transform(model_path, placement, uniform_scale)
		_rock_positions.append(position_2d)
		_add_rock_collision(placement, uniform_scale)
		_add_harvest_interactable(
			&"rock",
			"Roccia",
			rock_index + 1,
			placement,
			0.75,
			1.4
		)


func _scatter_shrubs() -> void:
	for shrub_index in range(shrub_count):
		var placement := _find_nature_position(2.9, 5.5, 0.32, false)
		if placement == INVALID_POSITION:
			continue
		var model_path := BERRY_BUSHES[
			_random.randi_range(0, BERRY_BUSHES.size() - 1)
		]
		var uniform_scale := _random.randf_range(0.68, 1.12)
		_append_model_transform(model_path, placement, uniform_scale)
		_add_harvest_interactable(
			&"shrub",
			"Cespuglio",
			shrub_index + 1,
			placement,
			0.7,
			1.35
		)


func _scatter_undergrowth() -> void:
	for _undergrowth_index in range(undergrowth_count):
		var placement := _find_nature_position(2.2, 4.5, 0.36, false)
		if placement == INVALID_POSITION:
			continue
		var model_path := UNDERGROWTH[
			_random.randi_range(0, UNDERGROWTH.size() - 1)
		]
		var uniform_scale := _random.randf_range(0.64, 1.05)
		if "Fern" in model_path:
			uniform_scale *= 0.48
		_append_model_transform(model_path, placement, uniform_scale)


func _scatter_ground_cover() -> void:
	for _ground_index in range(ground_cover_count):
		var placement := _find_nature_position(1.7, 4.5, 0.4, false)
		if placement == INVALID_POSITION:
			continue
		var model_path := GROUND_COVER[
			_random.randi_range(0, GROUND_COVER.size() - 1)
		]
		var uniform_scale := _random.randf_range(0.55, 1.02)
		if "Flower" in model_path:
			uniform_scale *= 0.68
		_append_model_transform(model_path, placement, uniform_scale)


func _scatter_mushrooms() -> void:
	for mushroom_index in range(mushroom_count):
		var placement := _find_nature_position(1.25, 3.5, 0.34, false)
		if placement == INVALID_POSITION:
			continue
		var model_path := MUSHROOMS[_random.randi_range(0, MUSHROOMS.size() - 1)]
		_append_model_transform(
			model_path,
			placement,
			_random.randf_range(0.78, 1.25)
		)
		_add_harvest_interactable(
			&"mushroom",
			"Fungo",
			mushroom_index + 1,
			placement,
			0.35,
			0.9
		)


func _scatter_path_stones() -> void:
	var start_z := -map_size.y * 0.5 + 6.0
	var end_z := map_size.y * 0.5 - 6.0
	var world_z := start_z
	while world_z <= end_z:
		var world_x := get_path_center_x(world_z) + _random.randf_range(-2.0, 2.0)
		var placement := Vector3(
			world_x,
			get_terrain_height(world_x, world_z) + 0.04,
			world_z
		)
		var model_path := PATH_STONES[
			_random.randi_range(0, PATH_STONES.size() - 1)
		]
		_append_model_transform(
			model_path,
			placement,
			_random.randf_range(0.55, 0.95)
		)
		world_z += _random.randf_range(2.4, 3.8)


func _find_nature_position(
	path_clearance: float,
	spawn_clearance: float,
	max_slope: float,
	require_tree_spacing: bool
) -> Vector3:
	var half_size := map_size * 0.5 - Vector2(5.0, 5.0)
	var spawn := get_spawn_position()
	var spawn_2d := Vector2(spawn.x, spawn.z)
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var position_2d := Vector2(
			_random.randf_range(-half_size.x, half_size.x),
			_random.randf_range(-half_size.y, half_size.y)
		)
		if (
			absf(position_2d.x - get_path_center_x(position_2d.y)) < path_clearance
			or position_2d.distance_to(spawn_2d) < spawn_clearance
		):
			continue
		if (
			require_tree_spacing
			and not _is_far_from_positions(
				position_2d,
				_tree_positions,
				minimum_tree_spacing
			)
		):
			continue
		var height := get_terrain_height(position_2d.x, position_2d.y)
		var slope := 1.0 - _get_terrain_normal(position_2d.x, position_2d.y).y
		if slope > max_slope:
			continue
		return Vector3(position_2d.x, height, position_2d.y)
	return INVALID_POSITION


func _is_far_from_positions(
	position_2d: Vector2,
	positions: Array[Vector2],
	minimum_distance: float
) -> bool:
	for other_position in positions:
		if position_2d.distance_to(other_position) < minimum_distance:
			return false
	return true


func _append_model_transform(
	model_path: String,
	placement: Vector3,
	uniform_scale: float
) -> void:
	if not _model_transforms.has(model_path):
		_model_transforms[model_path] = []
	var transforms := _model_transforms[model_path] as Array
	var yaw := _random.randf_range(-PI, PI)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * uniform_scale)
	transforms.append(Transform3D(basis, placement))


func _add_tree_collision(
	placement: Vector3,
	radius: float,
	height: float,
	uniform_scale: float
) -> void:
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius * uniform_scale
	cylinder.height = height * uniform_scale
	var collision_shape := CollisionShape3D.new()
	collision_shape.position = placement + Vector3(
		0.0,
		cylinder.height * 0.5,
		0.0
	)
	collision_shape.shape = cylinder
	prop_collisions.add_child(collision_shape)


func _add_rock_collision(placement: Vector3, uniform_scale: float) -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 1.65, 2.35) * uniform_scale
	var collision_shape := CollisionShape3D.new()
	collision_shape.position = placement + Vector3(0.0, box.size.y * 0.5, 0.0)
	collision_shape.rotation.y = _random.randf_range(-PI, PI)
	collision_shape.shape = box
	prop_collisions.add_child(collision_shape)


func _add_harvest_interactable(
	category: StringName,
	label: String,
	index: int,
	placement: Vector3,
	height_offset: float,
	interaction_radius: float
) -> void:
	var interactable := INTERACTABLE_SCENE.instantiate() as InteractableArea3D
	if interactable == null:
		push_error("Impossibile creare il trigger per %s." % label)
		return
	interactable.name = "%s_%03d" % [String(category).to_pascal_case(), index]
	interactable.position = placement + Vector3(0.0, height_offset, 0.0)
	interactable.interaction_id = StringName(
		"verdant_valley_%s_%03d" % [String(category), index]
	)
	interactable.display_name = "%s %d" % [label, index]
	interactable.category = category
	interactable.interaction_radius = interaction_radius
	interactable.max_generated_items = 2
	interactable.item_generation_probability = 0.5
	interactable.add_to_group(&"verdant_valley_interactable")
	interactables_container.add_child(interactable)
	interactable.generate_item_stock(_random)
	interactable.interacted.connect(
		_on_interactable_interacted.bind(interactable)
	)


func _on_interactable_interacted(
	interactor: Node3D,
	interactable: InteractableArea3D
) -> void:
	map_object_interacted.emit(
		interactable.interaction_id,
		interactable.category,
		interactor
	)
	map_interactable_interacted.emit(interactable, interactor)


func _build_multimeshes() -> void:
	for model_path in _model_transforms:
		var transforms := _model_transforms[model_path] as Array
		if transforms.is_empty():
			continue
		var packed_scene := load(model_path) as PackedScene
		if packed_scene == null:
			push_error("Modello naturalistico non caricabile: %s" % model_path)
			continue
		var model_root := packed_scene.instantiate() as Node3D
		if model_root == null:
			push_error("Il modello non ha una root Node3D: %s" % model_path)
			continue
		var mesh_instances: Array[MeshInstance3D] = []
		_collect_mesh_instances(model_root, mesh_instances)
		for mesh_index in range(mesh_instances.size()):
			_create_multimesh_part(
				model_path,
				mesh_index,
				model_root,
				mesh_instances[mesh_index],
				transforms
			)
		model_root.free()


func _collect_mesh_instances(
	node: Node,
	result: Array[MeshInstance3D]
) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		result.append(mesh_instance)
	for child in node.get_children():
		_collect_mesh_instances(child, result)


func _create_multimesh_part(
	model_path: String,
	mesh_index: int,
	model_root: Node3D,
	mesh_instance: MeshInstance3D,
	transforms: Array
) -> void:
	var local_transform := _get_transform_relative_to(mesh_instance, model_root)
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = mesh_instance.mesh
	multi_mesh.instance_count = transforms.size()
	multi_mesh.custom_aabb = AABB(
		Vector3(-map_size.x * 0.5, -5.0, -map_size.y * 0.5),
		Vector3(map_size.x, 35.0, map_size.y)
	)
	for instance_index in range(transforms.size()):
		multi_mesh.set_instance_transform(
			instance_index,
			(transforms[instance_index] as Transform3D) * local_transform
		)

	var multi_mesh_instance := MultiMeshInstance3D.new()
	multi_mesh_instance.name = "%s_%02d" % [
		model_path.get_file().get_basename().to_snake_case(),
		mesh_index + 1,
	]
	multi_mesh_instance.multimesh = multi_mesh
	multi_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	vegetation_container.add_child(multi_mesh_instance)


func _get_transform_relative_to(
	node: Node3D,
	ancestor: Node3D
) -> Transform3D:
	if node == ancestor:
		return Transform3D.IDENTITY
	var result := node.transform
	var current_parent := node.get_parent() as Node3D
	while current_parent != null and current_parent != ancestor:
		result = current_parent.transform * result
		current_parent = current_parent.get_parent() as Node3D
	return result
