class_name AstralMoveDefinition
extends Resource

@export var move_id: StringName = &""
@export var display_name: String = "Mossa"
@export_multiline var description: String = ""
@export_range(0, 999, 1) var power: int = 0
@export var element_id: StringName = &"neutro"
@export_range(0, 3, 1) var cooldown_turns: int = 0
