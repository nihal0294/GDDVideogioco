extends CharacterBody3D

@export_range(0.1, 20.0, 0.1) var move_speed: float = 5.0
@export_range(0.1, 50.0, 0.1) var acceleration: float = 20.0
@export_range(0.1, 50.0, 0.1) var deceleration: float = 24.0
@export_range(0.1, 20.0, 0.1) var turn_speed: float = 10.0
@export_range(0.1, 20.0, 0.1) var jump_velocity: float = 6.5
@export var local_input_enabled: bool = true

@onready var visual: Node3D = $Visual
@onready var local_input: LocalPlayerInput = $LocalInput

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _movement_locks: Dictionary[StringName, bool] = {}
var _submitted_command := PlayerMovementCommand.new()


func _physics_process(delta: float) -> void:
	var command := _consume_submitted_command()
	if local_input_enabled and local_input != null:
		command = local_input.sample_movement_command()
	simulate_movement(command, delta)


func submit_movement_command(command: PlayerMovementCommand) -> void:
	if command == null:
		_submitted_command = PlayerMovementCommand.new()
		return
	_submitted_command = PlayerMovementCommand.create(
		command.direction,
		command.jump_pressed
	)


func submit_movement_intent(
	direction: Vector2,
	jump_pressed: bool = false
) -> void:
	submit_movement_command(PlayerMovementCommand.create(direction, jump_pressed))


func set_local_input_enabled(enabled: bool) -> void:
	local_input_enabled = enabled
	if enabled:
		_submitted_command = PlayerMovementCommand.new()


func simulate_movement(command: PlayerMovementCommand, delta: float) -> void:
	var input_direction := command.direction if command != null else Vector2.ZERO
	var wants_to_jump := command != null and command.jump_pressed
	if not _movement_locks.is_empty():
		input_direction = Vector2.ZERO
		wants_to_jump = false
	var move_direction := Vector3(
		input_direction.x,
		0.0,
		input_direction.y
	).normalized()
	var target_horizontal_velocity := move_direction * move_speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var smoothing := acceleration if move_direction != Vector3.ZERO else deceleration

	horizontal_velocity = horizontal_velocity.move_toward(
		target_horizontal_velocity,
		smoothing * delta
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if is_on_floor():
		if wants_to_jump:
			velocity.y = jump_velocity
		elif velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	move_and_slide()

	if move_direction != Vector3.ZERO:
		var target_rotation := atan2(-move_direction.x, -move_direction.z)
		visual.rotation.y = rotate_toward(
			visual.rotation.y,
			target_rotation,
			turn_speed * delta
		)


func _consume_submitted_command() -> PlayerMovementCommand:
	var command := _submitted_command
	_submitted_command = PlayerMovementCommand.create(command.direction, false)
	return command


func set_movement_lock(lock_id: StringName, active: bool) -> void:
	if lock_id.is_empty():
		return
	if active:
		_movement_locks[lock_id] = true
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		_movement_locks.erase(lock_id)


func has_movement_lock(lock_id: StringName) -> bool:
	return _movement_locks.has(lock_id)


func is_movement_locked() -> bool:
	return not _movement_locks.is_empty()
