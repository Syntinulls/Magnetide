extends UpgradeSlot
class_name DynamicUpgradeSlot

## An upgrade slot whose item is chosen at runtime from a catalog (e.g. the weapon slot, an
## augment slot). Clicking the icon opens the selection popup; the equipped entry supplies the
## live name/icon/upgrade. Its upgrade track lives on whichever catalog entry is equipped.

## Equip mechanism to dispatch on generically (e.g. &"weapon", &"player_augment").
@export var slot_kind: StringName = &""
## Which slot of its kind this is (e.g. player augment 0 vs 1). Passed to the equip call.
@export var slot_index: int = 0
## Title shown above the selection popup's item list (falls back to display_name).
@export var popup_title: String = ""
## Selectable items for this slot, each carrying its own item, upgrade, and unlock gating.
@export var catalog: Array[UpgradeCatalogEntry] = []
## Whether this slot may be emptied again. Augment slots author this true; the weapon slot
## leaves it false because a run cannot start without a weapon equipped.
@export var can_unequip: bool = false


func is_selectable() -> bool:
	return true


func allows_unequip() -> bool:
	return can_unequip

# A dynamic slot has no fixed upgrade id — its upgrade track comes from the equipped item's
# `upgrade_data` (resolved per item_id at runtime by the station), so it uses the base &"".
