extends RefCounted
class_name RunArtifactTracker

## Per-run artifact caps (Step 3 of the salvage loot & artifact rework —
## see specs/salvage_loot_pool_system_spec.md).
##
## A run may collect a limited number of artifacts of each rarity; the cap itself is authored on
## SalvagePileData and passed in, so this only counts what has been banked. An artifact counts as
## "collected" when it is placed into the ship's storage — not when rolled/pulled/held — so the
## owning code (run controller / storage placement path) calls mark_collected() at that moment.
## Owned at the run level and reset on run start; persists across piles for the whole run.

var _collected: Dictionary = {}   # rarity_index (int) -> artifacts collected this run


## True while this artifact rarity is still under its per-run cap.
func can_pull(rarity: int, max_per_rarity: int) -> bool:
	return get_collected_count(rarity) < max_per_rarity


## Artifacts of this rarity already banked this run.
func get_collected_count(rarity: int) -> int:
	return int(_collected.get(rarity, 0))


## Count one artifact of this rarity against the per-run cap. Call when the artifact is placed
## into ship storage.
func mark_collected(rarity: int) -> void:
	_collected[rarity] = get_collected_count(rarity) + 1


## Clear all collected artifacts (call on run start).
func reset() -> void:
	_collected.clear()
