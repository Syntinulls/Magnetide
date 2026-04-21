extends Node2D
class_name EnemySpawner

signal enemy_killed(enemy: Enemy)

const DEFAULT_ENEMY_SCENE := preload("res://_project/enemies/enemy.tscn")

@export var spawn_zones: Array[NodePath] = []
@export var profile: EnemySpawnerProfile

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

	if profile == null:
		profile = EnemySpawnerProfile.new()

	_reset_spawn_timer()
	set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_cleanup_living_enemies()

	if not _is_magnet_active():
		return

	_spawn_timer_remaining -= delta
	if _spawn_timer_remaining > 0.0:
		return

	_run_spawn_pass()
	_reset_spawn_timer()


func _run_spawn_pass() -> void:
	var level_data := _get_current_level_data()
	if level_data == null:
		return

	var max_batches := maxi(level_data.max_batches_per_spawn, 0)
	if max_batches <= 0:
		return

	var batch_count := _rng.randi_range(1, max_batches)
	for _i in range(batch_count):
		_spawn_batch(level_data)


func _spawn_batch(level_data: EnemySpawnThreatLevelData) -> void:
	var threat_stage := _get_current_threat_stage()
	var valid_entries := _get_valid_pool_entries(level_data.get_pool(_is_magnet_active()), threat_stage)
	if valid_entries.is_empty():
		return

	var selected_entry := _roll_weighted_entry(valid_entries)
	if selected_entry == null or selected_entry.enemy == null:
		return

	var spawn_definition := selected_entry.enemy
	var valid_zones := _resolve_valid_zones(spawn_definition.allowed_spawn_zones)
	if valid_zones.is_empty():
		return

	var max_batch_size := spawn_definition.get_max_batch_size(threat_stage)
	if max_batch_size <= 0:
		return

	var remaining_capacity := _get_remaining_capacity(level_data.max_concurrent_enemies)
	if remaining_capacity == 0:
		return

	var spawn_count := _rng.randi_range(1, max_batch_size)
	if remaining_capacity > 0:
		spawn_count = mini(spawn_count, remaining_capacity)
	if spawn_count <= 0:
		return

	var zone := valid_zones[_rng.randi_range(0, valid_zones.size() - 1)]
	for _i in range(spawn_count):
		var enemy := _spawn_enemy(spawn_definition, zone)
		if enemy != null:
			_track_enemy(enemy)


func _spawn_enemy(spawn_definition: EnemySpawnDefinition, zone: Area2D) -> Enemy:
	var enemy_scene := spawn_definition.enemy_scene if spawn_definition.enemy_scene != null else DEFAULT_ENEMY_SCENE
	var enemy := enemy_scene.instantiate() as Enemy
	if enemy == null:
		return null

	enemy.data = spawn_definition.enemy_data
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


func _get_valid_pool_entries(pool: Array[WeightedEnemySpawnEntry], threat_stage: int) -> Array[WeightedEnemySpawnEntry]:
	var valid_entries: Array[WeightedEnemySpawnEntry] = []

	for entry in pool:
		if entry == null or entry.enemy == null:
			continue
		if entry.weight <= 0.0:
			continue
		if entry.enemy.get_max_batch_size(threat_stage) <= 0:
			continue
		if _resolve_valid_zones(entry.enemy.allowed_spawn_zones).is_empty():
			continue
		valid_entries.append(entry)

	return valid_entries


func _roll_weighted_entry(entries: Array[WeightedEnemySpawnEntry]) -> WeightedEnemySpawnEntry:
	var total_weight := 0.0
	for entry in entries:
		total_weight += entry.weight

	if total_weight <= 0.0:
		return null

	var roll := _rng.randf() * total_weight
	for entry in entries:
		roll -= entry.weight
		if roll <= 0.0:
			return entry

	return entries[entries.size() - 1]


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


func _get_current_level_data() -> EnemySpawnThreatLevelData:
	if profile == null:
		return null
	return profile.get_level_data(_get_current_threat_stage())


func _get_current_threat_stage() -> int:
	if _threat_manager == null:
		_resolve_threat_manager()
	if _threat_manager == null:
		return 0
	return _threat_manager.threat_level


func _get_remaining_capacity(max_concurrent_enemies: int) -> int:
	if max_concurrent_enemies <= 0:
		return -1
	return maxi(max_concurrent_enemies - _living_enemies.size(), 0)


func _reset_spawn_timer() -> void:
	var level_data := _get_current_level_data()
	if level_data == null:
		_spawn_timer_remaining = 10.0
		return
	_spawn_timer_remaining = maxf(level_data.spawn_interval_seconds, 0.1)


func _resolve_threat_manager() -> void:
	_threat_manager = get_node_or_null("../ThreatManager") as ThreatManager


func _is_magnet_active() -> bool:
	return Magnetide.magnet != null and Magnetide.magnet.is_active


func stop_for_run_end() -> void:
	set_process(false)
	_spawn_timer_remaining = 0.0
