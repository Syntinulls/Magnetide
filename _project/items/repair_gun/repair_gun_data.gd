extends HeldItemData
class_name RepairGunData

## Ship integrity restored per completed repair cycle (raw units, capped at max integrity)
@export var repair_amount: float = 10.0
## Repair cycles per second; drives the "Repairing" progress bar speed
@export var repair_rate: float = 0.5
## In-run scrap metal consumed per completed repair cycle
@export var repair_cost: int = 1
## Raycast distance from the muzzle to a repairable surface
@export var beam_range: float = 520.0


func create_use_behavior() -> HeldItemBehavior:
	return RepairGunBehavior.new()
