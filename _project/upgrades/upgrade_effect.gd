extends Resource
class_name UpgradeEffect

## One property changed by a RunUpgrade. A single upgrade can carry several of these so
## one upgrade level can affect multiple stats at once (e.g. weapon damage + magazine
## size). Each effect names its own target object and property, amount curve, and mode;
## the owning RunUpgrade supplies the current level (global, or per equipped item when the
## effect targets a weapon).

enum IncreaseMode { FLAT, PERCENT_OF_BASE }
## Which object this effect changes. PLAYER/SHIP/MAGNET are stats on the run loadout;
## WEAPON/MAGNET_GUN are stats on the equipped item; BEHAVIOR is a tunable on the owning
## augment's AugmentBehavior (which the behavior reads at runtime).
enum Target { PLAYER, SHIP, MAGNET, WEAPON, MAGNET_GUN, BEHAVIOR }

@export var target: Target = Target.PLAYER
## The exact variable/stat id changed on the target (e.g. &"player_speed", &"damage").
@export var target_property: StringName = &""
## Optional friendly label for gain text (e.g. "Shield Hit"). Falls back to a prettified
## target_property when empty.
@export var label: String = ""
## Flat amount added per level (used when level_amounts is empty).
@export var amount_per_level: float = 0.0
## Optional per-level amounts; when set, overrides amount_per_level.
@export var level_amounts: Array[float] = []
@export var increase_mode: IncreaseMode = IncreaseMode.FLAT


func get_total_amount_for_level(level: int, max_level: int) -> float:
	var clamped := clampi(level, 0, max_level)
	if not level_amounts.is_empty():
		var total := 0.0
		var count := mini(clamped, level_amounts.size())
		for index in range(count):
			total += level_amounts[index]
		return total
	return amount_per_level * float(clamped)


func get_value_for_level(base_value: Variant, level: int, max_level: int) -> Variant:
	if typeof(base_value) != TYPE_INT and typeof(base_value) != TYPE_FLOAT:
		return base_value
	var base_number := float(base_value)
	var total_amount := get_total_amount_for_level(level, max_level)
	var increase := total_amount
	if increase_mode == IncreaseMode.PERCENT_OF_BASE:
		increase = base_number * total_amount
	var upgraded_value := base_number + increase
	if typeof(base_value) == TYPE_INT:
		return int(round(upgraded_value))
	return upgraded_value


func get_delta_for_level(base_value: Variant, level: int, max_level: int) -> float:
	if typeof(base_value) != TYPE_INT and typeof(base_value) != TYPE_FLOAT:
		return 0.0
	return float(get_value_for_level(base_value, level, max_level)) - float(base_value)


## Next-level gain text for this one effect, e.g. "+5% Damage" or "+1 Magazine Size".
## Labels default to a humanized target_property when stat_name is empty.
func get_gain_text_for_level(stat_name: String, level: int, max_level: int) -> String:
	if level >= max_level:
		return ""
	var amount := amount_per_level
	if not level_amounts.is_empty():
		amount = level_amounts[clampi(level, 0, level_amounts.size() - 1)]
	var display_label := label
	if display_label.is_empty():
		display_label = stat_name if not stat_name.is_empty() else String(target_property).capitalize()
	var stat_suffix := "" if display_label.is_empty() else " %s" % display_label
	if increase_mode == IncreaseMode.PERCENT_OF_BASE:
		return "+%s%%%s" % [Utils.format_number(amount * 100.0), stat_suffix]
	return "+%s%s" % [Utils.format_number(amount), stat_suffix]
