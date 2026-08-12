class_name PauseMenu
extends Control

signal continue_requested
signal options_requested
signal save_requested
signal load_requested
signal exit_requested

@onready var continue_button: Button = %ContinueButton
@onready var options_button: Button = %OptionsButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var exit_button: Button = %ExitButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	options_button.pressed.connect(_on_options_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	_configure_focus_navigation()


func open(has_saves: bool = false) -> void:
	set_continue_available(has_saves)
	show()
	call_deferred("_focus_first_action")


func close() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	hide()


func set_continue_available(has_saves: bool) -> void:
	continue_button.disabled = not has_saves
	load_button.disabled = not has_saves
	continue_button.tooltip_text = (
		"Carica il salvataggio più recente."
		if has_saves
		else "Non è ancora presente alcun salvataggio."
	)
	load_button.tooltip_text = (
		"Scegli un salvataggio da caricare."
		if has_saves
		else "Non è ancora presente alcun salvataggio."
	)


func _on_continue_pressed() -> void:
	continue_requested.emit()


func _on_options_pressed() -> void:
	options_requested.emit()


func _on_save_pressed() -> void:
	save_requested.emit()


func _on_load_pressed() -> void:
	load_requested.emit()


func _on_exit_pressed() -> void:
	exit_requested.emit()


func _focus_first_action() -> void:
	if not visible:
		return
	if not continue_button.disabled:
		continue_button.grab_focus()
	else:
		options_button.grab_focus()


func _configure_focus_navigation() -> void:
	continue_button.focus_neighbor_bottom = continue_button.get_path_to(options_button)
	options_button.focus_neighbor_top = options_button.get_path_to(continue_button)
	options_button.focus_neighbor_bottom = options_button.get_path_to(save_button)
	save_button.focus_neighbor_top = save_button.get_path_to(options_button)
	save_button.focus_neighbor_bottom = save_button.get_path_to(load_button)
	load_button.focus_neighbor_top = load_button.get_path_to(save_button)
	load_button.focus_neighbor_bottom = load_button.get_path_to(exit_button)
	exit_button.focus_neighbor_top = exit_button.get_path_to(load_button)
