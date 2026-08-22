class_name AstralExchangeScreen
extends Control

signal close_requested()
signal notification_requested(message: String)

const GIFT_REWARD_ID: StringName = &"merchant_house_silphy_gift"
const GIFT_ASTRAL_ID: StringName = &"silphy"
const TRADE_REQUIRED_ID: StringName = &"flambore"
const TRADE_RECEIVED_ID: StringName = &"vorix"

@onready var gift_button: Button = %GiftButton
@onready var offered_options: OptionButton = %OfferedOptions
@onready var trade_button: Button = %TradeButton
@onready var confirmation: ConfirmationDialog = %TradeConfirmation

var _roster: AstralRoster = null
var _profile: PlayerProfile = null
var _eligible_astrals: Array[AstralInstance] = []


func _ready() -> void:
	gift_button.pressed.connect(_on_gift_pressed)
	trade_button.pressed.connect(_on_trade_pressed)
	confirmation.confirmed.connect(_confirm_trade)
	%CloseButton.pressed.connect(func() -> void: close_requested.emit())


func setup(roster: AstralRoster, profile: PlayerProfile) -> void:
	if _roster != null and _roster.roster_changed.is_connected(_refresh):
		_roster.roster_changed.disconnect(_refresh)
	_roster = roster
	_profile = profile
	if _roster != null:
		_roster.roster_changed.connect(_refresh)
	_refresh()


func open() -> void:
	show()
	_refresh()
	gift_button.grab_focus()


func close() -> void:
	confirmation.hide()
	hide()


func _refresh() -> void:
	if not is_node_ready():
		return
	var gift_claimed := _profile != null and _profile.has_claimed_reward(GIFT_REWARD_ID)
	gift_button.disabled = gift_claimed
	gift_button.text = "Regalo già ricevuto" if gift_claimed else "Ricevi Silphy Lv. 1"
	_eligible_astrals.clear()
	offered_options.clear()
	if _roster != null:
		for astral: AstralInstance in _roster.get_all_astrals():
			if astral != null and astral.definition != null and astral.definition.astral_id == TRADE_REQUIRED_ID:
				_eligible_astrals.append(astral)
				offered_options.add_item("%s Lv. %d" % [astral.definition.display_name, astral.level])
	if _eligible_astrals.is_empty():
		offered_options.add_item("Nessun Flambore disponibile")
		offered_options.disabled = true
		trade_button.disabled = true
	else:
		offered_options.disabled = false
		trade_button.disabled = false


func _on_gift_pressed() -> void:
	if _roster == null or _profile == null or _profile.has_claimed_reward(GIFT_REWARD_ID):
		return
	var definition := AstralCatalog.load_definition(GIFT_ASTRAL_ID)
	var received := _roster.give_astral(definition, 1)
	if received == null:
		notification_requested.emit("Squadra e Box sono pieni: libera uno spazio.")
		return
	_profile.claim_reward(GIFT_REWARD_ID)
	notification_requested.emit("%s si è unito a te al livello 1." % definition.display_name)
	_refresh()


func _on_trade_pressed() -> void:
	if _get_selected_offered() == null:
		return
	confirmation.dialog_text = "Vuoi scambiare questo Flambore per un Vorix di livello 1?"
	confirmation.popup_centered()


func _confirm_trade() -> void:
	var offered := _get_selected_offered()
	if offered == null or _roster == null:
		return
	var received := _roster.trade_astral(
		offered,
		TRADE_REQUIRED_ID,
		AstralCatalog.load_definition(TRADE_RECEIVED_ID),
		1
	)
	if received == null:
		notification_requested.emit("Lo scambio non è stato completato.")
		return
	notification_requested.emit("Scambio riuscito: hai ricevuto %s." % received.definition.display_name)
	_refresh()


func _get_selected_offered() -> AstralInstance:
	var index := offered_options.selected
	if index < 0 or index >= _eligible_astrals.size():
		return null
	return _eligible_astrals[index]
