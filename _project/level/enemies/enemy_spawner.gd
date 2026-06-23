extends Node2D
class_name EnemySpawner

signal enemy_killed(enemy: Enemy)

const DEFAULT_ENEMY_SCENE := preload("res://_project/enemies/enemy.tscn")

@export var spawn_zones: Array[NodePath] = []
## Flat list of every enemy in the game. Each profile declares its own threat
## eligibility and spawn conditions; the roster for a given threat level is
## derived by filtering this list.
@export var enemy_profiles: Array[EnemySpawnProfile] = []

@export_group("Threat Scaling")
## Max batches rolled per spawn pass.
@export_range(1, 16, 1) var max_batches_per_spawn: int = 1
## Spawn interval (seconds) indexed by threat level 1-10. The last value is used
## for any level beyond the array length.
@export var spawn_interval_by_level: Array[float] = [10.0, 9.0, 8.0, 7.0, 6.0, 5.5, 5.0, 4.5, 4.0, 3.5]
## Max concurrent living enemies indexed by threat level 1-10. Last value reused.
@export var max_concurrent_by_level: Array[int] = [4, 6, 8, 10, 12, 14, 16, 18, 20, 22]
## Spawn interval multiplier while the threat cap is reached (faster = more pressure).
@export_range(0.05, 1.0, 0.05) var cap_state_interval_multiplier: float = 0.6

var _zone_lookup: Dictionary = {}
var _living_enemies: Array[Enemy] = []
var _spawn_timer_remaining: float = 0.0
var _threat_manager: ThreatManager = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_rng.randomize()
	_resolve_threat_manager()
	_rebuild_zone_lookup()
	_reset_spawn_timer()
	set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_cleanup_living_enemies()

	_spawn_timer_remaining -= delta
	if _spawn_timer_remaining > 0.0:
		return

	_run_spawn_pass()
	_reset_spawn_timer()


func _run_spawn_pass() -> void:
	var batch_count := _rng.randi_range(1, maxi(max_batches_per_spawn, 1))
	for _i in range(batch_count):
		_spawn_batch()


func _spawn_batch() -> void:
	var eligible := _get_eligible_profiles()
	if eligible.is_empty():
		return

	var profile := _roll_weighted_profile(eligible)
	if profile == null:
		return

	var valid_zones := _resolve_valid_zones(profile.allowed_spawn_zones)
	if valid_zones.is_empty():
		return

	var remaining_capacity := _get_remaining_capacity(_current_max_concurrent())
	if remaining_capacity == 0:
		return

	var max_batch_size := maxi(profile.max_batch_size, 0)
	if max_batch_size <= 0:
		return

	var spawn_count := _rng.randi_range(1, max_batch_size)
	if remaining_capacity > 0:
		spawn_count = mini(spawn_count, remaining_capacity)
	if spawn_count <= 0:
		return

	var zone := valid_zones[_rng.randi_range(0, valid_zones.size() - 1)]
	for _i in range(spawn_count):
		var enemy := _spawn_enemy(profile, zone)
		if enemy != null:
			_track_enemy(enemy)


## Force-spawn a single basic enemy immediately, ignoring the spawn timer.
## Used for artifact-pile pressure and debug.
func force_spawn_basic_enemy() -> void:
	_cleanup_living_enemies()

	var profile := _get_basic_profile()
	if profile == null:
		return

	var valid_zones := _resolve_valid_zones(profile.allowed_spawn_zones)
	if valid_zones.is_empty():
		return

	var zone := valid_zones[_rng.randi_range(0, valid_zones.size() - 1)]
	var enemy := _spawn_enemy(profile, zone)
	if enemy != null:
		_track_enemy(enemy)


func _spawn_enemy(profile: EnemySpawnProfile, zone: Area2D) -> Enemy:
	var enemy_scene := profile.enemy_scene if profile.enemy_scene != null else DEFAULT_ENEMY_SCENE
	var enemy := enemy_scene.instantiate() as Enemy
	if enemy == null:
		return null

	enemy.data = profile.enemy_data
	enemy.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	enemy.position = to_local(_sample_point_in_zone(zone))
	add_child(enemy)
	return enemy


func _track_enemy(enemy: Enemy) -> void:
	if enemy == null or enemy in _living_enemies:
		return

	_living_enemies.append(enemy)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy))


func _on_enemy_died(enemy: Enemy) -> void:
	_untrack_enemy(enemy)
	enemy_killed.emit(enemy)


func _on_enemy_tree_exited(enemy: Enemy) -> void:
	_untrack_enemy(enemy)


func _untrack_enemy(enemy: Enemy) -> void:
	var index := _living_enemies.find(enemy)
	if index != -1:
		_living_enemies.remove_at(index)


func _cleanup_living_enemies() -> void:
	for i in range(_living_enemies.size() - 1, -1, -1):
		if not is_instance_valid(_living_enemies[i]):
			_living_enemies.remove_at(i)


## Profiles eligible to spawn right now (threat level + magnet context + zones).
func _get_eligible_profiles() -> Array[EnemySpawnProfile]:
	var magnet_active := _is_magnet_active()
	var level := _get_current_threat_level()
	var eligible: Array[EnemySpawnProfile] = []

	for profile in enemy_profiles:
		if profile == null or profile.spawn_weight <= 0.0:
			continue
		if profile.max_batch_size <= 0:
			continue
		if not profile.is_eligible_at_level(level):
			continue
		if magnet_active and not profile.can_spawn_magnet_active:
			continue
		if not magnet_active and not profile.can_spawn_magnet_idle:
			continue
		if _resolve_valid_zones(profile.allowed_spawn_zones).is_empty():
			continue
		eligible.append(profile)

	return eligible


func _roll_weighted_profile(profiles: Array[EnemySpawnProfile]) -> EnemySpawnProfile:
	var total_weight := 0.0
	for profile in profiles:
		total_weight += profile.spawn_weight

	if total_weight <= 0.0:
		return null

	var roll := _rng.randf() * total_weight
	for profile in profiles:
		roll -= profile.spawn_weight
		if roll <= 0.0:
			return profile

	return profiles[profiles.size() - 1]


## Lowest-threat magnet-active enemy, used by force_spawn_basic_enemy.
func _get_basic_profile() -> EnemySpawnProfile:
	var level := _get_current_threat_level()
	var best: EnemySpawnProfile = null

	for profile in enemy_profiles:
		if profile == null or profile.max_batch_size <= 0:
			continue
		if not profile.can_spawn_magnet_active:
			continue
		if not profile.is_eligible_at_level(level):
			continue
		if best == null or profile.min_threat_level < best.min_threat_level:
			best = profile

	return best


func _resolve_valid_zones(allowed_zone_names: PackedStringArray) -> Array[Area2D]:
	var zones: Array[Area2D] = []

	for zone_name in allowed_zone_names:
		var zone := _zone_lookup.get(StringName(zone_name), null) as Area2D
		if zone != null:
			zones.append(zone)

	return zones


func _sample_point_in_zone(zone: Area2D) -> Vector2:
	var collision_shape := _get_zone_collision_shape(zone)
	if collision_shape == null:
		return zone.global_position

	var rectangle_shape := collision_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		return zone.global_position

	var local_offset := Vector2(
		_rng.randf_range(-rectangle_shape.size.x * 0.5, rectangle_shape.size.x * 0.5),
		_rng.randf_range(-rectangle_shape.size.y * 0.5, rectangle_shape.size.y * 0.5)
	)
	var shape_transform := zone.global_transform * collision_shape.transform
	return shape_transform * local_offset


func _get_zone_collision_shape(zone: Area2D) -> CollisionShape2D:
	return zone.get_node_or_null("CollisionShape2D") as CollisionShape2D


func _rebuild_zone_lookup() -> void:
	_zone_lookup.clear()

	for zone_path in spawn_zones:
		var zone := get_node_or_null(zone_path) as Area2D
		if zone == null:
			continue
		_zone_lookup[StringName(zone.name)] = zone


## Current threat level as a player-facing value (1-10).
func _get_current_threat_level() -> int:
	if _threat_manager == null:
		_resolve_threat_manager()
	if _threat_manager == null:
		return 1
	return _threat_manager.get_player_threat_level()


func _is_cap_reached() -> bool:
	if _threat_manager == null:
		_resolve_threat_manager()
	return _threat_manager != null and _threat_manager.is_cap_reached


func _current_max_concurrent() -> int:
	return _int_value_for_level(max_concurrent_by_level, _get_current_threat_level(), 0)


func _current_spawn_interval() -> float:
	var interval := _float_value_for_level(spawn_interval_by_level, _get_current_threat_level(), 10.0)
	if _is_cap_reached():
		interval *= cap_state_interval_multiplier
	return maxf(interval, 0.1)


func _int_value_for_level(values: Array[int], level: int, fallback: int) -> int:
	if values.is_empty():
		return fallback
	return values[clampi(level - 1, 0, values.size() - 1)]


func _float_value_for_level(values: Array[float], level: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	return values[clampi(level - 1, 0, values.size() - 1)]


func _get_remaining_capacity(max_concurrent_enemies: int) -> int:
	if max_concurrent_enemies <= 0:
		return -1
	return maxi(max_concurrent_enemies - _living_enemies.size(), 0)


func _reset_spawn_timer() -> void:
	_spawn_timer_remaining = _current_spawn_interval()


func _resolve_threat_manager() -> void:
	_threat_manager = get_node_or_null("../ThreatManager") as ThreatManager


func _is_magnet_active() -> bool:
	return Magnetide.magnet != null and Magnetide.magnet.is_active


func stop_for_run_end() -> void:
	set_process(false)
	_spawn_timer_remaining = 0.0
