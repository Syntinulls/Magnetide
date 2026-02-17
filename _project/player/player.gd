extends CharacterBody2D

@export var speed: float = 200.0
@export var jump_velocity: float = -300.0
@export var gravity: float = 800.0

const BulletScene: PackedScene = preload("res://_project/player/bullet.tscn")

@onready var gun: Sprite2D = $Gun
@onready var muzzle: Marker2D = $Gun/Muzzle

func _physics_process(delta: float) -> void:
	gun.look_at(get_global_mouse_position())
	
	if Input.is_action_just_pressed("shoot"):
		shoot()
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = jump_velocity
	
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed
	
	move_and_slide()

func shoot() -> void:
	var bullet := BulletScene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = (get_global_mouse_position() - global_position).normalized()
	bullet.rotation = bullet.direction.angle()
	get_tree().current_scene.add_child(bullet)
