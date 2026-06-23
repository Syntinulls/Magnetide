extends VBoxContainer
class_name ControlPromptStack

## Bottom-center host for in-world interaction prompts. Any interactable can
## register a prompt keyed by a source name; the stack renders one row per
## active source, stacked vertically (higher priority lower in the stack, nearest
## the player's focus). Registration is idempotent — re-setting unchanged data is
## cheap, so interactables can safely call set_prompt every frame while active.

# source (StringName) -> { key, action, hold, priority }
var _prompts: Dictionary = {}


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 12)


func set_prompt(source: StringName, key: String, action: String, hold: bool = false, priority: int = 0) -> void:
	var existing: Variant = _prompts.get(source)
	if existing != null \
			and existing.key == key and existing.action == action \
			and existing.hold == hold and existing.priority == priority:
		return
	_prompts[source] = {"key": key, "action": action, "hold": hold, "priority": priority}
	_rebuild()


func clear_prompt(source: StringName) -> void:
	if _prompts.erase(source):
		_rebuild()


func clear_all() -> void:
	if _prompts.is_empty():
		return
	_prompts.clear()
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	var sources := _prompts.keys()
	# Lower priority first (top), higher priority last (bottom, nearest focus).
	sources.sort_custom(func(a, b): return int(_prompts[a].priority) < int(_prompts[b].priority))

	for source in sources:
		var data: Dictionary = _prompts[source]
		var prompt := ControlPrompt.new()
		prompt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		prompt.configure(data.key, data.action, data.hold)
		add_child(prompt)
