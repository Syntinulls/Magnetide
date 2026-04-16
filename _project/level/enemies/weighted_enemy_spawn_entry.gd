extends Resource
class_name WeightedEnemySpawnEntry

@export var enemy: EnemySpawnDefinition
@export_range(0.0, 9999.0, 0.1) var weight: float = 1.0
