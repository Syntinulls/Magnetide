extends StatusEffect
class_name BurningEffect

## Damage-over-time burn. Deals a fixed chunk of damage each tick and dresses the
## receiver in looping flame sprites that cycle: ignite at a random spot, grow,
## burn a moment, shrink to nothing, re-ignite elsewhere. Expiry (or receiver
## death) fades the flames out before freeing.

## Damage dealt to the receiver on each tick.
@export var damage_per_tick: float = 2.0
## Number of flame sprites cycling on the receiver at once.
@export var flame_count: int = 5
## Fallback ignite radius, used only when the receiver exposes no hitbox to
## derive the spawn area from.
@export var flame_offset_radius: float = 14.0
## Full-grown flame scale.
@export var flame_max_scale: float = 1.0
@export var flame_grow_time: float = 0.2
@export var flame_shrink_time: float = 0.15
## Each flame tints from start to end color over its own ignite->fade cycle.
@export var flame_color_start: Color = Color(1.0, 0.85, 0.3)
@export var flame_color_end: Color = Color(1.0, 0.5, 0.1)

var _flames: Array[AnimatedSprite2D] = []
var _flame_tweens: Array[Tween] = []
var _flame_extents: Vector2 = Vector2.ZERO

@onready var _flame_template: AnimatedSprite2D = $FlameTemplate


func _apply_tick() -> void:
	if receiver != null and receiver.has_method("take_damage"):
		receiver.call("take_damage", damage_per_tick, source)


func _on_started() -> void:
	_flame_extents = _resolve_flame_extents()
	for index in flame_count:
		var flame := _flame_template.duplicate() as AnimatedSprite2D
		flame.visible = true
		add_child(flame)
		_flames.append(flame)
		_flame_tweens.append(null)
		# Staggered starts so the flames don't pulse in sync.
		_cycle_flame(index, randf_range(0.0, flame_grow_time))


func _on_expired() -> void:
	for tween in _flame_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	if _flames.is_empty():
		queue_free()
		return
	var fade := create_tween().set_parallel(true)
	for flame in _flames:
		fade.tween_property(flame, "scale", Vector2.ZERO, flame_shrink_time)
	fade.chain().tween_callback(queue_free)


## One life of a single flame: ignite at a random offset/rotation, grow, burn for
## a moment, shrink to nothing, then re-ignite. Tints from flame_color_start to
## flame_color_end across the cycle. Loops until the effect expires.
func _cycle_flame(index: int, delay: float = 0.0) -> void:
	if _expired:
		return
	var flame := _flames[index]
	flame.scale = Vector2.ZERO
	flame.modulate = flame_color_start
	flame.position = _random_offset()
	flame.rotation = randf() * TAU
	flame.frame = randi() % maxi(flame.sprite_frames.get_frame_count(flame.animation), 1)
	var hold_time := randf_range(0.25, 0.6)
	var cycle_time := flame_grow_time + hold_time + flame_shrink_time
	var tween := create_tween().set_parallel(true)
	_flame_tweens[index] = tween
	tween.tween_property(flame, "scale", Vector2.ONE * flame_max_scale, flame_grow_time) \
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(flame, "scale", Vector2.ZERO, flame_shrink_time) \
		.set_delay(delay + flame_grow_time + hold_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(flame, "modulate", flame_color_end, cycle_time).set_delay(delay)
	tween.chain().tween_callback(_cycle_flame.bind(index))


## Flames spawn across the receiver's hitbox rectangle so they cover the enemy;
## falls back to a small circle when no hitbox is exposed.
func _resolve_flame_extents() -> Vector2:
	if receiver != null and receiver.has_method("get_hitbox"):
		var hitbox := receiver.call("get_hitbox") as Node
		if hitbox != null:
			for child in hitbox.get_children():
				var collision_shape := child as CollisionShape2D
				if collision_shape != null and collision_shape.shape is RectangleShape2D:
					return (collision_shape.shape as RectangleShape2D).size * 0.5
	return Vector2.ONE * flame_offset_radius


func _random_offset() -> Vector2:
	return Vector2(
		randf_range(-_flame_extents.x, _flame_extents.x),
		randf_range(-_flame_extents.y, _flame_extents.y)
	)
