class_name SquadScreen
extends Control

signal close_requested
signal notification_requested(message: String)

const PRESENTATION := preload("res://game/astrals/astral_presentation.gd")

@onready var astral_list: ItemList = %AstralList
@onready var astral_color: ColorRect = %AstralColor
@onready var portrait_preview: SubViewportContainer = %PortraitPreview
@onready var portrait_viewport: SubViewport = %PortraitViewport
@onready var portrait_model: AstralModel3D = %PortraitModel
@onready var astral_name: Label = %AstralName
@onready var lead_badge: Label = %LeadBadge
@onready var position_label: Label = %PositionLabel
@onready var rarity_value: Label = %RarityValue
@onready var description_label: Label = %DescriptionLabel
@onready var level_value: Label = %LevelValue
@onready var bst_value: Label = %BstValue
@onready var health_value: Label = %HealthValue
@onready var health_bar: ProgressBar = %HealthBar
@onready var attack_value: Label = %AttackValue
@onready var physical_defense_value: Label = %PhysicalDefenseValue
@onready var magic_attack_value: Label = %MagicAttackValue
@onready var magic_defense_value: Label = %MagicDefenseValue
@onready var speed_value: Label = %SpeedValue
@onready var elements_value: Label = %ElementsValue
@onready var experience_value: Label = %ExperienceValue
@onready var experience_bar: ProgressBar = %ExperienceBar
@onready var move_one: Label = %MoveOne
@onready var move_two: Label = %MoveTwo
@onready var move_three: Label = %MoveThree
@onready var move_four: Label = %MoveFour
@onready var move_up_button: Button = %MoveUpButton
@onready var move_down_button: Button = %MoveDownButton
@onready var set_lead_button: Button = %SetLeadButton
@onready var evolve_button: Button = %EvolveButton
@onready var close_button: Button = %CloseButton
@onready var evolution_menu: PopupMenu = $EvolutionMenu

var roster: AstralRoster = null
var inventory: Inventory = null
var _astrals: Array[AstralInstance] = []
var _selected_astral: AstralInstance = null
var _move_labels: Array[Label] = []


func _ready() -> void:
	_move_labels = [move_one, move_two, move_three, move_four]
	astral_list.item_selected.connect(_on_astral_selected)
	astral_list.item_activated.connect(_on_astral_activated)
	move_up_button.pressed.connect(_on_move_up_pressed)
	move_down_button.pressed.connect(_on_move_down_pressed)
	set_lead_button.pressed.connect(_on_set_lead_pressed)
	evolve_button.pressed.connect(_on_evolve_pressed)
	evolution_menu.id_pressed.connect(_on_evolution_selected)
	close_button.pressed.connect(_on_close_pressed)
	_configure_focus_navigation()
	_clear_details()


func setup(
	source_roster: AstralRoster = null,
	source_inventory: Inventory = null
) -> void:
	_disconnect_roster_signals()
	roster = source_roster
	inventory = source_inventory
	_connect_roster_signals()
	_refresh_roster()


func open() -> void:
	show()
	_refresh_roster()
	call_deferred("_focus_astral_list")


func close() -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	hide()


func _connect_roster_signals() -> void:
	if roster == null:
		return
	var roster_changed_callback := Callable(self, "_on_roster_changed")
	if (
		roster.has_signal("roster_changed")
		and not roster.is_connected("roster_changed", roster_changed_callback)
	):
		roster.connect("roster_changed", roster_changed_callback)
	var captured_callback := Callable(self, "_on_astral_captured")
	if (
		roster.has_signal("astral_captured")
		and not roster.is_connected("astral_captured", captured_callback)
	):
		roster.connect("astral_captured", captured_callback)


func _disconnect_roster_signals() -> void:
	if roster == null or not is_instance_valid(roster):
		return
	var roster_changed_callback := Callable(self, "_on_roster_changed")
	if (
		roster.has_signal("roster_changed")
		and roster.is_connected("roster_changed", roster_changed_callback)
	):
		roster.disconnect("roster_changed", roster_changed_callback)
	var captured_callback := Callable(self, "_on_astral_captured")
	if (
		roster.has_signal("astral_captured")
		and roster.is_connected("astral_captured", captured_callback)
	):
		roster.disconnect("astral_captured", captured_callback)


func _on_roster_changed() -> void:
	_refresh_roster()


func _on_astral_captured(_astral: AstralInstance) -> void:
	_refresh_roster()


func _refresh_roster() -> void:
	var retained_astral: AstralInstance = _selected_astral
	_astrals = _read_astrals()
	astral_list.clear()

	for index: int in _astrals.size():
		var astral: AstralInstance = _astrals[index]
		var definition: AstralDefinition = astral.definition
		var display_name := "Astral senza nome"
		var maximum_health := 0
		if definition != null:
			display_name = PRESENTATION.format_identity(astral)
			maximum_health = _get_maximum_health(astral, definition)
		var lead_marker := "★ " if index == 0 else ""
		var item_index := astral_list.add_item(
			"%d. %s%s    Lv.%d    HP %d/%d" % [
				index + 1,
				lead_marker,
				display_name,
				astral.level,
				astral.current_health,
				maximum_health,
			]
		)
		astral_list.set_item_metadata(item_index, astral)

	if _astrals.is_empty():
		var empty_index := astral_list.add_item("Nessun Astral nella squadra")
		astral_list.set_item_disabled(empty_index, true)
		_selected_astral = null
		_clear_details()
		return

	var selected_index := _astrals.find(retained_astral)
	if selected_index < 0:
		selected_index = 0
	astral_list.select(selected_index)
	astral_list.ensure_current_is_visible()
	_on_astral_selected(selected_index)


func _read_astrals() -> Array[AstralInstance]:
	var result: Array[AstralInstance] = []
	if roster == null:
		return result
	if roster.has_method("get_astrals"):
		var raw_astrals: Variant = roster.call("get_astrals")
		if raw_astrals is Array:
			for candidate: Variant in raw_astrals:
				if candidate is AstralInstance:
					result.append(candidate as AstralInstance)
		return result

	if not roster.has_method("get_astral_count") or not roster.has_method("get_astral"):
		return result
	var astral_count := int(roster.call("get_astral_count"))
	for index: int in astral_count:
		var candidate: Variant = roster.call("get_astral", index)
		if candidate is AstralInstance:
			result.append(candidate as AstralInstance)
	return result


func _on_astral_selected(item_index: int) -> void:
	if item_index < 0 or item_index >= _astrals.size():
		_selected_astral = null
		_clear_details()
		return
	_selected_astral = _astrals[item_index]
	_show_astral_details(_selected_astral, item_index)
	_update_reorder_buttons(item_index)


func _on_astral_activated(item_index: int) -> void:
	if item_index < 0 or item_index >= _astrals.size():
		return
	astral_list.select(item_index)
	_on_astral_selected(item_index)
	_set_selected_as_lead()


func _on_move_up_pressed() -> void:
	_move_selected_astral(-1)


func _on_move_down_pressed() -> void:
	_move_selected_astral(1)


func _on_set_lead_pressed() -> void:
	_set_selected_as_lead()


func _on_evolve_pressed() -> void:
	if roster == null or _selected_astral == null:
		return
	var options := roster.get_available_evolutions(_selected_astral, inventory)
	if options.is_empty():
		return
	evolution_menu.clear()
	for option_index: int in options.size():
		var option := options[option_index]
		evolution_menu.add_item(
			"%s - %s" % [option.target.display_name, option.get_method_text()],
			option_index
		)
		evolution_menu.set_item_metadata(option_index, option)
	evolution_menu.popup_centered(Vector2i(460, 0))


func _on_evolution_selected(menu_id: int) -> void:
	var menu_index := evolution_menu.get_item_index(menu_id)
	if menu_index < 0 or roster == null or _selected_astral == null:
		return
	var option := evolution_menu.get_item_metadata(menu_index) as AstralEvolutionOption
	var previous_name := _selected_astral.definition.display_name
	if not roster.evolve_astral(_selected_astral, option, inventory):
		notification_requested.emit("Le condizioni per l'evoluzione non sono soddisfatte.")
		return
	notification_requested.emit(
		"%s si è evoluto in %s!" % [
			previous_name,
			_selected_astral.definition.display_name,
		]
	)
	_refresh_roster()


func _on_close_pressed() -> void:
	close_requested.emit()


func _move_selected_astral(direction: int) -> void:
	var selected_index := _get_selected_index()
	var target_index := selected_index + direction
	if (
		roster == null
		or selected_index < 0
		or target_index < 0
		or target_index >= _astrals.size()
		or not roster.has_method("move_astral")
	):
		return
	var moved := bool(roster.call("move_astral", selected_index, target_index))
	if moved:
		_refresh_roster()
		_focus_astral_list()


func _set_selected_as_lead() -> void:
	var selected_index := _get_selected_index()
	if (
		roster == null
		or selected_index <= 0
		or not roster.has_method("set_active_astral")
	):
		return
	var changed := bool(roster.call("set_active_astral", selected_index))
	if changed:
		_refresh_roster()
		_focus_astral_list()


func _get_selected_index() -> int:
	if _selected_astral == null:
		return -1
	return _astrals.find(_selected_astral)


func _update_reorder_buttons(selected_index: int) -> void:
	var has_selection := selected_index >= 0 and selected_index < _astrals.size()
	move_up_button.disabled = not has_selection or selected_index == 0
	move_down_button.disabled = (
		not has_selection or selected_index == _astrals.size() - 1
	)
	set_lead_button.disabled = not has_selection or selected_index == 0


func _show_astral_details(astral: AstralInstance, roster_index: int) -> void:
	var definition: AstralDefinition = astral.definition
	if definition == null:
		_clear_details()
		return

	astral_name.text = PRESENTATION.format_identity(astral)
	description_label.text = (
		definition.description
		if not definition.description.strip_edges().is_empty()
		else "Nessuna descrizione disponibile."
	)
	lead_badge.visible = roster_index == 0
	position_label.text = "Posizione in squadra: %d" % (roster_index + 1)
	rarity_value.text = "Rarità: %s" % definition.get_rarity_name()
	rarity_value.add_theme_color_override("font_color", definition.get_rarity_color())
	level_value.text = str(astral.level)
	bst_value.text = "%d / %d" % [
		definition.get_base_stat_total(),
		AstralDefinition.MAX_BASE_STAT_TOTAL,
	]

	var maximum_health := _get_maximum_health(astral, definition)
	health_value.text = "%d / %d" % [astral.current_health, maximum_health]
	health_bar.max_value = maxf(float(maximum_health), 1.0)
	health_bar.value = clampf(float(astral.current_health), 0.0, health_bar.max_value)
	attack_value.text = str(astral.get_attack_power())
	physical_defense_value.text = str(astral.get_physical_defense())
	magic_attack_value.text = str(astral.get_magic_attack())
	magic_defense_value.text = str(astral.get_magic_defense())
	speed_value.text = str(astral.get_speed())
	elements_value.text = _format_elements(definition)
	_update_experience(astral, definition)
	_update_moves(astral, definition)
	_update_evolution_button(astral)

	var color_value: Variant = _get_property_value(
		definition,
		[&"visual_color"],
		Color(0.25, 0.65, 1.0, 1.0)
	)
	astral_color.color = (
		color_value
		if color_value is Color
		else Color(0.25, 0.65, 1.0, 1.0)
	)
	_show_static_portrait(definition)


func _get_maximum_health(
	astral: AstralInstance,
	definition: AstralDefinition
) -> int:
	if astral.has_method("get_max_health"):
		return maxi(int(astral.call("get_max_health")), 0)
	return maxi(
		int(_get_property_value(definition, [&"max_health"], 0)),
		0
	)


func _get_instance_or_definition_value(
	astral: AstralInstance,
	definition: AstralDefinition,
	property_names: Array[StringName]
) -> Variant:
	var instance_value: Variant = _get_property_value(
		astral,
		property_names,
		null
	)
	if instance_value != null:
		return instance_value
	return _get_property_value(definition, property_names, null)


func _update_experience(
	astral: AstralInstance,
	_definition: AstralDefinition
) -> void:
	var current_experience := astral.get_experience_progress_in_level()
	var required_experience := astral.get_experience_to_next_level()

	if required_experience <= 0:
		experience_value.text = "EXP totale %d    •    Livello massimo" % astral.experience
		experience_bar.max_value = 1.0
		experience_bar.value = 0.0
		return
	var remaining_experience := maxi(required_experience - current_experience, 0)
	experience_value.text = "EXP %d / %d    •    Totale %d    •    Mancano %d" % [
		current_experience,
		required_experience,
		astral.experience,
		remaining_experience,
	]
	experience_bar.max_value = float(required_experience)
	experience_bar.value = clampf(
		float(current_experience),
		0.0,
		experience_bar.max_value
	)


func _update_moves(
	astral: AstralInstance,
	definition: AstralDefinition
) -> void:
	var raw_moves: Variant = _get_property_value(
		astral,
		[&"move_pool", &"moves", &"equipped_moves"],
		null
	)
	if raw_moves == null:
		raw_moves = _get_property_value(
			definition,
			[&"default_moves", &"moves"],
			[]
		)
	var moves: Array[Variant] = []
	if raw_moves is Array:
		for move: Variant in raw_moves:
			moves.append(move)

	for index: int in _move_labels.size():
		var move_label: Label = _move_labels[index]
		if index < moves.size():
			move_label.text = "%d. %s" % [
				index + 1,
				_format_move(moves[index]),
			]
			move_label.modulate = Color.WHITE
		else:
			move_label.text = "%d. — Slot libero" % (index + 1)
			move_label.modulate = Color(0.62, 0.67, 0.74, 1.0)


func _format_move(move: Variant) -> String:
	if move == null:
		return "Mossa non definita"
	if move is String or move is StringName:
		return str(move)
	if move is Object:
		var move_object := move as Object
		var move_name: Variant = _get_property_value(
			move_object,
			[&"display_name", &"move_name", &"name"],
			"Mossa"
		)
		var power: Variant = _get_property_value(
			move_object,
			[&"power", &"attack_power"],
			null
		)
		var cooldown: Variant = _get_property_value(
			move_object,
			[&"cooldown_turns"],
			0
		)
		var element: Variant = _get_property_value(
			move_object,
			[&"element_id"],
			&"neutro"
		)
		var damage_class: Variant = _get_property_value(
			move_object,
			[&"damage_class"],
			AstralMoveDefinition.DamageClass.PHYSICAL
		)
		var damage_class_name := (
			"Magica"
			if int(damage_class) == AstralMoveDefinition.DamageClass.MAGICAL
			else "Fisica"
		)
		if power != null:
			return "%s    Potenza %s    %s    CD %d    %s" % [
				str(move_name),
				str(power),
				damage_class_name,
				int(cooldown),
				PRESENTATION.get_element_symbol(StringName(element)),
			]
		return str(move_name)
	return str(move)


func _format_elements(definition: AstralDefinition) -> String:
	var element_names: Array[String] = []
	for element_id: StringName in definition.get_elements():
		element_names.append(PRESENTATION.format_element(element_id))
	if element_names.is_empty():
		return PRESENTATION.format_element(&"neutro")
	return " / ".join(element_names)


func _update_evolution_button(astral: AstralInstance) -> void:
	var level_options := astral.get_available_evolutions()
	evolve_button.visible = not level_options.is_empty()
	var available := (
		roster.get_available_evolutions(astral, inventory)
		if roster != null
		else []
	)
	evolve_button.disabled = available.is_empty()
	evolve_button.text = (
		"Evolvi (%d)" % available.size()
		if not available.is_empty()
		else "Evoluzione non disponibile"
	)
	if available.is_empty() and not level_options.is_empty():
		evolve_button.tooltip_text = "Serve la pietra evolutiva richiesta."
	else:
		evolve_button.tooltip_text = "Scegli la nuova forma dell'Astral."


func _format_named_value(value: Variant) -> String:
	if value == null:
		return ""
	if value is String or value is StringName:
		return str(value).replace("_", " ").capitalize()
	if value is Object:
		return str(
			_get_property_value(
				value as Object,
				[&"display_name", &"element_name", &"name"],
				""
			)
		)
	return str(value)


func _format_numeric_stat(value: Variant) -> String:
	if value == null:
		return "—"
	if value is float:
		return "%.1f" % float(value)
	return str(value)


func _get_property_value(
	source: Object,
	property_names: Array[StringName],
	fallback: Variant
) -> Variant:
	if source == null:
		return fallback
	for property_name: StringName in property_names:
		if _object_has_property(source, property_name):
			return source.get(property_name)
	return fallback


func _object_has_property(source: Object, property_name: StringName) -> bool:
	for property_data: Dictionary in source.get_property_list():
		if StringName(property_data.get("name", "")) == property_name:
			return true
	return false


func _clear_details() -> void:
	astral_color.color = Color(0.16, 0.2, 0.28, 1.0)
	_hide_static_portrait()
	astral_name.text = "Nessun Astral selezionato"
	lead_badge.hide()
	position_label.text = "Posizione in squadra: —"
	rarity_value.text = "Rarità: —"
	rarity_value.remove_theme_color_override("font_color")
	description_label.text = "Seleziona un Astral per visualizzarne la scheda."
	level_value.text = "—"
	bst_value.text = "—"
	health_value.text = "—"
	health_bar.max_value = 1.0
	health_bar.value = 0.0
	attack_value.text = "—"
	physical_defense_value.text = "—"
	magic_attack_value.text = "—"
	magic_defense_value.text = "—"
	speed_value.text = "—"
	elements_value.text = "—"
	experience_value.text = "EXP —    •    Prossimo livello: —"
	experience_bar.max_value = 1.0
	experience_bar.value = 0.0
	for index: int in _move_labels.size():
		_move_labels[index].text = "%d. — Slot libero" % (index + 1)
		_move_labels[index].modulate = Color(0.62, 0.67, 0.74, 1.0)
	_update_reorder_buttons(-1)
	evolve_button.disabled = true
	evolve_button.hide()
	evolve_button.text = "Evoluzione non disponibile"


func _show_static_portrait(definition: AstralDefinition) -> void:
	portrait_model.stop_animation()
	portrait_model.show_definition(definition)
	portrait_preview.show()
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _hide_static_portrait() -> void:
	if not is_node_ready():
		return
	portrait_model.stop_animation()
	portrait_preview.hide()
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _focus_astral_list() -> void:
	if not visible or _astrals.is_empty():
		return
	astral_list.grab_focus()
	astral_list.ensure_current_is_visible()


func _configure_focus_navigation() -> void:
	astral_list.focus_neighbor_bottom = astral_list.get_path_to(move_up_button)
	move_up_button.focus_neighbor_top = move_up_button.get_path_to(astral_list)
	move_up_button.focus_neighbor_right = move_up_button.get_path_to(move_down_button)
	move_down_button.focus_neighbor_left = move_down_button.get_path_to(move_up_button)
	move_down_button.focus_neighbor_right = move_down_button.get_path_to(set_lead_button)
	set_lead_button.focus_neighbor_left = set_lead_button.get_path_to(move_down_button)
	set_lead_button.focus_neighbor_right = set_lead_button.get_path_to(evolve_button)
	evolve_button.focus_neighbor_left = evolve_button.get_path_to(set_lead_button)
	evolve_button.focus_neighbor_right = evolve_button.get_path_to(close_button)
	close_button.focus_neighbor_left = close_button.get_path_to(evolve_button)
	close_button.focus_neighbor_bottom = close_button.get_path_to(astral_list)
