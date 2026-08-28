extends Resource
class_name LeverModifierWeights

## Weighted none/positive/negative pools for rolling a lever minigame modifier.
## Weights are relative scalars, not percentages: a pool's chance is its weight
## over the total at that threat (WeightedRandom derives it at roll time). The
## none and positive weights hold constant over threat; only the negative pool
## grows, by negative_weight_per_stage per zero-based threat stage (0-9).

enum Pool { NONE, POSITIVE, NEGATIVE }

@export var none_weight: float = 70.0
@export var positive_weight: float = 15.0
@export var negative_base_weight: float = 5.0
## Additive negative-pool weight per threat stage above 0.
@export var negative_weight_per_stage: float = 3.0
@export var positive_modifiers: Array[LeverModifierBehavior] = []
@export var negative_modifiers: Array[LeverModifierBehavior] = []


func get_pool_weight(pool: int, threat_level: int) -> float:
	match pool:
		Pool.NONE:
			return none_weight
		Pool.POSITIVE:
			return positive_weight
		Pool.NEGATIVE:
			return negative_base_weight + negative_weight_per_stage * float(threat_level)
		_:
			return 0.0


## Rolls a pool, then picks uniformly inside it. Returns null for the none pool
## (and for a winning pool that has no modifiers authored).
func roll_modifier(threat_level: int, rng: RandomNumberGenerator = null) -> LeverModifierBehavior:
	var pools: Array = [Pool.NONE, Pool.POSITIVE, Pool.NEGATIVE]
	var selected: Variant = WeightedRandom.roll_weighted(
		pools, Callable(self, "_pool_weight").bind(threat_level), rng
	)
	if selected == null:
		return null
	var pool_modifiers := _pool_modifiers(int(selected))
	if pool_modifiers.is_empty():
		return null
	return pool_modifiers.pick_random()


func _pool_modifiers(pool: int) -> Array[LeverModifierBehavior]:
	match pool:
		Pool.POSITIVE:
			return positive_modifiers
		Pool.NEGATIVE:
			return negative_modifiers
		_:
			return []


func _pool_weight(pool: int, threat_level: int) -> float:
	return maxf(get_pool_weight(pool, threat_level), 0.0)
