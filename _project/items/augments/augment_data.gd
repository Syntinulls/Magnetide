extends UpgradeableItemData
class_name AugmentData

@export var behavior: AugmentBehavior = null
@export var owner_tags: Array[StringName] = []


func get_current_effect_summary(state: Resource) -> String:
	var level := _get_state_level(state)
	if not _is_state_unlocked(state):
		return "Locked"
	if behavior != null:
		var summary := behavior.get_current_effect_summary(level)
		if not summary.is_empty():
			return summary
	return super(state)


func get_next_level_gain_summary(state: Resource) -> String:
	var level := _get_state_level(state)
	if not _is_state_unlocked(state):
		return ""
	if behavior != null:
		return behavior.get_next_level_gain_summary(level, max_level)
	return super(state)
