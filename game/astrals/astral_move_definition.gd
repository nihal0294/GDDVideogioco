class_name AstralMoveDefinition
extends Resource

enum DamageClass {
	PHYSICAL,
	MAGICAL,
	STATUS,
}

@export var move_id: StringName = &""
@export var display_name: String = "Mossa"
@export_multiline var description: String = ""
@export_range(0, 999, 1) var power: int = 0
@export var element_id: StringName = &"neutro"
@export_enum("Fisico", "Magico", "Setup") var damage_class: int = DamageClass.PHYSICAL
@export_range(0, 5, 1) var cooldown_turns: int = 0


func get_damage_class_name() -> String:
	match damage_class:
		DamageClass.MAGICAL:
			return "Magico"
		DamageClass.STATUS:
			return "Setup"
		_:
			return "Fisico"
