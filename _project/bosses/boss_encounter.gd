extends Node
class_name BossEncounter

## Runs the level's boss fight, from summons to victory.
##
## When ThreatManager enters its boss phase this node halts the ship, clears ambient
## enemies and stops new ones, spawns the boss dormant, binds the HUD boss bar, and
## plays the intro before activating it. Between phases it plays each phase's
## transition cutscene and then releases the boss into the new phase. On defeat it
## pays out the reward, plays the outro, and reports encounter_finished; the run
## controller departs from there. Cutscenes receive the boss under CONTEXT_BOSS.

signal encounter_started(boss: Boss)
signal encounter_finished(boss: Boss)

const CONTEXT_BOSS := &"boss"

## Seconds the ship takes to brake to a stop when the fight starts.
@export_range(0.0, 20.0, 0.1, "or_greater") var ship_halt_seconds: float = 1.5

var _boss_scene: PackedScene = null
## Debug override for the next encounter's boss, consumed when it starts.
var _debug_scene: PackedScene = null
var _boss: Boss = null
var _level: Level = null
var _threat: ThreatManager = null
var _enemy_spawner: EnemySpawner = null
var _run_ended: bool = false


func _ready() -> void:
	_level = get_parent() as Level
	_threat = get_node_or_null("../ThreatManager") as ThreatManager
	_enemy_spawner = get_node_or_null("../EnemySpawner") as EnemySpawner
	if _threat:
		_threat.boss_started.connect(_on_boss_started)


## The level's boss (injected from the level definition).
func set_boss_scene(scene: PackedScene) -> void:
	_boss_scene = scene


func get_active_boss() -> Boss:
	return _boss if _boss and is_instance_valid(_boss) else null


## Debug entry point: fight `scene` now, whatever the threat level or the level's own
## boss. Ignored while a boss is already out.
func debug_summon(scene: PackedScene) -> void:
	if scene == null or get_active_boss() != null or _run_ended:
		return
	_debug_scene = scene
	if _threat and not _threat.is_boss_active:
		_threat.debug_start_boss()
	else:
		_on_boss_started()


func stop_for_run_end() -> void:
	_run_ended = true
	var boss := get_active_boss()
	if boss:
		boss.stop_for_run_end()
	var bar := Magnetide.boss_health_bar
	if bar:
		bar.unbind()


func _on_boss_started() -> void:
	var scene := _debug_scene if _debug_scene else _boss_scene
	_debug_scene = null
	if scene == null:
		push_warning("BossEncounter: the boss phase started but the level has no boss scene.")
		return
	_start_encounter(scene)


func _start_encounter(scene: PackedScene) -> void:
	var boss := scene.instantiate() as Boss
	if boss == null:
		push_error("BossEncounter: %s does not have a Boss root." % scene.resource_path)
		return
	_boss = boss

	if _enemy_spawner:
		_enemy_spawner.set_ambient_spawning_enabled(false)
	_clear_ambient_enemies()
	if _level:
		_level.tween_level_speed(0.0, ship_halt_seconds)
		if boss.data:
			var ratio := boss.data.spawn_viewport_ratio
			boss.position = _level.viewport_anchor.get_position(ratio.x, ratio.y)
	var world := Magnetide.world_root
	if world == null:
		world = get_parent()
	world.add_child(boss)
	boss.phase_transition_started.connect(_on_phase_transition_started)
	boss.defeated.connect(_on_boss_defeated)
	var bar := Magnetide.boss_health_bar
	if bar:
		bar.bind(boss)
	encounter_started.emit(boss)

	await _play_cutscene(boss.data.intro_cutscene if boss.data else null)
	if _run_ended or get_active_boss() != boss:
		return
	boss.activate()


func _on_phase_transition_started(index: int) -> void:
	var boss := get_active_boss()
	if boss == null:
		return
	var phase := boss.data.get_phase(index) if boss.data else null
	var cutscene := phase.transition_cutscene if phase else null
	if cutscene == null:
		# Released next frame, not inside the damage call that crossed the threshold.
		boss.finish_phase_transition.call_deferred()
		return
	await _play_cutscene(cutscene)
	if not _run_ended and get_active_boss() == boss:
		boss.finish_phase_transition()


func _on_boss_defeated() -> void:
	var boss := get_active_boss()
	if boss == null:
		return
	_award_reward(boss)
	var bar := Magnetide.boss_health_bar
	if bar:
		bar.unbind()
	await _play_cutscene(boss.data.outro_cutscene if boss.data else null)
	if _run_ended:
		return
	encounter_finished.emit(boss)


## Scrap flies from the boss to the HUD counter; items join the run's recovered cargo.
func _award_reward(boss: Boss) -> void:
	var reward := boss.data.reward if boss.data else null
	if reward == null:
		return
	var player := Magnetide.player as Player
	if player and reward.scrap_metal > 0:
		player.scrap_collector.collect_from(boss.global_position, reward.scrap_metal)
	var run := Magnetide.run as RunController
	if run:
		var threat_level := _threat.threat_level if _threat else ThreatManager.MAX_STAGE_INDEX
		run.award_bonus_loot(reward.roll_items(threat_level))


func _play_cutscene(cutscene: CutsceneBehavior) -> void:
	var cutscenes := Magnetide.cutscenes
	if cutscene == null or cutscenes == null:
		return
	await cutscenes.play(cutscene, {CONTEXT_BOSS: _boss})


## Ambient enemies still out when the fight starts leave rather than crowd it.
func _clear_ambient_enemies() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and enemy.state != Enemy.State.DEATH:
			enemy.queue_free()
