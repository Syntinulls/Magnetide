class_name BgmPlayer
extends Node

## Background-music playback service.
##
## Plays a single looping track at a time on a dedicated "Music" bus and
## crossfades between tracks. Two independent levels of volume are kept apart:
## the per-track fade envelope lives on the AudioStreamPlayer.volume_db (0 dB =
## audible, SILENT_VOLUME_DB = faded out), while the global music level the
## player chooses (options menu, later) lives on the Music bus. A debug scale is
## layered on top of the bus level for the mute-cycle hotkey.

const DEFAULT_BGM_FOLDER := "res://_project/audio/bgm/"
const MUSIC_BUS_NAME := "Music"
const DEFAULT_FADE_SECONDS := 1.5
## volume_db a fully faded-out player sits at (low enough to be inaudible).
const SILENT_VOLUME_DB := -60.0
## Debug hotkey cycles the bus level through these scales of the options volume.
## Starting index is the last entry so the first press lands on the first entry.
const DEBUG_VOLUME_SCALES: Array[float] = [0.5, 0.0, 1.0]

var _current_player: AudioStreamPlayer = null
var _current_track_key: String = ""
var _music_volume: float = 1.0
var _debug_scale_index: int = DEBUG_VOLUME_SCALES.size() - 1
var _enabled := true


func _ready() -> void:
	_ensure_music_bus()
	_apply_bus_volume()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("debug_cycle_music"):
		return
	if event is InputEventKey and event.echo:
		return
	cycle_debug_volume()
	get_viewport().set_input_as_handled()


## Fade in a track and loop it. If the requested track is already the current one
## and still playing, this is a no-op so music stays continuous across callers
## (e.g. holding the same track between the station and map screens).
func play_track(track: Variant, fade_in_seconds: float = DEFAULT_FADE_SECONDS) -> void:
	if not _enabled:
		return
	var resolved := _resolve_track(track)
	if resolved.is_empty():
		return
	var key := resolved["key"] as String
	if key == _current_track_key and _current_player and is_instance_valid(_current_player) and _current_player.playing:
		return
	_crossfade_to(resolved["stream"] as AudioStream, key, fade_in_seconds)


## Crossfade from the current track to a random other track in the bgm folder.
## Used when the run advances out of the acid storm into the next threat level.
func fade_to_random_track(fade_seconds: float = DEFAULT_FADE_SECONDS) -> void:
	if not _enabled:
		return
	var track := _pick_random_track()
	if track.is_empty():
		return
	_crossfade_to(track["stream"] as AudioStream, track["key"] as String, fade_seconds)


## Fade the current track out and stop. Called when the end-run sequence begins.
func fade_out(fade_seconds: float = DEFAULT_FADE_SECONDS) -> void:
	_fade_out_and_free(_current_player, fade_seconds)
	_current_player = null
	_current_track_key = ""


func stop() -> void:
	if _current_player and is_instance_valid(_current_player):
		_current_player.stop()
		_current_player.queue_free()
	_current_player = null
	_current_track_key = ""


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		stop()


## Options-menu hook: linear 0..1 music level, mapped onto the Music bus.
func set_music_volume(linear: float) -> void:
	_music_volume = clampf(linear, 0.0, 1.0)
	_apply_bus_volume()


func get_music_volume() -> float:
	return _music_volume


## Advance the debug mute cycle: 50% -> 0% -> original (of the options volume).
func cycle_debug_volume() -> void:
	_debug_scale_index = (_debug_scale_index + 1) % DEBUG_VOLUME_SCALES.size()
	_apply_bus_volume()


func _crossfade_to(stream: AudioStream, key: String, fade_seconds: float) -> void:
	_fade_out_and_free(_current_player, fade_seconds)

	var player := AudioStreamPlayer.new()
	player.bus = MUSIC_BUS_NAME
	player.volume_db = SILENT_VOLUME_DB
	player.stream = _make_looping(stream)
	add_child(player)
	player.play()

	_current_player = player
	_current_track_key = key

	if fade_seconds <= 0.0:
		player.volume_db = 0.0
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", 0.0, fade_seconds)


func _fade_out_and_free(player: AudioStreamPlayer, fade_seconds: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if fade_seconds <= 0.0:
		player.stop()
		player.queue_free()
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_VOLUME_DB, fade_seconds)
	tween.tween_callback(player.queue_free)


func _apply_bus_volume() -> void:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if bus_index == -1:
		return
	var linear := _music_volume * DEBUG_VOLUME_SCALES[_debug_scale_index]
	if linear <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear))


## OGG/MP3 streams loop natively via their `loop` flag; duplicate so we never
## mutate the shared cached resource other systems might reuse.
func _make_looping(stream: AudioStream) -> AudioStream:
	if "loop" in stream and not stream.loop:
		var looping := stream.duplicate() as AudioStream
		looping.loop = true
		return looping
	return stream


func _pick_random_track() -> Dictionary:
	var candidates: Array[String] = []
	var dir := DirAccess.open(DEFAULT_BGM_FOLDER)
	if dir == null:
		return {}
	for file_name in dir.get_files():
		if file_name.get_extension().to_lower() != "ogg":
			continue
		var path := DEFAULT_BGM_FOLDER.path_join(file_name)
		if path == _current_track_key:
			continue
		candidates.append(path)

	# Only the current track exists: keep it looping rather than restart it.
	if candidates.is_empty():
		return {}

	var path := candidates[randi() % candidates.size()]
	if not ResourceLoader.exists(path, "AudioStream"):
		return {}
	var stream := ResourceLoader.load(path, "AudioStream") as AudioStream
	if stream == null:
		return {}
	return {"stream": stream, "key": path}


func _resolve_track(track: Variant) -> Dictionary:
	if track is AudioStream:
		var stream := track as AudioStream
		var key := stream.resource_path
		if key.is_empty():
			key = "stream:%d" % stream.get_instance_id()
		return {"stream": stream, "key": key}

	if track is String or track is StringName:
		var path := _resolve_filename(String(track).strip_edges())
		if path.is_empty():
			return {}
		if not ResourceLoader.exists(path, "AudioStream"):
			push_warning("BgmPlayer could not find music file: %s" % path)
			return {}
		var stream := ResourceLoader.load(path, "AudioStream") as AudioStream
		if stream == null:
			push_warning("BgmPlayer could not load music file: %s" % path)
			return {}
		return {"stream": stream, "key": path}

	push_warning("BgmPlayer expected a filename or AudioStream, got: %s" % type_string(typeof(track)))
	return {}


func _resolve_filename(filename: String) -> String:
	if filename.is_empty():
		return ""
	var root := DEFAULT_BGM_FOLDER.trim_suffix("/")
	var resolved_path := root.path_join(filename).simplify_path()
	if resolved_path != root and resolved_path.begins_with(root + "/"):
		return resolved_path

	push_warning("BgmPlayer filenames must resolve inside %s: %s" % [DEFAULT_BGM_FOLDER, filename])
	return ""


func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS_NAME) != -1:
		return

	AudioServer.add_bus()
	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, MUSIC_BUS_NAME)
	AudioServer.set_bus_send(bus_index, "Master")
