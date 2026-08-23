class_name SynergyScreen
extends Control

signal back_requested

@onready var back_button: Button = %BackButton
@onready var summary_label: Label = %SummaryLabel
@onready var synergy_list: VBoxContainer = %SynergyList

var _roster: AstralRoster = null


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_refresh()


func setup(roster: AstralRoster) -> void:
	if _roster != null and _roster.roster_changed.is_connected(_refresh):
		_roster.roster_changed.disconnect(_refresh)
	_roster = roster
	if _roster != null and not _roster.roster_changed.is_connected(_refresh):
		_roster.roster_changed.connect(_refresh)
	_refresh()


func open() -> void:
	_refresh()
	show()
	call_deferred("_focus_back_button")


func close() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	hide()


func _on_back_pressed() -> void:
	back_requested.emit()


func _focus_back_button() -> void:
	if visible:
		back_button.grab_focus()


func get_party_count(species_id: StringName) -> int:
	var count := 0
	if _roster == null:
		return count
	for astral: AstralInstance in _roster.get_astrals():
		if (
			astral != null
			and astral.definition != null
			and astral.definition.has_species_type(species_id)
		):
			count += 1
	return count


func _refresh() -> void:
	if not is_node_ready():
		return
	for child: Node in synergy_list.get_children():
		synergy_list.remove_child(child)
		child.queue_free()
	var active_count := 0
	for definition: Dictionary in AstralSynergyCatalog.get_definitions():
		var species_id := StringName(definition.get("id", ""))
		var party_count := get_party_count(species_id)
		var active_tier := AstralSynergyCatalog.get_active_tier(
			species_id,
			party_count
		)
		if active_tier > 0:
			active_count += 1
		synergy_list.add_child(
			_create_synergy_card(species_id, party_count, active_tier)
		)
	summary_label.text = "%d sinergie attive · Party %d/%d" % [
		active_count,
		_roster.get_astral_count() if _roster != null else 0,
		AstralRoster.MAX_PARTY_SIZE,
	]


func _create_synergy_card(
	species_id: StringName,
	party_count: int,
	active_tier: int
) -> PanelContainer:
	var card := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 20)
	title.text = "%s · %d/%d" % [
		AstralSpecies.get_display_name(species_id),
		party_count,
		AstralSynergyCatalog.get_maximum_tier(species_id),
	]
	title.add_theme_color_override(
		"font_color",
		Color("82df9b") if active_tier > 0 else Color("9cabb8")
	)
	content.add_child(title)
	for tier: Variant in AstralSynergyCatalog.get_tiers(species_id):
		if not (tier is Array) or (tier as Array).size() < 2:
			continue
		var values := tier as Array
		var required_count := int(values[0])
		var tier_label := Label.new()
		tier_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tier_label.text = "%s %d · %s" % [
			"●" if party_count >= required_count else "○",
			required_count,
			String(values[1]),
		]
		tier_label.add_theme_color_override(
			"font_color",
			Color("c8f2d1")
			if party_count >= required_count
			else Color("72808c")
		)
		content.add_child(tier_label)
	return card
