extends RefCounted
class_name RunArtifactTracker

## Per-run artifact caps (Step 3 of the salvage loot & artifact rework —
## see specs/salvage_loot_pool_system_spec.md).
##
## A run may collect at most one artifact of each rarity (1 common, 1 rare, 1 epic). A rarity is
## "collected" when its artifact is placed into the ship's storage — not when rolled/pulled/held —
## so the owning code (run controller / storage placement path) calls mark_collected() at that
## moment. Owned at the run level and reset on run start; persists across piles for the whole run.

var _collected: Dictionary = {}   # rarity_index (int) -> true


## True if this artifact rarity has not yet been collected this run.
func can_pull(rarity: int) -> bool:
	return not _collected.has(rarity)


## Mark an artifact rarity as collected (commits the per-run cap). Call when the artifact is placed
## into ship storage.
func mark_collected(rarity: int) -> void:
	_collected[rarity] = true


## True if this artifact rarity has already been collected this run.
func is_collected(rarity: int) -> bool:
	return _collected.has(rarity)


## Clear all collected artifacts (call on run start).
func reset() -> void:
	_collected.clear()
