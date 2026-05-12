class_name SfxPlayer
extends Node

const DEFAULT_SFX_FOLDER := "res://_project/audio/sfx/"
const SFX_BUS_NAME := "SFX"

var _active_players_by_key: Dictionary = {}
var _idle_players: Array[AudioStreamPlayer] = []
var _enabled := true


func _ready() -> void:
	_ensure_sfx_bus()


func play(sound: Variant, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	if not _enabled:
		return null

	var sound_data := _resolve_sound(sound)
	if sound_data.is_empty():
		return null

	var stream := sound_data.get("stream") as AudioStream
	var key := sound_data.get("key", "") as String
	if stream == null or key.is_empty():
		return null

	var player := _active_players_by_key.get(key) as AudioStreamPlayer
	if player == null or not is_instance_valid(player):
		player = _take_idle_player()
		_active_players_by_key[key] = player

	player.stop()
	player.stream = stream
	player.bus = SFX_BUS_NAME
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.set_meta("sfx_key", key)
	player.play()
	return player


func stop(sound: Variant) -> void:
	var key := _resolve_sound_key(sound)
	if key.is_empty():
		return

	var player := _active_players_by_key.get(key) as AudioStreamPlayer
	if player == null or not is_instance_valid(player):
		_active_players_by_key.erase(key)
		return

	player.stop()
	_recycle_player(key, player)


func stop_all() -> void:
	for key in _active_players_by_key.keys():
		var player := _active_players_by_key[key] as AudioStreamPlayer
		if player and is_instance_valid(player):
			player.stop()
			_recycle_player(String(key), player)
	_active_players_by_key.clear()


func is_playing(sound: Variant) -> bool:
	var key := _resolve_sound_key(sound)
	if key.is_empty():
		return false

	var player := _active_players_by_key.get(key) as AudioStreamPlayer
	return player != null and is_instance_valid(player) and player.playing


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		stop_all()


func _resolve_sound(sound: Variant) -> Dictionary:
	var key := _resolve_sound_key(sound)
	if key.is_empty():
		return {}

	if sound is AudioStream:
		return {
			"stream": sound,
			"key": key,
		}

	if not ResourceLoader.exists(key, "AudioStream"):
		push_warning("SfxPlayer could not find SFX file: %s" % key)
		return {}

	var stream := ResourceLoader.load(key, "AudioStream") as AudioStream
	if stream == null:
		push_warning("SfxPlayer could not load SFX file: %s" % key)
		return {}

	return {
		"stream": stream,
		"key": key,
	}


func _resolve_sound_key(sound: Variant) -> String:
	if sound == null:
		return ""

	if sound is String or sound is StringName:
		var filename := String(sound).strip_edges()
		if filename.is_empty():
			return ""
		return _resolve_filename(filename)

	if sound is AudioStream:
		var stream := sound as AudioStream
		if not stream.resource_path.is_empty():
			return stream.resource_path
		return "stream:%s" % stream.get_instance_id()

	push_warning("SfxPlayer expected a filename or AudioStream, got: %s" % type_string(typeof(sound)))
	return ""


func _resolve_filename(filename: String) -> String:
	var root := DEFAULT_SFX_FOLDER.trim_suffix("/")
	var resolved_path := root.path_join(filename).simplify_path()
	if resolved_path != root and resolved_path.begins_with(root + "/"):
		return resolved_path

	push_warning("SfxPlayer filenames must resolve inside %s: %s" % [DEFAULT_SFX_FOLDER, filename])
	return ""


func _take_idle_player() -> AudioStreamPlayer:
	while not _idle_players.is_empty():
		var player := _idle_players.pop_back() as AudioStreamPlayer
		if player and is_instance_valid(player):
			return player

	var player := AudioStreamPlayer.new()
	player.bus = SFX_BUS_NAME
	player.finished.connect(_on_player_finished.bind(player))
	add_child(player)
	return player


func _on_player_finished(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player):
		return

	var key := String(player.get_meta("sfx_key", ""))
	if key.is_empty():
		return

	_recycle_player(key, player)


func _recycle_player(key: String, player: AudioStreamPlayer) -> void:
	if _active_players_by_key.get(key) == player:
		_active_players_by_key.erase(key)

	player.stream = null
	player.remove_meta("sfx_key")

	if not _idle_players.has(player):
		_idle_players.append(player)


func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index(SFX_BUS_NAME) != -1:
		return

	AudioServer.add_bus()
	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, SFX_BUS_NAME)
	AudioServer.set_bus_send(bus_index, "Master")
