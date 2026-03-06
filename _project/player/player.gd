extends CharacterBody2D
class_name Player

enum Weapon { GUN, MAGNET_GUN }

@export var speed: float = 400.0
@export var jump_velocity: float = -600.0
@export var gravity: float = 1600.0
@export var weapon: WeaponData

const BulletScene: PackedScene = preload("res://_project/player/bullet.tscn")
const MagnetGunTexture: Texture2D = preload("res://_project/player/guy_magnetgun.png")
const MagnetEffectTexture: Texture2D = preload("res://icon.svg")

var input_enabled: bool = true
var facing_right: bool = false
var current_weapon: Weapon = Weapon.GUN
var magnet_effect: Sprite2D = null
var _fire_cooldown: float = 0.0

@onready var body_sprite: Sprite2D = $BodySprite
@onready var legs_sprite: AnimatedSprite2D = $LegsSprite
@onready var arm_sprite: Sprite2D = $ArmSprite
@onready var weapon_sprite: Sprite2D = $ArmSprite/Weapon
@onready var muzzle: Marker2D = $ArmSprite/Weapon/Muzzle


func _ready() -> void:
	if weapon and weapon.weapon_sprite:
		weapon_sprite.texture = weapon.weapon_sprite
	# Initialize facing based on current mouse position
	var mouse_pos := get_global_mouse_position()
	var mouse_is_right := mouse_pos.x > global_position.x
	_apply_facing(mouse_is_right)


const ARM_OFFSET_X: float = -13.585
const ARM_POSITION_X: float = 12.56


func _apply_facing(new_facing_right: bool) -> void:
	facing_right = new_facing_right
	body_sprite.flip_h = facing_right
	legs_sprite.flip_h = facing_right
	arm_sprite.flip_h = facing_right
	weapon_sprite.flip_h = facing_right
	# Negate x-offset and x-position when flipped to keep pivot point correct
	var offset_mult := -1.0 if facing_right else 1.0
	arm_sprite.offset.x = ARM_OFFSET_X * offset_mult
	arm_sprite.position.x = ARM_POSITION_X * offset_mult
	if weapon:
		weapon_sprite.offset = Vector2(weapon.weapon_offset.x * offset_mult, weapon.weapon_offset.y)
		weapon_sprite.rotation = weapon.weapon_rotation * offset_mult
		muzzle.position = Vector2(weapon.muzzle_position.x * offset_mult, weapon.muzzle_position.y)


func _physics_process(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if input_enabled:
		var mouse_pos := get_global_mouse_position()
		
		# Facing is purely based on mouse X vs player X
		var mouse_is_right := mouse_pos.x > global_position.x
		if mouse_is_right != facing_right:
			_apply_facing(mouse_is_right)
		
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
		
		if Input.is_action_just_pressed("swap_weapon"):
			swap_weapon()
		
		match current_weapon:
			Weapon.GUN:
				if Input.is_action_pressed("shoot") and _fire_cooldown <= 0.0:
					shoot()
			Weapon.MAGNET_GUN:
				if Input.is_action_just_pressed("shoot"):
					magnetize()
				elif Input.is_action_just_released("shoot"):
					stop_magnetize()
		
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


func swap_weapon() -> void:
	if current_weapon == Weapon.GUN:
		current_weapon = Weapon.MAGNET_GUN
		weapon_sprite.texture = MagnetGunTexture
	else:
		current_weapon = Weapon.GUN
		if weapon and weapon.weapon_sprite:
			weapon_sprite.texture = weapon.weapon_sprite
		stop_magnetize()


func shoot() -> void:
	if not weapon:
		return
	_fire_cooldown = 1.0 / weapon.fire_rate
	var bullet := BulletScene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = (get_global_mouse_position() - global_position).normalized()
	bullet.damage = weapon.damage
	bullet.speed = weapon.bullet_speed
	if weapon.bullet_sprite:
		bullet.get_node("Sprite2D").texture = weapon.bullet_sprite
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
