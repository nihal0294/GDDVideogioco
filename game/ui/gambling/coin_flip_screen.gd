class_name CoinFlipScreen
extends Control

signal close_requested()
signal notification_requested(message: String)

const WAGERS: Array[int] = PlayerEconomyService.COIN_FLIP_WAGERS

@onready var currency_label: Label = %CurrencyLabel
@onready var wager_options: OptionButton = %WagerOptions
@onready var coin_label: Label = %CoinLabel
@onready var result_label: Label = %ResultLabel
@onready var heads_button: Button = %HeadsButton
@onready var tails_button: Button = %TailsButton

var _profile: PlayerProfile = null
var _economy: PlayerEconomyService = null
var _playing: bool = false


func _ready() -> void:
	for wager: int in WAGERS:
		wager_options.add_item("%d Fiorini" % wager)
	heads_button.pressed.connect(func() -> void: _play(true))
	tails_button.pressed.connect(func() -> void: _play(false))
	%CloseButton.pressed.connect(func() -> void:
		if not _playing:
			close_requested.emit()
	)


func setup(
	profile: PlayerProfile,
	economy: PlayerEconomyService = null
) -> void:
	if _profile != null and _profile.florins_changed.is_connected(_on_florins_changed):
		_profile.florins_changed.disconnect(_on_florins_changed)
	_profile = profile
	_economy = economy
	if _economy == null:
		_economy = PlayerEconomyService.new()
		_economy.setup(null, _profile)
	if _profile != null:
		_profile.florins_changed.connect(_on_florins_changed)
	_refresh_currency()


func open() -> void:
	show()
	result_label.text = "Scegli testa o croce."
	coin_label.text = "◉"
	_set_controls_disabled(false)
	heads_button.grab_focus()


func close() -> void:
	if not _playing:
		hide()


func set_random_seed(seed_value: int) -> void:
	if _economy != null:
		_economy.set_random_seed(seed_value)


func _play(chose_heads: bool) -> void:
	if _playing or _profile == null or _economy == null:
		return
	var wager := WAGERS[clampi(wager_options.selected, 0, WAGERS.size() - 1)]
	_playing = true
	var result := _economy.request_coin_flip(wager, chose_heads)
	var result_code := StringName(result.get("code", &"mutation_failed"))
	if not bool(result.get("success", false)):
		_playing = false
		if result_code == PlayerEconomyService.NOT_AUTHORITY:
			notification_requested.emit(
				"La puntata deve essere convalidata dall'autorita di gioco."
			)
		else:
			notification_requested.emit("Non hai abbastanza Fiorini per questa puntata.")
		return
	if result_code != PlayerEconomyService.OK:
		_playing = false
		notification_requested.emit("Non hai abbastanza Fiorini per questa puntata.")
		return
	var payout := int(result.get("payout", 0))
	_set_currency_amount(int(result.get("balance_after_wager", _profile.florins)))
	_set_controls_disabled(true)
	result_label.text = "La moneta gira..."
	for flip_index: int in 12:
		coin_label.text = "TESTA" if flip_index % 2 == 0 else "CROCE"
		await get_tree().create_timer(0.07, true).timeout
	var landed_heads := bool(result.get("landed_heads", false))
	coin_label.text = "TESTA" if landed_heads else "CROCE"
	if landed_heads == chose_heads:
		result_label.text = "Hai indovinato! Vinci %d Fiorini." % payout
	else:
		result_label.text = "Non hai indovinato. Ritenta quando vuoi."
	_playing = false
	_refresh_currency()
	_set_controls_disabled(false)


func _set_controls_disabled(disabled: bool) -> void:
	heads_button.disabled = disabled
	tails_button.disabled = disabled
	wager_options.disabled = disabled
	%CloseButton.disabled = disabled


func _on_florins_changed(_amount: int) -> void:
	if not _playing:
		_refresh_currency()


func _refresh_currency() -> void:
	if is_node_ready():
		_set_currency_amount(_profile.florins if _profile != null else 0)


func _set_currency_amount(amount: int) -> void:
	currency_label.text = "%d %s" % [
		amount,
		_profile.currency_name if _profile != null else "Fiorini",
	]
