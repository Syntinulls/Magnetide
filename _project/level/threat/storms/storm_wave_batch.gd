extends Resource
class_name StormWaveBatch

## One group of identical enemies within a storm wave. Batches spawn sequentially,
## reusing the enemy spawner's normal batch placement (zone sampling, lateral spread).

@export var profile: EnemySpawnProfile
## How many of this enemy the batch spawns.
@export_range(1, 99, 1) var count: int = 3
## Spawn zones (by node name) to place this batch in. Empty falls back to the
## profile's own allowed_spawn_zones.
@export var spawn_zones: PackedStringArray = PackedStringArray()


## Zones this batch should spawn in, falling back to the profile's own list.
func get_spawn_zones() -> PackedStringArray:
	if not spawn_zones.is_empty():
		return spawn_zones
	return profile.allowed_spawn_zones if profile != null else PackedStringArray()
