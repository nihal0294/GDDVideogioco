class_name NotificationToast
extends Control

@export_range(0.5, 10.0, 0.1) var display_duration: float = 2.5

@onready var message_label: Label = %MessageLabel
@onready var display_timer: Timer = $DisplayTimer

var current_message: String = ""
var pending_messages: Array[String] = []


func _ready() -> void:
	display_timer.timeout.connect(_on_display_timer_timeout)


func show_message(message: String, enqueue: bool = false) -> void:
	if enqueue and visible:
		pending_messages.append(message)
		return
	if not enqueue:
		pending_messages.clear()
	_display_message(message)


func has_pending_message(fragment: String) -> bool:
	for message in pending_messages:
		if fragment in message:
			return true
	return false


func _display_message(message: String) -> void:
	current_message = message
	message_label.text = message
	show()
	display_timer.start(display_duration)


func _on_display_timer_timeout() -> void:
	if pending_messages.is_empty():
		hide()
		return
	_display_message(pending_messages.pop_front())
