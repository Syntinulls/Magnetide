extends Area2D
class_name GrenadeExplosion

## An instantaneous area-of-effect blast: on spawn it deals a single hit of damage to
## every enemy overlapping its circle, plays the explosion animation once, then frees
## itself. The blast circle (CollisionShape2D) and target layer (collision_mask) are
## authored on this scene; the spawning projectile hands in its damage and source.

## Fallback damage; overridden by the spawning weapon's damage through configure().
@export var damage: float = 20.0

var source: Node = null

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _sprite: AnimatedSprite2D = $Sprite


func configure(config: Dictionary) -> void:
	damage = float(config.get(&"damage", damage))
	source = config.get(&"source", null) as Node


func _ready() -> void:
	_scale_sprite_to_blast()
	_play_animation()
	_apply_area_damage()


## Radius of the authored blast circle, the single source of truth for the effect's size.
func _get_blast_radius() -> float:
	if _collision_shape and _collision_shape.shape is CircleShape2D:
		return (_collision_shape.shape as CircleShape2D).radius
	return 0.0


## Scales the animation so its visible blast roughly matches the damage radius.
func _scale_sprite_to_blast() -> void:
	if not _sprite or not _sprite.sprite_frames:
		return
	var blast_radius := _get_blast_radius()
	if blast_radius <= 0.0:
		return
	var frame_texture := _sprite.sprite_frames.get_frame_texture(_sprite.animation, 0)
	if frame_texture == null:
		return
	var half_width := frame_texture.get_size().x * 0.5
	if half_width > 0.0:
		var uniform_scale := blast_radius / half_width
		_sprite.scale = Vector2(uniform_scale, uniform_scale)


func _play_animation() -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"explode"):
		_sprite.play(&"explode")
		_sprite.animation_finished.connect(queue_free)
	else:
		queue_free()


## Deals a single hit to every distinct enemy inside the blast. Uses an immediate physics
## shape query rather than Area2D overlap (which only populates after a physics frame) so
## the damage lands the instant the explosion appears. De-duplicated by target so an enemy
## with several hitboxes is only hit once.
func _apply_area_damage() -> void:
	var blast_radius := _get_blast_radius()
	if blast_radius <= 0.0:
		return
	var circle := CircleShape2D.new()
	circle.radius = blast_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hit_targets := {}
	for result in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var collider := result.get("collider") as Node
		if collider == null:
			continue
		var target: Node = collider
		if collider.has_method("get_target_owner"):
			target = collider.call("get_target_owner")
		if target == null or target == source:
			continue
		if hit_targets.has(target):
			continue
		hit_targets[target] = true
		if collider.has_method("take_damage"):
			collider.call("take_damage", damage, source)
		elif target.has_method("take_damage"):
			target.call("take_damage", damage, source)
