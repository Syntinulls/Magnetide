extends Resource
class_name EnemySpawnerProfile

const THREAT_LEVEL_COUNT: int = 5

var _levels: Array[EnemySpawnThreatLevelData] = _create_default_levels()

@export var levels: Array[EnemySpawnThreatLevelData]:
	get:
		return _levels
	set(value):
		_levels = _normalize_levels(value)


func _init() -> void:
	_levels = _normalize_levels(_levels)


func get_level_data(threat_stage: int) -> EnemySpawnThreatLevelData:
	if _levels.is_empty():
		_levels = _create_default_levels()
	return _levels[clampi(threat_stage, 0, THREAT_LEVEL_COUNT - 1)]


static func _create_default_levels() -> Array[EnemySpawnThreatLevelData]:
	var defaults: Array[EnemySpawnThreatLevelData] = []
	for _i in range(THREAT_LEVEL_COUNT):
		defaults.append(EnemySpawnThreatLevelData.new())
	return defaults


static func _normalize_levels(value: Array[EnemySpawnThreatLevelData]) -> Array[EnemySpawnThreatLevelData]:
	var defaults := _create_default_levels()
	var normalized: Array[EnemySpawnThreatLevelData] = []

	for i in range(THREAT_LEVEL_COUNT):
		if i < value.size() and value[i] != null:
			normalized.append(value[i])
		else:
			normalized.append(defaults[i])

	return normalized
