class_name LocalPlayerInput
extends Node


func sample_movement_command() -> PlayerMovementCommand:
	return PlayerMovementCommand.create(
		Input.get_vector(
			"move_left",
			"move_right",
			"move_forward",
			"move_backward"
		),
		Input.is_action_just_pressed("jump")
	)

