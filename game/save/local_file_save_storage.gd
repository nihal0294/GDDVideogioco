class_name LocalFileSaveStorage
extends SaveStorage

var _last_error: Error = OK


func ensure_directory(directory_path: String) -> bool:
	if not directory_path.begins_with("user://") or ".." in directory_path:
		_last_error = ERR_INVALID_PARAMETER
		return false
	var absolute_path := ProjectSettings.globalize_path(directory_path)
	_last_error = DirAccess.make_dir_recursive_absolute(absolute_path)
	return _last_error == OK or _last_error == ERR_ALREADY_EXISTS


func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func write_text(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_last_error = FileAccess.get_open_error()
		return false
	file.store_string(content)
	file.flush()
	file.close()
	_last_error = OK
	return true


func read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_last_error = FileAccess.get_open_error()
		return ""
	var content := file.get_as_text()
	file.close()
	_last_error = OK
	return content


func get_last_error() -> Error:
	return _last_error

