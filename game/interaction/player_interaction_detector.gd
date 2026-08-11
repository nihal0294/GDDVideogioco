class_name PlayerInteractionDetector
extends Area3D

signal target_changed(target: InteractableArea3D)
signal interaction_performed(target: InteractableArea3D)

var current_target: InteractableArea3D = null
var _candidates: Array[InteractableArea3D] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and try_interact():
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _candidates.size() > 1:
		_refresh_current_target()


func try_interact() -> bool:
	if not is_instance_valid(current_target):
		_set_current_target(null)
		return false

	current_target.interact(get_parent() as Node3D)
	interaction_performed.emit(current_target)
	return true


func _on_area_entered(area: Area3D) -> void:
	var interactable := area as InteractableArea3D
	if interactable == null or _candidates.has(interactable):
		return
	_candidates.append(interactable)
	_refresh_current_target()


func _on_area_exited(area: Area3D) -> void:
	var interactable := area as InteractableArea3D
	if interactable == null:
		return
	_candidates.erase(interactable)
	_refresh_current_target()


func _refresh_current_target() -> void:
	var index := _candidates.size() - 1
	while index >= 0:
		if not is_instance_valid(_candidates[index]):
			_candidates.remove_at(index)
		index -= 1

	var nearest_target: InteractableArea3D = null
	var nearest_distance_squared: float = INF
	for candidate in _candidates:
		var distance_squared := global_position.distance_squared_to(candidate.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_target = candidate

	_set_current_target(nearest_target)


func _set_current_target(value: InteractableArea3D) -> void:
	if current_target == value:
		return
	if is_instance_valid(current_target):
		current_target.set_focused(false)
	current_target = value
	if is_instance_valid(current_target):
		current_target.set_focused(true)
	target_changed.emit(current_target)
