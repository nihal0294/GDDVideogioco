class_name LevelUpSummary
extends Control

const STAT_ROWS: Array[Dictionary] = [
	{"key": &"health", "label": "Vita (HP)"},
	{"key": &"attack", "label": "Attacco (Atk)"},
	{"key": &"physical_defense", "label": "Difesa fisica (PDef)"},
	{"key": &"magic_attack", "label": "Attacco magico (MAtk)"},
	{"key": &"magic_defense", "label": "Difesa magica (MDef)"},
	{"key": &"speed", "label": "Velocità (Spd)"},
]

@export_range(0.25, 10.0, 0.05) var display_duration: float = 2.6

@onready var title_label: Label = %TitleLabel
@onready var rarity_label: Label = %RarityLabel
@onready var stats_grid: GridContainer = %StatsGrid
@onready var evolution_notice: Label = %EvolutionNotice

var _summaries: Array[Dictionary] = []
var _showing: bool = false
var _generation: int = 0


func enqueue_summary(
	astral: AstralInstance,
	previous_level: int,
	new_level: int
) -> void:
	if astral == null or astral.definition == null or new_level <= previous_level:
		return
	_summaries.append({
		"name": astral.definition.display_name,
		"rarity": astral.definition.get_rarity_name(),
		"rarity_color": astral.definition.get_rarity_color(),
		"previous_level": previous_level,
		"new_level": new_level,
		"before": astral.get_stat_snapshot(previous_level),
		"after": astral.get_stat_snapshot(new_level),
		"evolution_available": (
			astral.definition.get_available_evolutions(new_level).size()
			> astral.definition.get_available_evolutions(previous_level).size()
		),
	})
	if not _showing:
		call_deferred("_show_queued_summaries")


func clear_summaries() -> void:
	_generation += 1
	_summaries.clear()
	_showing = false
	hide()


func _show_queued_summaries() -> void:
	if _showing or _summaries.is_empty():
		return
	_showing = true
	var current_generation := _generation
	while not _summaries.is_empty() and current_generation == _generation:
		_display_summary(_summaries.pop_front())
		show()
		await get_tree().create_timer(display_duration, true, false, true).timeout
	if current_generation == _generation:
		hide()
		_showing = false


func _display_summary(summary: Dictionary) -> void:
	title_label.text = "%s sale al livello %d" % [
		String(summary.get("name", "Astral")),
		int(summary.get("new_level", 1)),
	]
	rarity_label.text = "%s    •    Livello %d → %d" % [
		String(summary.get("rarity", "Comune")),
		int(summary.get("previous_level", 1)),
		int(summary.get("new_level", 1)),
	]
	rarity_label.add_theme_color_override(
		"font_color",
		summary.get("rarity_color", Color.WHITE) as Color
	)
	for child: Node in stats_grid.get_children():
		child.queue_free()
	_add_cell("Statistica", true)
	_add_cell("Prima", true)
	_add_cell("Ottenuto", true)
	_add_cell("Dopo", true)
	var before := summary.get("before", {}) as Dictionary
	var after := summary.get("after", {}) as Dictionary
	for row: Dictionary in STAT_ROWS:
		var stat_key := row.get("key", &"") as StringName
		var previous_value := int(before.get(stat_key, 0))
		var new_value := int(after.get(stat_key, previous_value))
		_add_cell(String(row.get("label", "Stat")))
		_add_cell(str(previous_value))
		_add_cell("+%d" % maxi(new_value - previous_value, 0), false, true)
		_add_cell(str(new_value))
	evolution_notice.visible = bool(summary.get("evolution_available", false))


func _add_cell(text_value: String, header: bool = false, gain: bool = false) -> void:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(116, 26)
	if header:
		label.add_theme_color_override("font_color", Color(0.72, 0.86, 0.95, 1.0))
		label.add_theme_font_size_override("font_size", 15)
	elif gain:
		label.add_theme_color_override("font_color", Color(0.45, 0.94, 0.58, 1.0))
	stats_grid.add_child(label)
