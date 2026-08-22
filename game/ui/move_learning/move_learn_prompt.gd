class_name MoveLearnPrompt
extends Control

signal replacement_confirmed(
	astral: AstralInstance,
	move: AstralMoveDefinition,
	replaced_index: int
)
signal learning_declined(astral: AstralInstance, move: AstralMoveDefinition)
signal request_started
signal request_finished

const PRESENTATION := preload("res://game/astrals/astral_presentation.gd")

@onready var title_label: Label = %TitleLabel
@onready var explanation_label: Label = %ExplanationLabel
@onready var move_buttons: Array[Button] = [
	%MoveOneButton,
	%MoveTwoButton,
	%MoveThreeButton,
	%MoveFourButton,
]
@onready var decline_button: Button = %DeclineButton
@onready var confirmation: ConfirmationDialog = %Confirmation

var _requests: Array[Dictionary] = []
var _current: Dictionary = {}
var _selected_move_index: int = -1


func _ready() -> void:
	for index: int in move_buttons.size():
		move_buttons[index].pressed.connect(_on_move_selected.bind(index))
	decline_button.pressed.connect(_on_decline_selected)
	confirmation.confirmed.connect(_on_confirmation_accepted)


func enqueue_request(
	astral: AstralInstance,
	move: AstralMoveDefinition
) -> void:
	if astral == null or move == null or not astral.get_pending_moves().has(move):
		return
	if _matches_request(_current, astral, move):
		return
	for request: Dictionary in _requests:
		if _matches_request(request, astral, move):
			return
	_requests.append({"astral": astral, "move": move})
	if _current.is_empty():
		call_deferred("_show_next_request")


func has_active_request() -> bool:
	return not _current.is_empty()


func get_current_astral() -> AstralInstance:
	return _current.get("astral") as AstralInstance


func get_current_move() -> AstralMoveDefinition:
	return _current.get("move") as AstralMoveDefinition


func _show_next_request() -> void:
	if not _current.is_empty():
		return
	while not _requests.is_empty():
		var candidate: Dictionary = _requests.pop_front()
		var astral := candidate.get("astral") as AstralInstance
		var move := candidate.get("move") as AstralMoveDefinition
		if (
			astral != null
			and is_instance_valid(astral)
			and move != null
			and astral.get_pending_moves().has(move)
		):
			_current = candidate
			break
	if _current.is_empty():
		var was_visible := visible
		hide()
		if was_visible:
			request_finished.emit()
		return
	_populate_current_request()
	if not visible:
		show()
		request_started.emit()


func _populate_current_request() -> void:
	var astral := get_current_astral()
	var move := get_current_move()
	if astral == null or move == null:
		return
	title_label.text = "%s vuole imparare %s" % [
		PRESENTATION.format_identity(astral),
		move.display_name,
	]
	explanation_label.text = (
		"Conosce già quattro mosse. Scegli quale sostituire, "
		+ "oppure rinuncia alla nuova mossa."
	)
	for index: int in move_buttons.size():
		var known_move := astral.get_move(index)
		var button := move_buttons[index]
		button.disabled = known_move == null
		button.text = (
			"%d. %s    •    Potenza %d    •    CD %d" % [
				index + 1,
				known_move.display_name,
				known_move.power,
				known_move.cooldown_turns,
			]
			if known_move != null
			else "%d. Slot libero" % (index + 1)
		)
	_selected_move_index = -1
	move_buttons.front().grab_focus()


func _on_move_selected(index: int) -> void:
	var astral := get_current_astral()
	var new_move := get_current_move()
	var previous_move := astral.get_move(index) if astral != null else null
	if astral == null or new_move == null or previous_move == null:
		return
	_selected_move_index = index
	confirmation.title = "Conferma sostituzione"
	confirmation.ok_button_text = "Conferma"
	confirmation.dialog_text = "Sostituire %s con %s?" % [
		previous_move.display_name,
		new_move.display_name,
	]
	confirmation.popup_centered(Vector2i(540, 0))


func _on_decline_selected() -> void:
	var move := get_current_move()
	if move == null:
		return
	_selected_move_index = -2
	confirmation.title = "Conferma rinuncia"
	confirmation.ok_button_text = "Rinuncia"
	confirmation.dialog_text = "Rinunciare definitivamente a %s?" % move.display_name
	confirmation.popup_centered(Vector2i(540, 0))


func _on_confirmation_accepted() -> void:
	var astral := get_current_astral()
	var move := get_current_move()
	if astral == null or move == null:
		_finish_current_request()
		return
	if _selected_move_index >= 0:
		replacement_confirmed.emit(astral, move, _selected_move_index)
	elif _selected_move_index == -2:
		learning_declined.emit(astral, move)
	_finish_current_request()


func _finish_current_request() -> void:
	_current.clear()
	_selected_move_index = -1
	call_deferred("_show_next_request")


func _matches_request(
	request: Dictionary,
	astral: AstralInstance,
	move: AstralMoveDefinition
) -> bool:
	return request.get("astral") == astral and request.get("move") == move
