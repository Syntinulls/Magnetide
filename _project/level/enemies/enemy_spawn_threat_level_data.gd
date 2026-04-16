extends Resource
class_name EnemySpawnThreatLevelData

@export_range(0.1, 600.0, 0.1) var spawn_interval_seconds: float = 10.0
@export_range(1, 99, 1) var max_batches_per_spawn: int = 1
@export var magnet_active_pool: Array[WeightedEnemySpawnEntry] = []
@export var magnet_idle_pool: Array[WeightedEnemySpawnEntry] = []
@export var max_concurrent_enemies: int = 0


func get_pool(is_magnet_active: bool) -> Array[WeightedEnemySpawnEntry]:
	return magnet_active_pool if is_magnet_active else magnet_idle_pool
