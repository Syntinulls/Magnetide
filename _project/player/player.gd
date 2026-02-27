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
@onready var muzzle: Marker2D = $ArmSprite/Gun/Muzzle


func _ready() -> void:
	_apply_facing(facing_right)


func _apply_facing(new_facing_right: bool) -> void:
	facing_right = new_facing_right
	scale.x = -1.0 if facing_right else 1.0


func _physics_process(delta: float) -> void:
	if input_enabled:
		var mouse_pos := get_global_mouse_position()
		var new_facing := mouse_pos.x > global_position.x
		if new_facing != facing_right:
			_apply_facing(new_facing)
		
		var to_mouse := mouse_pos - arm_sprite.global_position
		var angle := to_mouse.angle() - PI
		arm_sprite.rotation = clampf(angle, -PI / 2, PI / 2)
		
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
