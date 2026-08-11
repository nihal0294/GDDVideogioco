class_name DayNightCycle
extends Node

signal time_changed(hour: int, minute: int)
signal new_day(day: int)

@export_range(0.0, 23.99, 0.25) var starting_hour: float = 8.0
@export_range(1.0, 600.0, 1.0) var real_seconds_per_game_hour: float = 60.0
@export_range(0.0, 12.0, 0.25) var sunrise_hour: float = 6.0
@export_range(12.0, 24.0, 0.25) var sunset_hour: float = 18.0
@export_range(0.0, 4.0, 0.05) var maximum_sun_energy: float = 1.15
@export var sunrise_color := Color("ffad73")
@export var noon_color := Color("fff4d6")
@export var night_ambient_color := Color("11182b")
@export var day_ambient_color := Color("b9d8f2")
@export var twilight_ambient_color := Color("9b5d55")

var sun: DirectionalLight3D
var world_environment: WorldEnvironment
var game_hour: float = 8.0
var elapsed_days: int = 0

var _clock_label: Label
var _clock_update_accumulator: float = 0.0
var _last_displayed_minute: int = -1
var _sun_azimuth: float = 0.0
var _environment: Environment


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game_hour = fposmod(starting_hour, 24.0)
	if sun != null:
		_sun_azimuth = sun.rotation.y
	_prepare_environment()
	_create_clock_ui()
	_update_clock(true)
	_update_lighting()


func _process(delta: float) -> void:
	var previous_hour := game_hour
	game_hour += delta / maxf(real_seconds_per_game_hour, 1.0)
	if game_hour >= 24.0:
		game_hour = fposmod(game_hour, 24.0)
		elapsed_days += 1
		new_day.emit(elapsed_days)
	elif game_hour < previous_hour:
		elapsed_days += 1
		new_day.emit(elapsed_days)

	_clock_update_accumulator += delta
	if _clock_update_accumulator >= 0.2:
		_clock_update_accumulator = fmod(_clock_update_accumulator, 0.2)
		_update_clock(false)
	_update_lighting()


func get_game_time() -> Dictionary[String, int]:
	var total_minutes := int(floor(game_hour * 60.0)) % (24 * 60)
	return {
		"hour": int(total_minutes / 60),
		"minute": total_minutes % 60,
		"day": elapsed_days,
	}


func set_game_time(hour: int, minute: int = 0) -> void:
	game_hour = fposmod(float(hour) + float(minute) / 60.0, 24.0)
	_update_clock(true)
	_update_lighting()


func _prepare_environment() -> void:
	if world_environment == null or world_environment.environment == null:
		return
	_environment = world_environment.environment.duplicate(true) as Environment
	world_environment.environment = _environment
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR


func _create_clock_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ClockCanvas"
	canvas.layer = 8
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.name = "ClockPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -170.0
	panel.offset_top = 18.0
	panel.offset_right = -18.0
	panel.offset_bottom = 68.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.05, 0.08, 0.88)
	panel_style.border_color = Color(0.72, 0.82, 0.92, 0.7)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", panel_style)
	canvas.add_child(panel)

	_clock_label = Label.new()
	_clock_label.name = "ClockLabel"
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock_label.add_theme_font_size_override("font_size", 22)
	_clock_label.add_theme_color_override("font_color", Color("f3f7ff"))
	_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_clock_label)


func _update_clock(force_update: bool) -> void:
	var time := get_game_time()
	var hour: int = time["hour"]
	var minute: int = time["minute"]
	var total_minutes := hour * 60 + minute
	if not force_update and total_minutes == _last_displayed_minute:
		return
	_last_displayed_minute = total_minutes
	if _clock_label != null:
		_clock_label.text = "Ora  %02d:%02d" % [hour, minute]
	time_changed.emit(hour, minute)


func _update_lighting() -> void:
	var daylight_duration := maxf(sunset_hour - sunrise_hour, 1.0)
	var solar_angle := (game_hour - sunrise_hour) / daylight_duration * PI
	var solar_elevation := sin(solar_angle)
	var daylight_factor := smoothstep(-0.08, 0.28, solar_elevation)
	var noon_factor := clampf(solar_elevation, 0.0, 1.0)

	if sun != null:
		sun.rotation = Vector3(-solar_angle, _sun_azimuth, 0.0)
		sun.light_energy = maximum_sun_energy * daylight_factor
		sun.light_color = sunrise_color.lerp(
			noon_color,
			pow(noon_factor, 0.35)
		)
		sun.shadow_enabled = daylight_factor > 0.02

	if _environment == null:
		return
	var ambient_color := night_ambient_color.lerp(day_ambient_color, daylight_factor)
	var twilight_weight := clampf(1.0 - absf(daylight_factor - 0.3) / 0.3, 0.0, 1.0)
	ambient_color = ambient_color.lerp(twilight_ambient_color, twilight_weight * 0.3)
	_environment.ambient_light_color = ambient_color
	_environment.ambient_light_energy = lerpf(0.16, 0.72, daylight_factor)
	_environment.background_energy_multiplier = lerpf(0.08, 1.0, daylight_factor)
