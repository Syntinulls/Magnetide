extends RigidBody2D
class_name SalvageItem

signal fell_off_screen(item: SalvageItem)

var item_data: SalvageItemData = null
var _is_attached_to_magnet: bool = false
var _magnet_target: Node2D = null
var _magnet_pull_force: float = 800.0
var _is_falling: bool = false
var _is_in_magnet_field: bool = false  # True when inside magnet's gravity field
var _sprite: Sprite2D = null
var _collision_shape: CollisionShape2D = null
var _settle_timer: float = 0.0
const SETTLE_TIME: float = 0.05  # Time to wait before considering item settled (very fast)

## Size of the item hitbox in pixels, from item data hitbox_size.
var hitbox_size: Vector2:
	get:
		if item_data:
			return item_data.hitbox_size
		return Vector2(40.0, 40.0)


func _ready() -> void:
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	
	# Collision setup: layer 2 = salvage items, mask 2+4 = other items + magnet body
	collision_layer = 2
	collision_mask = 2 | 4  # Collide with other items (2) and magnet body (4)
	
	_sprite = Sprite2D.new()
	_sprite.centered = true
	add_child(_sprite)
	
	_collision_shape = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = minf(hitbox_size.x, hitbox_size.y) * 0.5
	_collision_shape.shape = shape
	add_child(_collision_shape)


func setup(data: SalvageItemData) -> void:
	item_data = data
	
	if _sprite:
		if data.sprite:
			_sprite.texture = data.sprite
			# Scale sprite to fit within the item's area
			var tex_size := data.sprite.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				var scale_x := data.area.x / tex_size.x
				var scale_y := data.area.y / tex_size.y
				var uniform_scale := minf(scale_x, scale_y)
				_sprite.scale = Vector2(uniform_scale, uniform_scale)
		else:
			_create_placeholder_sprite()
	
	if _collision_shape and _collision_shape.shape is CircleShape2D:
		(_collision_shape.shape as CircleShape2D).radius = minf(hitbox_size.x, hitbox_size.y) * 0.5


func _create_placeholder_sprite() -> void:
	if not item_data:
		return
	var size := hitbox_size
	var img := Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	var color: Color = SalvagePile.RARITY_COLORS.get(item_data.rarity, Color.WHITE)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	_sprite.texture = tex


func start_magnet_pull(magnet: Node2D, pull_force: float) -> void:
	_magnet_target = magnet
	_magnet_pull_force = pull_force
	_is_attached_to_magnet = false
	_is_falling = false
	gravity_scale = 0.0
	freeze = false


func enter_magnet_field() -> void:
	_is_in_magnet_field = true
	_settle_timer = 0.0


func attach_to_magnet() -> void:
	if _is_attached_to_magnet:
		return
	_is_attached_to_magnet = true
	# Use kinematic freeze to maintain collision but stop movement
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector2.ZERO
	# Reparent to magnet so item moves with ship
	if _magnet_target:
		var local_pos := global_position - _magnet_target.global_position
		reparent(_magnet_target)
		position = local_pos


func release_from_magnet() -> void:
	_is_attached_to_magnet = false
	_is_in_magnet_field = false
	_is_falling = true
	_settle_timer = 0.0
	
	# Reset freeze state - order matters: set mode first, then unfreeze
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = false
	
	# Reparent back to scene root so item falls independently
	var scene_root := get_tree().current_scene
	if scene_root and get_parent() != scene_root:
		var pos := global_position
		reparent(scene_root)
		global_position = pos
	
	_magnet_target = null
	gravity_scale = 1.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0


func _physics_process(delta: float) -> void:
	if _is_falling:
		_check_off_screen()
		return
	
	if _is_attached_to_magnet:
		return
	
	if _magnet_target:
		var to_magnet := _magnet_target.global_position - global_position
		var distance := to_magnet.length()
		var direction := to_magnet.normalized()
		
		if _is_in_magnet_field:
			# Inside magnet field - strong snap to magnet with heavy damping
			var snap_force := _magnet_pull_force * 4.0
			apply_central_force(direction * snap_force)
			
			# Scale damping, velocity threshold, and settle time by distance
			# Closer to magnet = more damping, higher velocity threshold, faster settle
			var magnet_radius := 50.0  # Approximate magnet collision radius
			var proximity := clampf(1.0 - (distance - magnet_radius) / 200.0, 0.0, 1.0)
			
			# Damping: 0.95 far away, 0.7 when close
			var damping := lerpf(0.95, 0.7, proximity)
			linear_velocity *= damping
			
			# Velocity threshold: 30 far away, 150 when close (freeze at higher speeds when near)
			var velocity_threshold := lerpf(30.0, 150.0, proximity)
			
			# Settle time: 0.2s far away, 0.02s when close
			var settle_time := lerpf(0.2, 0.02, proximity)
			
			# Check if item has settled
			if linear_velocity.length() < velocity_threshold:
				_settle_timer += delta
				if _settle_timer >= settle_time:
					attach_to_magnet()
			else:
				_settle_timer = 0.0
		else:
			# Outside magnet field - pull increases rapidly as item gets closer
			# Use inverse cube for faster ramp-up (stronger when closer)
			var max_distance := 400.0  # Distance at which pull is weakest
			var normalized_dist := clampf(distance / max_distance, 0.05, 1.0)
			# Inverse cube relationship: much faster ramp-up as item approaches
			var pull_multiplier := 1.0 / (normalized_dist * normalized_dist * normalized_dist)
			var force := direction * _magnet_pull_force * pull_multiplier * 0.3
			apply_central_force(force)
			# Minimal damping so items accelerate quickly
			linear_velocity *= 0.99


func _check_off_screen() -> void:
	var screen_height := get_viewport().get_visible_rect().size.y
	if global_position.y > screen_height + 100.0:
		fell_off_screen.emit(self)
		queue_free()
