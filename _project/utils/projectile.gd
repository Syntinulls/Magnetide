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

var direction: Vector2 = Vector2.RIGHT
var source: Node = null

var _remaining_pierce: int = 1
var _damaged_targets: Array[Node] = []


static func create(config: Dictionary) -> Area2D:
	var projectile := (load("res://_project/utils/projectile.gd") as Script).new() as Area2D
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
	pierce = int(config.get(&"pierce", 1))
	_build_visual(config[&"sprite"])
	_build_collision()


func _ready() -> void:
	_remaining_pierce = maxi(pierce, 1)
	rotation = direction.angle() + PI / 2.0
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	var timer := get_tree().create_timer(maxf(lifetime, 0.01))
	timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _validate_config(config: Dictionary) -> void:
	for field in REQUIRED_CONFIG_FIELDS:
		assert(config.has(field), "Projectile config missing required field: %s" % String(field))


func _build_visual(sprite_value: Variant) -> void:
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
	add_child(sprite)


func _build_collision() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32.0, 12.0)
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
	if _damaged_targets.has(target):
		return
	if not receiver.has_method("take_damage"):
		return

	receiver.call("take_damage", damage, source)
	_damaged_targets.append(target)
	_remaining_pierce -= 1
	if _remaining_pierce <= 0:
		queue_free()
