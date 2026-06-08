extends CharacterBody2D
class_name Enemy

signal died

enum State { ALIVE, ATTACKING, DEAD }
enum DeathPhase { NONE, SHAKING, PAUSED, POPPING }
const INVALID_TARGET_CATEGORY: int = -1

@export var data: EnemyData

var state: State = State.ALIVE
var current_target_category: int = INVALID_TARGET_CATEGORY
var current_target_point: Node2D = null
var current_damage_target: Node2D = null
var current_health: float = 0.0
var has_taken_damage: bool = false
var has_triggered_health_threshold_retarget: bool = false

var _attack_timer: float = 0.0
var _death_timer: float = 0.0
var _death_pop_elapsed: float = 0.0
var _death_phase: DeathPhase = DeathPhase.NONE
var _death_rotation_velocity: float = 0.0
var _death_shake_origin: Vector2 = Vector2.ZERO
var _anim_timer: float = 0.0
var _anim_frame: int = 0
var _flash_tween: Tween = null
var _death_sequence_tween: Tween = null

@onready var sprite: Sprite2D = $Sprite
@onready var hitbox: Hitbox = $Hitbox
@onready var hitbox_collision_shape: CollisionShape2D = $Hitbox/CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	if not data:
		push_warning("Enemy has no EnemyData assigned.")
		return
	current_health = data.max_health
	_apply_data()
	_evaluate_target()


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
	var hitbox_shape := hitbox_collision_shape.shape as RectangleShape2D
	if hitbox_shape:
		hitbox_shape = hitbox_shape.duplicate()
		hitbox_shape.size = data.hitbox_size
		hitbox_collision_shape.shape = hitbox_shape
	var sprite_material := sprite.material as ShaderMaterial
	if sprite_material:
		sprite.material = sprite_material.duplicate()
	_set_animation(data.move_spritesheet, data.move_frames)


# -- State Processing --------------------------------------------------------

func _process_alive(delta: float) -> void:
	_maybe_trigger_health_threshold_retarget()
	if not _has_valid_target():
		_evaluate_target()

	if _has_valid_target():
		var dist := global_position.distance_to(current_target_point.global_position)
		if dist <= data.attack_range:
			_enter_state(State.ATTACKING)
			return
		var direction := (current_target_point.global_position - global_position).normalized()
		velocity = direction * data.movement_speed
		_rotate_toward_target()
	else:
		velocity = Vector2.ZERO
	_animate(delta, data.move_spritesheet, data.move_frames, data.move_fps)
	move_and_slide()


func _process_attacking(delta: float) -> void:
	velocity = Vector2.ZERO
	_maybe_trigger_health_threshold_retarget()
	if not _has_valid_target():
		_evaluate_target()
	if not _has_valid_target():
		_enter_state(State.ALIVE)
		return

	# Chase again if target left attack range (with small buffer)
	var dist := global_position.distance_to(current_target_point.global_position)
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
	_death_timer += delta
	_animate(delta, data.death_spritesheet, data.death_frames, data.death_fps)

	if _death_phase != DeathPhase.POPPING:
		velocity = Vector2.ZERO
		return

	_death_pop_elapsed += delta
	velocity.y += data.death_pop_gravity * delta
	rotation += _death_rotation_velocity * delta
	move_and_slide()

	if _death_pop_elapsed >= data.death_pop_max_time or _is_below_viewport():
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
			_death_pop_elapsed = 0.0
			hitbox_collision_shape.set_deferred("disabled", true)
			_set_animation(data.death_spritesheet, data.death_frames)
			_start_death_sequence()
			died.emit()


# -- Damage -------------------------------------------------------------------

func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	current_health -= amount
	_flash_white()
	Magnetide.sfx.play("enemy_hit.ogg", -6)
	if current_health <= 0.0:
		_enter_state(State.DEAD)
		return
	if not has_taken_damage:
		has_taken_damage = true
		if data.retarget_on_damage:
			_retarget()


func get_hitbox() -> Hitbox:
	return hitbox


func _flash_white() -> void:
	if _flash_tween:
		_flash_tween.kill()
	var mat := sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("flash_intensity", 1.0)
		_flash_tween = create_tween()
		_flash_tween.tween_property(mat, "shader_parameter/flash_intensity", 0.0, 0.15)


func _start_death_sequence() -> void:
	if _death_sequence_tween:
		_death_sequence_tween.kill()

	_death_phase = DeathPhase.SHAKING
	_death_shake_origin = position
	_death_rotation_velocity = 0.0

	var shake_duration := maxf(data.death_shake_duration, 0.0)
	var pause_duration := maxf(data.death_pause_duration, 0.0)
	_death_sequence_tween = create_tween()

	if shake_duration > 0.0 and data.death_shake_distance > 0.0 and data.death_shake_steps > 0:
		var steps := maxi(data.death_shake_steps, 1)
		var step_duration := shake_duration / float(steps)
		for i in steps:
			var offset := Vector2(
				randf_range(-data.death_shake_distance, data.death_shake_distance),
				randf_range(-data.death_shake_distance, data.death_shake_distance)
			)
			_death_sequence_tween.tween_property(self, "position", _death_shake_origin + offset, step_duration)
		_death_sequence_tween.tween_property(self, "position", _death_shake_origin, minf(step_duration, 0.06))
	elif shake_duration > 0.0:
		_death_sequence_tween.tween_interval(shake_duration)

	_death_sequence_tween.tween_callback(_finish_death_shake)
	if pause_duration > 0.0:
		_death_sequence_tween.tween_interval(pause_duration)
	_death_sequence_tween.tween_callback(_launch_death_pop)


func _finish_death_shake() -> void:
	if state != State.DEAD:
		return
	_death_phase = DeathPhase.PAUSED
	position = _death_shake_origin
	velocity = Vector2.ZERO


func _launch_death_pop() -> void:
	if state != State.DEAD:
		return
	_death_phase = DeathPhase.POPPING
	_death_pop_elapsed = 0.0
	position = _death_shake_origin
	velocity = Vector2(
		randf_range(data.death_pop_velocity_x_range.x, data.death_pop_velocity_x_range.y),
		-randf_range(data.death_pop_up_velocity_range.x, data.death_pop_up_velocity_range.y)
	)
	_death_rotation_velocity = randf_range(
		data.death_pop_rotation_velocity_range.x,
		data.death_pop_rotation_velocity_range.y
	)


func _is_below_viewport() -> bool:
	var viewport := get_viewport()
	if not viewport:
		return false
	var screen_position := get_global_transform_with_canvas().origin
	var viewport_height := viewport.get_visible_rect().size.y
	return screen_position.y > viewport_height + data.death_pop_despawn_margin


func _deal_damage() -> void:
	if current_damage_target and current_damage_target.has_method("take_damage"):
		current_damage_target.take_damage(data.damage)


# -- Targeting ----------------------------------------------------------------

func _retarget() -> void:
	var changed := _evaluate_target()
	if changed and state == State.ATTACKING:
		_enter_state(State.ALIVE)


func _evaluate_target() -> bool:
	var previous_category := current_target_category
	var previous_point := current_target_point
	var previous_damage_target := current_damage_target
	var resolved_target := _resolve_target_from_priorities(_get_active_priorities())

	current_target_category = int(resolved_target.get("category", INVALID_TARGET_CATEGORY))
	current_target_point = resolved_target.get("path_target", null) as Node2D
	current_damage_target = resolved_target.get("damage_target", null) as Node2D

	return (
		previous_category != current_target_category
		or previous_point != current_target_point
		or previous_damage_target != current_damage_target
	)


func _get_active_priorities() -> Array:
	if has_taken_damage and data.retarget_on_damage and not data.damaged_target_priorities.is_empty():
		return data.damaged_target_priorities
	return data.initial_target_priorities


func _resolve_target_from_priorities(priorities: Array) -> Dictionary:
	for category in priorities:
		var resolved := _resolve_target_for_category(int(category))
		if not resolved.is_empty():
			resolved["category"] = int(category)
			return resolved
	return {}


func _resolve_target_for_category(category: int) -> Dictionary:
	match category:
		EnemyData.TargetCategory.PLAYER:
			return _resolve_player_target()
		EnemyData.TargetCategory.MAGNET:
			return _resolve_structure_target(Magnetide.magnet)
		EnemyData.TargetCategory.SHIP:
			return _resolve_structure_target(Magnetide.ship)
	return {}


func _resolve_player_target() -> Dictionary:
	var player := Magnetide.player
	if not player or not player.has_method("get_hitbox"):
		return {}

	var hitbox := player.get_hitbox() as Node2D
	if not _is_damage_target_valid(hitbox):
		return {}

	return {
		"path_target": hitbox,
		"damage_target": hitbox,
	}


func _resolve_structure_target(structure: Node) -> Dictionary:
	if not structure or not structure.has_method("get_enemy_target_points"):
		return {}

	var points: Array[EnemyTargetPoint] = structure.get_enemy_target_points()
	if points.is_empty():
		return {}

	var point := _select_structure_point(points)
	if not point:
		return {}

	var damage_receiver := point.get_damage_receiver() as Node2D
	if not _is_damage_target_valid(damage_receiver):
		return {}

	return {
		"path_target": point,
		"damage_target": damage_receiver,
	}


func _select_structure_point(points: Array[EnemyTargetPoint]) -> EnemyTargetPoint:
	if points.is_empty():
		return null

	match data.structure_point_selection_mode:
		EnemyData.TargetPointSelectionMode.CLOSEST:
			var closest_point: EnemyTargetPoint = null
			var closest_distance := INF
			for point in points:
				var distance := global_position.distance_to(point.global_position)
				if distance < closest_distance:
					closest_distance = distance
					closest_point = point
			return closest_point
		_:
			return points.pick_random() as EnemyTargetPoint


func _has_valid_target() -> bool:
	if not current_target_point or not is_instance_valid(current_target_point):
		return false
	if current_target_point.has_method("is_target_enabled") and not current_target_point.is_target_enabled():
		return false
	return _is_damage_target_valid(current_damage_target)


func _is_damage_target_valid(target: Node2D) -> bool:
	if not target or not is_instance_valid(target):
		return false
	if target.has_method("is_valid_target"):
		return target.is_valid_target()
	return true


func _maybe_trigger_health_threshold_retarget() -> void:
	if not data.retarget_on_health_threshold:
		return
	if has_triggered_health_threshold_retarget:
		return
	if data.max_health <= 0.0:
		return
	if current_health / data.max_health > data.retarget_health_threshold:
		return

	has_triggered_health_threshold_retarget = true
	_retarget()


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
	if current_target_point and is_instance_valid(current_target_point):
		var angle := global_position.angle_to_point(current_target_point.global_position)
		rotation = angle + PI / 2.0


func stop_for_run_end() -> void:
	velocity = Vector2.ZERO
	set_process(false)
	set_physics_process(false)
