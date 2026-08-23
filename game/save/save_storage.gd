class_name SaveStorage
extends RefCounted


func ensure_directory(_directory_path: String) -> bool:
	return false


func file_exists(_path: String) -> bool:
	return false


func write_text(_path: String, _content: String) -> bool:
	return false


func read_text(_path: String) -> String:
	return ""


func get_last_error() -> Error:
	return ERR_UNAVAILABLE

