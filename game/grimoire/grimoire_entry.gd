class_name GrimoireEntry
extends Resource

@export_range(1, 9999, 1) var entry_number: int = 1
@export var astral: AstralDefinition
@export var spawn_zones: Array[String] = []
@export var habitat: String = "Sconosciuto"
@export_multiline var field_notes: String = ""


func get_entry_id() -> StringName:
	return astral.astral_id if astral != null else &""


func get_spawn_zones_text() -> String:
	return " / ".join(spawn_zones) if not spawn_zones.is_empty() else "Non disponibile"
