extends Area2D
class_name Projectile

const REQUIRED_CONFIG_FIELDS: Array[StringName] = [
	&"global_position",
	&"direction",
	&"sprite",
	&"damage",
	&"speed",
	&"lifetime",
	&"collision_layer",
	&"collision_mask",
	&"source",
]

@export var speed: float = 600.0
@export var lifetime: float = 3.0
@export var damage: float = 10.0
@export var pierce: int = 1:
	set(value):
		pierce = maxi(value, 1)
		_remaining_pierce = pierce
## Downward acceleration (px/s^2). 0 keeps the projectile on a straight line; a
## positive value gives it a ballistic arc (grenades, lobbed shots).
@export var projectile_gravity: float = 0.0
## When true, striking an enemy deals this projectile's damage (and consumes pierce).
## Turn it off for projectiles whose damage comes entirely from their impact effect —
## the grenade, where only the explosion hurts.
@export var impact_damage: bool = true
## When false, exhausting pierce stops further damage but does not destroy the
## projectile — it flies on until its lifetime expires (flame puffs). Pierce still
## caps how many enemies the projectile can damage.
@export var destroy_on_contact: bool = true

var direction: Vector2 = Vector2.RIGHT
var source: Node = null
## Shooter movement velocity at fire time, added on top of the projectile's own
## motion for the whole flight so shots inherit the shooter's momentum.
var inherited_velocity: Vector2 = Vector2.ZERO
## The sprite child (Sprite2D or AnimatedSprite2D), exposed so a ProjectileBehavior
## can scale/modulate/spin it over the projectile's lifetime.
var visual: Node2D = null

var _remaining_pierce: int = 1
var _damaged_targets: Array[Node] = []
var _velocity: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _detonated: bool = false
var _collision_size: Vector2 = Vector2(32.0, 12.0)
## Optional effect scene spawned at the point of impact (e.g. an explosion). It owns its
## own area/animation and any AoE damage; the projectile just hands it this projectile's
## damage and source. Spawning it consumes the projectile.
var _impact_effect: PackedScene = null
## Optional status effect scene (StatusEffect root) applied to each enemy this
## projectile damages. Unlike _impact_effect, this never consumes the projectile.
var _contact_effect: PackedScene = null
## Motion/tick strategy; a per-projectile duplicate of the authored resource.
var _behavior: ProjectileBehavior = null
## Optional material applied to the visual (e.g. the glow shader on flames).
var _visual_material: Material = null


static func create(config: Dictionary) -> Area2D:
	var projectile := (load("res://_project/combat/projectile.gd") as Script).new() as Area2D
	projectile.configure(config)
	return projectile


static func spawn(parent: Node, config: Dictionary) -> Area2D:
	if parent == null:
		push_error("Projectile.spawn requires a parent node.")
		return null
	var projectile := create(config)
	parent.add_child(projectile)
	return projectile


func configure(config: Dictionary) -> void:
	_validate_config(config)
	global_position = config[&"global_position"]
	direction = (config[&"direction"] as Vector2).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	damage = float(config[&"damage"])
	speed = float(config[&"speed"])
	lifetime = float(config[&"lifetime"])
	collision_layer = int(config[&"collision_layer"])
	collision_mask = int(config[&"collision_mask"])
	source = config[&"source"] as Node
	inherited_velocity = config.get(&"inherited_velocity", Vector2.ZERO)
	pierce = int(config.get(&"pierce", 1))
	projectile_gravity = float(config.get(&"gravity", 0.0))
	impact_damage = bool(config.get(&"impact_damage", true))
	destroy_on_contact = bool(config.get(&"destroy_on_contact", true))
	_impact_effect = config.get(&"impact_effect", null) as PackedScene
	_contact_effect = config.get(&"contact_effect", null) as PackedScene
	_collision_size = config.get(&"collision_size", Vector2(32.0, 12.0))
	var behavior_value := config.get(&"projectile_behavior", null) as ProjectileBehavior
	_behavior = behavior_value.duplicate() as ProjectileBehavior if behavior_value != null else null
	_visual_material = config.get(&"visual_material", null) as Material
	_build_visual(config[&"sprite"])
	_build_collision()


func _ready() -> void:
	_remaining_pierce = maxi(pierce, 1)
	_velocity = direction * speed + inherited_velocity
	rotation = direction.angle() + PI / 2.0
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if _behavior != null:
		_behavior.setup(self)


func _physics_process(delta: float) -> void:
	# Lifetime is tracked per-frame (not a one-shot timer) so the behavior hooks
	# receive the projectile's elapsed age.
	_elapsed += delta
	if _elapsed >= maxf(lifetime, 0.01):
		queue_free()
		return
	if projectile_gravity != 0.0:
		_velocity.y += projectile_gravity * delta
		position += _velocity * delta
		rotation = _velocity.angle() + PI / 2.0
	elif _behavior != null:
		position += (_behavior.get_velocity(self, _elapsed) + inherited_velocity) * delta
	else:
		position += (direction * speed + inherited_velocity) * delta
	if _behavior != null:
		_behavior.tick(self, _elapsed, delta)


func _validate_config(config: Dictionary) -> void:
	for field in REQUIRED_CONFIG_FIELDS:
		assert(config.has(field), "Projectile config missing required field: %s" % String(field))


func _build_visual(sprite_value: Variant) -> void:
	if sprite_value is SpriteFrames:
		var frames := sprite_value as SpriteFrames
		var animated := AnimatedSprite2D.new()
		animated.name = "Visual"
		animated.sprite_frames = frames
		var animation_names := frames.get_animation_names()
		if animation_names.size() > 0:
			animated.play(animation_names[0])
		animated.material = _visual_material
		visual = animated
		add_child(animated)
		return
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	if sprite_value is Texture2D:
		sprite.texture = sprite_value
	elif sprite_value is Sprite2D:
		var sprite_template := sprite_value as Sprite2D
		sprite.texture = sprite_template.texture
		sprite.region_enabled = sprite_template.region_enabled
		sprite.region_rect = sprite_template.region_rect
		sprite.modulate = sprite_template.modulate
	sprite.material = _visual_material
	visual = sprite
	add_child(sprite)


func _build_collision() -> void:
	var shape := RectangleShape2D.new()
	shape.size = _collision_size
	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	collision_shape.shape = shape
	add_child(collision_shape)


func _on_body_entered(body: Node) -> void:
	if body == source:
		return
	if body.has_method("get_hitbox") and body.get_hitbox() != null:
		return
	_apply_damage_to(body, body)


func _on_area_entered(area: Area2D) -> void:
	if area == source:
		return
	var target: Node = area
	if area.has_method("get_target_owner"):
		target = area.get_target_owner()
	if target == source:
		return
	_apply_damage_to(area, target)


func _apply_damage_to(receiver: Node, target: Node) -> void:
	if receiver == null or target == null:
		return
	# Only damageable targets (enemy hitboxes) count as an impact. Solid world colliders
	# that merely share the projectile's collision layer — the magnet's body — are passed
	# through, so a grenade doesn't detonate on the ship's own structures.
	if not receiver.has_method("take_damage"):
		return
	if _damaged_targets.has(target):
		return
	# Pierce caps how many enemies this projectile may damage even when it is not
	# destroyed on contact: once spent, it flies on inert until its lifetime ends.
	if impact_damage and _remaining_pierce <= 0:
		return
	_damaged_targets.append(target)

	if impact_damage:
		receiver.call("take_damage", damage, source)
		_remaining_pierce -= 1
		if _contact_effect != null:
			_apply_contact_effect(target)

	# An impact effect consumes the projectile on the first enemy it touches, regardless
	# of pierce (the explosion, not the projectile, carries the payload).
	if _impact_effect != null:
		_spawn_impact_effect()
		queue_free()
		return

	if impact_damage and _remaining_pierce <= 0 and destroy_on_contact:
		queue_free()


## Instantiates the contact effect and hands it to the enemy just damaged. The effect
## attaches to (or refreshes on) the target and lives there on its own; the projectile
## is never consumed by it.
func _apply_contact_effect(target: Node) -> void:
	var target_node := target as Node2D
	if target_node == null:
		return
	var instance := _contact_effect.instantiate()
	var effect := instance as StatusEffect
	if effect == null:
		instance.free()
		return
	effect.source = source
	effect.apply_to(target_node)


## Instantiates the impact effect (e.g. an explosion) at the current position. The effect
## owns its own area-of-effect damage and animation; the projectile only hands it this
## projectile's damage and source. Guarded so overlapping hits spawn a single effect.
func _spawn_impact_effect() -> void:
	if _detonated:
		return
	_detonated = true
	var parent := get_parent()
	if _impact_effect == null or parent == null:
		return
	var effect := _impact_effect.instantiate()
	# Position and configure before add_child: adding to the tree runs the effect's
	# _ready() synchronously, and it reads both to place and power its blast.
	if effect is Node2D:
		(effect as Node2D).global_position = global_position
	if effect.has_method("configure"):
		effect.call("configure", {
			&"damage": damage,
			&"source": source,
		})
	parent.add_child(effect)
