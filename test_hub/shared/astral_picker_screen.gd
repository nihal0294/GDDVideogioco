class_name AstralPickerScreen
extends Control

signal astral_selected(definition: AstralDefinition, level: int)

@export var title_text: String = "Choose an Astral":
	set(value):
		title_text = value
		if is_node_ready():
			title_label.text = title_text

@onready var title_label: Label = %TitleLabel
@onready var astral_list: ItemList = %AstralList
@onready var level_spin_box: SpinBox = %LevelSpinBox
@onready var confirm_button: Button = %ConfirmButton
@onready var close_button: Button = %CloseButton

var _definitions: Array[AstralDefinition] = []


func _ready() -> void:
	title_label.text = title_text
	confirm_button.pressed.connect(_on_confirm_pressed)
	close_button.pressed.connect(_on_close_pressed)
	level_spin_box.min_value = 1
	level_spin_box.max_value = AstralDefinition.MAX_LEVEL
	level_spin_box.value = 5


func open() -> void:
	_refresh_list()
	show()
	call_deferred("_focus_list")


func close() -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	hide()


func _refresh_list() -> void:
	if not _definitions.is_empty():
		return
	_definitions = AstralCatalog.load_ordered_definitions()
	astral_list.clear()
	for definition: AstralDefinition in _definitions:
		var item_index := astral_list.add_item(definition.display_name)
		astral_list.set_item_metadata(item_index, definition)
	if not _definitions.is_empty():
		astral_list.select(0)


func _on_confirm_pressed() -> void:
	var selected := astral_list.get_selected_items()
	if selected.is_empty():
		return
	var definition := astral_list.get_item_metadata(selected[0]) as AstralDefinition
	if definition == null:
		return
	astral_selected.emit(definition, int(level_spin_box.value))
	close()


func _on_close_pressed() -> void:
	close()


func _focus_list() -> void:
	if not visible or _definitions.is_empty():
		return
	astral_list.grab_focus()
	astral_list.ensure_current_is_visible()
