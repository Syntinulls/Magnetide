extends AugmentBehavior
class_name IncreasedRecyclingBehavior

## Gives the recycler a chance to pay out a completed scrap bundle twice.

## Effective double-bundle chance (percent) — the level-0 value, upgraded in place by the augment's
## AugmentUpgradeData effects (target BEHAVIOR).
@export var double_bundle_chance_percent: float = 25.0

var _recycler: Recycler = null


func initialize_for_run(context: Dictionary, _level: int) -> void:
	cleanup_after_run()
	_recycler = context.get("recycler", null) as Recycler
	if _recycler != null and is_instance_valid(_recycler):
		_recycler.double_bundle_chance_percent = maxf(double_bundle_chance_percent, 0.0)


func cleanup_after_run() -> void:
	if _recycler != null and is_instance_valid(_recycler):
		_recycler.double_bundle_chance_percent = 0.0
	_recycler = null


func get_current_effect_summary(_level: int) -> String:
	return "%s%% chance for a double scrap bundle" % Utils.format_number(
		maxf(double_bundle_chance_percent, 0.0)
	)
