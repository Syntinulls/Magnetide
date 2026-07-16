extends Resource
class_name UpgradeData

## Authored definition of how one item upgrades: its level cap, the per-level costs, and the
## per-level stat effects. Holds no progress — the current level lives in RunUpgrade state,
## keyed by the owning item's id. Referenced from ItemData.upgrade_data.

@export var display_name: String = ""
@export var max_level: int = 5:
	set(value):
		max_level = maxi(value, 1)
## Per-level cost; index i is the cost from level i to i+1.
@export var level_costs: Array[UpgradeLevelCost] = []
## The stat changes this upgrade applies per level. Author one or several so a single level can
## affect multiple stats/targets (player / ship / magnet / weapon / magnet gun / behavior).
@export var effects: Array[UpgradeEffect] = []


func is_maxed_at(level: int) -> bool:
	return level >= max_level


## Cost to go from `level` to `level + 1` (null if maxed or out of range).
func get_cost_for_level(level: int) -> UpgradeLevelCost:
	if level < 0 or level >= max_level:
		return null
	if level >= level_costs.size():
		return null
	return level_costs[level]


func get_display_name() -> String:
	return display_name if not display_name.is_empty() else "Upgrade"


## Combined next-level gain across every effect, e.g. "+5% Damage, +1 Magazine". With a single
## effect the caller's stat_name is used; with several, each effect labels itself.
func get_gain_text_for_level(stat_name: String, level: int) -> String:
	if is_maxed_at(level):
		return "MAX LEVEL"
	var parts := PackedStringArray()
	for effect in effects:
		var label := stat_name if effects.size() == 1 else ""
		var text := effect.get_gain_text_for_level(label, level, max_level)
		if not text.is_empty():
			parts.append(text)
	return ", ".join(parts)


## Applies the effects matching `effect_target` onto `target_resource`, reading base values from
## `base_resource`, for the given progress `level`.
func apply_for_level(target_resource: Object, base_resource: Object, level: int, effect_target: int) -> void:
	if target_resource == null or base_resource == null:
		return
	for effect in effects:
		if int(effect.target) != effect_target:
			continue
		var property_name := String(effect.target_property)
		if property_name.is_empty():
			continue
		if not Utils.has_property(base_resource, property_name) or not Utils.has_property(target_resource, property_name):
			continue
		var base_value: Variant = base_resource.get(property_name)
		var delta := effect.get_delta_for_level(base_value, level, max_level)
		var current_value: Variant = target_resource.get(property_name)
		if typeof(current_value) != TYPE_INT and typeof(current_value) != TYPE_FLOAT:
			continue
		var upgraded_value := float(current_value) + delta
		if typeof(base_value) == TYPE_INT:
			target_resource.set(property_name, int(round(upgraded_value)))
		else:
			target_resource.set(property_name, upgraded_value)
