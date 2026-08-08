extends Node
class_name StormController

## Runs a storm: the ordered waves of enemies and the weather over them.
##
## A storm is authored content, not a timer. When ThreatManager reports one has
## started this node halts the ship, suspends ambient spawning so its wave counter
## stays truthful, and spawns each wave batch by batch. A wave completes once every
## enemy it spawned is gone; when the last one clears the storm hands control back
## and the next threat level unlocks.

enum Phase { IDLE, INTRO, WAVE_INCOMING, WAVE_ACTIVE, OUTRO }

const EVENT_SOURCE := &"storm"
const EVENT_PRIORITY := 100
const WAVE_TEXT := "WAVE %d / %d"
const WAVE_INCOMING_SUBTEXT := "INCOMING IN %ds"
const WAVE_REMAINING_SUBTEXT := "REMAINING - %d"
const STORM_CLEARED_TEXT := "STORM CLEARED"

## Seconds the ship takes to halt when a storm starts, and to resume when it clears.
@export_range(0.0, 20.0, 0.1, "or_greater") var ship_halt_seconds: float = 1.5
@export_range(0.0, 20.0, 0.1, "or_greater") var ship_resume_seconds: float = 2.0
## CanvasLayer level for the weather vignette. Above the world (layer 0) but below
## the game UI (layer 10), so it covers gameplay without dimming the HUD.
@export var vignette_canvas_layer: int = 5

var _threat_manager: ThreatManager = null
var _enemy_spawner: EnemySpawner = null
var _level: Node = null
var _event_text: EventTextDisplay = null

var _phase: Phase = Phase.IDLE
var _storm: StormData = null
var _weather: StormWeatherEffect = null
var _wave_index: int = 0
var _wave: StormWave = null
var _batch_index: int = 0
var _phase_timer: float = 0.0
## Enemies this director spawned for the current wave. Ambient enemies alive when
## the storm began are deliberately not tracked — they would make the counter lie.
var _wave_enemies: Array[Enemy] = []

var _vignette_rect: TextureRect = null
var _vignette_tween: Tween = null
var _level_speed_tween: Tween = null
var _base_level_speed: float = 0.0

var is_storm_active: bool:
	get:
		return _phase != Phase.IDLE


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_level = get_parent()
	_threat_manager = get_node_or_null("../ThreatManager") as ThreatManager
	_enemy_spawner = get_node_or_null("../EnemySpawner") as EnemySpawner
	if _level and "level_speed" in _level:
		_base_level_speed = _level.level_speed
	if _threat_manager:
		_threat_manager.storm_started.connect(_on_storm_started)
	_build_vignette()
	set_process(false)


func _process(delta: float) -> void:
	if _weather:
		_weather.tick(delta)

	match _phase:
		Phase.INTRO:
			_tick_intro(delta)
		Phase.WAVE_INCOMING:
			_tick_wave_incoming(delta)
		Phase.WAVE_ACTIVE:
			_tick_wave_active(delta)
		Phase.OUTRO:
			_tick_outro(delta)
		_:
			pass


func stop_for_run_end() -> void:
	_teardown_weather()
	_wave_enemies.clear()
	_phase = Phase.IDLE
	_storm = null
	set_process(false)
	if _event_text:
		_event_text.clear(EVENT_SOURCE)


func _on_storm_started(storm: StormData) -> void:
	if storm == null:
		_finish_storm()
		return

	_storm = storm
	_wave_index = 0
	_wave_enemies.clear()
	_phase = Phase.INTRO
	_phase_timer = storm.intro_seconds
	set_process(true)

	if _enemy_spawner:
		_enemy_spawner.set_ambient_spawning_enabled(false)
	_tween_level_speed(0.0, ship_halt_seconds)
	_setup_weather(storm.weather)
	_post_message(storm.display_name, "", EventTextDisplay.Style.CRITICAL)


func _tick_intro(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer > 0.0:
		return
	_begin_wave(0)


func _tick_wave_incoming(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer > 0.0:
		_update_wave_text()
		return
	_phase = Phase.WAVE_ACTIVE
	_batch_index = 0
	_phase_timer = 0.0
	_spawn_next_batch()


func _tick_wave_active(delta: float) -> void:
	_prune_wave_enemies()

	if _batch_index < _wave.batches.size():
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_spawn_next_batch()
		_update_wave_text()
		return

	_update_wave_text()
	if not _wave_enemies.is_empty():
		return

	# Every enemy this wave spawned is gone.
	var next_index := _wave_index + 1
	if next_index >= _storm.get_wave_count():
		_begin_outro()
		return
	_phase_timer = _wave.next_wave_delay_seconds
	_wave_index = next_index
	_wave = _storm.get_wave(_wave_index)
	_phase = Phase.WAVE_INCOMING


func _tick_outro(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer > 0.0:
		return
	_finish_storm()


func _begin_wave(index: int) -> void:
	_wave_index = index
	_wave = _storm.get_wave(index)
	if _wave == null:
		_begin_outro()
		return
	_phase = Phase.WAVE_ACTIVE
	_batch_index = 0
	_phase_timer = 0.0
	_spawn_next_batch()
	_update_wave_text()


func _spawn_next_batch() -> void:
	if _wave == null or _batch_index >= _wave.batches.size():
		return
	var batch := _wave.batches[_batch_index]
	_batch_index += 1
	_phase_timer = _wave.batch_interval_seconds

	if batch == null or batch.profile == null or _enemy_spawner == null:
		return
	var stat_level := _storm.enemy_stat_level if _storm else 0
	for enemy in _enemy_spawner.spawn_batch_for_storm(
		batch.profile, batch.count, batch.get_spawn_zones(), stat_level
	):
		_wave_enemies.append(enemy)


## Drop enemies that died or left the tree. Despawns count as removal, not as a
## stall — an enemy that never reaches the ship must not hold the wave open.
func _prune_wave_enemies() -> void:
	for i in range(_wave_enemies.size() - 1, -1, -1):
		var enemy := _wave_enemies[i]
		if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_queued_for_deletion():
			_wave_enemies.remove_at(i)


func _begin_outro() -> void:
	_phase = Phase.OUTRO
	_phase_timer = _storm.outro_seconds if _storm else 0.0
	_teardown_weather()
	_tween_level_speed(_base_level_speed, ship_resume_seconds)
	if _enemy_spawner:
		_enemy_spawner.set_ambient_spawning_enabled(true)
	_post_message(STORM_CLEARED_TEXT, "", EventTextDisplay.Style.NORMAL)


func _finish_storm() -> void:
	_phase = Phase.IDLE
	_storm = null
	_wave = null
	_wave_enemies.clear()
	set_process(false)
	if _event_text:
		_event_text.clear(EVENT_SOURCE)
	if _threat_manager:
		_threat_manager.notify_storm_finished()


func _update_wave_text() -> void:
	if _storm == null:
		return
	var headline := WAVE_TEXT % [_wave_index + 1, _storm.get_wave_count()]
	var subtext := ""
	if _phase == Phase.WAVE_INCOMING:
		subtext = WAVE_INCOMING_SUBTEXT % int(ceil(maxf(_phase_timer, 0.0)))
	else:
		subtext = WAVE_REMAINING_SUBTEXT % _remaining_enemy_count()
	_post_message(headline, subtext, EventTextDisplay.Style.CRITICAL)


## Enemies still to kill this wave: those alive plus those not yet spawned.
func _remaining_enemy_count() -> int:
	var unspawned := 0
	if _wave:
		for i in range(_batch_index, _wave.batches.size()):
			var batch := _wave.batches[i]
			if batch != null and batch.profile != null:
				unspawned += batch.count
	return _wave_enemies.size() + unspawned


func _post_message(text: String, subtext: String, style: int) -> void:
	var event_text := _get_event_text()
	if event_text:
		event_text.show_message(EVENT_SOURCE, text, subtext, EVENT_PRIORITY, style)


func _get_event_text() -> EventTextDisplay:
	if _event_text == null or not is_instance_valid(_event_text):
		if Magnetide.game_ui:
			_event_text = Magnetide.game_ui.get_node_or_null("EventTextDisplay") as EventTextDisplay
	return _event_text


func _setup_weather(weather: StormWeatherEffect) -> void:
	_teardown_weather()
	if weather == null:
		return
	_weather = weather
	_weather.setup()
	_fade_vignette(weather.vignette_color, weather.vignette_fade_seconds)


func _teardown_weather() -> void:
	if _weather == null:
		return
	var fade_seconds := _weather.vignette_fade_seconds
	_weather.teardown()
	_weather = null
	_fade_vignette(Color(0, 0, 0, 0), fade_seconds)


func _tween_level_speed(target: float, duration: float) -> void:
	if _level == null or not ("level_speed" in _level):
		return
	if _level_speed_tween and _level_speed_tween.is_valid():
		_level_speed_tween.kill()
	_level_speed_tween = create_tween()
	_level_speed_tween.tween_property(_level, "level_speed", target, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_vignette() -> void:
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.add_point(0.45, Color(1, 1, 1, 0))
	gradient.set_offset(gradient.get_point_count() - 1, 1.0)
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 1))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 512
	texture.height = 512

	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "StormVignetteLayer"
	canvas_layer.layer = vignette_canvas_layer
	add_child(canvas_layer)

	_vignette_rect = TextureRect.new()
	_vignette_rect.name = "StormVignette"
	_vignette_rect.texture = texture
	_vignette_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_rect.modulate = Color(1, 1, 1, 0)
	canvas_layer.add_child(_vignette_rect)


func _fade_vignette(target_color: Color, duration: float) -> void:
	if _vignette_rect == null:
		return
	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_vignette_rect, "modulate", target_color, duration)
