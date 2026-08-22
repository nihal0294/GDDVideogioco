class_name CoinFlipScreen
extends Control

signal close_requested()
signal notification_requested(message: String)

const WAGERS: Array[int] = [10, 50, 100]

@onready var currency_label: Label = %CurrencyLabel
@onready var wager_options: OptionButton = %WagerOptions
@onready var coin_label: Label = %CoinLabel
@onready var result_label: Label = %ResultLabel
@onready var heads_button: Button = %HeadsButton
@onready var tails_button: Button = %TailsButton

var _profile: PlayerProfile = null
var _random := RandomNumberGenerator.new()
var _playing: bool = false


func _ready() -> void:
	_random.randomize()
	for wager: int in WAGERS:
		wager_options.add_item("%d Fiorini" % wager)
	heads_button.pressed.connect(func() -> void: _play(true))
	tails_button.pressed.connect(func() -> void: _play(false))
	%CloseButton.pressed.connect(func() -> void:
		if not _playing:
			close_requested.emit()
	)


func setup(profile: PlayerProfile) -> void:
	if _profile != null and _profile.florins_changed.is_connected(_on_florins_changed):
		_profile.florins_changed.disconnect(_on_florins_changed)
	_profile = profile
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
	_random.seed = seed_value


func _play(chose_heads: bool) -> void:
	if _playing or _profile == null:
		return
	var wager := WAGERS[clampi(wager_options.selected, 0, WAGERS.size() - 1)]
	if not _profile.spend_florins(wager):
		notification_requested.emit("Non hai abbastanza Fiorini per questa puntata.")
		return
	_playing = true
	_set_controls_disabled(true)
	result_label.text = "La moneta gira..."
	for flip_index: int in 12:
		coin_label.text = "TESTA" if flip_index % 2 == 0 else "CROCE"
		await get_tree().create_timer(0.07, true).timeout
	var landed_heads := _random.randi_range(0, 1) == 0
	coin_label.text = "TESTA" if landed_heads else "CROCE"
	if landed_heads == chose_heads:
		var payout := wager * 2
		_profile.add_florins(payout)
		result_label.text = "Hai indovinato! Vinci %d Fiorini." % payout
	else:
		result_label.text = "Non hai indovinato. Ritenta quando vuoi."
	_playing = false
	_set_controls_disabled(false)


func _set_controls_disabled(disabled: bool) -> void:
	heads_button.disabled = disabled
	tails_button.disabled = disabled
	wager_options.disabled = disabled
	%CloseButton.disabled = disabled


func _on_florins_changed(_amount: int) -> void:
	_refresh_currency()


func _refresh_currency() -> void:
	if is_node_ready():
		currency_label.text = "%d %s" % [
			_profile.florins if _profile != null else 0,
			_profile.currency_name if _profile != null else "Fiorini",
		]
