class_name WorldNpc
extends NpcCharacter

signal interaction_started(
	npc: WorldNpc,
	actor: CharacterBody3D,
	dialogue: String
)
signal interaction_finished(npc: WorldNpc, actor: CharacterBody3D)
signal florins_gift_requested(
	npc: WorldNpc,
	actor: CharacterBody3D,
	amount: int
)

@export_group("Dialogo")
@export_multiline var dialogue_line: String = "Salute, viandante."
@export_range(0.5, 10.0, 0.1) var dialogue_duration: float = 3.0
@export_group("Ricompensa")
@export_range(0, 999999, 1) var florins_gift: int = 0

@onready var name_label: Label3D = $NameLabel
@onready var body_mesh: MeshInstance3D = $Visual/Body
@onready var interaction_area: InteractableArea3D = $InteractionArea

var gift_claimed: bool = false
var _interaction_remaining: float = 0.0
var _interacting_actor: CharacterBody3D = null


func _ready() -> void:
	name_label.text = display_name
	interaction_area.interaction_id = npc_id
	interaction_area.display_name = display_name
	interaction_area.max_generated_items = 0
	interaction_area.item_generation_probability = 0.0
	if not interaction_area.interacted.is_connected(_on_interacted):
		interaction_area.interacted.connect(_on_interacted)
	add_to_group(&"world_npcs")


func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	stop_horizontal_movement(delta)
	move_and_slide()
	if _interacting_actor == null:
		return
	_interaction_remaining = maxf(_interaction_remaining - delta, 0.0)
	if not is_zero_approx(_interaction_remaining):
		return
	_finish_interaction()


func set_visual_color(color: Color) -> void:
	if body_mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.64
	body_mesh.material_override = material


func cancel_interaction() -> void:
	if _interacting_actor == null:
		return
	var actor := _interacting_actor
	_interacting_actor = null
	_interaction_remaining = 0.0
	interaction_finished.emit(self, actor)


func is_interacting() -> bool:
	return _interacting_actor != null


func get_save_data() -> Dictionary:
	return {"gift_claimed": gift_claimed}


func load_save_data(data: Dictionary) -> void:
	gift_claimed = bool(data.get("gift_claimed", false))


func _on_interacted(interactor: Node3D) -> void:
	var actor := interactor as CharacterBody3D
	if actor == null or _interacting_actor != null:
		return
	_interacting_actor = actor
	_interaction_remaining = dialogue_duration
	face_world_position(actor.global_position)
	interaction_started.emit(self, actor, dialogue_line)
	if _interacting_actor != actor:
		return
	if florins_gift > 0 and not gift_claimed:
		gift_claimed = true
		florins_gift_requested.emit(self, actor, florins_gift)


func _finish_interaction() -> void:
	if _interacting_actor == null:
		return
	var actor := _interacting_actor
	_interacting_actor = null
	interaction_finished.emit(self, actor)
