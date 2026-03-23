extends Node2D
class_name Magnet

signal item_attached(item: SalvageItem)
signal item_removed(item: SalvageItem)
signal overweight()
signal all_items_released()

## Maximum carry weight before the magnet stops pulling new items.
@export var max_carry_weight: float = 60.0
## Base speed items are pulled toward the magnet.
@export var pull_base_speed: float = 200.0
## Max speed items are pulled toward the magnet.
@export var pull_max_speed: float = 1500.0
## Time for pull speed to ramp from base to max.
@export var pull_ramp_time: float = 0.6
## Time between pulling new items from the pile in seconds.
@export var pull_interval: float = 2.5
## Distance the magnet lowers from its starting position when activated.
@export var lower_distance: float = 80.0
## Time to lower/raise the magnet in seconds.
@export var lower_raise_time: float = 0.8
## Threat penalty per magnet activation. Affected by upgrades.
@export var threat_penalty: float = 10.0

var _is_active: bool = false
var _attached_items: Array[SalvageItem] = []
var _current_weight: float = 0.0
var _pull_timer: float = 0.0
var _pile_data: SalvagePileData = null
var _current_threat_level: int = 0
var _pile_node: SalvagePile = null
var _salvageable_pull_count: int = 0
var _original_position: Vector2 = Vector2.ZERO
var _is_lowering: bool = false
var _is_raising: bool = false
var _lower_elapsed: float = 0.0
var _area: Area2D = null
var _field_shape: CollisionShape2D = null
var _effect_animation: AnimatedSprite2D = null
const MAGNET_HALF_WIDTH: float = 50.0  # Half width of magnet collision strip
const SPAWN_WIDTH_RATIO: float = 0.50  # Must match spawn ratio in _spawn_item_from_pile

var current_weight: float:
	get:
		return _current_weight

var is_overweight: bool:
	get:
		return _current_weight >= max_carry_weight

var is_active: bool:
	get:
		return _is_active


func _ready() -> void:
	set_process(false)
	_area = get_node_or_null("Area2D") as Area2D
	if _area:
		_area.body_entered.connect(_on_body_entered)
		_field_shape = _area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_effect_animation = get_node_or_null("EffectAnimation") as AnimatedSprite2D


func activate(pile_data: SalvagePileData, pile: SalvagePile, threat_level: int = 0) -> void:
	_pile_data = pile_data
	_pile_node = pile
	_current_threat_level = threat_level
	_is_active = true
	_pull_timer = 0.0
	_current_weight = 0.0
	_attached_items.clear()
	_original_position = position
	
	# Resize magnetic field trapezoid based on pile
	_update_field_shape_for_pile(pile)
	
	# Show and play effect animation
	if _effect_animation:
		_effect_animation.visible = true
		_effect_animation.play("default")

	# Start lowering
	_is_lowering = true
	_is_raising = false
	_lower_elapsed = 0.0
	set_process(true)


func deactivate() -> void:
	_is_active = false
	_pile_data = null
	_pile_node = null
	_release_all_items()
	
	# Hide and stop effect animation
	if _effect_animation:
		_effect_animation.stop()
		_effect_animation.visible = false

	# Start raising back to original position
	_is_raising = true
	_is_lowering = false
	_lower_elapsed = 0.0


func _release_all_items() -> void:
	# Release tracked items
	for item in _attached_items:
		if is_instance_valid(item):
			item.release_from_magnet()
	_attached_items.clear()
	
	# Also release any SalvageItem children that may have been reparented to magnet
	for child in get_children():
		if child is SalvageItem:
			child.release_from_magnet()
	
	_current_weight = 0.0
	all_items_released.emit()


func _process(delta: float) -> void:
	if _is_lowering:
		_process_lowering(delta)
		return

	if _is_raising:
		_process_raising(delta)
		return

	if not _is_active:
		return

	_pull_timer += delta
	if _pull_timer >= pull_interval and not is_overweight:
		_pull_timer = 0.0
		_spawn_item_from_pile()


func _process_lowering(delta: float) -> void:
	_lower_elapsed += delta
	var t := clampf(_lower_elapsed / lower_raise_time, 0.0, 1.0)
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	position.y = _original_position.y + lower_distance * eased

	if t >= 1.0:
		_is_lowering = false
		# Pull first item immediately
		if _is_active and not is_overweight:
			_spawn_item_from_pile()


func _process_raising(delta: float) -> void:
	_lower_elapsed += delta
	var t := clampf(_lower_elapsed / lower_raise_time, 0.0, 1.0)
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	var target_y := _original_position.y
	var start_y := _original_position.y + lower_distance
	position.y = lerpf(start_y, target_y, eased)

	if t >= 1.0:
		position = _original_position
		_is_raising = false
		set_process(false)


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
	if _current_weight + data.weight > max_carry_weight:
		overweight.emit()
		return

	var item := SalvageItem.new()
	# Add to scene tree at a scope that persists
	get_tree().current_scene.add_child(item)
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

	# Start pulling toward magnet
	item.start_magnet_pull(self)
	item.fell_off_screen.connect(_on_item_fell_off_screen)

	if is_overweight:
		overweight.emit()


func remove_item(item: SalvageItem) -> void:
	if item in _attached_items:
		_attached_items.erase(item)
		if item.item_data:
			_current_weight -= item.item_data.weight
			_current_weight = maxf(_current_weight, 0.0)
		item_removed.emit(item)


func get_attached_items() -> Array[SalvageItem]:
	return _attached_items


func _on_item_fell_off_screen(item: SalvageItem) -> void:
	_attached_items.erase(item)


func _on_body_entered(body: Node2D) -> void:
	if not _is_active:
		return
	
	var item := body as SalvageItem
	if not item or item in _attached_items:
		return
	
	# Check weight capacity
	if item.item_data and _current_weight + item.item_data.weight > max_carry_weight:
		overweight.emit()
		return
	
	# Item entered magnet field - enable gravity mode
	item.enter_magnet_field()
	
	# Track weight and item
	if item.item_data:
		_current_weight += item.item_data.weight
	_attached_items.append(item)
	item_attached.emit(item)
	
	if is_overweight:
		overweight.emit()


func _update_field_shape_for_pile(pile: SalvagePile) -> void:
	if not _field_shape:
		return
	
	# Calculate pile spawn width
	var pile_half_width := 100.0  # Default fallback
	var pile_sprite := pile.get_node_or_null("Sprite2D") as Sprite2D
	if pile_sprite and pile_sprite.texture:
		pile_half_width = pile_sprite.texture.get_size().x * pile.scale.x * 0.5
	
	# Bottom width = pile spawn width (35% of pile width on each side)
	var bottom_half_width := pile_half_width * SPAWN_WIDTH_RATIO
	
	# Height = distance from magnet to bottom of screen
	var screen_height := get_viewport().get_visible_rect().size.y
	var field_height := screen_height - global_position.y
	
	# Create trapezoid: top = magnet width, bottom = pile spawn width
	var trapezoid := ConvexPolygonShape2D.new()
	trapezoid.points = PackedVector2Array([
		Vector2(-MAGNET_HALF_WIDTH, 0),  # Top left
		Vector2(MAGNET_HALF_WIDTH, 0),   # Top right
		Vector2(bottom_half_width, field_height),   # Bottom right
		Vector2(-bottom_half_width, field_height)   # Bottom left
	])
	_field_shape.shape = trapezoid


## Reset the pity counter (called when a salvageable item is pulled).
func reset_pity_counter() -> void:
	_salvageable_pull_count = 0


## Increment the pity counter (called when a non-salvageable item is pulled).
func increment_pity_counter() -> void:
	_salvageable_pull_count += 1


## Get the current pity counter value.
func get_pity_counter() -> int:
	return _salvageable_pull_count
