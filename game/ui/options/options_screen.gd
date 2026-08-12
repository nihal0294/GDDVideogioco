class_name OptionsScreen
extends Control

signal apply_requested
signal back_requested

const CATEGORY_TITLES: Array[String] = [
	"Impostazioni di gioco",
	"Impostazioni Grafica",
	"Impostazioni Video",
	"Impostazioni Audio",
	"Controlli",
	"Lingua",
	"Interfaccia",
]

const CATEGORY_DESCRIPTIONS: Array[String] = [
	"Regole generali, assistenza al giocatore e preferenze dell'avventura.",
	"Qualità degli effetti, delle ombre e dei dettagli del mondo.",
	"Risoluzione, modalità schermo e sincronizzazione dell'immagine.",
	"Volume generale, musica, effetti e suoni dell'interfaccia.",
	"Configurazione di tastiera, mouse e controller.",
	"Lingua dei testi e dei contenuti di gioco.",
	"Dimensioni, leggibilità e disposizione dell'interfaccia.",
]

@onready var category_title: Label = %CategoryTitle
@onready var category_description: Label = %CategoryDescription
@onready var placeholder_label: Label = %PlaceholderLabel
@onready var apply_button: Button = %ApplyButton
@onready var back_button: Button = %BackButton
@onready var _category_buttons: Array[Button] = [
	%GameplayButton,
	%GraphicsButton,
	%VideoButton,
	%AudioButton,
	%ControlsButton,
	%LanguageButton,
	%InterfaceButton,
]

var _selected_category_index: int = 0


func _ready() -> void:
	for index: int in _category_buttons.size():
		_category_buttons[index].pressed.connect(_select_category.bind(index))
	apply_button.pressed.connect(_on_apply_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_configure_focus_navigation()
	_select_category(0)


func open() -> void:
	show()
	_select_category(_selected_category_index)
	call_deferred("_focus_selected_category")


func close() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	hide()


func get_selected_category() -> String:
	return CATEGORY_TITLES[_selected_category_index]


func _select_category(index: int) -> void:
	if index < 0 or index >= CATEGORY_TITLES.size():
		return
	_selected_category_index = index
	category_title.text = CATEGORY_TITLES[index]
	category_description.text = CATEGORY_DESCRIPTIONS[index]
	placeholder_label.text = (
		"Le opzioni di questa categoria non sono ancora disponibili. "
		+ "La schermata è pronta per ospitarle."
	)
	for button_index: int in _category_buttons.size():
		_category_buttons[button_index].button_pressed = button_index == index


func _on_apply_pressed() -> void:
	apply_requested.emit()


func _on_back_pressed() -> void:
	back_requested.emit()


func _focus_selected_category() -> void:
	if visible:
		_category_buttons[_selected_category_index].grab_focus()


func _configure_focus_navigation() -> void:
	for index: int in _category_buttons.size():
		var button := _category_buttons[index]
		if index > 0:
			button.focus_neighbor_top = button.get_path_to(_category_buttons[index - 1])
		if index + 1 < _category_buttons.size():
			button.focus_neighbor_bottom = button.get_path_to(_category_buttons[index + 1])
		button.focus_neighbor_right = button.get_path_to(apply_button)
	_category_buttons.back().focus_neighbor_bottom = (
		_category_buttons.back().get_path_to(apply_button)
	)
	apply_button.focus_neighbor_top = apply_button.get_path_to(_category_buttons.back())
	apply_button.focus_neighbor_left = apply_button.get_path_to(_category_buttons.back())
	apply_button.focus_neighbor_right = apply_button.get_path_to(back_button)
	back_button.focus_neighbor_left = back_button.get_path_to(apply_button)
	back_button.focus_neighbor_top = back_button.get_path_to(_category_buttons.back())
