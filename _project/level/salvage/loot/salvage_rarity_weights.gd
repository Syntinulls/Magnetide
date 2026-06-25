extends Resource
class_name SalvageRarityWeights

## Threat-scaled salvage rarity weights (Step 2 of the salvage loot & artifact rework —
## see specs/salvage_loot_pool_system_spec.md).
##
## Each salvage rarity's weight = base[i] + delta[i] * threat_level (uncapped, linear). The
## per-rarity delta is sampled from a concave inverse-tangent ease that rises from delta_min (COMMON)
## to delta_max (LEGENDARY), bunching the rarer tiers' deltas near delta_max so higher rarities scale
## faster in relative terms without ever overtaking the tier beneath them.
##
## Ordering invariant (P(COMMON) > P(RARE) > P(EPIC) > P(LEGENDARY) at every level): the base weights
## must satisfy, for each adjacent pair a (more common) and b (rarer):
##     base[a] - base[b] > (delta[b] - delta[a]) * (LEVEL_COUNT - 1)
## With LEVEL_COUNT = 10 the worst case is the last stage (index 9).

const TIER_COUNT: int = 4   # COMMON, RARE, EPIC, LEGENDARY (indices 0..3)

## Base weight per rarity at the stage it unlocks. Order: [COMMON, RARE, EPIC, LEGENDARY].
## Weight ramps up from this base starting at the rarity's min_stage (see get_rarity_weight).
@export var base_weights: PackedFloat32Array = PackedFloat32Array([100.0, 30.0, 18.0, 12.0])

## Minimum threat stage index (0-9) each rarity unlocks at. Below it the rarity is excluded
## (weight 0). COMMON/RARE = 0 (always), EPIC = 3 (threat 4), LEGENDARY = 6 (threat 7).
@export var min_stage: PackedInt32Array = PackedInt32Array([0, 0, 3, 6])

@export_group("Delta Curve")
## Per-level weight increase for the COMMON tier (curve floor / minimum).
@export var delta_min: float = 1.0
## Per-level weight increase for the LEGENDARY tier (curve top y-intercept / maximum).
@export var delta_max: float = 6.0
## Arctangent concavity. Larger = the rarer tiers' deltas bunch nearer delta_max (helps ordering).
@export var curve_sharpness: float = 3.0


## Per-level additive delta for a rarity, sampled from the concave inverse-tangent ease.
## Rises from delta_min (COMMON, u=0) to delta_max (LEGENDARY, u=1); rarer tiers bunch near delta_max.
func get_rarity_delta(rarity_index: int) -> float:
	var u := float(rarity_index) / float(TIER_COUNT - 1)   # COMMON->0.0 ... LEGENDARY->1.0
	var k := maxf(curve_sharpness, 0.0001)
	var shape := atan(k * u) / atan(k)                     # S(u): 0.0 at u=0 (common), 1.0 at u=1
	return delta_min + (delta_max - delta_min) * shape


## Weight for a rarity at a given threat stage index. Returns 0 while the rarity is still locked
## (below its min_stage); once unlocked it ramps linearly from base_weights at its unlock stage.
func get_rarity_weight(rarity_index: int, threat_level: int) -> float:
	var unlock := get_min_stage(rarity_index)
	if threat_level < unlock:
		return 0.0
	var base := base_weights[rarity_index] if rarity_index < base_weights.size() else 0.0
	return base + get_rarity_delta(rarity_index) * float(threat_level - unlock)


## Threat stage index (0-9) at which this rarity unlocks.
func get_min_stage(rarity_index: int) -> int:
	return min_stage[rarity_index] if rarity_index < min_stage.size() else 0


## True once the rarity is unlocked at the given threat stage index.
func is_unlocked(rarity_index: int, threat_level: int) -> bool:
	return threat_level >= get_min_stage(rarity_index)


## Weighted roll over the available rarities (curve-weighted). Returns a rarity index, or -1 if
## none are available / all weights are zero.
func roll_rarity(threat_level: int, available_rarities: Array[int]) -> int:
	if available_rarities.is_empty():
		return -1
	var selected: Variant = WeightedRandom.roll_weighted(
		available_rarities, Callable(self, "_roll_weight").bind(threat_level)
	)
	return int(selected) if selected != null else -1


func _roll_weight(rarity_index: int, threat_level: int) -> float:
	return maxf(get_rarity_weight(rarity_index, threat_level), 0.0)
