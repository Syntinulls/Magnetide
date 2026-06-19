extends Node
class_name RunController

signal run_finished(result: RunResult)
signal scrap_metal_count_changed(count: int)

const DEBUG_EXTRA_SALVAGE_ITEM_1: SalvageItemData = preload("res://_project/items/salvage/resources/tire.tres")
const DEBUG_EXTRA_SALVAGE_ITEM_2: SalvageItemData = preload("res://_project/items/salvage/resources/air_conditioner.tres")
const DEBUG_EXTRA_SALVAGE_ITEM_3: SalvageItemData = preload("res://_project/items/salvage/resources/xray_machine.tres")
const DEBUG_EXTRA_SALVAGE_ITEM_4: SalvageItemData = preload("res://_project/items/salvage/resources/portable_reactor.tres")
const DEPARTURE_DECEL_SECONDS: float = 2.25
const DEPARTURE_RISE_SECONDS: float = 3.0
const DEPARTURE_BOOST_SECONDS: float = 1.35
const DEPARTURE_FADE_SECONDS: float = 0.9
const DEPARTURE_SHIELD_REVEAL_RATIO: float = 0.75
const DEPARTURE_RISE_VIEWPORT_RATIO: float = 4.5
const DEPARTURE_CAMERA_LEAD_VIEWPORT_RATIO: float = 0.35
const DEPARTURE_BOOST_THRUST_START_RATIO: float = 0.9
const DEPARTURE_BOOST_VIEWPORT_RATIO: float = 7.0
const DEPARTURE_BOOST_CAMERA_RATIO: float = 0.22
const DEPARTURE_LEVEL_SPEED_EPSILON: float = 1.0
const DEPARTURE_PLAYER_WALK_SPEED: float = 180.0

var _level_definition: LevelDefinition = null
var _level: Node = null
var _game_ui: Control = null
var _ship: Ship = null
var _player: Player = null
var _magnet: Magnet = null
var _enemy_spawner: EnemySpawner = null
var _magnet_minigame: MagnetMinigame = null
var _run_loadout: RunLoadout = null
var _active_augment_behaviors: Array[AugmentBehavior] = []
var _elapsed_seconds: float = 0.0
var _enemies_killed: int = 0
var _scrap_metal_collected: int = 0
var _end_reason: RunResult.EndReason = RunResult.EndReason.VOLUNTARY_DEPARTURE
var _is_run_ending: bool = false

var scrap_metal_collected: int:
	get:
		return _scrap_metal_collected


func get_run_loadout() -> RunLoadout:
	return _run_loadout


func start_run(level_definition: LevelDefinition, level_node: Node, run_loadout: RunLoadout = null) -> void:
	_level_definition = level_definition
	_level = level_node
	_run_loadout = run_loadout
	_elapsed_seconds = 0.0
	_enemies_killed = 0
	_scrap_metal_collected = 0
	_end_reason = RunResult.EndReason.VOLUNTARY_DEPARTURE
	_is_run_ending = false
	call_deferred("_bind_runtime")


func _bind_runtime() -> void:
	if _level == null or not is_instance_valid(_level):
		return

	_ship = _level.get_node_or_null("Ship") as Ship
	if _ship:
		_player = _ship.get_node_or_null("Player") as Player
		_magnet = _ship.get_node_or_null("Magnet") as Magnet

	if "ui_root" in _level and _level.ui_root:
		_game_ui = _level.ui_root.get_node_or_null("GameUI") as Control

	_enemy_spawner = _level.get_node_or_null("EnemySpawner") as EnemySpawner
	_magnet_minigame = _level.get_node_or_null("MagnetMinigame") as MagnetMinigame

	Magnetide.register_run_context(self, _level, _level, _game_ui, _ship, _player, _magnet)
	_connect_runtime_signals()
	_initialize_augments()
	_sync_game_ui_scrap_counter()
	set_process(true)


func _connect_runtime_signals() -> void:
	if _player and not _player.destroyed.is_connected(_on_player_destroyed):
		_player.destroyed.connect(_on_player_destroyed)
	if _player and not _player.scrap_metal_collected.is_connected(record_scrap_metal_collected):
		_player.scrap_metal_collected.connect(record_scrap_metal_collected)
	if _ship and not _ship.destroyed.is_connected(_on_ship_destroyed):
		_ship.destroyed.connect(_on_ship_destroyed)
	if _enemy_spawner and not _enemy_spawner.enemy_killed.is_connected(_on_enemy_killed):
		_enemy_spawner.enemy_killed.connect(_on_enemy_killed)
	if _ship:
		for pylon in _ship.get_departure_pylons():
			if not pylon.departure_requested.is_connected(_on_departure_requested):
				pylon.departure_requested.connect(_on_departure_requested)


func _process(delta: float) -> void:
	if _is_run_ending:
		return
	_elapsed_seconds += delta
	for behavior in _active_augment_behaviors:
		if behavior != null and behavior.has_method("tick"):
			behavior.call("tick", delta)


func can_accept_departure_request() -> bool:
	return not _is_run_ending


func request_end_run(reason: RunResult.EndReason) -> void:
	if _is_run_ending:
		return

	_is_run_ending = true
	_end_reason = reason
	var departure_start_speed := _get_level_speed()
	_shutdown_gameplay(reason != RunResult.EndReason.VOLUNTARY_DEPARTURE)
	if reason == RunResult.EndReason.VOLUNTARY_DEPARTURE:
		_set_level_speed(departure_start_speed)

	if reason == RunResult.EndReason.VOLUNTARY_DEPARTURE:
		call_deferred("_finish_run_after_departure_cutscene", departure_start_speed)
	else:
		var result := _build_result()
		call_deferred("_finish_run", result)


func _shutdown_gameplay(stop_player: bool = true) -> void:
	set_process(false)
	_cleanup_augments()

	if _player and stop_player:
		_player.stop_for_run_end()
	if _magnet_minigame:
		_magnet_minigame.stop_for_run_end()
	if _enemy_spawner:
		_enemy_spawner.stop_for_run_end()
	if _level and "level_speed" in _level:
		_level.level_speed = 0.0
	if _level and "threat" in _level and _level.threat:
		_level.threat.stop_for_run_end()

	if _game_ui:
		var countdown := _game_ui.get_node_or_null("CountdownTimer") as CountdownTimer
		if countdown:
			countdown.stop_timer()

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy:
			enemy.stop_for_run_end()

	if _ship:
		_ship.stop_for_run_end()
		for pylon in _ship.get_departure_pylons():
			pylon.stop_for_run_end()


func _build_result() -> RunResult:
	var result := RunResult.new()
	if _level_definition:
		result.level_id = _level_definition.level_id
		result.level_display_name = _level_definition.display_name
	result.elapsed_seconds = _elapsed_seconds
	result.end_reason = _end_reason
	result.enemies_killed = _enemies_killed
	result.scrap_metal_collected = _scrap_metal_collected

	if _ship:
		result.salvage_items_collected = _ship.get_stored_item_count()
		if _end_reason == RunResult.EndReason.VOLUNTARY_DEPARTURE:
			result.stored_loot = _ship.get_stored_loot_payload()

	if _end_reason == RunResult.EndReason.VOLUNTARY_DEPARTURE \
		and DEBUG_EXTRA_SALVAGE_ITEM_1 != null \
		and DEBUG_EXTRA_SALVAGE_ITEM_2 != null \
		and DEBUG_EXTRA_SALVAGE_ITEM_3 != null \
		and DEBUG_EXTRA_SALVAGE_ITEM_4 != null:
		result.stored_loot.append(DEBUG_EXTRA_SALVAGE_ITEM_1)
		result.stored_loot.append(DEBUG_EXTRA_SALVAGE_ITEM_2)
		result.stored_loot.append(DEBUG_EXTRA_SALVAGE_ITEM_3)
		result.stored_loot.append(DEBUG_EXTRA_SALVAGE_ITEM_4)
		result.salvage_items_collected += 4

	return result


func _finish_run(result: RunResult) -> void:
	_cleanup_augments()
	run_finished.emit(result)


func _finish_run_after_departure_cutscene(departure_start_speed: float) -> void:
	await _play_departure_cutscene(departure_start_speed)
	var result := _build_result()
	_finish_run(result)


func _play_departure_cutscene(departure_start_speed: float) -> void:
	if _game_ui:
		_game_ui.visible = false

	var camera := _get_level_camera()
	if camera:
		camera.make_current()

	if _player:
		_player.start_walk_to_ship_center_for_cutscene(0.0, DEPARTURE_PLAYER_WALK_SPEED)

	if departure_start_speed > DEPARTURE_LEVEL_SPEED_EPSILON:
		await _tween_level_speed(departure_start_speed, 0.0, DEPARTURE_DECEL_SECONDS)
	_set_level_speed(0.0)

	if _player:
		if _player.is_cinematic_walk_active():
			await _player.cinematic_walk_finished
		_player.stop_for_run_end()

	if _ship:
		_ship.lock_stored_items_for_departure()
		_ship.set_departure_lift_thrusters(false)

	var viewport_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var rise_distance := viewport_height * DEPARTURE_RISE_VIEWPORT_RATIO
	var camera_lead_distance := viewport_height * DEPARTURE_CAMERA_LEAD_VIEWPORT_RATIO
	await _tween_ship_and_camera_with_shield_reveal(
		-rise_distance,
		-camera_lead_distance,
		DEPARTURE_RISE_SECONDS
	)

	var boost_distance := viewport_height * DEPARTURE_BOOST_VIEWPORT_RATIO
	await _tween_ship_and_camera(
		-boost_distance,
		-boost_distance * DEPARTURE_BOOST_CAMERA_RATIO,
		DEPARTURE_BOOST_SECONDS
	)
	await _fade_departure_to_black()


func _tween_level_speed(from_speed: float, to_speed: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_method(Callable(self, "_set_level_speed"), from_speed, to_speed, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _tween_ship_and_camera(ship_y_delta: float, camera_y_delta: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	var has_tweener := false

	if _ship:
		has_tweener = true
		tween.tween_property(_ship, "global_position:y", _ship.global_position.y + ship_y_delta, duration) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)

	var camera := _get_level_camera()
	if camera:
		has_tweener = true
		tween.tween_property(camera, "global_position:y", camera.global_position.y + camera_y_delta, duration) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)

	if has_tweener:
		await tween.finished


func _tween_ship_and_camera_with_shield_reveal(ship_y_delta: float, camera_lead_y_delta: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	var has_tweener := false
	var camera := _get_level_camera()
	var ship_start_y := _ship.global_position.y if _ship else 0.0
	var camera_start_y := camera.global_position.y if camera else 0.0

	if _ship or camera:
		has_tweener = true
		tween.tween_method(
			Callable(self, "_update_departure_rise").bind(ship_start_y, camera_start_y, ship_y_delta, camera_lead_y_delta),
			0.0,
			1.0,
			duration
		) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)

	if _ship:
		tween.tween_callback(_ship.show_departure_shield) \
			.set_delay(duration * DEPARTURE_SHIELD_REVEAL_RATIO)
		tween.tween_callback(_ship.set_departure_lift_thrusters.bind(true)) \
			.set_delay(duration * DEPARTURE_BOOST_THRUST_START_RATIO)

	if has_tweener:
		await tween.finished


func _update_departure_rise(
	progress: float,
	ship_start_y: float,
	camera_start_y: float,
	ship_y_delta: float,
	camera_lead_y_delta: float
) -> void:
	if _ship:
		_ship.global_position.y = ship_start_y + ship_y_delta * progress

	var camera := _get_level_camera()
	if camera:
		var lead_progress := clampf(progress, 0.0, 1.0)
		var eased_lead := lead_progress * lead_progress * (3.0 - 2.0 * lead_progress)
		camera.global_position.y = camera_start_y + ship_y_delta * progress + camera_lead_y_delta * eased_lead


func _fade_departure_to_black() -> void:
	var overlay := _create_departure_fade_overlay()
	if overlay == null:
		return

	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 1.0, DEPARTURE_FADE_SECONDS) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _create_departure_fade_overlay() -> ColorRect:
	if _level == null or not is_instance_valid(_level):
		return null

	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "DepartureFadeLayer"
	canvas_layer.layer = 90
	_level.add_child(canvas_layer)

	var rect := ColorRect.new()
	rect.name = "DepartureFade"
	rect.color = Color(0.0, 0.0, 0.0, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	canvas_layer.add_child(rect)
	return rect


func _get_level_camera() -> Camera2D:
	if _level == null or not is_instance_valid(_level):
		return null
	if "camera" in _level:
		return _level.camera as Camera2D
	return _level.get_node_or_null("Camera2D") as Camera2D


func _get_level_speed() -> float:
	if _level and "level_speed" in _level:
		return _level.level_speed
	return 0.0


func _set_level_speed(speed: float) -> void:
	if _level and "level_speed" in _level:
		_level.level_speed = speed


func _on_player_destroyed() -> void:
	request_end_run(RunResult.EndReason.PLAYER_DESTROYED)


func _on_ship_destroyed() -> void:
	request_end_run(RunResult.EndReason.SHIP_DESTROYED)


func _on_enemy_killed(_enemy: Enemy) -> void:
	_enemies_killed += 1


func record_scrap_metal_collected(amount: int) -> void:
	if amount <= 0:
		return
	_scrap_metal_collected += amount
	scrap_metal_count_changed.emit(_scrap_metal_collected)
	_sync_game_ui_scrap_counter()


func _sync_game_ui_scrap_counter() -> void:
	if not _game_ui:
		return
	if _game_ui.has_method("set_run_scrap_metal_count"):
		_game_ui.call("set_run_scrap_metal_count", _scrap_metal_collected)
	if _game_ui.has_method("bind_run_controller"):
		_game_ui.call("bind_run_controller", self)


func _on_departure_requested(_pylon: DeparturePylon) -> void:
	if not can_accept_departure_request():
		return
	request_end_run(RunResult.EndReason.VOLUNTARY_DEPARTURE)


func _exit_tree() -> void:
	_cleanup_augments()
	Magnetide.clear_run_context(self)


func _initialize_augments() -> void:
	_cleanup_augments()
	if _run_loadout == null:
		return

	var context := {
		"run_loadout": _run_loadout,
		"level": _level,
		"ship": _ship,
		"player": _player,
		"magnet": _magnet,
		"run_controller": self,
	}
	for augment in _run_loadout.get_equipped_augments():
		if augment == null or augment.behavior == null:
			continue
		var behavior := augment.behavior.duplicate(true) as AugmentBehavior
		if behavior == null:
			continue
		behavior.initialize_for_run(context, _run_loadout.get_item_level(augment))
		_active_augment_behaviors.append(behavior)


func _cleanup_augments() -> void:
	for behavior in _active_augment_behaviors:
		if behavior != null:
			behavior.cleanup_after_run()
	_active_augment_behaviors.clear()
