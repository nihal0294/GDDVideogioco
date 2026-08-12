class_name PlayerProfileScreen
extends Control

signal close_requested

@onready var player_name_value: Label = %PlayerNameValue
@onready var currency_value: Label = %CurrencyValue
@onready var captured_value: Label = %CapturedValue
@onready var medals_summary: Label = %MedalsSummary
@onready var medal_grid: GridContainer = %MedalGrid
@onready var adventure_summary: Label = %AdventureSummary
@onready var close_button: Button = %CloseButton

var profile: PlayerProfile = null


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	_refresh_profile()


func setup(source_profile: PlayerProfile) -> void:
	_disconnect_profile()
	profile = source_profile
	if profile != null:
		profile.profile_changed.connect(_refresh_profile)
	_refresh_profile()


func open() -> void:
	show()
	_refresh_profile()
	close_button.call_deferred("grab_focus")


func close() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	hide()


func _refresh_profile() -> void:
	_clear_medal_grid()
	if profile == null:
		player_name_value.text = "Avventuriero"
		currency_value.text = "0 Fiorini"
		captured_value.text = "0"
		medals_summary.text = "0 / 8"
		adventure_summary.text = "Nessun riepilogo disponibile."
		for medal_index: int in PlayerProfile.MEDAL_SLOT_COUNT:
			_add_medal_slot(medal_index, false)
		return

	player_name_value.text = profile.player_name
	currency_value.text = "%d %s" % [profile.florins, profile.currency_name]
	captured_value.text = str(profile.captured_monster_count)
	medals_summary.text = "%d / %d" % [
		profile.get_medal_count(),
		PlayerProfile.MEDAL_SLOT_COUNT,
	]
	adventure_summary.text = profile.adventure_summary
	for medal_index: int in PlayerProfile.MEDAL_SLOT_COUNT:
		_add_medal_slot(medal_index, profile.has_medal(medal_index))


func _add_medal_slot(medal_index: int, earned: bool) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(118.0, 82.0)
	panel.tooltip_text = (
		"Medaglia %d ottenuta" % (medal_index + 1)
		if earned
		else "Medaglia %d non ancora ottenuta" % (medal_index + 1)
	)
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.32, 0.22, 0.06, 0.98)
		if earned
		else Color(0.07, 0.085, 0.11, 0.96)
	)
	style.border_color = (
		Color(0.95, 0.72, 0.2, 0.95)
		if earned
		else Color(0.25, 0.3, 0.36, 0.8)
	)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_right = 9
	style.corner_radius_bottom_left = 9
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "%s\n%d" % ["◆" if earned else "◇", medal_index + 1]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.82, 0.36, 1.0) if earned else Color(0.48, 0.53, 0.6, 1.0)
	)
	panel.add_child(label)
	medal_grid.add_child(panel)


func _clear_medal_grid() -> void:
	for child: Node in medal_grid.get_children():
		medal_grid.remove_child(child)
		child.queue_free()


func _on_close_pressed() -> void:
	close_requested.emit()


func _disconnect_profile() -> void:
	if profile == null or not is_instance_valid(profile):
		return
	if profile.profile_changed.is_connected(_refresh_profile):
		profile.profile_changed.disconnect(_refresh_profile)
