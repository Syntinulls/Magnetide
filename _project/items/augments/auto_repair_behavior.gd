extends AugmentBehavior
class_name AutoRepairBehavior

## Spends in-run scrap to instantly restore ship integrity on a fixed cooldown, whenever the
## hull is damaged and the run's scrap pool covers the cost. The cooldown keeps charging while
## those conditions block a repair, so a hit taken with a ready charge is patched immediately.

## Ship integrity restored per repair.
@export var repair_amount: float = 10.0
## In-run scrap metal consumed per repair.
@export var repair_cost: int = 1
## Seconds between repairs — the level-0 value, upgraded in place by the augment's
## AugmentUpgradeData effects (target BEHAVIOR).
@export var cooldown_seconds: float = 6.0

var _ship: Ship = null
var _run: RunController = null
var _cooldown_elapsed: float = 0.0


func initialize_for_run(context: Dictionary, _level: int) -> void:
	cleanup_after_run()
	_ship = context.get("ship", null) as Ship
	_run = context.get("run_controller", null) as RunController


func cleanup_after_run() -> void:
	_ship = null
	_run = null
	_cooldown_elapsed = 0.0


func tick(delta: float) -> void:
	if _ship == null or not is_instance_valid(_ship) or _run == null or not is_instance_valid(_run):
		return
	var cooldown := maxf(cooldown_seconds, 0.0)
	_cooldown_elapsed = minf(_cooldown_elapsed + delta, cooldown)
	if _cooldown_elapsed < cooldown:
		return
	# A destroyed or full hull leaves the charge banked rather than spending scrap on nothing.
	if _ship.current_health <= 0.0 or _ship.current_health >= _ship.max_health:
		return
	var cost := maxi(repair_cost, 0)
	if cost > 0 and not _run.spend_scrap_metal(cost):
		return
	_cooldown_elapsed = 0.0
	_ship.repair(maxf(repair_amount, 0.0))


func get_current_effect_summary(_level: int) -> String:
	return "Repairs %s hull every %ss for %d scrap" % [
		Utils.format_number(maxf(repair_amount, 0.0)),
		Utils.format_number(maxf(cooldown_seconds, 0.0)),
		maxi(repair_cost, 0),
	]
