class_name RuntimeContext
extends Node

signal session_registered(session: PlayerSession)
signal session_unregistered(session_id: StringName)
signal runtime_mode_changed(mode: RuntimeMode)

enum RuntimeMode {
	OFFLINE,
	LISTEN_SERVER,
	NETWORK_CLIENT,
	DEDICATED_SERVER,
}

@export var runtime_mode: RuntimeMode = RuntimeMode.OFFLINE
@export var world_instance_id: StringName = &"local_world"

var _sessions: Dictionary[StringName, PlayerSession] = {}
var _actor_sessions: Dictionary[int, PlayerSession] = {}


func set_runtime_mode(mode: RuntimeMode) -> void:
	if runtime_mode == mode:
		return
	runtime_mode = mode
	for session: PlayerSession in _sessions.values():
		session.set_authority_enabled(is_authority())
	runtime_mode_changed.emit(runtime_mode)


func is_authority() -> bool:
	return runtime_mode != RuntimeMode.NETWORK_CLIENT


func is_headless() -> bool:
	return (
		runtime_mode == RuntimeMode.DEDICATED_SERVER
		or DisplayServer.get_name() == "headless"
	)


func has_presentation() -> bool:
	return not is_headless()


func register_session(session: PlayerSession) -> bool:
	if session == null or session.session_id.is_empty():
		return false
	var existing := _sessions.get(session.session_id) as PlayerSession
	if existing != null and existing != session:
		unregister_session(existing.session_id)
	_sessions[session.session_id] = session
	_index_actor(session, null, session.actor)
	var actor_callback := Callable(self, "_on_session_actor_changed").bind(session)
	if not session.actor_changed.is_connected(actor_callback):
		session.actor_changed.connect(actor_callback)
	session.set_authority_enabled(is_authority())
	session_registered.emit(session)
	return true


func unregister_session(session_id: StringName) -> bool:
	var session := _sessions.get(session_id) as PlayerSession
	if session == null:
		return false
	var actor_callback := Callable(self, "_on_session_actor_changed").bind(session)
	if session.actor_changed.is_connected(actor_callback):
		session.actor_changed.disconnect(actor_callback)
	_index_actor(session, session.actor, null)
	_sessions.erase(session_id)
	session_unregistered.emit(session_id)
	return true


func get_session(session_id: StringName) -> PlayerSession:
	return _sessions.get(session_id) as PlayerSession


func get_local_session() -> PlayerSession:
	for session: PlayerSession in _sessions.values():
		if session.is_local:
			return session
	return null


func get_session_for_actor(candidate: Node) -> PlayerSession:
	var current := candidate
	while current != null:
		var session := _actor_sessions.get(current.get_instance_id()) as PlayerSession
		if session != null:
			return session
		current = current.get_parent()
	return null


func get_sessions() -> Array[PlayerSession]:
	var result: Array[PlayerSession] = []
	for session: PlayerSession in _sessions.values():
		result.append(session)
	return result


func _on_session_actor_changed(
	previous_actor: Node3D,
	current_actor: Node3D,
	session: PlayerSession
) -> void:
	_index_actor(session, previous_actor, current_actor)


func _index_actor(
	session: PlayerSession,
	previous_actor: Node3D,
	current_actor: Node3D
) -> void:
	if previous_actor != null:
		_actor_sessions.erase(previous_actor.get_instance_id())
	if current_actor != null:
		_actor_sessions[current_actor.get_instance_id()] = session

