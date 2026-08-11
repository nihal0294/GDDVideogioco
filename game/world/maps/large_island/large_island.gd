class_name LargeIsland
extends Node3D

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

const PALM_SCENE: PackedScene = preload(
	"res://game/world/props/beach/palm.tscn"
)
const TENT_SCENE: PackedScene = preload(
	"res://game/world/props/beach/tent.tscn"
)
const ROCK_SCENE: PackedScene = preload(
	"res://game/world/props/beach/rock.tscn"
)
const DRIFTWOOD_SCENE: PackedScene = preload(
	"res://game/world/props/beach/driftwood.tscn"
)
const PARASOL_SCENE: PackedScene = preload(
	"res://game/world/props/beach/parasol.tscn"
)

const SAND_COLOR := Color("d7bd78")
const GRASS_COLOR := Color("659d4f")
const HIGHLAND_COLOR := Color("547d43")
const ROCK_COLOR := Color("777b73")
const INVALID_POSITION := Vector3(0.0, -10000.0, 0.0)
const MAX_PLACEMENT_ATTEMPTS := 80

@export_group("Dimensioni")
@export var map_size := Vector2(300.0, 300.0)
@export_range(10.0, 100.0, 1.0) var chunk_size: float = 50.0
@export_range(1.0, 10.0, 0.5) var vertex_spacing: float = 2.0
@export var sea_level: float = 0.0
@export_range(0.1, 1.5, 0.05) var maximum_wade_depth: float = 0.4
@export_range(32, 192, 8) var water_collision_segments: int = 96

@export_group("Rilievi")
@export var mountain_position := Vector2(-58.0, -42.0)
@export_range(3.0, 20.0, 0.5) var mountain_height: float = 10.0
@export_range(15.0, 60.0, 1.0) var mountain_radius: float = 32.0

@export_group("Generazione")
@export var generation_seed: int = 18427
@export_range(2.0, 20.0, 0.5) var minimum_prop_spacing: float = 5.5
@export_range(0, 100, 1) var palm_count: int = 45
@export_range(0, 30, 1) var tent_count: int = 8
@export_range(0, 100, 1) var rock_count: int = 28
@export_range(0, 60, 1) var driftwood_count: int = 15
@export_range(0, 30, 1) var parasol_count: int = 7

@onready var terrain_container: Node3D = $GeneratedTerrain
@onready var water: MeshInstance3D = $Water
@onready var deep_water_collision: StaticBody3D = $DeepWaterCollision
@onready var prop_container: Node3D = $Props

var _coast_noise := FastNoiseLite.new()
var _height_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _random := RandomNumberGenerator.new()
var _terrain_material := StandardMaterial3D.new()
var _placed_positions: Array[Vector2] = []


func _ready() -> void:
	_configure_generation()
	_generate_terrain()
	_configure_water()
	_generate_deep_water_collision()
	_generate_props()
	generation_finished.emit()


func get_spawn_position() -> Vector3:
	return Vector3(0.0, get_terrain_height(0.0, 0.0) + 1.15, 0.0)


func get_terrain_height(world_x: float, world_z: float) -> float:
	var half_width := map_size.x * 0.5 - 6.0
	var half_depth := map_size.y * 0.5 - 6.0
	var normalized_distance := Vector2(
		world_x / half_width,
		world_z / half_depth
	).length()
	var coast_variation := _coast_noise.get_noise_2d(world_x, world_z) * 0.055
	var distance_inside_coast := 1.0 - normalized_distance + coast_variation

	if distance_inside_coast <= -0.02:
		return sea_level - 0.55 - minf(absf(distance_inside_coast) * 8.0, 3.2)

	var shore_rise := smoothstep(-0.02, 0.13, distance_inside_coast)
	var interior_weight := smoothstep(0.04, 0.58, distance_inside_coast)
	var broad_noise := _height_noise.get_noise_2d(world_x, world_z)
	var detail_noise := _detail_noise.get_noise_2d(world_x, world_z)
	var height := (
		sea_level
		- 0.32
		+ shore_rise * 1.22
		+ interior_weight * (2.15 + broad_noise * 2.7 + detail_noise * 0.9)
	)
	height += interior_weight * _get_landform_height(
		Vector2(world_x, world_z),
		mountain_position,
		mountain_radius,
		mountain_height
	)
	height += interior_weight * _get_landform_height(
		Vector2(world_x, world_z),
		Vector2(48.0, 54.0),
		44.0,
		4.2
	)
	height += interior_weight * _get_landform_height(
		Vector2(world_x, world_z),
		Vector2(-72.0, 68.0),
		38.0,
		3.4
	)

	var center_weight := 1.0 - smoothstep(0.0, 11.0, Vector2(world_x, world_z).length())
	return lerpf(height, sea_level + 3.0, center_weight)


func get_deep_water_boundary_point(angle: float) -> Vector2:
	var half_extent := map_size * 0.5 - Vector2(6.0, 6.0)
	var direction := Vector2(cos(angle), sin(angle))
	var inside_radius := 0.82
	var outside_radius := 1.16
	var target_height := sea_level - maximum_wade_depth

	for _iteration in range(18):
		var radius := (inside_radius + outside_radius) * 0.5
		var sample_position := direction * half_extent * radius
		if get_terrain_height(sample_position.x, sample_position.y) > target_height:
			inside_radius = radius
		else:
			outside_radius = radius
	return direction * half_extent * outside_radius


func _get_landform_height(
	position_2d: Vector2,
	center: Vector2,
	radius: float,
	elevation: float
) -> float:
	var weight := clampf(1.0 - position_2d.distance_to(center) / radius, 0.0, 1.0)
	var smooth_weight := weight * weight * (3.0 - 2.0 * weight)
	return smooth_weight * elevation


func get_interactables() -> Array[InteractableArea3D]:
	var result: Array[InteractableArea3D] = []
	for node in get_tree().get_nodes_in_group(&"large_island_interactable"):
		var interactable := node as InteractableArea3D
		if interactable != null and is_ancestor_of(interactable):
			result.append(interactable)
	return result


func _configure_generation() -> void:
	map_size.x = maxf(map_size.x, chunk_size)
	map_size.y = maxf(map_size.y, chunk_size)
	vertex_spacing = minf(vertex_spacing, chunk_size)
	_random.seed = generation_seed

	_coast_noise.seed = generation_seed
	_coast_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_coast_noise.frequency = 0.018
	_coast_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_coast_noise.fractal_octaves = 3

	_height_noise.seed = generation_seed + 101
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.frequency = 0.012
	_height_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_height_noise.fractal_octaves = 4

	_detail_noise.seed = generation_seed + 307
	_detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_detail_noise.frequency = 0.042
	_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail_noise.fractal_octaves = 2

	_terrain_material.vertex_color_use_as_albedo = true
	_terrain_material.roughness = 0.92
	_terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _generate_terrain() -> void:
	var chunks_x := ceili(map_size.x / chunk_size)
	var chunks_z := ceili(map_size.y / chunk_size)
	var map_start := Vector2(-map_size.x * 0.5, -map_size.y * 0.5)

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
		push_error("Impossibile generare il chunk di terreno %d,%d." % [chunk_x, chunk_z])
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
	var sand_to_grass := smoothstep(sea_level + 0.35, sea_level + 2.0, height)
	var grass_to_highland := smoothstep(sea_level + 5.0, sea_level + 8.0, height)
	var highland_to_rock := smoothstep(sea_level + 9.0, sea_level + 13.0, height)
	var color := SAND_COLOR.lerp(GRASS_COLOR, sand_to_grass)
	color = color.lerp(HIGHLAND_COLOR, grass_to_highland)
	color = color.lerp(ROCK_COLOR, highland_to_rock)
	var variation := _detail_noise.get_noise_2d(world_x, world_z) * 0.035
	return Color(
		clampf(color.r + variation, 0.0, 1.0),
		clampf(color.g + variation, 0.0, 1.0),
		clampf(color.b + variation, 0.0, 1.0),
		1.0
	)


func _configure_water() -> void:
	water.position.y = sea_level
	var plane := water.mesh as PlaneMesh
	if plane != null:
		plane.size = map_size + Vector2(120.0, 120.0)
	var water_material := water.get_active_material(0) as ShaderMaterial
	if water_material != null:
		water_material.set_shader_parameter(
			"island_half_extent",
			map_size * 0.5 - Vector2(6.0, 6.0)
		)


func _generate_deep_water_collision() -> void:
	var boundary_points: Array[Vector2] = []
	for segment_index in range(water_collision_segments):
		var angle := TAU * float(segment_index) / float(water_collision_segments)
		boundary_points.append(get_deep_water_boundary_point(angle))

	for segment_index in range(water_collision_segments):
		var start := boundary_points[segment_index]
		var end := boundary_points[(segment_index + 1) % water_collision_segments]
		var segment := end - start
		var shape := BoxShape3D.new()
		shape.size = Vector3(segment.length() + 1.2, 5.0, 1.8)

		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "DeepWaterSegment_%03d" % (segment_index + 1)
		collision_shape.position = Vector3(
			(start.x + end.x) * 0.5,
			sea_level + 0.5,
			(start.y + end.y) * 0.5
		)
		collision_shape.rotation.y = -atan2(segment.y, segment.x)
		collision_shape.shape = shape
		deep_water_collision.add_child(collision_shape)


func _generate_props() -> void:
	_placed_positions.clear()
	for definition in _get_prop_definitions():
		var scene := definition["scene"] as PackedScene
		var count := int(definition["count"])
		for prop_index in range(count):
			var placement := _find_prop_position(definition)
			if placement == INVALID_POSITION:
				push_warning(
					"Spazio insufficiente per %s %d." % [
						String(definition["label"]),
						prop_index + 1,
					]
				)
				continue
			_create_prop(scene, definition, placement, prop_index + 1)


func _get_prop_definitions() -> Array[Dictionary]:
	return [
		{
			"scene": PALM_SCENE,
			"count": palm_count,
			"category": &"palm",
			"label": "Palma",
			"min_radius": 0.34,
			"max_radius": 0.9,
			"min_height": sea_level + 0.4,
			"max_slope": 0.2,
			"min_scale": 0.88,
			"max_scale": 1.12,
		},
		{
			"scene": TENT_SCENE,
			"count": tent_count,
			"category": &"tent",
			"label": "Tenda",
			"min_radius": 0.25,
			"max_radius": 0.66,
			"min_height": sea_level + 0.75,
			"max_slope": 0.09,
			"min_scale": 0.95,
			"max_scale": 1.05,
		},
		{
			"scene": ROCK_SCENE,
			"count": rock_count,
			"category": &"rock",
			"label": "Roccia",
			"min_radius": 0.2,
			"max_radius": 0.94,
			"min_height": sea_level + 0.2,
			"max_slope": 0.28,
			"min_scale": 0.72,
			"max_scale": 1.35,
		},
		{
			"scene": DRIFTWOOD_SCENE,
			"count": driftwood_count,
			"category": &"driftwood",
			"label": "Legno alla deriva",
			"min_radius": 0.78,
			"max_radius": 0.98,
			"min_height": sea_level - 0.08,
			"max_slope": 0.22,
			"min_scale": 0.8,
			"max_scale": 1.2,
		},
		{
			"scene": PARASOL_SCENE,
			"count": parasol_count,
			"category": &"parasol",
			"label": "Ombrellone",
			"min_radius": 0.7,
			"max_radius": 0.9,
			"min_height": sea_level + 0.18,
			"max_slope": 0.1,
			"min_scale": 0.94,
			"max_scale": 1.08,
		},
	]


func _find_prop_position(definition: Dictionary) -> Vector3:
	var half_width := map_size.x * 0.5 - 8.0
	var half_depth := map_size.y * 0.5 - 8.0
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var world_x := _random.randf_range(-half_width, half_width)
		var world_z := _random.randf_range(-half_depth, half_depth)
		var flat_position := Vector2(world_x, world_z)
		var normalized_radius := Vector2(
			world_x / half_width,
			world_z / half_depth
		).length()
		if (
			normalized_radius < float(definition["min_radius"])
			or normalized_radius > float(definition["max_radius"])
			or _is_reserved_space(flat_position)
			or not _is_far_from_other_props(flat_position)
		):
			continue

		var height := get_terrain_height(world_x, world_z)
		if height < float(definition["min_height"]):
			continue
		var slope := 1.0 - _get_terrain_normal(world_x, world_z).y
		if slope > float(definition["max_slope"]):
			continue

		_placed_positions.append(flat_position)
		return Vector3(world_x, height, world_z)
	return INVALID_POSITION


func _is_reserved_space(position_2d: Vector2) -> bool:
	if position_2d.length() < 22.0:
		return true
	var north_south_path := absf(
		position_2d.x - sin(position_2d.y * 0.025) * 5.0
	) < 4.0
	var east_west_path := absf(
		position_2d.y - sin(position_2d.x * 0.03) * 6.0
	) < 4.0
	return north_south_path or east_west_path


func _is_far_from_other_props(position_2d: Vector2) -> bool:
	for placed_position in _placed_positions:
		if placed_position.distance_to(position_2d) < minimum_prop_spacing:
			return false
	return true


func _create_prop(
	scene: PackedScene,
	definition: Dictionary,
	placement: Vector3,
	index: int
) -> void:
	var prop := scene.instantiate() as Node3D
	if prop == null:
		push_error("La scena del prop non ha una root Node3D.")
		return

	var category := StringName(definition["category"])
	var label := String(definition["label"])
	prop.name = "%s_%03d" % [String(category).to_pascal_case(), index]
	prop.position = placement
	prop.rotation.y = _random.randf_range(-PI, PI)
	var uniform_scale := _random.randf_range(
		float(definition["min_scale"]),
		float(definition["max_scale"])
	)
	prop.scale = Vector3.ONE * uniform_scale
	prop.add_to_group(&"large_island_prop")

	var interactable := prop.find_child("Interactable", true, false) as InteractableArea3D
	if interactable != null:
		interactable.interaction_id = StringName(
			"large_island_%s_%03d" % [String(category), index]
		)
		interactable.display_name = "%s %d" % [label, index]
		interactable.category = category
		interactable.add_to_group(&"large_island_interactable")

	prop_container.add_child(prop)
	if interactable != null:
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
