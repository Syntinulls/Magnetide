extends ItemData
class_name StatItemData

## A static loadout stat modelled as an upgradeable item (player health, ship hull, magnet
## capacity, ...). Carries only identity; its upgrade_data's effects target loadout properties.
## Held by a static upgrade slot; progress is tracked per item_id like any other item.
