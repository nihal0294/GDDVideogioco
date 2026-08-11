extends StaticBody3D

signal map_object_interacted(
	object_id: StringName,
	category: StringName,
	interactor: Node3D
)
signal map_interactable_interacted(
	interactable: InteractableArea3D,
	interactor: Node3D
)

@onready var map_mesh: MeshInstance3D = $MapMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var interactables: Node3D = $Interactables


func _ready() -> void:
	_build_collision()
	_connect_interactables()


func _build_collision() -> void:
	var source_mesh := map_mesh.mesh
	if source_mesh == null:
		push_error("La mappa island non ha una mesh da usare per la collisione.")
		return

	var trimesh_shape := source_mesh.create_trimesh_shape()
	if trimesh_shape == null:
		push_error("Impossibile creare la collisione trimesh per la mappa island.")
		return

	collision_shape.shape = trimesh_shape


func _connect_interactables() -> void:
	for child in interactables.get_children():
		var interactable := child as InteractableArea3D
		if interactable == null:
			continue
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
