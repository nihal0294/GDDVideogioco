class_name AstralEvolutionOption
extends Resource

enum Method {
	LEVEL,
	ITEM,
}

@export var method: Method = Method.LEVEL
@export_range(1, 100, 1) var required_level: int = 1
@export var required_item_id: StringName = &""
@export var target: AstralDefinition


func is_available(level: int, item_id: StringName = &"") -> bool:
	if target == null or level < required_level:
		return false
	if method == Method.ITEM:
		return not required_item_id.is_empty() and item_id == required_item_id
	return true


func get_method_text() -> String:
	if method == Method.ITEM:
		return "Oggetto: %s" % String(required_item_id).replace("_", " ").capitalize()
	return "Livello %d" % required_level
