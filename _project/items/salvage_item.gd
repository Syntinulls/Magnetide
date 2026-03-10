extends RigidBody2D
class_name SalvageItem

signal fell_off_screen(item: SalvageItem)

const SETTLE_TIME: float = 0.05
const STORAGE_COLLISION_LAYER: int = 8
const OUTLINE_SHADER: Shader = preload("res://_project/items/salvage_item_outline.gdshader")

var item_data: SalvageItemData = null
var _is_attached_to_magnet: bool = false
var _is_held_by_gun: bool = false
var _is_in_storage: bool = false
var _is_repelled: bool = false
var _magnet_target: Node2D = null
var _is_falling: bool = false
var _is_in_magnet_field: bool = false
var _sprite: Sprite2D = null
var _collision_shape: CollisionShape2D = null
var _settle_timer: float = 0.0
var _outline_material: ShaderMaterial = null
var _contacting_items: Array[SalvageItem] = []
var _gun_hold_target: Vector2 = Vector2.ZERO
var _gun_hold_velocity: Vector2 = Vector2.ZERO
var _is_flying_to_gun: bool = false  # True while traveling to anchor, false once tethered
var _pull_elapsed: float = 0.0  # Time spent being pulled (for speed ramp)

# Pull config from the magnet/gun pulling this item
var _pull_base_speed: float = 200.0
var _pull_max_speed: float = 1500.0
var _pull_ramp_time: float = 0.6

# Item-specific physics constants (independent of what's pulling)
const ITEM_PULL_DAMPING: float = 0.85
const ITEM_MAX_SPEED: float = 2000.0  # Absolute max speed cap
const PULL_ARRIVAL_THRESHOLD: float = 15.0  # Distance to consider "arrived"

# Tethered mode constants (when attached to magnet gun anchor)
const TETHER_SMOOTHING: float = 15.0
const TETHER_DAMPING: float = 0.85
const TETHER_MAX_SPEED: float = 400.0

var is_attached_to_magnet: bool:
	get:
		return _is_attached_to_magnet

var is_held_by_gun: bool:
	get:
		return _is_held_by_gun

var is_in_storage: bool:
	get:
		return _is_in_storage

## Returns true if the item has reached the magnet gun anchor and is tethered
var has_reached_anchor: bool:
	get:
		return _is_held_by_gun and not _is_flying_to_gun

## Returns true if this item can be grabbed by the magnet gun (attached or being pulled)
var can_be_grabbed: bool:
	get:
		return (_is_attached_to_magnet or _magnet_target != null) and not _is_held_by_gun and not _is_in_storage and not _is_falling and not _is_repelled

## Size of the item hitbox in pixels, from item data hitbox_size.
var hitbox_size: Vector2:
	get:
		if item_data:
			return item_data.hitbox_size
		return Vector2(40.0, 40.0)


func _ready() -> void:
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 8
	
	# Collision setup: layer 2 = salvage items, mask 2+4 = other items + magnet body
	collision_layer = 2
	collision_mask = 2 | 4  # Collide with other items (2) and magnet body (4)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_sprite = Sprite2D.new()
	_sprite.centered = true
	add_child(_sprite)
	
	# Setup outline shader material (disabled by default)
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	_outline_material.set_shader_parameter("outline_enabled", false)
	_outline_material.set_shader_parameter("outline_width", 6.0)
	_sprite.material = _outline_material
	
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


func start_magnet_pull(magnet: Node2D) -> void:
	_magnet_target = magnet
	_is_attached_to_magnet = false
	_is_falling = false
	_pull_elapsed = 0.0  # Reset speed ramp
	
	# Get pull config from the magnet
	if magnet.has_method("get") or "pull_base_speed" in magnet:
		_pull_base_speed = magnet.pull_base_speed
		_pull_max_speed = magnet.pull_max_speed
		_pull_ramp_time = magnet.pull_ramp_time
	
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
	# Record contacts at time of freezing for dependency tracking
	_record_contacts()


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
	if _is_repelled or _is_falling:
		_check_off_screen()
		return
	
	if _is_held_by_gun:
		var to_target := _gun_hold_target - global_position
		var dist := to_target.length()
		
		if _is_flying_to_gun:
			# Use shared pull logic with speed ramp
			_pull_elapsed += delta
			var speed := _get_ramped_pull_speed()
			
			if dist > PULL_ARRIVAL_THRESHOLD:
				global_position += to_target.normalized() * speed * delta
			else:
				# Arrived at anchor - switch to tethered mode
				_is_flying_to_gun = false
				global_position = _gun_hold_target
				_gun_hold_velocity = Vector2.ZERO
		else:
			# Tethered mode - smooth follow with inertia/dampening
			_gun_hold_velocity += to_target * TETHER_SMOOTHING * delta
			_gun_hold_velocity *= TETHER_DAMPING
			# Cap max speed to prevent wild slinging when turning
			if _gun_hold_velocity.length() > TETHER_MAX_SPEED * delta:
				_gun_hold_velocity = _gun_hold_velocity.normalized() * TETHER_MAX_SPEED * delta
			global_position += _gun_hold_velocity
		return
	
	if _is_attached_to_magnet:
		return
	
	if _magnet_target:
		var to_magnet := _magnet_target.global_position - global_position
		var distance := to_magnet.length()
		var direction := to_magnet.normalized()
		
		# Use position-based movement with speed ramp (same as magnet gun)
		_pull_elapsed += delta
		var speed := _get_ramped_pull_speed()
		
		# Cap and apply velocity
		linear_velocity = direction * speed
		linear_velocity *= ITEM_PULL_DAMPING
		
		if _is_in_magnet_field:
			# Inside magnet field - check for settling
			var magnet_radius := 50.0
			var proximity := clampf(1.0 - (distance - magnet_radius) / 200.0, 0.0, 1.0)
			
			# Settle time: 0.2s far away, 0.02s when close
			var settle_time := lerpf(0.2, 0.02, proximity)
			
			# Check if item has settled (close enough to magnet)
			if distance < magnet_radius + 20.0:
				_settle_timer += delta
				if _settle_timer >= settle_time:
					attach_to_magnet()
			else:
				_settle_timer = 0.0


func _get_ramped_pull_speed() -> float:
	var ramp_t := clampf(_pull_elapsed / _pull_ramp_time, 0.0, 1.0)
	# Exponential ramp: starts slow, accelerates quickly
	var speed := lerpf(_pull_base_speed, _pull_max_speed, ramp_t * ramp_t)
	# Cap at item's absolute max speed
	return minf(speed, ITEM_MAX_SPEED)


func _check_off_screen() -> void:
	var vp_rect := get_viewport().get_visible_rect()
	var margin := 150.0
	if global_position.y > vp_rect.size.y + margin \
		or global_position.y < -margin \
		or global_position.x > vp_rect.size.x + margin \
		or global_position.x < -margin:
		fell_off_screen.emit(self)
		queue_free()


## Outline
func set_outlined(enabled: bool) -> void:
	if _outline_material:
		_outline_material.set_shader_parameter("outline_enabled", enabled)


## Contact tracking for dependency chain
func _on_body_entered(body: Node) -> void:
	var other := body as SalvageItem
	if other and other not in _contacting_items:
		_contacting_items.append(other)


func _on_body_exited(body: Node) -> void:
	var other := body as SalvageItem
	if other:
		_contacting_items.erase(other)


func _record_contacts() -> void:
	_contacting_items.clear()
	for body in get_colliding_bodies():
		var other := body as SalvageItem
		if other:
			_contacting_items.append(other)


func get_contact_chain() -> Array[SalvageItem]:
	var visited: Array[SalvageItem] = []
	var stack: Array[SalvageItem] = []
	for c in _contacting_items:
		if is_instance_valid(c) and c._is_attached_to_magnet:
			stack.append(c)
	while stack.size() > 0:
		var current: SalvageItem = stack.pop_back()
		if current in visited:
			continue
		visited.append(current)
		for neighbor in current._contacting_items:
			if is_instance_valid(neighbor) and neighbor._is_attached_to_magnet and neighbor not in visited:
				stack.append(neighbor)
	return visited


## Grab from magnet onto magnet gun
func grab_for_magnet_gun(puller: Node2D) -> void:
	_is_attached_to_magnet = false
	_is_in_magnet_field = false
	_is_held_by_gun = true
	_is_flying_to_gun = true
	_pull_elapsed = 0.0
	_settle_timer = 0.0
	
	# Get pull config from the magnet gun (player)
	if "pull_base_speed" in puller:
		_pull_base_speed = puller.pull_base_speed
		_pull_max_speed = puller.pull_max_speed
		_pull_ramp_time = puller.pull_ramp_time
	
	# Disable collider so it doesn't interact with anything while held
	if _collision_shape:
		_collision_shape.set_deferred("disabled", true)
	
	# Unfreeze so we can move it, but zero out physics
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	gravity_scale = 0.0
	
	# Reparent to scene root
	var scene_root := get_tree().current_scene
	if scene_root and get_parent() != scene_root:
		var pos := global_position
		reparent(scene_root)
		global_position = pos
	
	_magnet_target = null
	z_index = 10  # Render above everything while held


func update_gun_hold_position(target_pos: Vector2) -> void:
	_gun_hold_target = target_pos


## Flip the item's x position relative to the anchor point (called when player flips)
func flip_relative_to_anchor(anchor_pos: Vector2) -> void:
	if not _is_held_by_gun:
		return
	# Mirror x position around the anchor
	var offset_x := global_position.x - anchor_pos.x
	global_position.x = anchor_pos.x - offset_x
	# Also flip the target and reset velocity to prevent slingshot
	var target_offset_x := _gun_hold_target.x - anchor_pos.x
	_gun_hold_target.x = anchor_pos.x - target_offset_x
	_gun_hold_velocity.x = -_gun_hold_velocity.x * 0.3  # Dampen and reverse x velocity


## Place item into storage at the given position
func place_in_storage(target_pos: Vector2) -> void:
	_is_held_by_gun = false
	_is_in_storage = true
	_gun_hold_velocity = Vector2.ZERO
	
	# Teleport to target position
	global_position = target_pos
	
	# Re-enable collider
	if _collision_shape:
		_collision_shape.set_deferred("disabled", false)
	
	# Set collision for storage: collide with other items (2) and storage borders (8)
	collision_layer = 2
	collision_mask = 2 | STORAGE_COLLISION_LAYER
	
	# Unfreeze and enable gravity to let it drop
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = false
	gravity_scale = 1.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	z_index = -3  # Render behind ship and storage marker


## Repel item off the magnet gun with an impulse
func repel_from_gun(impulse: Vector2) -> void:
	_is_held_by_gun = false
	_is_repelled = true
	
	# Re-enable collider briefly isn't needed since it will queue_free
	# Leave collider disabled so it doesn't hit anything on the way out
	
	# Unfreeze and apply impulse
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = false
	gravity_scale = 0.5
	linear_velocity = Vector2.ZERO
	apply_central_impulse(impulse)
	z_index = 10


## Force-release from gun (e.g. when looting ends while holding an item)
func force_release_from_gun() -> void:
	if not _is_held_by_gun:
		return
	repel_from_gun(Vector2.DOWN * 200.0)
