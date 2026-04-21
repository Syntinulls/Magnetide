extends Node2D
class_name Magnet

signal item_attached(item: SalvageItem)
signal item_removed(item: SalvageItem)
signal capacity_reached()
signal all_items_released()

# ============================================================================
# MAGNET PROPERTIES
# ============================================================================

## Time between pulling each item from the pile (seconds).
@export var pull_frequency: float = 2.5
## Number of items pulled simultaneously per interval. Always 1 for now.
@export var pull_batch_size: int = 1
## Max number of items the magnet can hold at once. Stops pulling once reached.
@export var hold_capacity: int = 10

# ============================================================================
# PULL SPEED PARAMETERS
# ============================================================================

## Base speed items are pulled toward the magnet.
@export var pull_base_speed: float = 200.0
## Max speed items are pulled toward the magnet.
@export var pull_max_speed: float = 1500.0
## Time for pull speed to ramp from base to max.
@export var pull_ramp_time: float = 0.6

# ============================================================================
# SURFACE RESISTANCE PARAMETERS (Phase 2)
# ============================================================================

## Near-zero crawl speed when item is at surface.
@export var surface_slow_speed: float = 15.0
## Seconds spent freeing from ground at surface.
@export var surface_dwell_time: float = 1.2
## Time to ramp from surface to max speed after breakaway.
@export var breakaway_ramp_time: float = 0.3
## Max speed after breakaway.
@export var breakaway_max_speed: float = 2000.0
## Base threat cost per magnet activation. Affected by upgrades.
@export var threat_penalty: float = 10.0
## Width of the magnet pull area at the top (full width, not half).
@export var magnet_width: float = 100.0:
	set(value):
		magnet_width = value
		_update_magnet_visuals()
@export_group("Combat")
@export var max_health: float = 150.0

var _is_active: bool = false
var _attached_items: Array[SalvageItem] = []
var _counted_items: Array[SalvageItem] = []
var _held_count: int = 0
var _pull_timer: float = 0.0
var _items_in_field: Array[SalvageItem] = []  # All unfrozen items currently in pull area
var _pile_data: SalvagePileData = null
var _current_threat_level: int = 0
var _pile_node: SalvagePile = null
var _salvageable_pull_count: int = 0
var _area: Area2D = null
var _field_shape: CollisionShape2D = null
var _effect_animation: AnimatedSprite2D = null
var _magnet_sprite: NinePatchSprite = null
var _body_shape: CollisionShape2D = null
var _left_wall: StaticBody2D = null
var _right_wall: StaticBody2D = null
var _is_pull_suspended_by_capacity: bool = false
var _is_spawn_paused_for_departure: bool = false
var current_health: float = 0.0
const SPAWN_WIDTH_RATIO: float = 0.50  # Must match spawn ratio in _spawn_item_from_pile
const WALL_THICKNESS: float = 10.0  # Thickness of edge collision walls
const EDGE_WALL_FRICTION: float = 0.0
const EDGE_WALL_BOUNCE: float = 0.0

var held_count: int:
	get:
		return _held_count

var is_at_capacity: bool:
	get:
		return _held_count >= hold_capacity

var is_active: bool:
	get:
		return _is_active


func _ready() -> void:
	current_health = max_health
	set_process(false)
	_area = get_node_or_null("MagnetPullArea") as Area2D
	if not _area:
		_area = get_node_or_null("Area2D") as Area2D
	if _area:
		_area.body_entered.connect(_on_body_entered)
		_field_shape = _area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_effect_animation = get_node_or_null("EffectAnimation") as AnimatedSprite2D
	_magnet_sprite = get_node_or_null("MagnetSprite") as NinePatchSprite
	var static_body := get_node_or_null("Collider") as StaticBody2D
	if not static_body:
		static_body = get_node_or_null("StaticBody2D") as StaticBody2D
	if static_body:
		_body_shape = static_body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_update_magnet_visuals()
	_update_pull_state()


func apply_run_loadout(loadout: RunLoadout) -> void:
	if loadout == null:
		return

	pull_frequency = loadout.magnet_pull_frequency
	pull_batch_size = loadout.magnet_pull_batch_size
	hold_capacity = loadout.magnet_hold_capacity
	pull_base_speed = loadout.magnet_pull_base_speed
	pull_max_speed = loadout.magnet_pull_max_speed
	pull_ramp_time = loadout.magnet_pull_ramp_time
	surface_slow_speed = loadout.magnet_surface_slow_speed
	surface_dwell_time = loadout.magnet_surface_dwell_time
	breakaway_ramp_time = loadout.magnet_breakaway_ramp_time
	breakaway_max_speed = loadout.magnet_breakaway_max_speed
	threat_penalty = loadout.magnet_threat_penalty
	magnet_width = loadout.magnet_width
	max_health = loadout.magnet_max_health
	current_health = max_health if not is_inside_tree() else minf(current_health, max_health)
	if is_inside_tree():
		_update_magnet_visuals()
		_update_pull_state()


func activate(pile_data: SalvagePileData, pile: SalvagePile, threat_level: int = 0) -> void:
	_pile_data = pile_data
	_pile_node = pile
	_current_threat_level = threat_level
	_is_active = true
	_pull_timer = 0.0
	_held_count = 0
	_attached_items.clear()
	_counted_items.clear()
	_items_in_field.clear()
	_is_pull_suspended_by_capacity = false
	_is_spawn_paused_for_departure = false
	
	# Resize magnetic field trapezoid based on pile
	_update_field_shape_for_pile(pile)
	
	_update_pull_state()
	set_process(true)


func deactivate() -> void:
	_is_active = false
	_pile_data = null
	_pile_node = null
	_is_pull_suspended_by_capacity = false
	_is_spawn_paused_for_departure = false
	_release_all_items()
	
	_update_pull_state()
	set_process(false)


func _release_all_items() -> void:
	# Release tracked items
	for item in _attached_items:
		if is_instance_valid(item):
			item.release_from_magnet()
	_attached_items.clear()
	_counted_items.clear()
	
	# Also release any SalvageItem children that may have been reparented to magnet
	for child in get_children():
		if child is SalvageItem:
			child.release_from_magnet()
	
	_held_count = 0
	_items_in_field.clear()
	_is_pull_suspended_by_capacity = false
	_update_pull_state()
	all_items_released.emit()


func _process(delta: float) -> void:
	if not _is_active:
		return
	if _is_spawn_paused_for_departure:
		return

	_pull_timer += delta
	if _pull_timer >= pull_frequency and not is_at_capacity:
		_pull_timer = 0.0
		_spawn_item_from_pile()


func _spawn_item_from_pile() -> void:
	if not _pile_data or not _pile_node or not is_instance_valid(_pile_node):
		return

	# TODO: Use new roll system
	# 1. Call _pile_data.roll_item(_salvageable_pull_count, _current_threat_level)
	# 2. Check result["is_salvageable"] to update pity counter:
	#    - If true: reset_pity_counter()
	#    - If false: increment_pity_counter()
	# 3. Use result["item"] as data
	var result := _pile_data.roll_item(_salvageable_pull_count, _current_threat_level)
	if not result or not result.has("item") or result["item"] == null:
		return
	
	var is_salvageable: bool = result.get("is_salvageable", false)
	if is_salvageable:
		reset_pity_counter()
	else:
		increment_pity_counter()
	
	var data: SalvageItemData = result["item"]
	if not data:
		return

	# Check if adding this item would exceed capacity
	if is_at_capacity:
		return

	var item := SalvageItem.new()
	# Add to scene tree at a scope that persists
	var world_root := Magnetide.world_root
	if world_root:
		world_root.add_child(item)
	else:
		add_child(item)
	item.setup(data)

	# Spawn item at pile position (top of pile) with random x variance within pile width
	var pile_top := _pile_node.global_position
	var pile_sprite := _pile_node.get_node_or_null("Sprite2D") as Sprite2D
	var pile_half_width := 50.0  # Default fallback
	if pile_sprite and pile_sprite.texture:
		var tex_size := pile_sprite.texture.get_size() * _pile_node.scale
		pile_top.y -= tex_size.y
		pile_half_width = tex_size.x * 0.5
	
	# Random x within 50% of pile width
	var spawn_width_ratio := 0.50
	var x_range := pile_half_width * spawn_width_ratio
	var x_offset := randf_range(-x_range, x_range)

	# Spawn at bottom of screen (items pulled up from below)
	var screen_height := get_viewport().get_visible_rect().size.y
	item.global_position = Vector2(_pile_node.global_position.x + x_offset, screen_height)
	item.z_index = -1  # Render behind salvage pile

	# Pull direction: mostly up, with small bias toward center based on distance from center
	# Items at the edge get more horizontal bias, items near center get almost none
	var center_bias_strength := 0.15  # Max horizontal component at full distance
	var normalized_offset := x_offset / x_range if x_range > 0.0 else 0.0  # -1 to 1
	var horizontal_bias := -normalized_offset * center_bias_strength  # Negative to pull toward center
	var pull_direction := Vector2(horizontal_bias, -1.0).normalized()
	item.start_magnet_pull(self, pull_direction)
	item.fell_off_screen.connect(_on_item_fell_off_screen)


func remove_item(item: SalvageItem) -> void:
	if item in _attached_items:
		_attached_items.erase(item)
		if _remove_counted_item(item):
			_update_pull_state()
			item_removed.emit(item)


func get_attached_items() -> Array[SalvageItem]:
	return _attached_items


func set_spawn_paused_for_departure(paused: bool) -> void:
	_is_spawn_paused_for_departure = paused


func _on_item_fell_off_screen(item: SalvageItem) -> void:
	if item in _attached_items:
		_attached_items.erase(item)
		if _remove_counted_item(item):
			_update_pull_state()
			item_removed.emit(item)


func _on_body_entered(body: Node2D) -> void:
	if not _is_active:
		return
	
	var item := body as SalvageItem
	if not item or item in _attached_items:
		return
	
	# Check capacity
	if is_at_capacity:
		item.release_from_magnet()
		return
	
	# Item entered magnet field - enable gravity mode
	item.enter_magnet_field()
	
	# Track item
	_attached_items.append(item)
	if not item.frozen.is_connected(_on_tracked_item_frozen):
		item.frozen.connect(_on_tracked_item_frozen)


func _update_field_shape_for_pile(pile: SalvagePile) -> void:
	if not _field_shape:
		return
	
	# Calculate pile spawn width
	var pile_half_width := 100.0  # Default fallback
	var pile_sprite := pile.get_node_or_null("Sprite2D") as Sprite2D
	if pile_sprite and pile_sprite.texture:
		pile_half_width = pile_sprite.texture.get_size().x * pile.scale.x * 0.5
	
	# Bottom width = 3/4 of pile width
	var bottom_half_width := pile_half_width * 0.75
	
	# Height = distance from magnet to bottom of screen
	var screen_height := get_viewport().get_visible_rect().size.y
	var field_height := screen_height - global_position.y
	
	# Create trapezoid: top = magnet width, bottom = pile spawn width
	var top_left := Vector2(-magnet_width * 0.5, 0)
	var top_right := Vector2(magnet_width * 0.5, 0)
	var bottom_right := Vector2(bottom_half_width, field_height)
	var bottom_left := Vector2(-bottom_half_width, field_height)
	
	var trapezoid := ConvexPolygonShape2D.new()
	trapezoid.points = PackedVector2Array([top_left, top_right, bottom_right, bottom_left])
	_field_shape.shape = trapezoid
	
	# Create edge collision walls to keep items within the pull area
	_update_edge_walls(top_left, bottom_left, top_right, bottom_right)


## Reset the pity counter (called when a salvageable item is pulled).
func reset_pity_counter() -> void:
	_salvageable_pull_count = 0


## Increment the pity counter (called when a non-salvageable item is pulled).
func increment_pity_counter() -> void:
	_salvageable_pull_count += 1


## Get the current pity counter value.
func get_pity_counter() -> int:
	return _salvageable_pull_count


## Get the total threat cost for activating the magnet over the given pile.
func get_activation_threat_cost(pile_data: SalvagePileData = null) -> float:
	if pile_data:
		return pile_data.get_activation_threat_cost(threat_penalty)
	return threat_penalty


## Update magnet visuals (sprite size) and collision shape based on magnet_width.
func _update_magnet_visuals() -> void:
	if _magnet_sprite:
		_magnet_sprite.target_size.x = magnet_width
	if _body_shape and _body_shape.shape is RectangleShape2D:
		var rect_shape := _body_shape.shape as RectangleShape2D
		rect_shape.size = Vector2(magnet_width, 44.0)
	_sync_enemy_hitbox_to_body_shape()


func _update_pull_state() -> void:
	var was_suspended := _is_pull_suspended_by_capacity
	_is_pull_suspended_by_capacity = _is_active and is_at_capacity

	if _area:
		_area.monitoring = _is_active

	if _effect_animation:
		var should_show_effect := _is_active and not _is_pull_suspended_by_capacity
		_effect_animation.visible = should_show_effect
		if should_show_effect:
			if not _effect_animation.is_playing():
				_effect_animation.play("default")
		else:
			_effect_animation.stop()

	if _is_pull_suspended_by_capacity and not was_suspended:
		_release_uncounted_tracked_items()
		capacity_reached.emit()


func _on_tracked_item_frozen(item: SalvageItem) -> void:
	if not _is_active:
		return
	if item not in _attached_items:
		return
	if item in _counted_items:
		return

	_counted_items.append(item)
	_held_count += 1
	_update_pull_state()
	item_attached.emit(item)


func _remove_counted_item(item: SalvageItem) -> bool:
	if item not in _counted_items:
		return false

	_counted_items.erase(item)
	_held_count = maxi(_held_count - 1, 0)
	return true


func _release_uncounted_tracked_items() -> void:
	var items_to_release: Array[SalvageItem] = []
	for item in _attached_items:
		if is_instance_valid(item) and item not in _counted_items:
			items_to_release.append(item)

	for item in items_to_release:
		_attached_items.erase(item)
		if item.frozen.is_connected(_on_tracked_item_frozen):
			item.frozen.disconnect(_on_tracked_item_frozen)
		item.release_from_magnet()


func _sync_enemy_hitbox_to_body_shape() -> void:
	var hitbox := get_hitbox()
	if not hitbox or not _body_shape:
		return

	var hitbox_collision_shape := _get_first_hitbox_collision_shape(hitbox)
	var hitbox_collision_polygon := _get_first_hitbox_collision_polygon(hitbox)

	if _body_shape.shape is RectangleShape2D:
		var rect_shape := _body_shape.shape as RectangleShape2D
		var rect_size := rect_shape.size
		if hitbox_collision_shape and hitbox_collision_shape.shape is RectangleShape2D:
			var hitbox_rect := hitbox_collision_shape.shape as RectangleShape2D
			hitbox_rect.size = rect_size
			hitbox_collision_shape.position = _body_shape.position
		elif hitbox_collision_polygon:
			hitbox_collision_polygon.polygon = PackedVector2Array([
				Vector2(-rect_size.x * 0.5, -rect_size.y * 0.5),
				Vector2(rect_size.x * 0.5, -rect_size.y * 0.5),
				Vector2(rect_size.x * 0.5, rect_size.y * 0.5),
				Vector2(-rect_size.x * 0.5, rect_size.y * 0.5),
			])
			hitbox_collision_polygon.position = _body_shape.position


func _get_first_hitbox_collision_shape(hitbox: Hitbox) -> CollisionShape2D:
	var shapes := hitbox.find_children("*", "CollisionShape2D", true, false)
	if shapes.is_empty():
		return null
	return shapes[0] as CollisionShape2D


func _get_first_hitbox_collision_polygon(hitbox: Hitbox) -> CollisionPolygon2D:
	var polygons := hitbox.find_children("*", "CollisionPolygon2D", true, false)
	if polygons.is_empty():
		return null
	return polygons[0] as CollisionPolygon2D


## Create or update edge collision walls along the trapezoid edges.
func _update_edge_walls(top_left: Vector2, bottom_left: Vector2, top_right: Vector2, bottom_right: Vector2) -> void:
	# Create walls if they don't exist
	if not _left_wall:
		_left_wall = StaticBody2D.new()
		_left_wall.collision_layer = 1  # Boundary layer (NOT magnet layer 4)
		_left_wall.collision_mask = 2  # Collide with salvage items
		_left_wall.physics_material_override = _create_edge_wall_material()
		var new_left_shape := CollisionShape2D.new()
		new_left_shape.shape = ConvexPolygonShape2D.new()
		_left_wall.add_child(new_left_shape)
		add_child(_left_wall)
	
	if not _right_wall:
		_right_wall = StaticBody2D.new()
		_right_wall.collision_layer = 1  # Boundary layer (NOT magnet layer 4)
		_right_wall.collision_mask = 2  # Collide with salvage items
		_right_wall.physics_material_override = _create_edge_wall_material()
		var new_right_shape := CollisionShape2D.new()
		new_right_shape.shape = ConvexPolygonShape2D.new()
		_right_wall.add_child(new_right_shape)
		add_child(_right_wall)
	
	# Calculate wall polygons (thin rectangles along each edge)
	# Left wall: offset inward by wall thickness
	var left_dir := (top_left - bottom_left).normalized()
	var left_normal := Vector2(left_dir.y, -left_dir.x)  # Perpendicular, pointing inward (right)
	
	var left_poly := PackedVector2Array([
		bottom_left,
		top_left,
		top_left + left_normal * WALL_THICKNESS,
		bottom_left + left_normal * WALL_THICKNESS
	])
	
	# Right wall: offset inward by wall thickness
	var right_dir := (top_right - bottom_right).normalized()
	var right_normal := Vector2(-right_dir.y, right_dir.x)  # Perpendicular, pointing inward (left)
	
	var right_poly := PackedVector2Array([
		bottom_right,
		top_right,
		top_right + right_normal * WALL_THICKNESS,
		bottom_right + right_normal * WALL_THICKNESS
	])
	
	# Update shapes
	var left_shape := _left_wall.get_child(0) as CollisionShape2D
	if left_shape and left_shape.shape is ConvexPolygonShape2D:
		(left_shape.shape as ConvexPolygonShape2D).points = left_poly
	
	var right_shape := _right_wall.get_child(0) as CollisionShape2D
	if right_shape and right_shape.shape is ConvexPolygonShape2D:
		(right_shape.shape as ConvexPolygonShape2D).points = right_poly


func _create_edge_wall_material() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = EDGE_WALL_FRICTION
	material.bounce = EDGE_WALL_BOUNCE
	material.rough = true
	return material


# ============================================================================
# NEW AREA-BASED PULL SYSTEM (Stubs)
# ============================================================================

## Called when an item enters the magnetic field area
func _on_item_entered_field(item: SalvageItem) -> void:
	if item not in _items_in_field:
		_items_in_field.append(item)
		# Set surface line reference on item for Phase 2 detection
		if _pile_node:
			item.set_surface_line(_pile_node.get_surface_line())


## Called when an item exits the magnetic field area
func _on_item_exited_field(item: SalvageItem) -> void:
	_items_in_field.erase(item)


## Apply pull force to all unfrozen items in the field (called each frame)
func _apply_pull_to_field_items(delta: float) -> void:
	# Clean up invalid items
	_items_in_field = _items_in_field.filter(func(item): return is_instance_valid(item))
	
	for item in _items_in_field:
		# Skip frozen items - they don't receive pull force
		if item._is_frozen:
			continue
		
		# Check for phase transitions
		item._check_phase_transition()
		
		# Get pull speed based on current phase
		var speed := item._process_pull_phase(delta)
		
		# Apply pull velocity in the item's pull direction
		item.linear_velocity = item._pull_direction * speed
		
		# Apply soft-body collision forces
		item._apply_soft_collision_forces(delta)
		
		# Check if item should freeze
		item._check_freeze_condition(delta)


## Get the surface line from the current pile (for Phase 2 detection)
func get_surface_line() -> Line2D:
	if _pile_node and _pile_node.has_method("get_surface_line"):
		return _pile_node.get_surface_line()
	return null


func take_damage(amount: float) -> void:
	current_health = maxf(current_health - amount, 0.0)


func get_hitbox() -> Hitbox:
	var hitboxes := find_children("*", "Hitbox", true, false)
	if hitboxes.is_empty():
		return null
	return hitboxes[0] as Hitbox


func get_enemy_target_points() -> Array[EnemyTargetPoint]:
	var points: Array[EnemyTargetPoint] = []
	for child in find_children("*", "EnemyTargetPoint", true, false):
		var point := child as EnemyTargetPoint
		if point and point.category == EnemyData.TargetCategory.MAGNET and point.is_target_enabled():
			points.append(point)
	return points
