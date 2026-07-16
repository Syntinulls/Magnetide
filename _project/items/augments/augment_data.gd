extends ItemData
class_name AugmentData

@export var behavior: AugmentBehavior = null
@export var owner_tags: Array[StringName] = []


func get_current_effect_summary(state: Resource) -> String:
	if not _is_state_unlocked(state):
		return "Locked"
	if behavior != null:
		var level := _get_state_level(state)
		var summary := _upgraded_behavior(level).get_current_effect_summary(level)
		if not summary.is_empty():
			return summary
	return super(state)


func get_next_level_gain_summary(state: Resource) -> String:
	var level := _get_state_level(state)
	if not _is_state_unlocked(state) or behavior == null or level >= get_max_level():
		return ""
	return "%s -> %s" % [
		_upgraded_behavior(level).get_current_effect_summary(level),
		_upgraded_behavior(level + 1).get_current_effect_summary(level + 1),
	]


## A copy of this augment's behavior with its upgrade_data BEHAVIOR effects applied at `level`, so
## the copy's tunables reflect that level. Returns the shared behavior when there is no upgrade_data.
func _upgraded_behavior(level: int) -> AugmentBehavior:
	if behavior == null:
		return null
	if upgrade_data == null:
		return behavior
	var upgraded := behavior.duplicate(true) as AugmentBehavior
	upgrade_data.apply_for_level(upgraded, behavior, level, UpgradeEffect.Target.BEHAVIOR)
	return upgraded
