extends Node
class_name PlayerInteraction

## Generic bridge between the player and world interactables. The player side
## knows nothing about specific stations; each interactable owns its behavior
## and registers in a group:
##
## Drop targets (group "item_drop_targets") accept an item carried by the magnet
## gun and implement:
##   drop_priority: int                                   — higher wins on overlap
##   is_drop_point(point: Vector2) -> bool
##   can_accept_dropped_item(item: SalvageItem, point: Vector2) -> bool
##   get_drop_prompt_label(item: SalvageItem) -> String   — "" hides the prompt
##   update_drop_state(item, point: Vector2, is_active: bool)  — own highlight
##   clear_drop_state()
##   accept_dropped_item(player: Player, item, point: Vector2) -> Dictionary
##     returns { "accepted": bool, "regrab": SalvageItem or absent }
##
## Proximity interactables (group "proximity_interactables") react to the
## interact key while the player stands in range and implement:
##   can_proximity_interact(player_position: Vector2) -> bool
##   get_proximity_prompt_label() -> String
##   set_proximity_highlighted(enabled: bool)
##   proximity_interact(player: Player)
##
## The active prompt always highlights its interactable (and vice versa), since
## both are driven from the same target selection here.

const DROP_TARGET_GROUP := &"item_drop_targets"
const PROXIMITY_GROUP := &"proximity_interactables"

const DROP_PROMPT_SOURCE := &"place"
const PROXIMITY_PROMPT_SOURCE := &"proximity"

var _active_drop_target: Node = null
var _active_drop_label: String = ""
var _proximity_target: Node = null

@onready var _player: Player = owner as Player


## Per-frame while the magnet gun carries an anchored item: pick the accepting
## drop target under the cursor and let every target update its own visuals.
func update_carry(item: SalvageItem, point: Vector2) -> void:
	var candidate := _get_drop_target_at(point)
	var active := candidate if candidate != null and candidate.call("can_accept_dropped_item", item, point) else null

	for target in _get_drop_targets():
		target.call("update_drop_state", item, point, target == active)

	_active_drop_target = active
	_active_drop_label = String(active.call("get_drop_prompt_label", item)) if active else ""
	_update_drop_prompt()


## Prompt label of the accepting target under the cursor ("" when none).
func get_active_drop_label() -> String:
	return _active_drop_label


func clear_carry() -> void:
	for target in _get_drop_targets():
		target.call("clear_drop_state")
	_active_drop_target = null
	_active_drop_label = ""
	_update_drop_prompt()


## Resolve a place click. The topmost containing target wins outright: a click
## on a target that cannot accept the item is swallowed, never falling through
## to a lower target. Returns { "accepted": bool, "regrab": SalvageItem? }.
func try_drop(item: SalvageItem, point: Vector2) -> Dictionary:
	var target := _get_drop_target_at(point)
	if target == null or not target.call("can_accept_dropped_item", item, point):
		return {"accepted": false}
	var result: Dictionary = target.call("accept_dropped_item", _player, item, point)
	if result.get("accepted", false):
		clear_carry()
	return result


## Per-frame while not carrying: maintain the proximity prompt + highlight and
## fire the interaction on the interact key.
func process_proximity() -> void:
	var target: Node = null
	for candidate in _player.get_tree().get_nodes_in_group(PROXIMITY_GROUP):
		if candidate.call("can_proximity_interact", _player.global_position):
			target = candidate
			break
	_set_proximity_target(target)

	if _proximity_target and Input.is_action_just_pressed("interact"):
		var interact_target := _proximity_target
		_set_proximity_target(null)
		interact_target.call("proximity_interact", _player)


func clear_proximity() -> void:
	_set_proximity_target(null)


func _set_proximity_target(target: Node) -> void:
	if target == _proximity_target:
		_update_proximity_prompt()
		return
	if _proximity_target and is_instance_valid(_proximity_target):
		_proximity_target.call("set_proximity_highlighted", false)
	_proximity_target = target
	if _proximity_target:
		_proximity_target.call("set_proximity_highlighted", true)
	_update_proximity_prompt()


func _update_proximity_prompt() -> void:
	var prompts := Magnetide.control_prompts
	if prompts == null:
		return
	if _proximity_target and is_instance_valid(_proximity_target):
		prompts.set_prompt(PROXIMITY_PROMPT_SOURCE, "E", String(_proximity_target.call("get_proximity_prompt_label")), false, 3)
	else:
		prompts.clear_prompt(PROXIMITY_PROMPT_SOURCE)


func _update_drop_prompt() -> void:
	var prompts := Magnetide.control_prompts
	if prompts == null:
		return
	if _active_drop_label != "":
		prompts.set_prompt(DROP_PROMPT_SOURCE, "LMB", _active_drop_label, false, 2)
	else:
		prompts.clear_prompt(DROP_PROMPT_SOURCE)


func _get_drop_targets() -> Array[Node]:
	return _player.get_tree().get_nodes_in_group(DROP_TARGET_GROUP)


## Topmost (highest drop_priority) target containing the point.
func _get_drop_target_at(point: Vector2) -> Node:
	var best: Node = null
	var best_priority := -0x7FFFFFFF
	for target in _get_drop_targets():
		if not target.call("is_drop_point", point):
			continue
		var priority := int(target.get("drop_priority"))
		if priority > best_priority:
			best_priority = priority
			best = target
	return best
