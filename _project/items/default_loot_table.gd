extends Node
class_name DefaultLootTable

## Creates a default loot table with placeholder items for testing.
## This will be replaced by proper .tres resources later.
static func create() -> LootTable:
	var table := LootTable.new()

	var scrap_metal := SalvageItemData.new()
	scrap_metal.item_name = "Scrap Metal"
	scrap_metal.value = 5
	scrap_metal.chance = 40.0
	scrap_metal.rarity = SalvagePile.Rarity.COMMON
	scrap_metal.weight = 1.0
	scrap_metal.min_threat_level = 0
	table.items.append(scrap_metal)

	var rusty_gear := SalvageItemData.new()
	rusty_gear.item_name = "Rusty Gear"
	rusty_gear.value = 10
	rusty_gear.chance = 25.0
	rusty_gear.rarity = SalvagePile.Rarity.COMMON
	rusty_gear.weight = 1.5
	rusty_gear.min_threat_level = 0
	table.items.append(rusty_gear)

	var copper_wire := SalvageItemData.new()
	copper_wire.item_name = "Copper Wire"
	copper_wire.value = 20
	copper_wire.chance = 15.0
	copper_wire.rarity = SalvagePile.Rarity.RARE
	copper_wire.weight = 0.5
	copper_wire.min_threat_level = 0
	table.items.append(copper_wire)

	var engine_part := SalvageItemData.new()
	engine_part.item_name = "Engine Part"
	engine_part.value = 50
	engine_part.chance = 10.0
	engine_part.rarity = SalvagePile.Rarity.RARE
	engine_part.weight = 3.0
	engine_part.min_threat_level = 0
	table.items.append(engine_part)

	var power_cell := SalvageItemData.new()
	power_cell.item_name = "Power Cell"
	power_cell.value = 100
	power_cell.chance = 7.0
	power_cell.rarity = SalvagePile.Rarity.EPIC
	power_cell.weight = 2.0
	power_cell.min_threat_level = 0
	table.items.append(power_cell)

	var nav_module := SalvageItemData.new()
	nav_module.item_name = "Navigation Module"
	nav_module.value = 250
	nav_module.chance = 3.0
	nav_module.rarity = SalvagePile.Rarity.LEGENDARY
	nav_module.weight = 4.0
	nav_module.min_threat_level = 0
	table.items.append(nav_module)

	return table
