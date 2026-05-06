extends Node
class_name RunController

signal run_finished(result: RunResult)

const DEBUG_EXTRA_SALVAGE_ITEM_1: SalvageItemData = preload("res://_project/items/resources/tire.tres")
const DEBUG_EXTRA_SALVAGE_ITEM_2: SalvageItemData = preload("res://_project/items/resources/air_conditioner.tres")
const DEBUG_EXTRA_SALVAGE_ITEM_3: SalvageItemData = preload("res://_project/items/resources/xray_machine.tres")
const DEBUG_EXTRA_SALVAGE_ITEM_4: SalvageItemData = preload("res://_project/items/resources/portable_reactor.tres")

var _level_definition: LevelDefinition = null
var _level: Node = null
var _game_ui: Control = null
var _ship: Ship = null
var _player: Player = null
var _magnet: Magnet = null
var _enemy_spawner: EnemySpawner = null
var _magnet_minigame: MagnetMinigame = null
var _elapsed_seconds: float = 0.0
var _enemies_killed: int = 0
var _end_reason: RunResult.EndReason = RunResult.EndReason.VOLUNTARY_DEPARTURE
var _is_run_ending: bool = false


func start_run(level_definition: LevelDefinition, level_node: Node) -> void:
	_level_definition = level_definition
	_level = level_node
	_elapsed_seconds = 0.0
	_enemies_killed = 0
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
	set_process(true)


func _connect_runtime_signals() -> void:
	if _player and not _player.destroyed.is_connected(_on_player_destroyed):
		_player.destroyed.connect(_on_player_destroyed)
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


func can_accept_departure_request() -> bool:
	return not _is_run_ending


func request_end_run(reason: RunResult.EndReason) -> void:
	if _is_run_ending:
		return

	_is_run_ending = true
	_end_reason = reason
	_shutdown_gameplay()

	var result := _build_result()
	call_deferred("_finish_run", result)


func _shutdown_gameplay() -> void:
	set_process(false)

	if _player:
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

	if _ship:
		result.salvage_items_collected = _ship.get_stored_item_count()
		result.stored_loot = _ship.get_stored_loot_payload()

	if DEBUG_EXTRA_SALVAGE_ITEM_1 != null and \
		DEBUG_EXTRA_SALVAGE_ITEM_2 != null and \
		DEBUG_EXTRA_SALVAGE_ITEM_3 != null and \
		DEBUG_EXTRA_SALVAGE_ITEM_4 != null:
		result.stored_loot.append(DEBUG_EXTRA_SALVAGE_ITEM_1)
		result.stored_loot.append(DEBUG_EXTRA_SALVAGE_ITEM_2)
		result.stored_loot.append(DEBUG_EXTRA_SALVAGE_ITEM_3)
		result.stored_loot.append(DEBUG_EXTRA_SALVAGE_ITEM_4)
		result.salvage_items_collected += 4

	return result


func _finish_run(result: RunResult) -> void:
	run_finished.emit(result)


func _on_player_destroyed() -> void:
	request_end_run(RunResult.EndReason.PLAYER_DESTROYED)


func _on_ship_destroyed() -> void:
	request_end_run(RunResult.EndReason.SHIP_DESTROYED)


func _on_enemy_killed(_enemy: Enemy) -> void:
	_enemies_killed += 1


func _on_departure_requested(_pylon: DeparturePylon) -> void:
	if not can_accept_departure_request():
		return
	request_end_run(RunResult.EndReason.VOLUNTARY_DEPARTURE)


func _exit_tree() -> void:
	Magnetide.clear_run_context(self)
