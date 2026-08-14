extends Node2D
class_name StatusEffect

## Timed status effect attached to a combatant. The effect lives as a direct child
## of its receiver, ticks itself every tick_interval, and frees itself when its
## rolled duration runs out. Applying an effect the receiver already carries (same
## effect_id) refreshes the existing effect's timer instead of stacking a copy.

## Identity used to match an incoming effect against one already on the receiver.
@export var effect_id: StringName = &""
## Player-facing name used in weapon tooltips ("Applies burning to enemies").
## Falls back to effect_id when empty.
@export var display_name: String = ""
## Unique tint for this effect's name in tooltips (burning = orange).
@export var display_color: Color = Color.WHITE
## Seconds between _apply_tick() calls. The first tick lands one interval after
## the effect attaches.
@export var tick_interval: float = 1.0
## Duration is rolled once per application (and per refresh) in
## [duration_min, duration_max].
@export var duration_min: float = 6.0
@export var duration_max: float = 8.0

## The node this effect is attached to (its parent).
var receiver: Node2D = null
## Originator of the effect (the player for weapon-applied effects); forwarded as
## the damage source so enemy target-switching reacts as it would to a direct hit.
var source: Node = null

var _remaining: float = 0.0
var _tick_elapsed: float = 0.0
var _expired: bool = false


## Entry point: attach this effect to target, or refresh the matching effect
## already there. When refreshing, this incoming instance discards itself.
func apply_to(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	for child in target.get_children():
		var existing := child as StatusEffect
		if existing != null and existing.effect_id == effect_id and not existing._expired:
			existing.refresh()
			queue_free()
			return
	position = Vector2.ZERO
	target.add_child(self)


func refresh() -> void:
	_remaining = _roll_duration()
	_on_refreshed()


func _ready() -> void:
	receiver = get_parent() as Node2D
	_remaining = _roll_duration()
	# Ending on death keeps effect visuals from riding the enemy's death pop.
	if receiver != null and receiver.has_signal(&"died"):
		receiver.connect(&"died", _expire)
	_on_started()


func _process(delta: float) -> void:
	var interval := maxf(tick_interval, 0.01)
	_tick_elapsed += delta
	while _tick_elapsed >= interval:
		_tick_elapsed -= interval
		_apply_tick()
	_remaining -= delta
	if _remaining <= 0.0:
		_expire()


## Ends the effect exactly once: stops ticking and hands teardown to _on_expired().
func _expire() -> void:
	if _expired:
		return
	_expired = true
	set_process(false)
	_on_expired()


func _roll_duration() -> float:
	return randf_range(duration_min, maxf(duration_max, duration_min))


# -- Overridable hooks -------------------------------------------------------

## Applies one tick of the effect to the receiver.
func _apply_tick() -> void:
	pass


## Called once when the effect first attaches to its receiver.
func _on_started() -> void:
	pass


## Called when a re-application refreshed this effect's duration.
func _on_refreshed() -> void:
	pass


## Teardown at expiry (or receiver death). Default frees immediately; override to
## fade visuals out first — the override owns calling queue_free() when done.
func _on_expired() -> void:
	queue_free()
