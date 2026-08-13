extends CharacterBody2D
class_name Player

## The player character body: movement, jumping, knockback, facing/aim and the
## walk/leg animations. Everything else is delegated to component children
## (health, equipment + per-item behaviors, world interaction, scrap
## collection, the shared progress bar). Cross-concept combat calls
## (take_damage etc.) land here and forward to the health component.

signal cinematic_walk_finished

@export var speed: float = 400.0
## Exponential damping applied per second to horizontal enemy knockback; higher
## values stop the push sooner.
@export var knockback_damping: float = 8.0

const ARM_OFFSET_X: float = -13.585
const ARM_POSITION_X: float = 12.56
const JUMP_SFX := "player/jump_metal_1_1.ogg"
const JUMP_SFX_VOLUME_DB := -6.0
const LAND_SFX := "player/jump_metal_1_2.ogg"
const LAND_SFX_VOLUME_DB := -6.0
const FOOTSTEP_SFX: Array[String] = [
	"player/metal_footstep_1.ogg",
	"player/metal_footstep_2.ogg",
	"player/metal_footstep_3.ogg",
	"player/metal_footstep_4.ogg",
	"player/metal_footstep_5.ogg"
]
const FOOTSTEP_SFX_VOLUME_DB := -6.0
const FOOTSTEP_INTERVAL_SECONDS := 0.28
const FOOTSTEP_MIN_SPEED := 8.0
## Horizontal knockback speed (px/s) below which the residual push is dropped.
const KNOCKBACK_STOP_SPEED := 10.0
const DAMAGE_FLASH_FADE_SECONDS := 0.15

## Jump physics resolved from the run loadout on apply — derived from the
## loadout's jump max/min height and time-to-apex, never authored directly here.
var jump_velocity: float = -600.0
var jump_cut_velocity: float = -360.0
var gravity: float = 1600.0

var input_enabled: bool = true
## While true the player can neither receive nor deal damage (departure cutscene).
var combat_disabled: bool = false
var facing_right: bool = false
## Outgoing weapon damage multiplier applied to every projectile the player fires.
## Driven at runtime by augments (e.g. Adrenaline scales this with missing health).
var outgoing_damage_multiplier: float = 1.0

var _has_floor_state: bool = false
var _was_on_floor: bool = false
var _footstep_timer: float = 0.0
## Residual horizontal push from enemy knockback, re-added on top of the
## per-frame input velocity (which is rewritten every physics tick) and decayed
## by knockback_damping until it falls below KNOCKBACK_STOP_SPEED.
var _knockback_velocity_x: float = 0.0
var _damage_flash_tween: Tween = null
var _cinematic_walk_active: bool = false
var _cinematic_walk_target_x: float = 0.0
var _cinematic_walk_speed: float = 160.0
var _cinematic_walk_arrive_epsilon: float = 4.0

var _health: PlayerHealth = null
var _equipment: PlayerEquipment = null
var _interaction: PlayerInteraction = null
var _scrap_collector: PlayerScrapCollector = null
var _progress_bar: PlayerProgressBarController = null

@onready var body_sprite: Sprite2D = $BodySprite
@onready var legs_sprite: AnimatedSprite2D = $LegsSprite
@onready var arm_sprite: Sprite2D = $ArmSprite
@onready var weapon_sprite: Sprite2D = $ArmSprite/Weapon
@onready var muzzle: Marker2D = $ArmSprite/Weapon/Muzzle
@onready var muzzle_effect: MuzzleEffect = $ArmSprite/Weapon/Muzzle/MuzzleEffect
@onready var repair_beam: RepairBeam = $RepairBeam

## Component accessors resolve lazily (not @onready) because the run loadout is
## applied before the player enters the tree.
var health: PlayerHealth:
	get:
		if _health == null:
			_health = get_node_or_null(^"Health") as PlayerHealth
		return _health

var equipment: PlayerEquipment:
	get:
		if _equipment == null:
			_equipment = get_node_or_null(^"Equipment") as PlayerEquipment
		return _equipment

var interaction: PlayerInteraction:
	get:
		if _interaction == null:
			_interaction = get_node_or_null(^"Interaction") as PlayerInteraction
		return _interaction

var scrap_collector: PlayerScrapCollector:
	get:
		if _scrap_collector == null:
			_scrap_collector = get_node_or_null(^"ScrapCollector") as PlayerScrapCollector
		return _scrap_collector

var progress_bar: PlayerProgressBarController:
	get:
		if _progress_bar == null:
			_progress_bar = get_node_or_null(^"ProgressBarController") as PlayerProgressBarController
		return _progress_bar


func _ready() -> void:
	add_to_group("player")
	health.damaged.connect(_on_health_damaged)
	var mouse_pos := get_global_mouse_position()
	_apply_facing(mouse_pos.x > global_position.x)
	equipment.initialize()


func _physics_process(delta: float) -> void:
	var was_on_floor := _was_on_floor if _has_floor_state else is_on_floor()

	if _cinematic_walk_active:
		_process_cinematic_walk(delta)
	elif input_enabled and not Magnetide.is_ui_input_captured():
		var mouse_pos := get_global_mouse_position()

		# Facing is purely based on mouse X vs player X
		var mouse_is_right := mouse_pos.x > global_position.x
		if mouse_is_right != facing_right:
			_apply_facing(mouse_is_right)
			equipment.notify_facing_changed()

		_update_arm_aim(mouse_pos)
		equipment.process_current(delta)

		if equipment.get_held_item() == null:
			interaction.process_proximity()
		else:
			interaction.clear_proximity()

		# Variable-height jump: hold to reach max height, release early to cut to min.
		if is_on_floor() and Input.is_action_pressed("move_jump"):
			velocity.y = jump_velocity
			_play_jump_sfx()
		if Input.is_action_just_released("move_jump") and velocity.y < jump_cut_velocity:
			velocity.y = jump_cut_velocity

		var direction := Input.get_axis("move_left", "move_right")
		velocity.x = direction * speed
	else:
		velocity.x = 0.0
		equipment.process_blocked(delta)

	if _knockback_velocity_x != 0.0:
		velocity.x += _knockback_velocity_x
		_knockback_velocity_x *= exp(-knockback_damping * delta)
		if absf(_knockback_velocity_x) < KNOCKBACK_STOP_SPEED:
			_knockback_velocity_x = 0.0

	if not is_on_floor():
		velocity.y += gravity * delta

	move_and_slide()
	_update_floor_sfx_state(was_on_floor)
	_process_footstep_sfx(delta)
	_update_leg_animation()


func apply_run_loadout(loadout: RunLoadout) -> void:
	if loadout == null:
		return

	var is_runtime_reconfigure := is_inside_tree()

	speed = loadout.player_speed
	jump_velocity = loadout.get_player_jump_velocity()
	jump_cut_velocity = loadout.get_player_jump_cut_velocity()
	gravity = loadout.get_player_gravity()
	health.apply_loadout(loadout, is_runtime_reconfigure)
	equipment.apply_loadout(
		loadout.player_equipment,
		loadout.player_selected_equipment_index,
		is_runtime_reconfigure
	)


## Aim direction from the player toward the mouse cursor (weapons and the
## repair beam both fire along it).
func get_aim_direction() -> Vector2:
	var aim_direction := get_global_mouse_position() - global_position
	if aim_direction.length_squared() <= 0.0001:
		aim_direction = Vector2.RIGHT * (-facing_mult())
	return aim_direction.normalized()


func facing_mult() -> float:
	return -1.0 if facing_right else 1.0


func get_ship() -> Node2D:
	var parent := get_parent()
	if parent and parent.has_method("is_point_in_storage_area"):
		return parent as Node2D
	return null


## Discrete push from an enemy hit (e.g. a charger dash). The horizontal
## component decays exponentially over the following ticks; the vertical
## component is a one-time impulse that gravity resolves. Sent separately from
## take_damage so the push lands even when a shield absorbs the hit's damage.
func apply_knockback(impulse: Vector2) -> void:
	if health.current_health <= 0.0 or combat_disabled or health.invulnerable or _cinematic_walk_active:
		return
	_knockback_velocity_x = impulse.x
	velocity.y += impulse.y


## Combat contract, duck-typed by projectiles/enemies/storms against the body.
func take_damage(amount: float, source: Node = null) -> void:
	health.take_damage(amount, source)


func apply_storm_damage(amount: float) -> void:
	health.apply_storm_damage(amount)


func heal(amount: float) -> void:
	health.heal(amount)


## Called externally when looting ends to clean up hover state (but keep held item).
func on_looting_ended() -> void:
	equipment.notify_looting_ended()


func start_walk_to_ship_center_for_cutscene(target_local_x: float = 0.0, walk_speed: float = 160.0) -> void:
	input_enabled = false
	equipment.deactivate_current()
	_apply_facing(true)
	arm_sprite.rotation = 0.0
	_cinematic_walk_target_x = target_local_x
	_cinematic_walk_speed = maxf(walk_speed, 1.0)
	_cinematic_walk_active = true
	set_process(true)
	set_physics_process(true)


func is_cinematic_walk_active() -> bool:
	return _cinematic_walk_active


func stop_for_run_end() -> void:
	input_enabled = false
	velocity = Vector2.ZERO
	equipment.stop_for_run_end()
	progress_bar.clear_all()
	set_process(false)
	set_physics_process(false)


func get_hitbox() -> Hitbox:
	var hitboxes := find_children("*", "Hitbox", true, false)
	if hitboxes.is_empty():
		return null
	return hitboxes[0] as Hitbox


## Enemies aim here instead of the player's root (which sits at the feet). The
## point is a child of the hitbox's collision shape, so it always tracks the
## actual hitbox center.
func get_enemy_target_points() -> Array[EnemyTargetPoint]:
	var points: Array[EnemyTargetPoint] = []
	var point := get_node_or_null("Hitbox/CollisionShape2D/EnemyTargetPoint") as EnemyTargetPoint
	if point:
		points.append(point)
	return points


func _apply_facing(new_facing_right: bool) -> void:
	facing_right = new_facing_right
	if not body_sprite:
		return
	body_sprite.flip_h = facing_right
	legs_sprite.flip_h = facing_right
	arm_sprite.flip_h = facing_right
	weapon_sprite.flip_h = facing_right
	if muzzle_effect:
		muzzle_effect.flip_h = not facing_right
	# Negate x-offset and x-position when flipped to keep pivot point correct
	var offset_mult := -1.0 if facing_right else 1.0
	arm_sprite.offset.x = ARM_OFFSET_X * offset_mult
	arm_sprite.position.x = ARM_POSITION_X * offset_mult
	equipment.apply_facing(offset_mult)


func _update_arm_aim(mouse_pos: Vector2) -> void:
	# Use arm's global position for accurate angle calculation.
	var delta_y := mouse_pos.y - arm_sprite.global_position.y
	var delta_x := absf(mouse_pos.x - arm_sprite.global_position.x)

	# atan2 with abs(delta_x) gives the angle from horizontal:
	# positive delta_y = mouse below = negative rotation (down).
	var arm_rotation := -atan2(delta_y, delta_x)
	arm_rotation = clampf(arm_rotation, -PI / 2, PI / 2)
	# When facing right, flip_h mirrors the sprite so we negate the rotation
	if facing_right:
		arm_rotation = -arm_rotation
	arm_sprite.rotation = arm_rotation


func _process_cinematic_walk(_delta: float) -> void:
	var to_target := _cinematic_walk_target_x - position.x
	if absf(to_target) <= _cinematic_walk_arrive_epsilon:
		position.x = _cinematic_walk_target_x
		velocity.x = 0.0
		_cinematic_walk_active = false
		cinematic_walk_finished.emit()
		return

	var direction := signf(to_target)
	velocity.x = direction * _cinematic_walk_speed
	_apply_facing(direction > 0.0)


func _update_leg_animation() -> void:
	var current_anim := legs_sprite.animation

	if not is_on_floor():
		legs_sprite.speed_scale = 1.0
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


## Red half-opacity hit flash across every player sprite layer (they share one
## flash ShaderMaterial, so driving it through body_sprite tints all of them).
func _on_health_damaged(_amount: float) -> void:
	var flash_material := body_sprite.material as ShaderMaterial
	if flash_material == null:
		return
	if _damage_flash_tween:
		_damage_flash_tween.kill()
	flash_material.set_shader_parameter("flash_intensity", 1.0)
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(flash_material, "shader_parameter/flash_intensity", 0.0, DAMAGE_FLASH_FADE_SECONDS)


func _play_jump_sfx() -> void:
	if Magnetide.sfx and not JUMP_SFX.is_empty():
		Magnetide.sfx.play(JUMP_SFX, JUMP_SFX_VOLUME_DB)


func _play_land_sfx() -> void:
	if Magnetide.sfx and not LAND_SFX.is_empty():
		Magnetide.sfx.play(LAND_SFX, LAND_SFX_VOLUME_DB)


func _play_footstep_sfx() -> void:
	if not Magnetide.sfx or FOOTSTEP_SFX.is_empty():
		return
	Magnetide.sfx.play(FOOTSTEP_SFX[randi() % FOOTSTEP_SFX.size()], FOOTSTEP_SFX_VOLUME_DB)


func _process_footstep_sfx(delta: float) -> void:
	var is_grounded_walking := is_on_floor() and absf(velocity.x) >= FOOTSTEP_MIN_SPEED
	if not is_grounded_walking:
		_footstep_timer = 0.0
		return

	_footstep_timer -= delta
	if _footstep_timer > 0.0:
		return

	_play_footstep_sfx()
	_footstep_timer = FOOTSTEP_INTERVAL_SECONDS


func _update_floor_sfx_state(was_on_floor: bool) -> void:
	var is_now_on_floor := is_on_floor()
	if _has_floor_state and not was_on_floor and is_now_on_floor:
		_play_land_sfx()
		_footstep_timer = FOOTSTEP_INTERVAL_SECONDS * 0.5

	_was_on_floor = is_now_on_floor
	_has_floor_state = true
