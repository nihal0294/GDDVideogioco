extends SceneTree

class MemorySaveStorage:
	extends SaveStorage

	var files: Dictionary[String, String] = {}
	var last_error: Error = OK

	func ensure_directory(_directory_path: String) -> bool:
		last_error = OK
		return true

	func file_exists(path: String) -> bool:
		return files.has(path)

	func write_text(path: String, content: String) -> bool:
		files[path] = content
		last_error = OK
		return true

	func read_text(path: String) -> String:
		if not files.has(path):
			last_error = ERR_FILE_NOT_FOUND
			return ""
		last_error = OK
		return files[path]

	func get_last_error() -> Error:
		return last_error


var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_main := load("res://game/main/main.tscn") as PackedScene
	_expect(packed_main != null, "Scena Main non caricabile.")
	if packed_main == null:
		_finish()
		return
	var main := packed_main.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame

	var runtime := main.get_node_or_null("RuntimeContext") as RuntimeContext
	var session := main.get_node_or_null("LocalPlayerSession") as PlayerSession
	var actor := main.get_node_or_null("Player") as CharacterBody3D
	var inventory := main.get_node_or_null("Inventory") as Inventory
	var roster := main.get_node_or_null("AstralRoster") as AstralRoster
	var profile := main.get_node_or_null("PlayerProfile") as PlayerProfile
	var save_manager := main.get_node_or_null("SaveManager") as SaveManager
	_expect(runtime != null and session != null, "RuntimeContext o PlayerSession mancante.")
	_expect(
		actor != null and inventory != null and roster != null and profile != null,
		"Dipendenze della sessione mancanti."
	)
	if runtime == null or session == null or actor == null:
		main.queue_free()
		await process_frame
		_finish()
		return

	_expect(session.actor == actor, "La sessione non possiede l'actor locale.")
	_expect(session.inventory == inventory, "Inventario non associato alla sessione.")
	_expect(session.astral_roster == roster, "Roster non associato alla sessione.")
	_expect(runtime.get_local_session() == session, "Sessione locale non risolvibile.")
	_expect(
		runtime.get_session_for_actor(actor) == session
		and runtime.get_session_for_actor(actor.get_node("InteractionDetector")) == session,
		"Risoluzione actor o nodo figlio verso PlayerSession fallita."
	)
	_expect(runtime.is_authority(), "Il runtime offline non risulta autoritativo.")

	profile.load_save_data({"florins": 500})
	var purchase := session.economy.request_purchase(&"runa_base")
	_expect(
		bool(purchase.get("success", false))
		and inventory.get_quantity(&"runa_base") == 1
		and profile.florins == 400,
		"L'economia autoritativa non completa un acquisto valido."
	)
	runtime.set_runtime_mode(RuntimeContext.RuntimeMode.NETWORK_CLIENT)
	var rejected := session.economy.request_purchase(&"runa_base")
	_expect(
		StringName(rejected.get("code", &"")) == PlayerEconomyService.NOT_AUTHORITY
		and inventory.get_quantity(&"runa_base") == 1
		and profile.florins == 400,
		"Un client non autoritativo modifica l'economia locale."
	)
	runtime.set_runtime_mode(RuntimeContext.RuntimeMode.OFFLINE)

	var command := PlayerMovementCommand.create(Vector2(0.5, -1.0), true)
	var restored_command := PlayerMovementCommand.from_dictionary(
		command.to_dictionary()
	)
	_expect(
		restored_command.direction.is_equal_approx(command.direction)
		and restored_command.jump_pressed,
		"Il comando di movimento non e serializzabile."
	)
	actor.call("set_local_input_enabled", false)
	actor.call("submit_movement_command", restored_command)
	_expect(not bool(actor.get("local_input_enabled")), "Input locale non disattivabile.")
	actor.call("simulate_movement", restored_command, 0.1)
	_expect(
		Vector2(actor.velocity.x, actor.velocity.z).length_squared() > 0.000001,
		"La simulazione non consuma un comando esterno."
	)
	actor.call("set_local_input_enabled", true)

	var memory_storage := MemorySaveStorage.new()
	_expect(
		save_manager != null and save_manager.set_storage(memory_storage),
		"SaveManager non accetta uno storage iniettabile."
	)
	if save_manager != null:
		_expect(save_manager.create_save(0), "Salvataggio in memoria fallito.")
		profile.load_save_data({"florins": 0})
		_expect(
			save_manager.load_save(0) and profile.florins == 400,
			"Round-trip tramite storage iniettabile fallito."
		)

	main.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Multiplayer architecture smoke test: PASS")
		quit(0)
	else:
		print(
			"Multiplayer architecture smoke test: FAIL (%d errori)"
			% _failures.size()
		)
		quit(1)
