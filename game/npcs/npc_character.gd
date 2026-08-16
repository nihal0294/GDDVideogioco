class_name NpcCharacter
extends CharacterBody3D

@export var npc_id: StringName = &"npc"
@export var display_name: String = "NPC"
@export_range(0.5, 10.0, 0.1) var movement_speed: float = 3.4
@export_range(0.5, 20.0, 0.1) var acceleration: float = 10.0
@export_range(0.5, 20.0, 0.1) var turn_speed: float = 8.0

@onready var visual: Node3D = $Visual

var gravity: float = float(
	ProjectSettings.get_setting("physics/3d/default_gravity")
)


func apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta


func stop_horizontal_movement(delta: float) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(
		Vector3.ZERO,
		acceleration * delta
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func move_toward_world_position(target: Vector3, delta: float) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		stop_horizontal_movement(delta)
		return
	direction = direction.normalized()
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(
		direction * movement_speed,
		acceleration * delta
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	face_world_position(target, delta)


func face_world_position(target: Vector3, delta: float = 0.0) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = (
		target_yaw
		if delta <= 0.0
		else rotate_toward(rotation.y, target_yaw, turn_speed * delta)
	)
