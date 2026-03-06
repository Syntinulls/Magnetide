extends CharacterBody2D
class_name Enemy

signal died

enum State { ALIVE, ATTACKING, DEAD }

## Shared priority table mapping group names to priority values.
## Higher value = higher priority target. Enemies prefer targets in
## higher-priority groups when multiple are in detection range.
const TARGET_PRIORITIES: Dictionary = {
	"target_high": 100,
	"target_medium": 50,
	"target_low": 10,
}

@export var data: EnemyData

var state: State = State.ALIVE
var current_target: Node2D = null
var current_health: float = 0.0

var _attack_timer: float = 0.0
var _death_timer: float = 0.0
var _anim_timer: float = 0.0
var _anim_frame: int = 0
var _flash_tween: Tween = null

@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	if not data:
		push_warning("Enemy has no EnemyData assigned.")
		return
	current_health = data.max_health
	_apply_data()


func _physics_process(delta: float) -> void:
	if not data:
		return
	match state:
		State.ALIVE:
			_process_alive(delta)
		State.ATTACKING:
			_process_attacking(delta)
		State.DEAD:
			_process_dead(delta)


func _apply_data() -> void:
	var shape := collision_shape.shape as CircleShape2D
	if shape:
		shape = shape.duplicate()
		shape.radius = data.collision_radius
		collision_shape.shape = shape
	_set_animation(data.move_spritesheet, data.move_frames)


# -- State Processing --------------------------------------------------------

func _process_alive(delta: float) -> void:
	_find_target()
	if current_target and is_instance_valid(current_target):
		var dist := global_position.distance_to(current_target.global_position)
		if dist <= data.attack_range:
			_enter_state(State.ATTACKING)
			return
		var direction := (current_target.global_position - global_position).normalized()
		velocity = direction * data.movement_speed
		_rotate_toward_target()
	else:
		velocity = Vector2.ZERO
	_animate(delta, data.move_spritesheet, data.move_frames, data.move_fps)
	move_and_slide()


func _process_attacking(delta: float) -> void:
	velocity = Vector2.ZERO
	if not current_target or not is_instance_valid(current_target):
		_enter_state(State.ALIVE)
		return

	# Retarget if health is low and a higher-priority target exists
	if data.max_health > 0.0 and current_health / data.max_health <= data.retarget_health_ratio:
		var better := _find_higher_priority_target()
		if better:
			current_target = better
			_enter_state(State.ALIVE)
			return

	# Chase again if target left attack range (with small buffer)
	var dist := global_position.distance_to(current_target.global_position)
	if dist > data.attack_range * 1.5:
		_enter_state(State.ALIVE)
		return

	_rotate_toward_target()
	_attack_timer += delta
	if _attack_timer >= data.attack_interval:
		_attack_timer -= data.attack_interval
		_deal_damage()
	_animate(delta, data.attack_spritesheet, data.attack_frames, data.attack_fps)


func _process_dead(delta: float) -> void:
	velocity = Vector2.ZERO
	_death_timer += delta
	_animate(delta, data.death_spritesheet, data.death_frames, data.death_fps)
	if _death_timer >= data.death_linger_time:
		queue_free()


func _enter_state(new_state: State) -> void:
	state = new_state
	_anim_frame = 0
	_anim_timer = 0.0
	match new_state:
		State.ATTACKING:
			_attack_timer = 0.0
		State.DEAD:
			_death_timer = 0.0
			collision_shape.set_deferred("disabled", true)
			_set_animation(data.death_spritesheet, data.death_frames)
			died.emit()


# -- Damage -------------------------------------------------------------------

func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	current_health -= amount
	_flash_white()
	if current_health <= 0.0:
		_enter_state(State.DEAD)


func _flash_white() -> void:
	if _flash_tween:
		_flash_tween.kill()
	var mat := sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("flash_intensity", 1.0)
		_flash_tween = create_tween()
		_flash_tween.tween_property(mat, "shader_parameter/flash_intensity", 0.0, 0.15)


func _deal_damage() -> void:
	if current_target and current_target.has_method("take_damage"):
		current_target.take_damage(data.damage)


# -- Targeting ----------------------------------------------------------------

func _find_target() -> void:
	var best_target: Node2D = null
	var best_priority: int = -1
	var best_distance: float = INF

	for group_name: String in TARGET_PRIORITIES:
		var priority: int = TARGET_PRIORITIES[group_name]
		for node: Node in get_tree().get_nodes_in_group(group_name):
			if node is Node2D:
				var dist := global_position.distance_to(node.global_position)
				if dist <= data.detection_range:
					if priority > best_priority or (priority == best_priority and dist < best_distance):
						best_target = node as Node2D
						best_priority = priority
						best_distance = dist
	current_target = best_target


func _find_higher_priority_target() -> Node2D:
	var current_pri := _get_target_priority(current_target)
	var best_target: Node2D = null
	var best_priority: int = current_pri
	var best_distance: float = INF

	for group_name: String in TARGET_PRIORITIES:
		var priority: int = TARGET_PRIORITIES[group_name]
		if priority <= current_pri:
			continue
		for node: Node in get_tree().get_nodes_in_group(group_name):
			if node is Node2D:
				var dist := global_position.distance_to(node.global_position)
				if dist <= data.detection_range:
					if priority > best_priority or (priority == best_priority and dist < best_distance):
						best_target = node as Node2D
						best_priority = priority
						best_distance = dist
	return best_target


func _get_target_priority(target: Node2D) -> int:
	if not target:
		return -1
	for group_name: String in TARGET_PRIORITIES:
		if target.is_in_group(group_name):
			return TARGET_PRIORITIES[group_name]
	return -1


# -- Animation ----------------------------------------------------------------

func _set_animation(spritesheet: Texture2D, frames: int) -> void:
	sprite.texture = spritesheet
	sprite.hframes = frames
	sprite.frame = 0
	_anim_frame = 0
	_anim_timer = 0.0


func _animate(delta: float, spritesheet: Texture2D, frames: int, fps: float) -> void:
	if sprite.texture != spritesheet:
		_set_animation(spritesheet, frames)
	if frames <= 1 or fps <= 0.0:
		return
	_anim_timer += delta
	var frame_duration := 1.0 / fps
	while _anim_timer >= frame_duration:
		_anim_timer -= frame_duration
		_anim_frame = (_anim_frame + 1) % frames
	sprite.frame = _anim_frame


func _rotate_toward_target() -> void:
	if current_target and is_instance_valid(current_target):
		var angle := global_position.angle_to_point(current_target.global_position)
		rotation = angle + PI / 2.0
