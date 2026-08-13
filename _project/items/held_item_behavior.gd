extends Resource
class_name HeldItemBehavior

## Strategy + runtime state for one equipped hotbar item. The item's data class
## creates one live instance per hotbar slot (HeldItemData.create_use_behavior →
## PlayerEquipment), so each slot keeps its own state — ammo, held item, repair
## progress — across equipment switches. Authored .tres resources hold tuning;
## instances of this class hold what changes at runtime.

var player: Player = null
var data: HeldItemData = null


func setup(for_player: Player, for_data: HeldItemData) -> void:
	player = for_player
	data = for_data


## This slot became the selected equipment.
func equipped() -> void:
	pass


## The player switched away. Transient effects stop; slot state persists so it
## can resume on reselect.
func unequipped() -> void:
	pass


## Per-physics-frame input handling while selected and player input is available.
func process_input(_delta: float) -> void:
	pass


## Per-physics-frame tick while selected but input is blocked (cutscene, UI
## capture). Behaviors that render a continuous effect drop it here.
func process_blocked(_delta: float) -> void:
	pass


## The player's facing flipped while this behavior is selected.
func facing_changed() -> void:
	pass


## World item currently carried by this behavior (magnet gun), or null.
func get_held_item() -> SalvageItem:
	return null


## The looting phase ended: clear transient hover state, keep carried items.
func on_looting_ended() -> void:
	pass


## Run teardown: stop everything, including state that unequipped() preserves.
func on_run_end() -> void:
	unequipped()
