class_name PlayerMovementCommand
extends RefCounted

var direction: Vector2 = Vector2.ZERO
var jump_pressed: bool = false


static func create(
	movement_direction: Vector2,
	wants_to_jump: bool = false
) -> PlayerMovementCommand:
	var command := PlayerMovementCommand.new()
	command.direction = movement_direction.limit_length(1.0)
	command.jump_pressed = wants_to_jump
	return command


func to_dictionary() -> Dictionary:
	return {
		"direction_x": direction.x,
		"direction_y": direction.y,
		"jump_pressed": jump_pressed,
	}


static func from_dictionary(data: Dictionary) -> PlayerMovementCommand:
	var x := _finite_float(data.get("direction_x", 0.0))
	var y := _finite_float(data.get("direction_y", 0.0))
	return create(Vector2(x, y), bool(data.get("jump_pressed", false)))


static func _finite_float(value: Variant) -> float:
	if value is int:
		return float(value)
	if value is float and is_finite(float(value)):
		return float(value)
	return 0.0

