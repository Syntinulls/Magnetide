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
## Spawn interval (seconds) indexed by threat level 1-10. Lower = enemies spawn
## more often. The last value is reused for any level beyond the array length.
@export var spawn_interval_by_level: Array[float] = [12.0, 10.0, 8.0, 6.5, 5.0, 4.0, 3.2, 2.5, 2.0, 1.5]
## Max concurrent living enemies indexed by threat level 1-10. Last value reused.
@export var max_concurrent_by_level: Array[int] = [4, 6, 9, 12, 16, 20, 25, 31, 37, 44]
## Max batches spawned per pass, indexed by threat level 1-10. Each pass rolls
## 1..this many batches and independently picks a weighted eligible type for each,
## so a type can repeat (e.g. two batches of worms, or one worm + one mosquito).
## Last value reused.
@export var max_spawn_occurrences_by_level: Array[int] = [1, 2, 2, 3, 3, 4, 4, 5, 5, 6]
## Per-batch max spawn count, indexed by threat level 1-10. Combined (min) with
## each enemy profile's own max_batch_size. Last value reused.
@export var batch_size_by_level: Array[int] = [1, 2, 2, 3, 3, 4, 4, 5, 5, 6]
## Spawn-rate multiplier while the threat cap is reached (storm imminent). Works
## like magnet_active_spawn_rate_multiplier — the interval is divided by this — so
## >1 spawns enemies more often to pressure the leave-or-continue decision.
@export_range(0.1, 10.0, 0.1, "or_greater") var cap_state_spawn_rate_multiplier: float = 3.0
## Spawn-rate multiplier while the magnet minigame is active. >1 = enemies spawn
## more often during looting than in idle traversal (the interval is divided by
## this). 1.0 = no change.
@export_range(0.1, 10.0, 0.1, "or_greater") var magnet_active_spawn_rate_multiplier: float = 2.0
## Enemy max-health multiplier at the top threat level. Level 1 uses the base
## EnemyData value (1.0x) and it scales linearly to this at level 10. Locked in
## per enemy at spawn.
@export_range(1.0, 20.0, 0.1) var health_multiplier_at_max_level: float = 4.0
## Enemy damage multiplier at the top threat level. Level 1 = 1.0x, scaling
## linearly to this at level 10. Locked in per enemy at spawn.
@export_range(1.0, 20.0, 0.1) var damage_multiplier_at_max_level: float = 3.0

@export_group("Batch Spread")
## Within a batch, enemies spawn one at a time, each offset from the previous by a
## random distance in [min, max] px along the axis perpendicular to its direction
## toward the player/ship (a random side). Perpendicular keeps the spread lateral
## so enemies fan out sideways instead of creeping in front of / behind the group
## toward the player's screen.
@export_range(0.0, 2000.0, 1.0, "or_greater") var batch_spread_min_distance: float = 100.0
@export_range(0.0, 2000.0, 1.0, "or_greater") var batch_spread_max_distance: float = 400.0

var _zone_lookup: Dictionary = {}
var _living_enemies: Array[Enemy] = []
var _spawn_timer_remaining: float = 0.0
## Per-profile spawn cooldown remaining, in seconds. Keyed by EnemySpawnProfile.
var _profile_cooldowns: Dictionary = {}
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
	_tick_profile_cooldowns(delta)

	_spawn_timer_remaining -= delta
	if _spawn_timer_remaining > 0.0:
		return

	_run_spawn_pass()
	_reset_spawn_timer()


func _run_spawn_pass() -> void:
	var eligible := _get_eligible_profiles()
	if eligible.is_empty():
		return

	var max_occurrences := _int_value_for_level(max_spawn_occurrences_by_level, _get_current_threat_level(), 1)
	var occurrence_count := _rng.randi_range(1, maxi(max_occurrences, 1))

	# Each batch independently picks a weighted eligible type (with replacement),
	# so the same type can appear in more than one batch this pass.
	for _i in range(occurrence_count):
		_spawn_batch(_roll_weighted_profile(eligible))


func _spawn_batch(profile: EnemySpawnProfile) -> void:
	if profile == null:
		return

	var valid_zones := _resolve_valid_zones(profile.allowed_spawn_zones)
	if valid_zones.is_empty():
		return

	var remaining_capacity := _get_remaining_capacity(_current_max_concurrent())
	if remaining_capacity == 0:
		return

	var level_batch_max := _int_value_for_level(batch_size_by_level, _get_current_threat_level(), 1)
	var max_batch_size := maxi(mini(profile.max_batch_size, level_batch_max), 0)
	if max_batch_size <= 0:
		return

	var spawn_count := _rng.randi_range(1, max_batch_size)
	if remaining_capacity > 0:
		spawn_count = mini(spawn_count, remaining_capacity)
	if spawn_count <= 0:
		return

	var zone := valid_zones[_rng.randi_range(0, valid_zones.size() - 1)]
	var reference_point := _get_spread_reference_point()
	var spawn_position := _sample_point_in_zone(zone)
	for _i in range(spawn_count):
		if _i > 0:
			spawn_position += _random_batch_spread_offset(spawn_position, reference_point)
		var enemy := _spawn_enemy(profile, spawn_position)
		if enemy != null:
			_track_enemy(enemy)

	if profile.spawn_cooldown > 0.0:
		_profile_cooldowns[profile] = profile.spawn_cooldown


## Offset for the next enemy in a batch: perpendicular to the direction from
## `from_position` toward `reference_point`, on a random side, a random distance in
## the configured [min, max] range. Lateral spread avoids pushing enemies in front
## of / behind the group toward the player.
func _random_batch_spread_offset(from_position: Vector2, reference_point: Vector2) -> Vector2:
	var to_target := reference_point - from_position
	var perpendicular := Vector2(-to_target.y, to_target.x)
	if perpendicular.length_squared() <= 0.0001:
		perpendicular = Vector2.UP
	perpendicular = perpendicular.normalized()
	if _rng.randf() < 0.5:
		perpendicular = -perpendicular

	var min_distance := minf(batch_spread_min_distance, batch_spread_max_distance)
	var max_distance := maxf(batch_spread_min_distance, batch_spread_max_distance)
	return perpendicular * _rng.randf_range(min_distance, max_distance)


## Point the batch spread orients around — perpendicular offsets are taken relative
## to the direction toward this. Prefers the player, then the ship.
func _get_spread_reference_point() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player):
		return player.global_position
	var ship := get_tree().get_first_node_in_group(EnemyData.GROUP_SHIP) as Node2D
	if ship != null and is_instance_valid(ship):
		return ship.global_position
	return global_position


## Force-spawn a single random enemy from the roster, ignoring the spawn timer and
## threat/magnet gating so any registered enemy is testable. Debug only.
func force_spawn_random_enemy() -> void:
	_cleanup_living_enemies()

	var spawnable: Array[EnemySpawnProfile] = []
	for profile in enemy_profiles:
		if profile == null or profile.max_batch_size <= 0:
			continue
		if _resolve_valid_zones(profile.allowed_spawn_zones).is_empty():
			continue
		spawnable.append(profile)

	if spawnable.is_empty():
		return

	var profile := spawnable[_rng.randi_range(0, spawnable.size() - 1)]
	var valid_zones := _resolve_valid_zones(profile.allowed_spawn_zones)
	var zone := valid_zones[_rng.randi_range(0, valid_zones.size() - 1)]
	var enemy := _spawn_enemy(profile, _sample_point_in_zone(zone))
	if enemy != null:
		_track_enemy(enemy)


## Force-spawn a single enemy by its profile id, ignoring the spawn timer and
## threat/magnet gating. Debug only.
func force_spawn_enemy_by_id(id: StringName) -> void:
	_cleanup_living_enemies()

	for profile in enemy_profiles:
		if profile == null or profile.id != id:
			continue
		var valid_zones := _resolve_valid_zones(profile.allowed_spawn_zones)
		if valid_zones.is_empty():
			return
		var zone := valid_zones[_rng.randi_range(0, valid_zones.size() - 1)]
		var enemy := _spawn_enemy(profile, _sample_point_in_zone(zone))
		if enemy != null:
			_track_enemy(enemy)
		return


func _spawn_enemy(profile: EnemySpawnProfile, spawn_global_position: Vector2) -> Enemy:
	var enemy_scene := profile.enemy_scene if profile.enemy_scene != null else DEFAULT_ENEMY_SCENE
	var enemy := enemy_scene.instantiate() as Enemy
	if enemy == null:
		return null

	enemy.data = profile.enemy_data
	var level := _get_current_threat_level()
	enemy.health_scale = _threat_stat_scale(health_multiplier_at_max_level, level)
	enemy.damage_scale = _threat_stat_scale(damage_multiplier_at_max_level, level)
	enemy.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	enemy.position = to_local(spawn_global_position)
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
		if _profile_cooldowns.has(profile):
			continue
		if _resolve_valid_zones(profile.allowed_spawn_zones).is_empty():
			continue
		eligible.append(profile)

	return eligible


## Decrement each profile's remaining spawn cooldown, dropping expired entries.
func _tick_profile_cooldowns(delta: float) -> void:
	for profile in _profile_cooldowns.keys():
		var remaining: float = _profile_cooldowns[profile] - delta
		if remaining <= 0.0:
			_profile_cooldowns.erase(profile)
		else:
			_profile_cooldowns[profile] = remaining


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
	# Cap-reached (storm imminent) and magnet-active rates never stack; storm
	# imminent takes precedence if they ever coincide.
	if _is_cap_reached() and cap_state_spawn_rate_multiplier > 0.0:
		interval /= cap_state_spawn_rate_multiplier
	elif _is_magnet_active() and magnet_active_spawn_rate_multiplier > 0.0:
		interval /= magnet_active_spawn_rate_multiplier
	return maxf(interval, 0.1)


## Linear stat multiplier from 1.0x at threat level 1 to `max_multiplier` at the
## top threat level (ThreatManager.LEVEL_COUNT). Levels outside 1..top are clamped.
func _threat_stat_scale(max_multiplier: float, level: int) -> float:
	var top_threat_level := maxi(ThreatManager.LEVEL_COUNT, 2)
	var t := clampf(float(level - 1) / float(top_threat_level - 1), 0.0, 1.0)
	return lerpf(1.0, maxf(max_multiplier, 1.0), t)


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
