extends Resource
class_name ThreatLevelData

## Placeholder until the enemy spawner system owns this data.
## Negative means "unset."
@export var enemy_count: int = -1
## Placeholder until the enemy spawner system owns this data.
@export var enemy_types: PackedStringArray = PackedStringArray()

@export_group("Pile Weights")
@export var common_weight: float = 0.0
@export var rare_weight: float = 0.0
@export var epic_weight: float = 0.0
@export var legendary_weight: float = 0.0
@export var artifact_weight: float = 0.0

@export_group("Weather")
## Placeholder until the weather system owns this data.
@export var weather_conditions: PackedStringArray = PackedStringArray()


func get_pile_rarity_weights() -> Dictionary:
	return {
		SalvagePile.Rarity.COMMON: common_weight,
		SalvagePile.Rarity.RARE: rare_weight,
		SalvagePile.Rarity.EPIC: epic_weight,
		SalvagePile.Rarity.LEGENDARY: legendary_weight,
		SalvagePile.Rarity.ARTIFACT: artifact_weight,
	}
