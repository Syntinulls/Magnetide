extends ItemData
class_name StatItemData

## A static loadout stat modelled as an upgradeable item (player health, ship hull, magnet
## capacity, ...). Carries only identity; its upgrade_data's effects target loadout properties.
## Held by a static upgrade slot; progress is tracked per item_id like any other item.

## Extra run-loadout properties the station's hover readout should list for this stat,
## for a track whose value does not come from an authored upgrade effect (ship storage
## size grows through a hardcoded table, so its effects list is empty and the readout
## would otherwise have nothing to show). Leave empty when the effects already cover it.
@export var readout_properties: Array[StringName] = []
