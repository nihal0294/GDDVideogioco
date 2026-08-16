class_name AstralMoveDefinition
extends Resource

enum DamageClass {
	PHYSICAL,
	MAGICAL,
}

@export var move_id: StringName = &""
@export var display_name: String = "Mossa"
@export_multiline var description: String = ""
@export_range(0, 999, 1) var power: int = 0
@export var element_id: StringName = &"neutro"
@export_enum("Fisico", "Magico") var damage_class: int = DamageClass.PHYSICAL
@export_range(0, 3, 1) var cooldown_turns: int = 0


func get_damage_class_name() -> String:
	return "Magico" if damage_class == DamageClass.MAGICAL else "Fisico"
