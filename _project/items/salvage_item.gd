extends RigidBody2D
class_name SalvageItem

signal fell_off_screen(item: SalvageItem)
signal frozen(item: SalvageItem)
signal unfrozen(item: SalvageItem)

## Pull phase state machine for magnet pull behavior
enum PullPhase { NONE, UNDERGROUND, SURFACE, BREAKAWAY }

# ============================================================================
# DEPRECATED - To be removed after refactor
# ============================================================================
const SETTLE_TIME: float = 0.05
const STORAGE_COLLISION_LAYER: int = 8
const OUTLINE_SHADER: Shader = preload("res://_project/items/salvage_item_outline.gdshader")
const TRASH_RARITY_COLOR: Color = Color("b8b8b8")
const TRASH_DISPLAY_NAME: String = "Trash"
const TRASH_PARTICLE_COUNT_MIN: int = 8
const TRASH_PARTICLE_COUNT_MAX: int = 12

var item_data: SalvageItemData = null
var rarity: int = SalvageItemData.ItemRarity.COMMON
var _is_trash: bool = false
var _trash_area: Vector2 = Vector2(64, 64)
var _trash_hitbox_size: Vector2 = Vector2(36, 36)
var _trash_weight: float = 0.75
var _is_held_by_gun: bool = false
var _is_in_storage: bool = false
var _is_locked_for_research: bool = false
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

# New pull phase state machine
var _pull_phase: PullPhase = PullPhase.NONE
var _surface_dwell_elapsed: float = 0.0        # Time spent at surface (Phase 2)
var _surface_line: Line2D = null               # Reference to pile's surface line
var _soft_collision_area: Area2D = null        # Child Area2D for soft-body collision
var _overlapping_items: Array[SalvageItem] = []
var _soft_velocity: Vector2 = Vector2.ZERO     # Accumulated soft-body repulsion velocity
var _freeze_timer: float = 0.0                 # Timer for freeze settling
var _is_frozen: bool = false                   # True when item is frozen/attached
var _is_touching_magnet: bool = false          # True when in contact with magnet body
var _is_settling_on_magnet: bool = false       # True when ramping down velocity after magnet contact
var _is_touching_frozen_item: bool = false     # True when in contact with a frozen item

# Pull config from the magnet/gun pulling this item
var _pull_base_speed: float = 200.0
var _pull_max_speed: float = 1500.0
var _pull_ramp_time: float = 0.6
var _pull_direction: Vector2 = Vector2.UP  # Fixed pull direction based on trapezoid edge

# Surface resistance config (Phase 2/3) - copied from magnet on pull start
var _surface_slow_speed: float = 15.0
var _surface_dwell_time: float = 1.2
var _breakaway_ramp_time: float = 0.3
var _breakaway_max_speed: float = 2000.0
var _breakaway_elapsed: float = 0.0  # Time spent in breakaway phase

# ============================================================================
# DEPRECATED - To be removed after refactor
# ============================================================================
const ITEM_PULL_DAMPING: float = 0.85
const ITEM_MAX_SPEED: float = 2000.0  # Absolute max speed cap
const PULL_ARRIVAL_THRESHOLD: float = 15.0  # Distance to consider "arrived"

# ============================================================================
# NEW PHYSICS CONSTANTS
# ============================================================================

# Freeze/Settle constants
const FREEZE_VELOCITY_THRESHOLD: float = 20.0  # Speed below which settle timer ticks
const FREEZE_TIME: float = 0.15                 # Seconds of low velocity before freezing

# Soft-body collision constants (Area2D simulation)
const SOFT_REPULSION_STRENGTH: float = 200.0   # Force multiplier for overlap pushback
const SOFT_DAMPING: float = 0.9                # Velocity damping per frame
const SOFT_MAX_REPULSION: float = 300.0        # Cap on repulsion velocity

# Weight bias constants
const REFERENCE_WEIGHT: float = 1.0            # Weight at which acceleration is unmodified
const WEIGHT_INFLUENCE: float = 0.3            # 0.0 = weight ignored, 1.0 = fully proportional

# Base damping constants
const DEFAULT_LINEAR_DAMP: float = 2.0
const DEFAULT_ANGULAR_DAMP: float = 50.0
const REPEL_LINEAR_DAMP: float = 0.0
const REPEL_ANGULAR_DAMP: float = 0.0

# Storage friction constants
const STORAGE_LINEAR_DAMP: float = 10.0        # High damping to prevent rolling/drifting in storage
const STORAGE_ANGULAR_DAMP: float = 60.0       # Very high damping so stored items barely rotate
const DROP_GRAVITY_SCALE: float = 2.0
const REPEL_GRAVITY_SCALE: float = 2.5

# Resettle re-entry tuning
const RESETTLE_BREAKAWAY_PROGRESS_EXPONENT: float = 1.75
const RESETTLE_INITIAL_SPEED_FACTOR: float = 0.35

# Tethered mode constants (when attached to magnet gun anchor)
const TETHER_SMOOTHING: float = 15.0
const TETHER_DAMPING: float = 0.85
const TETHER_MAX_SPEED: float = 400.0

var is_held_by_gun: bool:
	get:
		return _is_held_by_gun

var is_in_storage: bool:
	get:
		return _is_in_storage

var is_trash: bool:
	get:
		return _is_trash

var is_artifact: bool:
	get:
		return item_data != null and item_data.is_artifact

var is_locked_for_research: bool:
	get:
		return _is_locked_for_research

## Returns true if the item has reached the magnet gun anchor and is tethered
var has_reached_anchor: bool:
	get:
		return _is_held_by_gun and not _is_flying_to_gun

## Returns true if this item is currently settled on the magnet and can be grabbed.
var is_frozen_on_magnet: bool:
	get:
		return _is_frozen

## Returns true if this item can be grabbed by the magnet gun.
var can_be_grabbed: bool:
	get:
		return not _is_locked_for_research and not _is_held_by_gun and not _is_falling and not _is_repelled and (is_frozen_on_magnet or _is_in_storage)

## Size of the item hitbox in pixels, from item data actual_hitbox_size.
var hitbox_size: Vector2:
	get:
		if _is_trash:
			return _trash_hitbox_size
		if item_data:
			return item_data.actual_hitbox_size
		return Vector2(40.0, 40.0)


func _ready() -> void:
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 8
	angular_damp = DEFAULT_ANGULAR_DAMP  # Very high angular drag to minimize rotation
	linear_damp = DEFAULT_LINEAR_DAMP    # Some linear drag for softer movement
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY  # Enable CCD to prevent tunneling at high speeds
	
	# Collision setup: layer 2 = salvage items
	# Mask: 1 = boundaries, 2 = other items, 4 = magnet body
	collision_layer = 2
	collision_mask = 1 | 2 | 4  # Collide with boundaries, other items, and magnet
	
	# Soft physics material (Suika-style: low bounce, moderate friction)
	var soft_material := PhysicsMaterial.new()
	soft_material.bounce = 0.1      # Very low bounce
	soft_material.friction = 0.3    # Moderate friction
	physics_material_override = soft_material
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_sprite = Sprite2D.new()
	_sprite.centered = true
	add_child(_sprite)
	
	# Setup outline shader material (disabled by default)
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	_outline_material.set_shader_parameter("outline_enabled", false)
	_outline_material.set_shader_parameter("outline_width", 3.0)
	_sprite.material = _outline_material
	
	_collision_shape = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = minf(hitbox_size.x, hitbox_size.y) * 0.5
	_collision_shape.shape = shape
	add_child(_collision_shape)


func setup(data: SalvageItemData) -> void:
	_is_trash = false
	_is_locked_for_research = false
	item_data = data
	rarity = int(data.rarity) if data else SalvageItemData.ItemRarity.COMMON
	
	if _sprite:
		if data.sprite:
			_apply_sprite_texture(data.sprite, data.actual_area)
		else:
			_create_placeholder_sprite()
	
	if _collision_shape and _collision_shape.shape is CircleShape2D:
		var new_radius := minf(hitbox_size.x, hitbox_size.y) * 0.5
		(_collision_shape.shape as CircleShape2D).radius = new_radius


func setup_trash(texture: Texture2D, area: Vector2 = Vector2(64, 64), hitbox: Vector2 = Vector2(36, 36), weight: float = 0.75) -> void:
	_is_trash = true
	_is_locked_for_research = false
	item_data = null
	rarity = SalvageItemData.ItemRarity.COMMON
	_trash_area = area
	_trash_hitbox_size = hitbox
	_trash_weight = weight
	
	if _sprite:
		if texture:
			_apply_sprite_texture(texture, _trash_area)
		else:
			_create_trash_placeholder_sprite()
	
	if _collision_shape and _collision_shape.shape is CircleShape2D:
		var new_radius := minf(hitbox_size.x, hitbox_size.y) * 0.5
		(_collision_shape.shape as CircleShape2D).radius = new_radius


func _apply_sprite_texture(texture: Texture2D, area: Vector2) -> void:
	if not _sprite or not texture:
		return
	_sprite.texture = texture
	var tex_size := texture.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		var scale_x := area.x / tex_size.x
		var scale_y := area.y / tex_size.y
		var uniform_scale := minf(scale_x, scale_y)
		_sprite.scale = Vector2(uniform_scale, uniform_scale)


func _create_placeholder_sprite() -> void:
	if not item_data:
		return
	var size := hitbox_size
	var img := Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	var color: Color = get_rarity_color()
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	_sprite.texture = tex


func _create_trash_placeholder_sprite() -> void:
	var size := hitbox_size
	var img := Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	img.fill(TRASH_RARITY_COLOR)
	var tex := ImageTexture.create_from_image(img)
	_sprite.texture = tex


func get_display_name() -> String:
	if _is_trash:
		return TRASH_DISPLAY_NAME
	if item_data and not item_data.item_name.is_empty():
		return item_data.item_name
	return "Unknown Salvage"


func get_rarity_color() -> Color:
	if _is_trash:
		return TRASH_RARITY_COLOR
	if is_artifact:
		return SalvageItemData.ARTIFACT_COLOR
	return SalvageItemData.get_color_for_rarity(rarity)


func pop_trash() -> void:
	if not _is_trash:
		queue_free()
		return
	_spawn_trash_pop_particles()
	queue_free()


func start_magnet_pull(magnet: Node2D, direction: Vector2 = Vector2.UP) -> void:
	_magnet_target = magnet
	_is_falling = false
	_pull_elapsed = 0.0  # Reset speed ramp
	_pull_direction = direction.normalized()
	
	# Initialize pull phase system
	_pull_phase = PullPhase.UNDERGROUND
	_surface_dwell_elapsed = 0.0
	_breakaway_elapsed = 0.0
	_is_frozen = false
	_freeze_timer = 0.0
	
	_apply_pull_config_from_source(magnet)
	
	gravity_scale = 0.0
	freeze = false


func restart_magnet_pull_for_resettle(magnet: Node2D) -> void:
	var was_frozen := _is_frozen
	_enter_resettle_pull_state()
	if was_frozen:
		unfrozen.emit(self)
	if magnet == null:
		return

	_magnet_target = magnet
	_is_falling = false
	if _pull_direction == Vector2.ZERO:
		_pull_direction = Vector2.UP
	_apply_pull_config_from_source(magnet)
	_breakaway_elapsed = _get_resettle_breakaway_elapsed(magnet)
	linear_velocity = _pull_direction * (_get_breakaway_speed_for_elapsed(_breakaway_elapsed) * RESETTLE_INITIAL_SPEED_FACTOR)
	angular_velocity = 0.0


func enter_magnet_field() -> void:
	_is_in_magnet_field = true
	_settle_timer = 0.0


func release_from_magnet() -> void:
	# Don't release if held by magnet gun - gun takes priority
	if _is_held_by_gun:
		return
	
	_clear_settled_magnet_state()
	_is_in_magnet_field = false
	_is_falling = true
	_settle_timer = 0.0
	
	# Reset freeze state - order matters: set mode first, then unfreeze
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = false
	
	# Reparent back to scene root so item falls independently
	var scene_root := Magnetide.world_root
	if scene_root and get_parent() != scene_root:
		var pos := global_position
		reparent(scene_root)
		global_position = pos
	
	_magnet_target = null
	gravity_scale = DROP_GRAVITY_SCALE
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
	
	if _is_frozen:
		return
	
	# Handle settling on magnet - aggressively ramp down all velocity until frozen
	if _is_settling_on_magnet:
		# Rapidly decay all velocity
		linear_velocity *= 0.8
		angular_velocity *= 0.7
		
		# Check if velocity is low enough to freeze
		var total_velocity := linear_velocity.length() + absf(angular_velocity) * 10.0
		if total_velocity < 5.0:
			_freeze_item()
		return  # Don't process normal pull logic while settling
	
	if _magnet_target and _pull_phase != PullPhase.NONE:
		# Get pull speed based on current phase (this also increments phase timers)
		var target_speed := _process_pull_phase(delta)
		
		# Check for phase transitions AFTER updating timers
		_check_phase_transition()
		
		# Don't apply pull impulse if touching frozen items or magnet - let physics settle naturally
		if not _is_touching_frozen_item and not _is_touching_magnet:
			var current_pull_speed := linear_velocity.dot(_pull_direction)
			var speed_diff := target_speed - current_pull_speed
			# Use weaker impulse in SURFACE phase to reduce jitter
			var impulse_strength := 0.05 if _pull_phase == PullPhase.SURFACE else 0.1
			var impulse := _pull_direction * speed_diff * mass * impulse_strength
			apply_central_impulse(impulse)
		
		# Aggressively zero out angular velocity to prevent spinning
		angular_velocity *= 0.8
		
		# Check if item should freeze (only in magnet field AND after breakaway)
		# Don't freeze during SURFACE phase - items need to complete dwell time first
		if _is_in_magnet_field and _pull_phase == PullPhase.BREAKAWAY:
			_check_freeze_condition(delta)


func _get_ramped_pull_speed() -> float:
	var ramp_t := clampf(_pull_elapsed / _pull_ramp_time, 0.0, 1.0)
	# Exponential ramp: starts slow, accelerates quickly
	var speed := lerpf(_pull_base_speed, _pull_max_speed, ramp_t * ramp_t)
	# Cap at item's absolute max speed
	return minf(speed, ITEM_MAX_SPEED)


func _apply_pull_config_from_source(pull_source: Node2D) -> void:
	if pull_source == null:
		return
	if "pull_base_speed" in pull_source:
		_pull_base_speed = pull_source.pull_base_speed
		_pull_max_speed = pull_source.pull_max_speed
		_pull_ramp_time = pull_source.pull_ramp_time
	if "surface_slow_speed" in pull_source:
		_surface_slow_speed = pull_source.surface_slow_speed
		_surface_dwell_time = pull_source.surface_dwell_time
		_breakaway_ramp_time = pull_source.breakaway_ramp_time
		_breakaway_max_speed = pull_source.breakaway_max_speed
	if pull_source.has_method("get_surface_line"):
		_surface_line = pull_source.get_surface_line()


func _get_resettle_breakaway_elapsed(magnet: Node2D) -> float:
	if magnet == null:
		return 0.0
	if _breakaway_ramp_time <= 0.0:
		return 0.0

	var distance_to_magnet := global_position.distance_to(magnet.global_position)
	var viewport_height := get_viewport().get_visible_rect().size.y
	var pull_reference_distance := maxf(viewport_height - magnet.global_position.y, 1.0)
	var pull_progress := 1.0 - clampf(distance_to_magnet / pull_reference_distance, 0.0, 1.0)
	var resettle_progress := pow(pull_progress, RESETTLE_BREAKAWAY_PROGRESS_EXPONENT)
	return _breakaway_ramp_time * resettle_progress


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


## Contact tracking for dependency chain and magnet friction
func _on_body_entered(body: Node) -> void:
	# Check if touching magnet body (StaticBody2D on layer 4)
	if body is StaticBody2D:
		if body.collision_layer & 4:
			_is_touching_magnet = true
			# Only start settling if in BREAKAWAY phase (not SURFACE or UNDERGROUND)
			if _pull_phase == PullPhase.BREAKAWAY:
				_is_settling_on_magnet = true
			return
	
	var other := body as SalvageItem
	if is_instance_valid(other):
		if other not in _contacting_items:
			_contacting_items.append(other)
		# Track contact with frozen items
		if other._is_frozen:
			_is_touching_frozen_item = true
			# Start settling if in BREAKAWAY phase and touching frozen pile
			if _pull_phase == PullPhase.BREAKAWAY:
				_is_settling_on_magnet = true


func _on_body_exited(body: Node) -> void:
	# Check if leaving magnet body
	if body is StaticBody2D and body.collision_layer & 4:
		_is_touching_magnet = false
		# Don't reset _is_settling_on_magnet - once settling starts, it continues until frozen
		return
	
	var other := body as SalvageItem
	if is_instance_valid(other):
		# Don't remove contacts if we're frozen - we need to keep them for unfreeze chain
		if not _is_frozen:
			_contacting_items.erase(other)
			_prune_contacting_items()
			# Check if still touching any frozen items
			_is_touching_frozen_item = false
			for item in _contacting_items:
				if item._is_frozen:
					_is_touching_frozen_item = true
					break


func _record_contacts() -> void:
	_prune_contacting_items()
	# Don't clear - keep contacts tracked via _on_body_entered
	# Just add any we might have missed from get_colliding_bodies
	for body in get_colliding_bodies():
		var other := body as SalvageItem
		if is_instance_valid(other) and other not in _contacting_items:
			_contacting_items.append(other)


func get_contact_chain() -> Array[SalvageItem]:
	_prune_contacting_items()
	var visited: Array[SalvageItem] = []
	var stack: Array[SalvageItem] = []
	for c in _contacting_items:
		if is_instance_valid(c) and c.is_frozen_on_magnet:
			stack.append(c)
	while stack.size() > 0:
		var current: SalvageItem = stack.pop_back()
		if current in visited:
			continue
		visited.append(current)
		current._prune_contacting_items()
		for neighbor in current._contacting_items:
			if is_instance_valid(neighbor) and neighbor.is_frozen_on_magnet and neighbor not in visited:
				stack.append(neighbor)
	return visited


func get_storage_contact_chain() -> Array[SalvageItem]:
	_prune_contacting_items()
	var visited: Array[SalvageItem] = []
	var stack: Array[SalvageItem] = []
	for c in _contacting_items:
		if is_instance_valid(c) and c.is_in_storage:
			stack.append(c)
	while stack.size() > 0:
		var current: SalvageItem = stack.pop_back()
		if current in visited:
			continue
		visited.append(current)
		current._prune_contacting_items()
		for neighbor in current._contacting_items:
			if is_instance_valid(neighbor) and neighbor.is_in_storage and neighbor not in visited:
				stack.append(neighbor)
	return visited


## Grab from magnet onto magnet gun
func grab_for_magnet_gun(puller: Node2D) -> void:
	_is_locked_for_research = false

	# Unfreeze all contacting frozen items so they can resettle
	_unfreeze_contacting_items()
	
	_clear_settled_magnet_state()
	_is_in_magnet_field = false
	_is_held_by_gun = true
	_is_in_storage = false
	_is_repelled = false
	_is_falling = false
	_is_flying_to_gun = true
	_pull_elapsed = 0.0
	_settle_timer = 0.0
	_pull_phase = PullPhase.NONE
	_magnet_target = null
	linear_damp = DEFAULT_LINEAR_DAMP
	angular_damp = DEFAULT_ANGULAR_DAMP
	
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
	var scene_root := Magnetide.world_root
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
func place_in_storage(target_pos: Vector2, storage_parent: Node = null) -> void:
	_clear_settled_magnet_state()
	_is_held_by_gun = false
	_is_in_storage = true
	_is_locked_for_research = false
	_is_repelled = false
	_is_falling = false
	_is_flying_to_gun = false
	_pull_phase = PullPhase.NONE
	_magnet_target = null
	_gun_hold_velocity = Vector2.ZERO

	if storage_parent and get_parent() != storage_parent:
		var current_pos := global_position
		reparent(storage_parent)
		global_position = current_pos
	
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
	gravity_scale = DROP_GRAVITY_SCALE
	linear_damp = STORAGE_LINEAR_DAMP
	angular_damp = STORAGE_ANGULAR_DAMP
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	z_index = 0


func lock_for_research(target_pos: Vector2, research_parent: Node = null) -> void:
	_clear_settled_magnet_state()
	_is_held_by_gun = false
	_is_in_storage = false
	_is_locked_for_research = true
	_is_repelled = false
	_is_falling = false
	_is_flying_to_gun = false
	_pull_phase = PullPhase.NONE
	_magnet_target = null
	_gun_hold_velocity = Vector2.ZERO
	_soft_velocity = Vector2.ZERO
	_is_frozen = true
	set_outlined(false)

	if research_parent and get_parent() != research_parent:
		var current_pos := global_position
		reparent(research_parent)
		global_position = current_pos

	global_position = target_pos

	if _collision_shape:
		_collision_shape.set_deferred("disabled", true)

	collision_layer = 0
	collision_mask = 0
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	gravity_scale = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	z_index = 3


func lock_for_departure_cutscene(storage_parent: Node = null) -> void:
	_clear_settled_magnet_state()
	_is_held_by_gun = false
	_is_in_storage = true
	_is_repelled = false
	_is_falling = false
	_is_flying_to_gun = false
	_pull_phase = PullPhase.NONE
	_magnet_target = null
	_gun_hold_velocity = Vector2.ZERO
	_soft_velocity = Vector2.ZERO

	if storage_parent and get_parent() != storage_parent:
		var current_pos := global_position
		reparent(storage_parent)
		global_position = current_pos

	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	gravity_scale = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	set_physics_process(false)


## Repel item off the magnet gun with an impulse
func repel_from_gun(impulse: Vector2) -> void:
	_clear_settled_magnet_state()
	_is_held_by_gun = false
	_is_repelled = true
	
	# Re-enable collider briefly isn't needed since it will queue_free
	# Leave collider disabled so it doesn't hit anything on the way out
	
	# Unfreeze and apply impulse
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = false
	gravity_scale = REPEL_GRAVITY_SCALE
	linear_damp = REPEL_LINEAR_DAMP
	angular_damp = REPEL_ANGULAR_DAMP
	linear_velocity = Vector2.ZERO
	apply_central_impulse(impulse)
	z_index = 10


## Force-release from gun (e.g. when looting ends while holding an item)
func force_release_from_gun() -> void:
	if not _is_held_by_gun:
		return
	repel_from_gun(Vector2.DOWN * 200.0)


# ============================================================================
# NEW PULL PHASE SYSTEM (Stubs)
# ============================================================================

## Set the surface line reference for Phase 2 detection
func set_surface_line(line: Line2D) -> void:
	_surface_line = line


## Get the Y position of the surface line at the item's current X position
func _get_surface_y_at_position() -> float:
	if not _surface_line or _surface_line.points.size() < 2:
		return INF  # No surface line, never trigger Phase 2
	
	# Convert item's global position to surface line's local space
	var local_pos := _surface_line.to_local(global_position)
	var local_x := local_pos.x
	var points := _surface_line.points
	
	# Find the two points that bracket the given X
	for i in range(points.size() - 1):
		var p1 := points[i]
		var p2 := points[i + 1]
		
		if (p1.x <= local_x and local_x <= p2.x) or (p2.x <= local_x and local_x <= p1.x):
			# Interpolate Y between these two points
			var t := (local_x - p1.x) / (p2.x - p1.x) if abs(p2.x - p1.x) > 0.001 else 0.0
			var local_y := lerpf(p1.y, p2.y, t)
			# Convert back to global Y
			return _surface_line.to_global(Vector2(local_x, local_y)).y
	
	# X is outside the line bounds - return nearest endpoint's global Y
	if local_x < points[0].x:
		return _surface_line.to_global(points[0]).y
	return _surface_line.to_global(points[points.size() - 1]).y


## Process pull physics based on current phase. Returns the pull speed for this frame.
func _process_pull_phase(delta: float) -> float:
	var weight_factor := _get_weight_factor()
	
	match _pull_phase:
		PullPhase.UNDERGROUND:
			# Phase 1: Normal exponential ramp from base to max speed
			_pull_elapsed += delta
			var ramp_t := clampf(_pull_elapsed / _pull_ramp_time, 0.0, 1.0)
			var speed := lerpf(_pull_base_speed, _pull_max_speed, ramp_t * ramp_t)
			return speed * weight_factor
		
		PullPhase.SURFACE:
			# Phase 2: Slow crawl at surface while "freeing" from ground
			_surface_dwell_elapsed += delta
			return _surface_slow_speed * weight_factor
		
		PullPhase.BREAKAWAY:
			# Phase 3: Sharp acceleration then normal ramp to max
			_breakaway_elapsed += delta
			var ramp_t := clampf(_breakaway_elapsed / _breakaway_ramp_time, 0.0, 1.0)
			# Use cubic easing for sharp initial acceleration
			var eased_t := ramp_t * ramp_t * ramp_t
			var speed := lerpf(_surface_slow_speed, _breakaway_max_speed, eased_t)
			return speed * weight_factor
		
		_:
			return 0.0


## Check if item should transition to next pull phase
func _check_phase_transition() -> void:
	match _pull_phase:
		PullPhase.UNDERGROUND:
			# Transition to SURFACE when item crosses the surface line
			var surface_y := _get_surface_y_at_position()
			if global_position.y <= surface_y:
				_pull_phase = PullPhase.SURFACE
				_surface_dwell_elapsed = 0.0
				# Abrupt slowdown - immediately set velocity to surface slow speed
				linear_velocity = _pull_direction * _surface_slow_speed
				angular_velocity = 0.0
		
		PullPhase.SURFACE:
			# Transition to BREAKAWAY after dwell time expires (scaled by weight)
			var weight_scaled_dwell := _surface_dwell_time * _get_dwell_weight_factor()
			if _surface_dwell_elapsed >= weight_scaled_dwell:
				_pull_phase = PullPhase.BREAKAWAY
				_breakaway_elapsed = 0.0
		
		PullPhase.BREAKAWAY:
			# Breakaway continues until item enters magnet field and freezes
			# No automatic transition - handled by freeze logic
			pass


## Get weight-biased speed multiplier (lighter = faster)
func _get_weight_factor() -> float:
	var item_weight := _get_item_weight()
	if item_weight <= 0.0:
		return 1.0
	return lerpf(1.0, REFERENCE_WEIGHT / item_weight, WEIGHT_INFLUENCE)


## Get weight-biased dwell time multiplier (heavier = longer dwell, lighter = shorter)
## Returns multiplier where 1.0 = reference weight, >1.0 = heavier, <1.0 = lighter
func _get_dwell_weight_factor() -> float:
	var item_weight := _get_item_weight()
	if item_weight <= 0.0:
		return 1.0
	# Heavier items take longer to break away (higher multiplier)
	# Lighter items break away faster (lower multiplier)
	# Using sqrt for gentler scaling
	return sqrt(item_weight / REFERENCE_WEIGHT)


func _get_item_weight() -> float:
	if _is_trash:
		return _trash_weight
	if item_data:
		return item_data.weight
	return 1.0


func _spawn_trash_pop_particles() -> void:
	if not is_inside_tree():
		return
	var texture := _sprite.texture if _sprite else null
	var parent_node := Magnetide.world_root
	if not parent_node:
		parent_node = get_parent()
	if not parent_node:
		return

	var count := randi_range(TRASH_PARTICLE_COUNT_MIN, TRASH_PARTICLE_COUNT_MAX)
	for i in count:
		var fragment := Sprite2D.new()
		fragment.texture = texture
		fragment.centered = true
		fragment.global_position = global_position
		fragment.rotation = randf_range(0.0, TAU)
		fragment.scale = (_sprite.scale if _sprite else Vector2.ONE) * randf_range(0.12, 0.24)
		fragment.modulate = Color(1.0, 1.0, 1.0, randf_range(0.75, 1.0))
		fragment.z_index = z_index + 1
		parent_node.add_child(fragment)

		var direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		var target := global_position + direction * randf_range(24.0, 72.0) + Vector2(0.0, randf_range(-16.0, 24.0))
		var tween := fragment.create_tween()
		tween.set_parallel(true)
		tween.tween_property(fragment, "global_position", target, randf_range(0.25, 0.45)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(fragment, "rotation", fragment.rotation + randf_range(-PI * 2.0, PI * 2.0), randf_range(0.25, 0.45))
		tween.tween_property(fragment, "modulate:a", 0.0, 0.22).set_delay(0.12)
		tween.chain().tween_callback(fragment.queue_free)


# ============================================================================
# NEW SOFT-BODY COLLISION SYSTEM (Stubs)
# ============================================================================

## Setup the child Area2D for soft-body collision detection
func _setup_soft_collision_area() -> void:
	_soft_collision_area = Area2D.new()
	# Use layer 8 for soft-body detection (separate from RigidBody layer 2)
	_soft_collision_area.collision_layer = 8  # Be detectable by other soft-body areas
	_soft_collision_area.collision_mask = 8   # Detect other soft-body areas
	_soft_collision_area.monitoring = true
	_soft_collision_area.monitorable = true
	
	# Create shape matching our collision shape - use a reasonable default
	# Will be updated in setup() with actual item size
	var area_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	var radius := minf(hitbox_size.x, hitbox_size.y) * 0.5
	if radius < 1.0:
		radius = 20.0  # Default fallback
	circle.radius = radius
	area_shape.shape = circle
	_soft_collision_area.add_child(area_shape)
	add_child(_soft_collision_area)
	
	_soft_collision_area.area_entered.connect(_on_soft_area_entered)
	_soft_collision_area.area_exited.connect(_on_soft_area_exited)


func _on_soft_area_entered(area: Area2D) -> void:
	var other_item := area.get_parent() as SalvageItem
	if other_item and other_item != self and other_item not in _overlapping_items:
		_overlapping_items.append(other_item)
		# Frozen items don't unfreeze - they act as immovable obstacles


func _on_soft_area_exited(area: Area2D) -> void:
	var other_item := area.get_parent() as SalvageItem
	if other_item:
		_overlapping_items.erase(other_item)


## Calculate and apply soft-body repulsion forces from overlapping items
func _apply_soft_collision_forces(delta: float) -> void:
	if _overlapping_items.is_empty():
		_soft_velocity *= SOFT_DAMPING
		return
	
	var repulsion := Vector2.ZERO
	for other in _overlapping_items:
		if not is_instance_valid(other):
			continue
		var to_self := global_position - other.global_position
		var dist := to_self.length()
		if dist < 0.01:
			to_self = Vector2(randf() - 0.5, randf() - 0.5).normalized()
			dist = 0.01
		
		var combined_radii := (hitbox_size.x * 0.5) + (other.hitbox_size.x * 0.5)
		var overlap_depth := combined_radii - dist
		if overlap_depth > 0:
			var force := to_self.normalized() * overlap_depth * SOFT_REPULSION_STRENGTH
			repulsion += force
	
	# Apply weight factor - heavier items resist pushback more
	repulsion *= _get_weight_factor()
	
	# Accumulate and cap velocity
	_soft_velocity += repulsion
	if _soft_velocity.length() > SOFT_MAX_REPULSION:
		_soft_velocity = _soft_velocity.normalized() * SOFT_MAX_REPULSION
	_soft_velocity *= SOFT_DAMPING
	
	# Apply soft velocity as position offset (since RigidBody2D item-to-item collision is disabled)
	global_position += _soft_velocity * delta


# ============================================================================
# NEW FREEZE/UNFREEZE SYSTEM (Stubs)
# ============================================================================

## Check if item should freeze based on velocity threshold
func _check_freeze_condition(delta: float) -> void:
	if _is_frozen:
		return
	
	if linear_velocity.length() < FREEZE_VELOCITY_THRESHOLD:
		_freeze_timer += delta
		if _freeze_timer >= FREEZE_TIME:
			_freeze_item()
	else:
		_freeze_timer = 0.0


## Freeze the item in place
func _freeze_item() -> void:
	if _is_frozen:
		return
	_is_frozen = true
	_freeze_timer = 0.0
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector2.ZERO
	_record_contacts()
	frozen.emit(self)


func _clear_settled_magnet_state() -> void:
	_is_frozen = false
	_freeze_timer = 0.0
	_is_settling_on_magnet = false
	_is_touching_magnet = false
	_is_touching_frozen_item = false


func _enter_resettle_pull_state() -> void:
	_clear_settled_magnet_state()
	_pull_phase = PullPhase.BREAKAWAY
	_pull_elapsed = 0.0
	_surface_dwell_elapsed = 0.0
	_breakaway_elapsed = 0.0
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = false


func _get_breakaway_speed_for_elapsed(elapsed: float) -> float:
	var ramp_t := clampf(elapsed / _breakaway_ramp_time, 0.0, 1.0) if _breakaway_ramp_time > 0.0 else 1.0
	var eased_t := ramp_t * ramp_t * ramp_t
	var speed := lerpf(_surface_slow_speed, _breakaway_max_speed, eased_t)
	return speed * _get_weight_factor()


## Unfreeze the item and re-enter pull cycle
func unfreeze_for_resettle() -> void:
	if not _is_frozen:
		return
	_enter_resettle_pull_state()
	unfrozen.emit(self)


func wake_for_storage_resettle() -> void:
	if not _is_in_storage:
		return

	_clear_settled_magnet_state()
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = false
	sleeping = false
	gravity_scale = DROP_GRAVITY_SCALE
	linear_damp = STORAGE_LINEAR_DAMP
	angular_damp = STORAGE_ANGULAR_DAMP
	angular_velocity = 0.0
	if _collision_shape:
		_collision_shape.set_deferred("disabled", false)

	# Give the body a tiny downward push so resting stacks wake up immediately.
	if linear_velocity.y < 10.0:
		linear_velocity.y = 10.0


## Unfreeze all frozen items currently in contact with this item
func _unfreeze_contacting_items() -> void:
	_prune_contacting_items()
	for item in _contacting_items:
		if is_instance_valid(item) and item._is_frozen:
			item.call_deferred("unfreeze_for_resettle")


func _prune_contacting_items() -> void:
	for i in range(_contacting_items.size() - 1, -1, -1):
		if not is_instance_valid(_contacting_items[i]):
			_contacting_items.remove_at(i)
