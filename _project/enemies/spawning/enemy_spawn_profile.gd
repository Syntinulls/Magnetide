extends Resource
class_name EnemySpawnProfile

## Per-enemy spawn profile. The enemy spawner owns one flat list of these (one
## per enemy in the game). Each profile declares the threat level the enemy
## unlocks at plus its own spawn conditions, so an enemy is authored exactly
## once instead of being duplicated across every threat level it appears in.

@export var id: StringName = &""
@export var enemy_scene: PackedScene
@export var enemy_data: EnemyData
## Spawn zones (by node name) this enemy may appear in.
@export var allowed_spawn_zones: PackedStringArray = PackedStringArray()

@export_group("Threat Eligibility")
## Threat level (1-10) at or above which this enemy may spawn.
@export_range(1, 10, 1) var min_threat_level: int = 1
## Upper threat level (1-10) beyond which this enemy stops spawning.
## 0 means no upper bound (the enemy never phases out).
@export_range(0, 10, 1) var max_threat_level: int = 0

@export_group("Spawn Conditions")
## Relative weight when rolling among the eligible enemies.
@export_range(0.0, 9999.0, 0.1) var spawn_weight: float = 1.0
## Eligible during active magnet looting.
@export var can_spawn_magnet_active: bool = true
## Eligible during idle/background traversal (no magnet active).
@export var can_spawn_magnet_idle: bool = false
## Maximum number spawned in a single batch.
@export_range(0, 99, 1) var max_batch_size: int = 1


## True if this enemy is allowed to spawn at the given threat level (1-10).
func is_eligible_at_level(level: int) -> bool:
	if level < min_threat_level:
		return false
	if max_threat_level > 0 and level > max_threat_level:
		return false
	return true
