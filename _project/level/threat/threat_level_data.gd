extends Resource
class_name ThreatLevelData

## Placeholder until the enemy spawner system owns this data.
## Negative means "unset."
@export var enemy_count: int = -1
## Placeholder until the enemy spawner system owns this data.
@export var enemy_types: PackedStringArray = PackedStringArray()

@export_group("Weather")
## Placeholder until the weather system owns this data.
@export var weather_conditions: PackedStringArray = PackedStringArray()
