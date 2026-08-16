class_name TrainerNpc
extends NpcCharacter

signal challenge_detected(trainer: TrainerNpc, actor: CharacterBody3D)
signal dialogue_started(trainer: TrainerNpc, dialogue: String)
signal battle_requested(trainer: TrainerNpc)
signal challenge_cancelled(trainer: TrainerNpc)

enum TrainerState {
	IDLE,
	REQUESTED,
	APPROACHING,
	DIALOGUE,
	BATTLE,
	COOLDOWN,
	DEFEATED,
}

@export_group("Sfida")
@export_multiline var challenge_line: String = "Preparati alla sfida!"
@export var astral_definition: AstralDefinition
@export_range(1, 999, 1) var astral_level: int = 5
@export_range(3.0, 30.0, 0.5) var vision_distance: float = 11.0
@export_range(15.0, 160.0, 1.0) var vision_angle_degrees: float = 70.0
@export_range(0.01, 5.0, 0.05) var minimum_detected_speed: float = 0.15
@export_range(1.2, 3.5, 0.1) var engagement_distance: float = 1.9
@export_range(0.5, 10.0, 0.1) var dialogue_duration: float = 2.8
@export_range(2.0, 30.0, 0.5) var maximum_approach_duration: float = 12.0
@export_group("Ricompense")
@export_range(0, 999999, 1) var reward_florins: int = 50
@export var reward_item_id: StringName = &"bacca"
@export_range(0, 10, 1) var reward_item_amount: int = 1

@onready var challenge_marker: Label3D = $ChallengeMarker
@onready var name_label: Label3D = $NameLabel
@onready var body_mesh: MeshInstance3D = $Visual/Body

var player: CharacterBody3D = null
var defeated: bool = false
var _state: TrainerState = TrainerState.IDLE
var _dialogue_remaining: float = 0.0
var _approach_remaining: float = 0.0
var _cooldown_remaining: float = 0.0


func _ready() -> void:
	name_label.text = display_name
	challenge_marker.hide()
	add_to_group(&"trainers")


func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	match _state:
		TrainerState.IDLE:
			stop_horizontal_movement(delta)
			_check_for_player()
		TrainerState.REQUESTED:
			stop_horizontal_movement(delta)
		TrainerState.APPROACHING:
			_update_approach(delta)
		TrainerState.DIALOGUE:
			stop_horizontal_movement(delta)
			_update_dialogue(delta)
		TrainerState.BATTLE, TrainerState.DEFEATED:
			stop_horizontal_movement(delta)
		TrainerState.COOLDOWN:
			stop_horizontal_movement(delta)
			_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
			if is_zero_approx(_cooldown_remaining):
				_state = TrainerState.IDLE
	move_and_slide()


func start_challenge(actor: CharacterBody3D) -> bool:
	if defeated or actor == null or _state != TrainerState.REQUESTED:
		return false
	player = actor
	_state = TrainerState.APPROACHING
	_approach_remaining = maximum_approach_duration
	challenge_marker.show()
	return true


func cancel_challenge() -> void:
	if defeated:
		return
	player = null
	challenge_marker.hide()
	_state = TrainerState.COOLDOWN
	_cooldown_remaining = 2.0


func mark_battle_started() -> void:
	if _state == TrainerState.DIALOGUE:
		_state = TrainerState.BATTLE
	challenge_marker.hide()
	velocity = Vector3.ZERO


func finish_battle(player_won: bool) -> void:
	player = null
	challenge_marker.hide()
	velocity = Vector3.ZERO
	if player_won:
		defeated = true
		_state = TrainerState.DEFEATED
		name_label.text = "%s · sconfitto" % display_name
		_set_body_tint(Color(0.42, 0.46, 0.52, 1.0))
	else:
		_state = TrainerState.COOLDOWN
		_cooldown_remaining = 4.0


func set_visual_color(color: Color) -> void:
	_set_body_tint(color)


func get_save_data() -> Dictionary:
	return {"defeated": defeated}


func load_save_data(data: Dictionary) -> void:
	var was_defeated := bool(data.get("defeated", false))
	if was_defeated:
		finish_battle(true)
	else:
		defeated = false
		_state = TrainerState.IDLE
		name_label.text = display_name


func get_state() -> TrainerState:
	return _state


func force_challenge_for_test(actor: CharacterBody3D) -> void:
	if defeated or actor == null or _state != TrainerState.IDLE:
		return
	_state = TrainerState.REQUESTED
	challenge_detected.emit(self, actor)


func can_see_player() -> bool:
	if defeated or player == null or not is_instance_valid(player):
		return false
	var horizontal_velocity := Vector2(player.velocity.x, player.velocity.z)
	if horizontal_velocity.length() < minimum_detected_speed:
		return false
	var offset := player.global_position - global_position
	var flat_offset := Vector3(offset.x, 0.0, offset.z)
	if (
		flat_offset.length_squared() <= 0.0001
		or flat_offset.length() > vision_distance
	):
		return false
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var direction := flat_offset.normalized()
	var minimum_dot := cos(deg_to_rad(vision_angle_degrees * 0.5))
	return forward.dot(direction) >= minimum_dot and _has_clear_line_of_sight()


func _check_for_player() -> void:
	if not can_see_player():
		return
	_state = TrainerState.REQUESTED
	challenge_detected.emit(self, player)


func _has_clear_line_of_sight() -> bool:
	if player == null or not is_inside_tree():
		return false
	var from := global_position + Vector3.UP * 1.35
	var target_center := player.global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(from, target_center, 1)
	query.exclude = [get_rid(), player.get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _update_approach(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		challenge_cancelled.emit(self)
		cancel_challenge()
		return
	_approach_remaining = maxf(_approach_remaining - delta, 0.0)
	var flat_distance := Vector2(
		player.global_position.x - global_position.x,
		player.global_position.z - global_position.z
	).length()
	if flat_distance <= engagement_distance:
		_begin_dialogue()
		return
	if is_zero_approx(_approach_remaining):
		challenge_cancelled.emit(self)
		cancel_challenge()
		return
	move_toward_world_position(player.global_position, delta)


func _begin_dialogue() -> void:
	_state = TrainerState.DIALOGUE
	_dialogue_remaining = dialogue_duration
	velocity.x = 0.0
	velocity.z = 0.0
	if player != null:
		face_world_position(player.global_position)
	dialogue_started.emit(self, challenge_line)


func _update_dialogue(delta: float) -> void:
	_dialogue_remaining = maxf(_dialogue_remaining - delta, 0.0)
	if not is_zero_approx(_dialogue_remaining):
		return
	_state = TrainerState.BATTLE
	battle_requested.emit(self)


func _set_body_tint(color: Color) -> void:
	if body_mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.64
	body_mesh.material_override = material
