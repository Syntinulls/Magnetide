extends CharacterBody2D
class_name Player

@export var speed: float = 400.0
@export var jump_velocity: float = -600.0
@export var gravity: float = 1600.0
@export_group("Combat")
@export var max_health: float = 100.0

## Equipment slots - indices match hotbar slots
@export var equipment: Array[EquipmentData] = []

const BulletScene: PackedScene = preload("res://_project/player/bullet.tscn")
const MagnetEffectTexture: Texture2D = preload("res://icon.svg")

var input_enabled: bool = true
var facing_right: bool = false
var magnet_effect: Sprite2D = null
var current_health: float = 0.0
var _fire_cooldown: float = 0.0
var _selected_equipment_index: int = 0

## Currently selected equipment
var current_equipment: EquipmentData:
	get:
		if _selected_equipment_index >= 0 and _selected_equipment_index < equipment.size():
			return equipment[_selected_equipment_index]
		return null

## Convenience getter for current weapon (if equipped)
var current_weapon_data: WeaponData:
	get:
		var equip := current_equipment
		return equip as WeaponData if equip is WeaponData else null

## Convenience getter for current magnet tool (if equipped)
var current_magnet_tool: MagnetToolData:
	get:
		var equip := current_equipment
		return equip as MagnetToolData if equip is MagnetToolData else null

## Pull config - read from current magnet tool or use defaults
var pull_base_speed: float:
	get:
		var tool := current_magnet_tool
		return tool.pull_base_speed if tool else 133.0

var pull_max_speed: float:
	get:
		var tool := current_magnet_tool
		return tool.pull_max_speed if tool else 1000.0

var pull_ramp_time: float:
	get:
		var tool := current_magnet_tool
		return tool.pull_ramp_time if tool else 0.6

# Magnet gun state
var _held_item: SalvageItem = null
var _hovered_item: SalvageItem = null
var _repel_hold_elapsed: float = 0.0
var _is_repel_holding: bool = false
var _repel_bar: ColorRect = null
var _repel_bar_bg: ColorRect = null
var _repel_bar_container: Control = null

@onready var body_sprite: Sprite2D = $BodySprite
@onready var legs_sprite: AnimatedSprite2D = $LegsSprite
@onready var arm_sprite: Sprite2D = $ArmSprite
@onready var weapon_sprite: Sprite2D = $ArmSprite/Weapon
@onready var muzzle: Marker2D = $ArmSprite/Weapon/Muzzle


func _ready() -> void:
	current_health = max_health
	# Initialize facing based on current mouse position
	var mouse_pos := get_global_mouse_position()
	var mouse_is_right := mouse_pos.x > global_position.x
	_apply_facing(mouse_is_right)
	_create_repel_bar()
	_apply_current_equipment()
	# Defer hotbar setup to ensure UI is ready
	call_deferred("_connect_hotbar")
	call_deferred("_populate_hotbar")


const ARM_OFFSET_X: float = -13.585
const ARM_POSITION_X: float = 12.56


func _apply_facing(new_facing_right: bool) -> void:
	facing_right = new_facing_right
	if not body_sprite:
		return
	body_sprite.flip_h = facing_right
	legs_sprite.flip_h = facing_right
	arm_sprite.flip_h = facing_right
	weapon_sprite.flip_h = facing_right
	# Negate x-offset and x-position when flipped to keep pivot point correct
	var offset_mult := -1.0 if facing_right else 1.0
	arm_sprite.offset.x = ARM_OFFSET_X * offset_mult
	arm_sprite.position.x = ARM_POSITION_X * offset_mult
	_apply_equipment_positioning(offset_mult)


func _facing_mult() -> float:
	return -1.0 if facing_right else 1.0


func _apply_equipment_positioning(offset_mult: float) -> void:
	var equip := current_equipment
	if equip is WeaponData:
		var wpn := equip as WeaponData
		weapon_sprite.offset = Vector2(wpn.weapon_offset.x * offset_mult, wpn.weapon_offset.y)
		weapon_sprite.rotation = wpn.weapon_rotation * offset_mult
		muzzle.position = Vector2(wpn.muzzle_position.x * offset_mult, wpn.muzzle_position.y)
	elif equip is MagnetToolData:
		var tool := equip as MagnetToolData
		weapon_sprite.offset = Vector2(tool.weapon_offset.x * offset_mult, tool.weapon_offset.y)
		weapon_sprite.rotation = tool.weapon_rotation * offset_mult
		muzzle.position = Vector2(tool.muzzle_position.x * offset_mult, tool.muzzle_position.y)


func _physics_process(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if input_enabled:
		var mouse_pos := get_global_mouse_position()
		
		# Facing is purely based on mouse X vs player X
		var mouse_is_right := mouse_pos.x > global_position.x
		if mouse_is_right != facing_right:
			var was_holding := _held_item and is_instance_valid(_held_item)
			_apply_facing(mouse_is_right)
			# Flip held item position when player flips
			if was_holding and _held_item:
				_held_item.flip_relative_to_anchor(global_position)
		
		# Calculate vertical angle from arm to mouse
		# Use arm's global position for accurate angle calculation
		var delta_y := mouse_pos.y - arm_sprite.global_position.y
		var delta_x := absf(mouse_pos.x - arm_sprite.global_position.x)
		
		# atan2 with abs(delta_x) gives us angle from horizontal
		# Positive delta_y = mouse below = negative rotation (down)
		# Negative delta_y = mouse above = positive rotation (up)
		var arm_rotation := -atan2(delta_y, delta_x)
		
		# Clamp to -90° to 90° range
		arm_rotation = clampf(arm_rotation, -PI / 2, PI / 2)
		# When facing right, flip_h mirrors the sprite so we negate the rotation
		if facing_right:
			arm_rotation = -arm_rotation
		arm_sprite.rotation = arm_rotation
		
		var equip := current_equipment
		if equip is WeaponData:
			_process_weapon_input(delta)
		elif equip is MagnetToolData:
			_process_magnet_tool_input(delta)
		
		if Input.is_action_just_pressed("move_jump") and is_on_floor():
			velocity.y = jump_velocity
		
		var direction := Input.get_axis("move_left", "move_right")
		velocity.x = direction * speed
	else:
		velocity.x = 0.0
	
	if not is_on_floor():
		velocity.y += gravity * delta
	
	move_and_slide()
	
	_update_leg_animation()


func _update_leg_animation() -> void:
	var current_anim := legs_sprite.animation
	
	if not is_on_floor():
		legs_sprite.speed_scale = 1.0
		if velocity.y < 0.0:
			if current_anim != "bend":
				legs_sprite.play("bend")
		else:
			if current_anim != "bend":
				legs_sprite.play("bend")
		return
	
	var is_moving: bool = abs(velocity.x) > 0.1
	if is_moving:
		var moving_right: bool = velocity.x > 0.0
		var walking_backwards: bool = moving_right != facing_right
		if current_anim != "walk":
			legs_sprite.play("walk")
		legs_sprite.speed_scale = -1.0 if walking_backwards else 1.0
	elif current_anim != "idle":
		legs_sprite.play("idle")
		legs_sprite.speed_scale = 1.0


func _connect_hotbar() -> void:
	call_deferred("_setup_hotbar_connection")


func _setup_hotbar_connection() -> void:
	var hotbar := Magnetide.hotbar
	if hotbar:
		hotbar.slot_selected.connect(_on_hotbar_slot_selected)
	else:
		push_warning("Player: Hotbar not found")


func _on_hotbar_slot_selected(index: int) -> void:
	_switch_to_equipment(index)


func _switch_to_equipment(index: int) -> void:
	if index == _selected_equipment_index:
		return
	if index < 0 or index >= equipment.size():
		return
	
	_cleanup_current_equipment()
	_selected_equipment_index = index
	_apply_current_equipment()


func _cleanup_current_equipment() -> void:
	var equip := current_equipment
	if equip is MagnetToolData:
		stop_magnetize()
		_clear_magnet_gun_state()


func _apply_current_equipment() -> void:
	if not weapon_sprite:
		return
	var equip := current_equipment
	if equip is WeaponData:
		var wpn := equip as WeaponData
		weapon_sprite.texture = wpn.weapon_sprite
	elif equip is MagnetToolData:
		var tool := equip as MagnetToolData
		weapon_sprite.texture = tool.weapon_sprite
	elif equip == null:
		weapon_sprite.texture = null
	# If equip exists but type not recognized, keep existing texture
	_apply_equipment_positioning(_facing_mult())


func _populate_hotbar() -> void:
	var hotbar := Magnetide.hotbar
	if not hotbar:
		return
	var items: Array = []
	for equip in equipment:
		if equip:
			items.append({ "icon": equip.hotbar_icon, "data": equip })
		else:
			items.append({ "icon": null, "data": null })
	hotbar.set_all_slots(items)


func _process_weapon_input(_delta: float) -> void:
	if Input.is_action_pressed("shoot") and _fire_cooldown <= 0.0:
		shoot()


func _process_magnet_tool_input(delta: float) -> void:
	_process_magnet_gun(delta)


func shoot() -> void:
	var wpn := current_weapon_data
	if not wpn:
		return
	_fire_cooldown = 1.0 / wpn.fire_rate
	var bullet := BulletScene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = (get_global_mouse_position() - global_position).normalized()
	bullet.damage = wpn.damage
	bullet.speed = wpn.bullet_speed
	if wpn.bullet_sprite:
		bullet.get_node("Sprite2D").texture = wpn.bullet_sprite
	get_tree().current_scene.add_child(bullet)


func magnetize() -> void:
	if magnet_effect != null:
		return
	magnet_effect = Sprite2D.new()
	magnet_effect.texture = MagnetEffectTexture
	magnet_effect.scale = Vector2(0.5, 0.5)
	muzzle.add_child(magnet_effect)


func stop_magnetize() -> void:
	if magnet_effect != null:
		magnet_effect.queue_free()
		magnet_effect = null


# =============================================================================
# Magnet Gun Logic
# =============================================================================

func _get_magnet_gun_hold_point() -> Vector2:
	var tool := current_magnet_tool
	var hold_dist := tool.hold_distance if tool else 30.0
	var gun_dir := (muzzle.global_position - arm_sprite.global_position).normalized()
	return muzzle.global_position + gun_dir * hold_dist


func _process_magnet_gun(delta: float) -> void:
	if _held_item and is_instance_valid(_held_item):
		# Update held item position to follow gun
		_held_item.update_gun_hold_position(_get_magnet_gun_hold_point())
		
		# Only allow repel/place once item has reached the anchor point
		if _held_item.has_reached_anchor:
			# Right-click hold to repel
			if Input.is_action_pressed("shoot_alt"):
				_is_repel_holding = true
				_repel_hold_elapsed += delta
				_update_repel_bar()
				var tool := current_magnet_tool
				var repel_time := tool.repel_hold_time if tool else 0.8
				if _repel_hold_elapsed >= repel_time:
					_repel_held_item()
			else:
				if _is_repel_holding:
					# Released too early - reset
					_is_repel_holding = false
					_repel_hold_elapsed = 0.0
					_update_repel_bar()
			
			# Left-click to place in storage
			if Input.is_action_just_pressed("shoot"):
				var mouse_pos := get_global_mouse_position()
				var ship_node := _get_ship()
				if ship_node and ship_node.is_point_in_storage_area(mouse_pos):
					_place_item_in_storage(mouse_pos)
	else:
		# No item held - hover detection and grab
		_process_magnet_gun_hover()
		
		if Input.is_action_just_pressed("shoot"):
			if _hovered_item and is_instance_valid(_hovered_item):
				_grab_item_from_magnet(_hovered_item)


func _process_magnet_gun_hover() -> void:
	var mouse_pos := get_global_mouse_position()
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collision_mask = 2  # Salvage items layer
	query.collide_with_bodies = true
	var results := space_state.intersect_point(query, 8)
	
	var best_item: SalvageItem = null
	var best_dist := INF
	for result in results:
		var body: Object = result["collider"]
		if body is SalvageItem:
			var item := body as SalvageItem
			if item.can_be_grabbed:
				var dist := mouse_pos.distance_to(item.global_position)
				if dist < best_dist:
					best_dist = dist
					best_item = item
	
	# Update outline
	if _hovered_item != best_item:
		if _hovered_item and is_instance_valid(_hovered_item):
			_hovered_item.set_outlined(false)
		_hovered_item = best_item
		if _hovered_item:
			_hovered_item.set_outlined(true)


func _grab_item_from_magnet(item: SalvageItem) -> void:
	if _held_item != null:
		return  # Already holding an item
	
	# Get contact chain before grabbing (items that need to re-settle)
	var dependents := item.get_contact_chain()
	
	# Remove from magnet tracking
	var magnet := Magnetide.magnet
	if magnet:
		magnet.remove_item(item)
	
	# Grab the item
	item.set_outlined(false)
	item.grab_for_magnet_gun(self)
	item.update_gun_hold_position(_get_magnet_gun_hold_point())
	_held_item = item
	_hovered_item = null
	
	# Unfreeze dependent items so they can re-settle
	for dep in dependents:
		if is_instance_valid(dep) and dep != item and dep.is_attached_to_magnet:
			_unfreeze_item_for_resettle(dep)


func _unfreeze_item_for_resettle(item: SalvageItem) -> void:
	# Use the new unfreeze API on SalvageItem
	item.unfreeze_for_resettle()
	
	# Reparent to scene root (out of Magnet) so physics runs normally
	var magnet := Magnetide.magnet
	var scene_root := get_tree().current_scene
	if scene_root and item.get_parent() != scene_root:
		var pos := item.global_position
		item.reparent(scene_root)
		item.global_position = pos
	
	# Re-start the magnet pull so the item flies back and re-attaches
	if magnet:
		item.start_magnet_pull(magnet)


func _repel_held_item() -> void:
	if not _held_item or not is_instance_valid(_held_item):
		return
	
	# Calculate repel direction (away from gun, toward where gun is pointing)
	var tool := current_magnet_tool
	var repel_force := tool.repel_impulse_force if tool else 600.0
	var gun_dir := (muzzle.global_position - arm_sprite.global_position).normalized()
	var impulse := gun_dir * repel_force
	
	_held_item.repel_from_gun(impulse)
	_held_item = null
	_is_repel_holding = false
	_repel_hold_elapsed = 0.0
	_update_repel_bar()


func _place_item_in_storage(mouse_pos: Vector2) -> void:
	if not _held_item or not is_instance_valid(_held_item):
		return
	
	var ship_node := _get_ship()
	if not ship_node:
		return
	
	_held_item.place_in_storage(mouse_pos)
	ship_node.add_to_storage(_held_item)
	_held_item = null
	_is_repel_holding = false
	_repel_hold_elapsed = 0.0
	_update_repel_bar()


func _clear_magnet_gun_state() -> void:
	# Clear hover
	if _hovered_item and is_instance_valid(_hovered_item):
		_hovered_item.set_outlined(false)
	_hovered_item = null
	
	# Force-release held item
	if _held_item and is_instance_valid(_held_item):
		_held_item.force_release_from_gun()
	_held_item = null
	
	_is_repel_holding = false
	_repel_hold_elapsed = 0.0
	_update_repel_bar()


func _get_ship() -> Node2D:
	var parent := get_parent()
	if parent and parent.has_method("is_point_in_storage_area"):
		return parent as Node2D
	return null


# =============================================================================
# Repel Progress Bar
# =============================================================================

const REPEL_BAR_WIDTH: float = 40.0
const REPEL_BAR_HEIGHT: float = 6.0
const REPEL_BAR_OFFSET_Y: float = -70.0

func _create_repel_bar() -> void:
	# Defer to ensure GameUI is ready
	call_deferred("_setup_repel_bar")


func _setup_repel_bar() -> void:
	var game_ui := Magnetide.game_ui
	if not game_ui:
		push_warning("Player: GameUI not found, repel bar will not be created")
		return
	
	_repel_bar_container = Control.new()
	_repel_bar_container.name = "RepelBarContainer"
	_repel_bar_container.visible = false
	_repel_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(_repel_bar_container)
	
	# Background
	_repel_bar_bg = ColorRect.new()
	_repel_bar_bg.size = Vector2(REPEL_BAR_WIDTH, REPEL_BAR_HEIGHT)
	_repel_bar_bg.position = Vector2(-REPEL_BAR_WIDTH * 0.5, 0)
	_repel_bar_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	_repel_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_repel_bar_container.add_child(_repel_bar_bg)
	
	# Fill bar
	_repel_bar = ColorRect.new()
	_repel_bar.size = Vector2(0, REPEL_BAR_HEIGHT)
	_repel_bar.position = Vector2(-REPEL_BAR_WIDTH * 0.5, 0)
	_repel_bar.color = Color(1.0, 0.3, 0.2, 0.9)
	_repel_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_repel_bar_container.add_child(_repel_bar)


func _update_repel_bar() -> void:
	if not _repel_bar_container:
		return
	_repel_bar_container.visible = _is_repel_holding
	if _is_repel_holding:
		# Position bar above player's head in screen space
		var screen_pos := get_viewport().get_canvas_transform() * (global_position + Vector2(0, REPEL_BAR_OFFSET_Y))
		_repel_bar_container.position = screen_pos
		if _repel_bar:
			var tool := current_magnet_tool
			var repel_time := tool.repel_hold_time if tool else 0.8
			var fill := clampf(_repel_hold_elapsed / repel_time, 0.0, 1.0)
			_repel_bar.size.x = REPEL_BAR_WIDTH * fill


## Called externally when looting ends to clean up hover state (but keep held item)
func on_looting_ended() -> void:
	# Clear hover only - player keeps any item held by magnet gun
	if _hovered_item and is_instance_valid(_hovered_item):
		_hovered_item.set_outlined(false)
	_hovered_item = null


func take_damage(amount: float) -> void:
	current_health = maxf(current_health - amount, 0.0)


func get_hitbox() -> Hitbox:
	var hitboxes := find_children("*", "Hitbox", true, false)
	if hitboxes.is_empty():
		return null
	return hitboxes[0] as Hitbox
