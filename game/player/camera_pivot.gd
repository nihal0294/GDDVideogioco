#This feature is to be removed!!!
#I(Agatino) did it just to learn about commit and push
#This script allow the player to adjust the camera, allowing him 
#to see from other prospectives-
#This script doesn't affect movement based on camera positionm so the movement
#is awkward.
#If you want to remove this, just make CameraRig(and its children) child of 
#Player and delete this node (CameraPivot) entirely. Be sure to delete the scipt
#attached to it

extends Node3D

@export var mouse_sensitivity: float = 0.003
@export var pitch_min: float = -80.0
@export var pitch_max: float = 80.0
@export var reset_speed: float = 3.0

var is_rotating: bool = false
var default_rotation: Vector3

func _ready() -> void:
	default_rotation = rotation

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_rotating = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_rotating else Input.MOUSE_MODE_VISIBLE

	if is_rotating and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		rotation.x -= event.relative.y * mouse_sensitivity
		rotation.x = clamp(rotation.x, deg_to_rad(pitch_min), deg_to_rad(pitch_max))

func _process(delta: float) -> void:
	if not is_rotating:
		rotation = rotation.lerp(default_rotation, reset_speed * delta)
