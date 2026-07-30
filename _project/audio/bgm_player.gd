class_name BgmPlayer
extends Node

## Background-music playback service.
##
## Plays one category playlist at a time on a dedicated "Music" bus. Each
## category maps to a subfolder of audio/bgm/; every audio file in that folder
## is in the category's rotation, so adding a track is a file drop, not a code
## edit. Tracks play once each: when one ends, a short silent gap passes, then
## another random track from the same category fades in. Switching categories
## crossfades immediately.
##
## Two independent levels of volume are kept apart: the per-track fade envelope
## lives on the AudioStreamPlayer.volume_db (0 dB = audible, SILENT_VOLUME_DB =
## faded out), while the global music level the player chooses (options menu,
## later) lives on the Music bus. A debug scale is layered on top of the bus
## level for the debug panel's mute cycle.

enum Category { MAIN_MENU, STATION, IN_RUN, STORM, BOSS }

const BGM_ROOT := "res://_project/audio/bgm/"
const CATEGORY_FOLDERS := {
	Category.MAIN_MENU: "main_menu",
	Category.STATION: "station",
	Category.IN_RUN: "run",
	Category.STORM: "storm",
	Category.BOSS: "boss",
}
const STREAM_EXTENSIONS: Array[String] = ["ogg", "mp3", "wav"]
const MUSIC_BUS_NAME := "Music"
const DEFAULT_FADE_SECONDS := 1.5
## Silent gap between one track ending naturally and the next fading in.
const TRACK_GAP_MIN_SECONDS := 3.0
const TRACK_GAP_MAX_SECONDS := 5.0
## volume_db a fully faded-out player sits at (low enough to be inaudible).
const SILENT_VOLUME_DB := -60.0
## The debug mute cycle steps the bus level through these scales of the options
## volume. Starting index is the last entry so the first step lands on the first.
const DEBUG_VOLUME_SCALES: Array[float] = [0.5, 0.0, 1.0]

var _current_player: AudioStreamPlayer = null
var _current_track_path: String = ""
var _current_category: int = -1
## Shuffle-bag memory per category: tracks already played this cycle. A track
## repeats only after every other track in its category has played. Kept per
## category so leaving and re-entering one (run -> storm -> run) resumes its
## cycle instead of restarting it.
var _played_by_category: Dictionary = {}
## Bumped on every interrupt (category switch, fade-out, stop) so in-flight
## track-finished callbacks and gap timers from the old playlist cancel.
var _playlist_epoch: int = 0
var _music_volume: float = 1.0
var _debug_scale_index: int = DEBUG_VOLUME_SCALES.size() - 1
var _enabled := true


func _ready() -> void:
	# Music keeps playing (and fades keep tweening) while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_music_bus()
	_apply_bus_volume()


## Start (or continue) a category's playlist. If the category is already the
## active one this is a no-op, so music stays continuous across callers (e.g.
## holding station music between the station and map screens). Switching
## categories interrupts: the current track fades out while the first track of
## the new category fades in. A category whose folder has no tracks yet fades
## the music out to silence.
func play_category(category: Category, fade_seconds: float = DEFAULT_FADE_SECONDS) -> void:
	if not _enabled:
		return
	if int(category) == _current_category:
		return
	_current_category = int(category)
	_playlist_epoch += 1
	var track_path := _pick_track(_current_category)
	if track_path.is_empty():
		_fade_out_and_free(_current_player, fade_seconds)
		_current_player = null
		_current_track_path = ""
		return
	_crossfade_to(track_path, fade_seconds)


## Fade the current track out and stop. Called when the end-run sequence begins.
func fade_out(fade_seconds: float = DEFAULT_FADE_SECONDS) -> void:
	_playlist_epoch += 1
	_current_category = -1
	_fade_out_and_free(_current_player, fade_seconds)
	_current_player = null
	_current_track_path = ""


func stop() -> void:
	_playlist_epoch += 1
	_current_category = -1
	if _current_player and is_instance_valid(_current_player):
		_current_player.stop()
		_current_player.queue_free()
	_current_player = null
	_current_track_path = ""


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


func _crossfade_to(track_path: String, fade_seconds: float) -> void:
	var stream := ResourceLoader.load(track_path, "AudioStream") as AudioStream
	if stream == null:
		push_warning("BgmPlayer could not load music file: %s" % track_path)
		return

	_fade_out_and_free(_current_player, fade_seconds)

	var player := AudioStreamPlayer.new()
	player.bus = MUSIC_BUS_NAME
	player.volume_db = SILENT_VOLUME_DB
	player.stream = _make_one_shot(stream)
	add_child(player)
	player.finished.connect(_on_track_finished.bind(_playlist_epoch))
	player.play()

	_current_player = player
	_current_track_path = track_path

	if fade_seconds <= 0.0:
		player.volume_db = 0.0
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", 0.0, fade_seconds)


## A track ended naturally: free its player, wait out the gap, then fade in
## another random track from the active category.
func _on_track_finished(epoch: int) -> void:
	if epoch != _playlist_epoch:
		return
	if _current_player and is_instance_valid(_current_player):
		_current_player.queue_free()
	_current_player = null

	var gap := randf_range(TRACK_GAP_MIN_SECONDS, TRACK_GAP_MAX_SECONDS)
	await get_tree().create_timer(gap).timeout
	if epoch != _playlist_epoch or not _enabled:
		return
	var track_path := _pick_track(_current_category)
	if track_path.is_empty():
		return
	_crossfade_to(track_path, DEFAULT_FADE_SECONDS)


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


## Random track from the category's shuffle bag: tracks the category hasn't
## played this cycle. When every track has played, the bag resets — avoiding an
## immediate back-to-back repeat of the last track when there is more than one.
func _pick_track(category: int) -> String:
	var tracks := _scan_category_tracks(category)
	if tracks.is_empty():
		return ""

	var played: Array = _played_by_category.get_or_add(category, [])
	var unplayed := tracks.filter(func(track: String) -> bool: return not track in played)
	if unplayed.is_empty():
		played.clear()
		unplayed = tracks.duplicate()
		if unplayed.size() > 1:
			unplayed.erase(_current_track_path)

	var path: String = unplayed[randi() % unplayed.size()]
	played.append(path)
	return path


## Lists the audio files in a category's folder. In exported builds imported
## audio is listed via its .import/.remap stub, so those suffixes are stripped
## before the extension check.
func _scan_category_tracks(category: int) -> Array[String]:
	if not CATEGORY_FOLDERS.has(category):
		return []
	var folder := BGM_ROOT.path_join(CATEGORY_FOLDERS[category])
	var dir := DirAccess.open(folder)
	if dir == null:
		return []

	var tracks: Array[String] = []
	for file_name in dir.get_files():
		var stream_name := file_name
		if stream_name.ends_with(".import") or stream_name.ends_with(".remap"):
			stream_name = stream_name.get_basename()
		if not stream_name.get_extension().to_lower() in STREAM_EXTENSIONS:
			continue
		var path := folder.path_join(stream_name)
		if path in tracks or not ResourceLoader.exists(path, "AudioStream"):
			continue
		tracks.append(path)
	return tracks


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


## Rotation relies on the `finished` signal, which a looping stream never emits.
## Duplicate before disabling the flag so the shared cached resource other
## systems might reuse is never mutated.
func _make_one_shot(stream: AudioStream) -> AudioStream:
	if "loop" in stream and stream.loop:
		var one_shot := stream.duplicate() as AudioStream
		one_shot.loop = false
		return one_shot
	return stream


func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS_NAME) != -1:
		return

	AudioServer.add_bus()
	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, MUSIC_BUS_NAME)
	AudioServer.set_bus_send(bus_index, "Master")
