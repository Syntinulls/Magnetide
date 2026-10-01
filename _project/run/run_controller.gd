extends Node
class_name RunController

signal run_finished(result: RunResult)
signal scrap_metal_count_changed(count: int)

const DEPARTURE_CUTSCENE: CutsceneBehavior = preload("res://_project/run/departure_cutscene_behavior.tres")
## The lever's prompt verb and confirm text per interlevel gate. Storms and the boss
## are irreversible, so their confirm text asks for a second press.
const LEVER_ADVANCE_COPY: Dictionary = {
	ThreatManager.GateKind.PLAIN: ["CONTINUE", ""],
	ThreatManager.GateKind.STORM: ["ENTER STORM", "ENTER STORM?"],
	ThreatManager.GateKind.BOSS: ["FIGHT BOSS", "FIGHT BOSS?"],
}

var _level_definition: LevelDefinition = null
var _level: Node = null
var _game_ui: Control = null
var _ship: Ship = null
var _player: Player = null
var _magnet: Magnet = null
var _recycler: Recycler = null
var _magnet_lever: MagnetLever = null
var _enemy_spawner: EnemySpawner = null
var _magnet_minigame: MagnetMinigame = null
var _storm_controller: StormController = null
var _boss_encounter: BossEncounter = null
var _threat: ThreatManager = null
var _run_loadout: RunLoadout = null
var _artifact_tracker: RunArtifactTracker = RunArtifactTracker.new()
var _active_augment_behaviors: Array[AugmentBehavior] = []
var _elapsed_seconds: float = 0.0
var _enemies_killed: int = 0
var _scrap_metal_collected: int = 0
var _end_reason: RunResult.EndReason = RunResult.EndReason.VOLUNTARY_DEPARTURE
var _is_run_ending: bool = false
## Items awarded outside ship storage (a boss reward), added to the departure payload.
var _bonus_loot: Array[SalvageItemData] = []

var scrap_metal_collected: int:
	get:
		return _scrap_metal_collected


func get_run_loadout() -> RunLoadout:
	return _run_loadout


## Per-run artifact tracker (1-each caps). Read by the magnet (roll gating) and the ship storage
## path (cap commit on placement).
func get_artifact_tracker() -> RunArtifactTracker:
	return _artifact_tracker


func start_run(level_definition: LevelDefinition, level_node: Node, run_loadout: RunLoadout = null) -> void:
	_level_definition = level_definition
	_level = level_node
	_run_loadout = run_loadout
	_elapsed_seconds = 0.0
	_enemies_killed = 0
	_scrap_metal_collected = 0
	_end_reason = RunResult.EndReason.VOLUNTARY_DEPARTURE
	_is_run_ending = false
	_bonus_loot.clear()
	_artifact_tracker.reset()
	call_deferred("_bind_runtime")


func _bind_runtime() -> void:
	if _level == null or not is_instance_valid(_level):
		return

	_ship = _level.get_node_or_null("Ship") as Ship
	if _ship:
		_player = _ship.get_node_or_null("Player") as Player
		_magnet = _ship.get_node_or_null("Magnet") as Magnet
		_magnet_lever = _ship.get_node_or_null("MagnetLever") as MagnetLever
		_recycler = _ship.get_node_or_null("Recycler") as Recycler

	if "ui_root" in _level and _level.ui_root:
		_game_ui = _level.ui_root.get_node_or_null("GameUI") as Control

	_enemy_spawner = _level.get_node_or_null("EnemySpawner") as EnemySpawner
	_magnet_minigame = _level.get_node_or_null("MagnetMinigame") as MagnetMinigame
	_storm_controller = _level.get_node_or_null("StormController") as StormController
	_boss_encounter = _level.get_node_or_null("BossEncounter") as BossEncounter
	_threat = _level.get_node_or_null("ThreatManager") as ThreatManager

	Magnetide.register_run_context(self, _level, _level, _game_ui, _ship, _player, _magnet)
	_inject_level_content()
	_connect_runtime_signals()
	_initialize_augments()
	_sync_game_ui_scrap_counter()
	_start_run_music()
	set_process(true)


func _connect_runtime_signals() -> void:
	if _player and not _player.health.destroyed.is_connected(_on_player_destroyed):
		_player.health.destroyed.connect(_on_player_destroyed)
	if _player and not _player.scrap_collector.scrap_metal_collected.is_connected(record_scrap_metal_collected):
		_player.scrap_collector.scrap_metal_collected.connect(record_scrap_metal_collected)
	if _ship and not _ship.destroyed.is_connected(_on_ship_destroyed):
		_ship.destroyed.connect(_on_ship_destroyed)
	if _enemy_spawner and not _enemy_spawner.enemy_killed.is_connected(_on_enemy_killed):
		_enemy_spawner.enemy_killed.connect(_on_enemy_killed)
	if _ship:
		for pylon in _ship.get_departure_pylons():
			if not pylon.departure_requested.is_connected(_on_departure_requested):
				pylon.departure_requested.connect(_on_departure_requested)
	if _threat and not _threat.storm_started.is_connected(_on_storm_started):
		_threat.storm_started.connect(_on_storm_started)
	if _threat and not _threat.storm_finished.is_connected(_on_storm_finished):
		_threat.storm_finished.connect(_on_storm_finished)
	if _threat and not _threat.boss_started.is_connected(_on_boss_started):
		_threat.boss_started.connect(_on_boss_started)
	if _boss_encounter and not _boss_encounter.encounter_finished.is_connected(_on_boss_encounter_finished):
		_boss_encounter.encounter_finished.connect(_on_boss_encounter_finished)
	# The run coordinates the lever's window role: the threat manager owns the state
	# and the lever owns the input, but neither should know about the other.
	if _threat and not _threat.window_opened.is_connected(_on_threat_window_opened):
		_threat.window_opened.connect(_on_threat_window_opened)
	if _threat and not _threat.window_closed.is_connected(_on_threat_window_closed):
		_threat.window_closed.connect(_on_threat_window_closed)
	if _magnet_lever and not _magnet_lever.advance_confirmed.is_connected(_on_advance_confirmed):
		_magnet_lever.advance_confirmed.connect(_on_advance_confirmed)


## Push the level definition's authored content into the runtime nodes. A level's
## enemy roster, storms and boss are defined by its definition, not by whichever
## scene happens to instance the spawner.
func _inject_level_content() -> void:
	if _level_definition == null:
		return
	if _enemy_spawner:
		_enemy_spawner.set_enemy_profiles(_level_definition.enemy_profiles)
	if _threat:
		_threat.set_storms(_level_definition.storms)
		_threat.set_boss_available(_level_definition.boss_scene != null)
	if _boss_encounter:
		_boss_encounter.set_boss_scene(_level_definition.boss_scene)


func _process(delta: float) -> void:
	if _is_run_ending:
		return
	_elapsed_seconds += delta
	for behavior in _active_augment_behaviors:
		if behavior != null and behavior.has_method("tick"):
			behavior.call("tick", delta)


## Departure is only possible during the interlevel window — the run's one
## deliberate exit. Gating here turns off the pylons' interaction, highlight and
## control prompt together, since all three hang off this one check.
func can_accept_departure_request() -> bool:
	if _is_run_ending:
		return false
	return _threat != null and _threat.is_departure_window_open


## True once the run has entered its end sequence (departure cutscene or death
## teardown). Used by UI (pause menu) to refuse actions during the sequence.
func is_run_ending() -> bool:
	return _is_run_ending


func request_end_run(reason: RunResult.EndReason) -> void:
	if _is_run_ending:
		return

	_is_run_ending = true
	_end_reason = reason
	if Magnetide.bgm:
		Magnetide.bgm.fade_out()
	var is_departure := RunResult.reason_keeps_loot(reason)
	var departure_start_speed := _get_level_speed()
	_shutdown_gameplay(not is_departure)
	if is_departure:
		_set_level_speed(departure_start_speed)
		call_deferred("_finish_run_after_departure_cutscene")
	else:
		var result := _build_result()
		call_deferred("_finish_run", result)


func _shutdown_gameplay(stop_player: bool = true) -> void:
	set_process(false)
	_cleanup_augments()

	if _player:
		# Even when the player keeps walking for the departure cutscene, they can
		# no longer deal or receive damage.
		_player.combat_disabled = true
		if stop_player:
			_player.stop_for_run_end()
	if _game_ui and _game_ui.has_method("stop_for_run_end"):
		_game_ui.call("stop_for_run_end")
	if _magnet_minigame:
		_magnet_minigame.stop_for_run_end()
	if _enemy_spawner:
		_enemy_spawner.stop_for_run_end()
	if _storm_controller:
		_storm_controller.stop_for_run_end()
	if _boss_encounter:
		_boss_encounter.stop_for_run_end()
	if _level and "level_speed" in _level:
		_level.level_speed = 0.0
	if _level and "threat" in _level and _level.threat:
		_level.threat.stop_for_run_end()

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
		if result.keeps_loot():
			result.stored_loot = _ship.get_stored_loot_payload()
	if result.keeps_loot():
		result.stored_loot.append_array(_bonus_loot)

	return result


func _finish_run(result: RunResult) -> void:
	_cleanup_augments()
	run_finished.emit(result)


func _finish_run_after_departure_cutscene() -> void:
	var cutscenes := Magnetide.cutscenes
	if cutscenes:
		await cutscenes.play(DEPARTURE_CUTSCENE)
	var result := _build_result()
	_finish_run(result)


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


func _start_run_music() -> void:
	if Magnetide.bgm:
		Magnetide.bgm.play_category(BgmPlayer.Category.IN_RUN)


## Hand the lever its window role. Entering a storm or the boss fight is
## irreversible, so the lever asks for a confirming second press; at a plain gate
## one press commits.
func _on_threat_window_opened(_seconds: float, gate: ThreatManager.GateKind) -> void:
	if _magnet_lever == null or _threat == null:
		return
	if _threat.can_advance() and LEVER_ADVANCE_COPY.has(gate):
		var copy: Array = LEVER_ADVANCE_COPY[gate]
		_magnet_lever.set_advance_mode(true, copy[0], copy[1])


func _on_threat_window_closed() -> void:
	if _magnet_lever:
		_magnet_lever.set_advance_mode(false)


func _on_advance_confirmed() -> void:
	if _threat:
		_threat.advance()


func _on_storm_started(_storm: StormData) -> void:
	if Magnetide.bgm:
		Magnetide.bgm.play_category(BgmPlayer.Category.STORM)


## Clearing a storm returns music to the in-run playlist. The interlevel window
## deliberately does not switch category — a 30-second swap either side of a
## decision beat would thrash.
func _on_storm_finished(_storm: StormData) -> void:
	if Magnetide.bgm:
		Magnetide.bgm.play_category(BgmPlayer.Category.IN_RUN)


func _on_boss_started() -> void:
	if Magnetide.bgm:
		Magnetide.bgm.play_category(BgmPlayer.Category.BOSS)


## Beating the boss ends the run as a departure: the ship leaves with its cargo.
func _on_boss_encounter_finished(_boss: Boss) -> void:
	request_end_run(RunResult.EndReason.BOSS_DEFEATED)


## Add items to the run's recovered cargo without placing them in ship storage (a
## boss reward). They reach the salvage screen only if the run ends keeping loot.
func award_bonus_loot(items: Array[SalvageItemData]) -> void:
	for item in items:
		if item == null:
			continue
		_bonus_loot.append(item)
		if _player and _player.loot_labels:
			_player.loot_labels.record(item.item_name, 1)


func record_scrap_metal_collected(amount: int) -> void:
	if amount <= 0:
		return
	_scrap_metal_collected += amount
	scrap_metal_count_changed.emit(_scrap_metal_collected)
	_sync_game_ui_scrap_counter()


## Spend from the run's scrap pool (e.g. repair gun cycles). All-or-nothing: returns
## false without deducting when the pool can't cover the amount. Spent scrap also
## shrinks the end-of-run banked payout, which reads the same counter.
func spend_scrap_metal(amount: int) -> bool:
	if amount <= 0 or _scrap_metal_collected < amount:
		return false
	_scrap_metal_collected -= amount
	scrap_metal_count_changed.emit(_scrap_metal_collected)
	_sync_game_ui_scrap_counter()
	return true


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
		"recycler": _recycler,
		"run_controller": self,
	}
	for augment in _run_loadout.get_equipped_augments():
		if augment == null or augment.behavior == null:
			continue
		var behavior := augment.behavior.duplicate(true) as AugmentBehavior
		if behavior == null:
			continue
		var level := _run_loadout.get_item_level(augment)
		if augment.upgrade_data != null:
			augment.upgrade_data.apply_for_level(behavior, augment.behavior, level, UpgradeEffect.Target.BEHAVIOR)
		behavior.initialize_for_run(context, level)
		_active_augment_behaviors.append(behavior)


func _cleanup_augments() -> void:
	for behavior in _active_augment_behaviors:
		if behavior != null:
			behavior.cleanup_after_run()
	_active_augment_behaviors.clear()
