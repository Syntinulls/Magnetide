extends CharacterBody2D
class_name Player

@export var speed: float = 400.0
@export var jump_velocity: float = -600.0
@export var gravity: float = 1600.0

const BulletScene: PackedScene = preload("res://_project/player/bullet.tscn")

var input_enabled: bool = true
var facing_right: bool = false

@onready var body_sprite: Sprite2D = $BodySprite
@onready var arm_sprite: Sprite2D = $ArmSprite
@onready var gun_sprite: Sprite2D = $ArmSprite/Gun
@onready var muzzle: Marker2D = $ArmSprite/Gun/Muzzle


func _ready() -> void:
	# Initialize facing based on current mouse position
	var mouse_pos := get_global_mouse_position()
	var mouse_is_right := mouse_pos.x > global_position.x
	_apply_facing(mouse_is_right)


const ARM_OFFSET_X: float = -13.585
const ARM_POSITION_X: float = 12.56
const GUN_OFFSET_X: float = -15.125
const GUN_ROTATION: float = -0.14660765
const MUZZLE_POSITION_X: float = -55.915

func _apply_facing(new_facing_right: bool) -> void:
	facing_right = new_facing_right
	body_sprite.flip_h = facing_right
	arm_sprite.flip_h = facing_right
	gun_sprite.flip_h = facing_right
	# Negate x-offset and x-position when flipped to keep pivot point correct
	var offset_mult := -1.0 if facing_right else 1.0
	arm_sprite.offset.x = ARM_OFFSET_X * offset_mult
	arm_sprite.position.x = ARM_POSITION_X * offset_mult
	gun_sprite.offset.x = GUN_OFFSET_X * offset_mult
	gun_sprite.rotation = GUN_ROTATION * offset_mult
	muzzle.position.x = MUZZLE_POSITION_X * offset_mult


func _physics_process(delta: float) -> void:
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
		
		if Input.is_action_just_pressed("shoot"):
			shoot()
		
		if Input.is_action_just_pressed("move_jump") and is_on_floor():
			velocity.y = jump_velocity
		
		var direction := Input.get_axis("move_left", "move_right")
		velocity.x = direction * speed
	else:
		velocity.x = 0.0
	
	if not is_on_floor():
		velocity.y += gravity * delta
	
	move_and_slide()

func shoot() -> void:
	var bullet := BulletScene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = (get_global_mouse_position() - global_position).normalized()
	bullet.rotation = bullet.direction.angle()
	get_tree().current_scene.add_child(bullet)
