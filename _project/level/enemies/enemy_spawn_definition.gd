extends Resource
class_name EnemySpawnDefinition

const THREAT_LEVEL_COUNT: int = 5

@export var id: StringName = &""
@export var enemy_scene: PackedScene
@export var enemy_data: EnemyData
@export var allowed_spawn_zones: PackedStringArray = PackedStringArray()
@export var max_batch_sizes_by_threat: PackedInt32Array = PackedInt32Array([1, 1, 1, 1, 1])


func get_max_batch_size(threat_stage: int) -> int:
	if max_batch_sizes_by_threat.is_empty():
		return 0

	var clamped_stage := clampi(threat_stage, 0, THREAT_LEVEL_COUNT - 1)
	if clamped_stage < max_batch_sizes_by_threat.size():
		return maxi(max_batch_sizes_by_threat[clamped_stage], 0)

	return maxi(max_batch_sizes_by_threat[max_batch_sizes_by_threat.size() - 1], 0)
