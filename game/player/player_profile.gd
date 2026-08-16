class_name PlayerProfile
extends Node

signal profile_changed()
signal florins_changed(amount: int)
signal capture_count_changed(amount: int)
signal medal_earned(medal_index: int)

const MEDAL_SLOT_COUNT: int = 8
const MAX_PLAYER_NAME_LENGTH: int = 64
const MAX_CURRENCY_NAME_LENGTH: int = 32
const MAX_ADVENTURE_SUMMARY_LENGTH: int = 2048
const MAX_FLORINS: int = 999999
const MAX_CAPTURE_COUNT: int = 999999

@export var player_name: String = "Avventuriero"
@export var currency_name: String = "Fiorini"
@export_range(0, 999999, 1) var florins: int = 0
@export_range(0, 999999, 1) var captured_monster_count: int = 0
@export_multiline var adventure_summary: String = (
	"L'avventura è appena cominciata nella Valle Verde. "
	+ "Il protagonista è partito sulle tracce della persona amata e dei misteri di Astrea."
)
@export_storage var earned_medals: Array[bool] = [
	false, false, false, false, false, false, false, false,
]

var _roster: AstralRoster = null


func setup(roster: AstralRoster) -> void:
	_disconnect_roster()
	_roster = roster
	if (
		_roster != null
		and not _roster.astral_captured.is_connected(_on_astral_captured)
	):
		_roster.astral_captured.connect(_on_astral_captured)
	_normalize_medals()
	profile_changed.emit()


func add_florins(amount: int) -> bool:
	if amount <= 0 or florins >= MAX_FLORINS:
		return false
	if amount >= MAX_FLORINS - florins:
		florins = MAX_FLORINS
	else:
		florins += amount
	florins_changed.emit(florins)
	profile_changed.emit()
	return true


func spend_florins(amount: int) -> bool:
	if amount <= 0 or amount > florins:
		return false
	florins -= amount
	florins_changed.emit(florins)
	profile_changed.emit()
	return true


func earn_medal(medal_index: int) -> bool:
	_normalize_medals()
	if (
		medal_index < 0
		or medal_index >= MEDAL_SLOT_COUNT
		or earned_medals[medal_index]
	):
		return false
	earned_medals[medal_index] = true
	medal_earned.emit(medal_index)
	profile_changed.emit()
	return true


func has_medal(medal_index: int) -> bool:
	_normalize_medals()
	return (
		medal_index >= 0
		and medal_index < MEDAL_SLOT_COUNT
		and earned_medals[medal_index]
	)


func get_medal_count() -> int:
	_normalize_medals()
	return earned_medals.count(true)


func get_save_data() -> Dictionary:
	return {
		"player_name": player_name,
		"currency_name": currency_name,
		"florins": florins,
		"captured_monster_count": captured_monster_count,
		"earned_medals": earned_medals.duplicate(),
		"adventure_summary": adventure_summary,
	}


func load_save_data(data: Dictionary) -> void:
	player_name = _validated_string(
		data.get("player_name", player_name),
		player_name,
		MAX_PLAYER_NAME_LENGTH
	)
	currency_name = _validated_string(
		data.get("currency_name", currency_name),
		currency_name,
		MAX_CURRENCY_NAME_LENGTH
	)
	florins = clampi(
		_validated_int(data.get("florins", 0), 0),
		0,
		MAX_FLORINS
	)
	captured_monster_count = clampi(
		_validated_int(data.get("captured_monster_count", 0), 0),
		0,
		MAX_CAPTURE_COUNT
	)
	adventure_summary = _validated_string(
		data.get("adventure_summary", adventure_summary),
		adventure_summary,
		MAX_ADVENTURE_SUMMARY_LENGTH
	)
	var raw_medals: Variant = data.get("earned_medals", [])
	earned_medals.clear()
	if raw_medals is Array:
		for medal_value: Variant in raw_medals:
			var medal_is_earned := false
			if medal_value is bool:
				medal_is_earned = bool(medal_value)
			earned_medals.append(medal_is_earned)
			if earned_medals.size() >= MEDAL_SLOT_COUNT:
				break
	_normalize_medals()
	florins_changed.emit(florins)
	capture_count_changed.emit(captured_monster_count)
	profile_changed.emit()


func _on_astral_captured(_astral: AstralInstance) -> void:
	captured_monster_count = mini(
		captured_monster_count + 1,
		MAX_CAPTURE_COUNT
	)
	capture_count_changed.emit(captured_monster_count)
	profile_changed.emit()


func _normalize_medals() -> void:
	if earned_medals.size() > MEDAL_SLOT_COUNT:
		earned_medals.resize(MEDAL_SLOT_COUNT)
	while earned_medals.size() < MEDAL_SLOT_COUNT:
		earned_medals.append(false)


func _disconnect_roster() -> void:
	if (
		_roster != null
		and is_instance_valid(_roster)
		and _roster.astral_captured.is_connected(_on_astral_captured)
	):
		_roster.astral_captured.disconnect(_on_astral_captured)
	_roster = null


static func _validated_int(value: Variant, fallback: int) -> int:
	if value is int:
		return int(value)
	if value is float and is_finite(float(value)):
		return int(value)
	return fallback


static func _validated_string(
	value: Variant,
	fallback: String,
	maximum_length: int
) -> String:
	if not (value is String or value is StringName):
		return fallback.left(maximum_length)
	return String(value).left(maximum_length)
