class_name ElementChartScreen
extends Control

signal back_requested

const CELL_SIZE := Vector2(106.0, 52.0)
const DIAGONAL_COLOR := Color("435b78")
const STRONG_RESISTANCE_COLOR := Color("264d73")
const RESISTANCE_COLOR := Color("477493")
const NEUTRAL_COLOR := Color("39434f")
const WEAKNESS_COLOR := Color("a36b2f")
const STRONG_WEAKNESS_COLOR := Color("a63d3d")

@onready var chart_grid: GridContainer = %ChartGrid
@onready var legend: HBoxContainer = %Legend
@onready var back_button: Button = %BackButton

var _cells: Dictionary = {}


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_build_legend()
	_build_chart()


func open() -> void:
	show()
	call_deferred("_focus_back_button")


func close() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	hide()


func get_chart_cell(
	attacking_element: StringName,
	defending_element: StringName
) -> Control:
	var key := _cell_key(attacking_element, defending_element)
	return _cells.get(key) as Control


func get_element_count() -> int:
	return ElementChart.ELEMENT_IDS.size()


func _build_chart() -> void:
	for child: Node in chart_grid.get_children():
		child.queue_free()
	_cells.clear()
	chart_grid.columns = ElementChart.ELEMENT_IDS.size()
	for attacking_element: StringName in ElementChart.ELEMENT_IDS:
		for defending_element: StringName in ElementChart.ELEMENT_IDS:
			var is_diagonal := attacking_element == defending_element
			var multiplier := ElementChart.get_multiplier(
				attacking_element,
				defending_element
			)
			var cell := _create_cell(
				attacking_element,
				defending_element,
				multiplier,
				is_diagonal
			)
			chart_grid.add_child(cell)
			_cells[_cell_key(attacking_element, defending_element)] = cell


func _create_cell(
	attacking_element: StringName,
	defending_element: StringName,
	multiplier: float,
	is_diagonal: bool
) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.set_meta(&"attacking_element", attacking_element)
	cell.set_meta(&"defending_element", defending_element)
	cell.set_meta(&"multiplier", multiplier)
	cell.set_meta(&"is_diagonal", is_diagonal)
	cell.add_theme_stylebox_override(
		"panel",
		_create_cell_style(
			DIAGONAL_COLOR if is_diagonal else _get_multiplier_color(multiplier)
		)
	)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15 if is_diagonal else 18)
	label.text = (
		ElementChart.get_display_name(attacking_element)
		if is_diagonal
		else ElementChart.get_multiplier_label(multiplier)
	)
	cell.add_child(label)
	cell.tooltip_text = "%s → %s: %s (%s)" % [
		ElementChart.get_display_name(attacking_element),
		ElementChart.get_display_name(defending_element),
		ElementChart.get_multiplier_label(multiplier),
		ElementChart.get_effectiveness_name(multiplier),
	]
	return cell


func _build_legend() -> void:
	for child: Node in legend.get_children():
		child.queue_free()
	var entries: Array[Dictionary] = [
		{"value": 0.25, "label": "1/4  Forte resistenza"},
		{"value": 0.5, "label": "1/2  Resistenza"},
		{"value": 1.0, "label": "1  Neutrale"},
		{"value": 2.0, "label": "2  Superefficace"},
		{"value": 4.0, "label": "4  Iperefficace"},
	]
	for entry: Dictionary in entries:
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override(
			"panel",
			_create_cell_style(_get_multiplier_color(float(entry["value"])))
		)
		var label := Label.new()
		label.text = String(entry["label"])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(164.0, 34.0)
		badge.add_child(label)
		legend.add_child(badge)


func _get_multiplier_color(multiplier: float) -> Color:
	if multiplier <= ElementChart.STRONG_RESISTANCE:
		return STRONG_RESISTANCE_COLOR
	if multiplier < ElementChart.NEUTRAL:
		return RESISTANCE_COLOR
	if multiplier >= ElementChart.STRONG_WEAKNESS:
		return STRONG_WEAKNESS_COLOR
	if multiplier > ElementChart.NEUTRAL:
		return WEAKNESS_COLOR
	return NEUTRAL_COLOR


func _create_cell_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = background_color.lightened(0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _cell_key(
	attacking_element: StringName,
	defending_element: StringName
) -> String:
	return "%s>%s" % [
		ElementChart.normalize_element(attacking_element),
		ElementChart.normalize_element(defending_element),
	]


func _on_back_pressed() -> void:
	back_requested.emit()


func _focus_back_button() -> void:
	if visible:
		back_button.grab_focus()
