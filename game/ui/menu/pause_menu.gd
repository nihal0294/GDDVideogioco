class_name PauseMenu
extends Control

@onready var options_button: Button = %OptionsButton


func open() -> void:
	show()
	options_button.grab_focus()


func close() -> void:
	hide()
