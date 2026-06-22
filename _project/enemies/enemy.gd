extends CharacterBody2D
class_name Enemy

signal died

enum State { IDLE, MOVE, ATTACK, DEATH }
enum DeathPhase { NONE, SHAKING, PAUSED, POPPING }

const INVALID_TARGET_GROUP: StringName = &""
const ANIM_IDLE: StringName = &"idle"
const ANIM_MOVE: StringName = &"move"
const ANIM_ATTACK: StringName = &"attack"
const ANIM_DEATH: StringName = &"death"
const DefaultMoveBehaviorScript: Script = preload("res://_project/enemies/behaviors/default_move.gd")
const DefaultAttackBehaviorScript: Script = preload("res://_project/enemies/behaviors/default_attack.gd")

@export var data: EnemyData

var state: State = State.IDLE
var current_target_group: StringName = INVALID_TARGET_GROUP
var current_target_root: Node2D = null
var current_target_point: Node2D = null
var current_damage_target: Node2D = null
var current_health: float = 0.0

var _move_behavior: Resource = null
var _attack_behavior: Resource = null
var _target_acquire_timer: float = 0.0
var _death_timer: float = 0.0
var _death_pop_elapsed: float = 0.0
var _death_phase: DeathPhase = DeathPhase.NONE
var _death_rotation_velocity: float = 0.0
var _death_shake_origin: Vector2 = Vector2.ZERO
var _flash_tween: Tween = null
var _death_sequence_tween: Tween = null

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Hitbox = $Hitbox
@onready var hitbox_collision_shape: CollisionShape2D = $Hitbox/CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	if not data:
		push_warning("Enemy has no EnemyData assigned.")
		return

	current_health = data.max_health
	_apply_data()
	_setup_behaviors()
	_acquire_target(false)
	_enter_state(_select_base_state())


func _physics_process(delta: float) -> void:
	if not data:
		return
	if state == State.DEATH:
		_process_death(delta)
		return

	_process_active(delta)


func _apply_data() -> void:
	var hitbox_shape := hitbox_collision_shape.shape as RectangleShape2D
	if hitbox_shape:
		hitbox_shape = hitbox_shape.duplicate()
		hitbox_shape.size = data.hitbox_size
		hitbox_collision_shape.shape = hitbox_shape

	var sprite_material := sprite.material as ShaderMaterial
	if sprite_material:
		sprite.material = sprite_material.duplicate()

	if data.sprite_frames:
		sprite.sprite_frames = data.sprite_frames
	play_enemy_animation(ANIM_IDLE)


func _setup_behaviors() -> void:
	if data.move_behavior:
		_move_behavior = data.move_behavior.duplicate(true)
	else:
		_move_behavior = DefaultMoveBehaviorScript.new()
	if data.attack_behavior:
		_attack_behavior = data.attack_behavior.duplicate(true)
	else:
		_attack_behavior = DefaultAttackBehaviorScript.new()
	if _move_behavior:
		_move_behavior.setup(self)
	if _attack_behavior:
		_attack_behavior.setup(self)


func _process_active(delta: float) -> void:
	_update_targeting(delta)

	var next_state := _select_base_state()
	if next_state != state:
		_enter_state(next_state)

	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			play_enemy_animation(ANIM_IDLE)
		State.MOVE:
			if _move_behavior:
				_move_behavior.physics_tick(self, delta)
		State.ATTACK:
			if _attack_behavior:
				_attack_behavior.physics_tick(self, delta)

	move_and_slide()


func _process_death(delta: float) -> void:
	_death_timer += delta
	if _death_phase != DeathPhase.POPPING:
		velocity = Vector2.ZERO
		return

	_death_pop_elapsed += delta
	velocity.y += data.death_pop_gravity * delta
	rotation += _death_rotation_velocity * delta
	move_and_slide()

	if _death_pop_elapsed >= data.death_pop_max_time or _is_below_viewport():
		queue_free()


func _select_base_state() -> State:
	if not has_valid_target():
		return State.IDLE
	if _attack_behavior and _attack_behavior.can_attack(self):
		return State.ATTACK
	return State.MOVE


func _enter_state(new_state: State) -> void:
	if state == new_state:
		return

	if state == State.MOVE and _move_behavior:
		_move_behavior.on_exit_move(self)
	elif state == State.ATTACK and _attack_behavior:
		_attack_behavior.on_exit_attack(self)

	state = new_state

	match new_state:
		State.IDLE:
			velocity = Vector2.ZERO
			play_enemy_animation(ANIM_IDLE)
		State.MOVE:
			if _move_behavior:
				_move_behavior.on_enter_move(self)
			play_enemy_animation(ANIM_MOVE)
		State.ATTACK:
			if _attack_behavior:
				_attack_behavior.on_enter_attack(self)
		State.DEATH:
			_enter_death_state()


func _enter_death_state() -> void:
	velocity = Vector2.ZERO
	current_target_group = INVALID_TARGET_GROUP
	current_target_root = null
	current_target_point = null
	current_damage_target = null
	_death_timer = 0.0
	_death_pop_elapsed = 0.0
	if _move_behavior:
		_move_behavior.teardown(self)
	if _attack_behavior:
		_attack_behavior.teardown(self)
	hitbox_collision_shape.set_deferred("disabled", true)
	play_enemy_animation(ANIM_DEATH)
	_start_death_sequence()
	died.emit()


# -- Shared Enemy API --------------------------------------------------------

func take_damage(amount: float, source: Node = null) -> void:
	if state == State.DEATH:
		return

	current_health -= amount
	_flash_white()
	if Magnetide.sfx:
		Magnetide.sfx.play("enemy_hit.ogg", -6)

	if current_health <= 0.0:
		_enter_state(State.DEATH)
		return

	if data.target_switching_mode == EnemyData.TargetSwitchingMode.RECEIVED_DAMAGE:
		_switch_target_to_damage_source(source)


func get_hitbox() -> Hitbox:
	return hitbox


func get_current_target_group() -> StringName:
	return current_target_group


func has_valid_target() -> bool:
	if not current_target_point or not is_instance_valid(current_target_point):
		return false
	if current_target_point.has_method("is_target_enabled") and not current_target_point.is_target_enabled():
		return false
	if not _is_damage_target_valid(current_damage_target):
		return false
	if data.target_range > 0.0 and global_position.distance_to(current_target_point.global_position) > data.target_range:
		return false
	return true


func get_current_target_root() -> Node2D:
	return current_target_root


func get_current_target_point() -> Node2D:
	return current_target_point


func get_current_damage_target() -> Node2D:
	return current_damage_target


func get_direction_to_target() -> Vector2:
	if not has_valid_target():
		return Vector2.ZERO
	return (current_target_point.global_position - global_position).normalized()


func get_distance_to_target() -> float:
	if not has_valid_target():
		return INF
	return global_position.distance_to(current_target_point.global_position)


func get_movement_speed() -> float:
	return data.movement_speed if data else 0.0


func get_attack_range() -> float:
	return data.attack_range if data else 0.0


func get_attack_interval() -> float:
	return data.attack_interval if data else 0.0


func set_desired_velocity(next_velocity: Vector2) -> void:
	velocity = next_velocity


func face_current_target() -> void:
	if current_target_point and is_instance_valid(current_target_point):
		var angle := global_position.angle_to_point(current_target_point.global_position)
		rotation = angle + PI / 2.0


func deal_damage_to_current_target(amount: float = -1.0) -> void:
	if not current_damage_target or not current_damage_target.has_method("take_damage"):
		return
	var damage_amount := data.damage if amount < 0.0 else amount
	current_damage_target.take_damage(damage_amount, self)


func get_projectile_parent() -> Node:
	if Magnetide.world_root:
		return Magnetide.world_root
	return get_parent()


func play_enemy_animation(animation_name: StringName) -> void:
	if not sprite.sprite_frames:
		return
	if not sprite.sprite_frames.has_animation(animation_name):
		return
	if sprite.animation != animation_name:
		sprite.play(animation_name)
	elif not sprite.is_playing():
		sprite.play()


func stop_for_run_end() -> void:
	velocity = Vector2.ZERO
	set_process(false)
	set_physics_process(false)


# -- Targeting ---------------------------------------------------------------

func _update_targeting(delta: float) -> void:
	if not has_valid_target():
		_clear_target()
		_target_acquire_timer -= delta
		if _target_acquire_timer <= 0.0:
			_acquire_target(false)
			_target_acquire_timer = _get_target_acquire_interval()
		return

	_target_acquire_timer -= delta
	if _target_acquire_timer > 0.0:
		return

	if data.target_switching_mode == EnemyData.TargetSwitchingMode.PROXIMITY:
		_acquire_target(true)
		_target_acquire_timer = _get_proximity_switch_interval()
	else:
		_target_acquire_timer = _get_target_acquire_interval()


func _acquire_target(allow_switch: bool) -> bool:
	var previous_group := current_target_group
	var previous_root := current_target_root
	var previous_point := current_target_point
	var previous_damage_target := current_damage_target

	if has_valid_target() and not allow_switch:
		return false

	var resolved_target := _select_target_from_candidates(
		_collect_target_candidates(_get_active_target_groups()),
		data.target_priority_mode
	)

	current_target_group = resolved_target.get("group", INVALID_TARGET_GROUP)
	current_target_root = resolved_target.get("target_root", null) as Node2D
	current_target_point = resolved_target.get("path_target", null) as Node2D
	current_damage_target = resolved_target.get("damage_target", null) as Node2D

	return (
		previous_group != current_target_group
		or previous_root != current_target_root
		or previous_point != current_target_point
		or previous_damage_target != current_damage_target
	)


func _clear_target() -> void:
	current_target_group = INVALID_TARGET_GROUP
	current_target_root = null
	current_target_point = null
	current_damage_target = null


func _switch_target_to_damage_source(source: Node) -> bool:
	var source_root := _get_damage_source_target_root(source)
	if source_root == null:
		return false

	var source_group := _get_target_group_for_node(source_root)
	if source_group == INVALID_TARGET_GROUP:
		return false
	if not data.get_target_priority_groups_including_random_excludes().has(String(source_group)):
		return false

	var resolved := _resolve_node_target(source_root)
	if resolved.is_empty():
		return false

	current_target_group = source_group
	current_target_root = resolved.get("target_root", null) as Node2D
	current_target_point = resolved.get("path_target", null) as Node2D
	current_damage_target = resolved.get("damage_target", null) as Node2D
	_target_acquire_timer = _get_target_acquire_interval()
	return true


func _get_damage_source_target_root(source: Node) -> Node2D:
	if source == null or not is_instance_valid(source):
		return null
	if source.has_method("get_target_owner"):
		var target_owner := source.get_target_owner() as Node2D
		if target_owner:
			return target_owner
	var node := source
	while node:
		var node_2d := node as Node2D
		if node_2d and _get_target_group_for_node(node_2d) != INVALID_TARGET_GROUP:
			return node_2d
		node = node.get_parent()
	return source as Node2D


func _get_target_group_for_node(node: Node) -> StringName:
	if node == null:
		return INVALID_TARGET_GROUP
	for group_name in data.valid_targets:
		if node.is_in_group(group_name):
			return StringName(group_name)
	return INVALID_TARGET_GROUP


func _get_active_target_groups() -> Array[String]:
	return data.get_target_priority_groups()


func _collect_target_candidates(groups: Array[String]) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for i in groups.size():
		var group_name := groups[i]
		if group_name.is_empty():
			continue

		for node in get_tree().get_nodes_in_group(group_name):
			var resolved := _resolve_node_target(node)
			if resolved.is_empty():
				continue
			resolved["group"] = StringName(group_name)
			resolved["priority_index"] = i
			candidates.append(resolved)
	return candidates


func _select_target_from_candidates(candidates: Array[Dictionary], selection_mode: EnemyData.TargetSelectionMode) -> Dictionary:
	if candidates.is_empty():
		return {}

	match selection_mode:
		EnemyData.TargetSelectionMode.RANDOM:
			return _select_random_target(candidates)
		EnemyData.TargetSelectionMode.CLOSEST:
			return _select_closest_target(candidates)
		_:
			return _select_ordered_target(candidates)


func _select_random_target(candidates: Array[Dictionary]) -> Dictionary:
	var filtered_candidates: Array[Dictionary] = []
	for candidate in candidates:
		var group_name := String(candidate.get("group", ""))
		if data.target_priority_random_excludes.has(group_name):
			continue
		filtered_candidates.append(candidate)

	if filtered_candidates.is_empty():
		return {}
	return filtered_candidates.pick_random()


func _select_ordered_target(candidates: Array[Dictionary]) -> Dictionary:
	var best_priority_index := INF
	var same_priority_candidates: Array[Dictionary] = []
	for candidate in candidates:
		var priority_index := int(candidate.get("priority_index", 0))
		if priority_index < best_priority_index:
			best_priority_index = priority_index
			same_priority_candidates.clear()
			same_priority_candidates.append(candidate)
		elif priority_index == best_priority_index:
			same_priority_candidates.append(candidate)
	return _select_closest_target(same_priority_candidates)


func _select_closest_target(candidates: Array[Dictionary]) -> Dictionary:
	var closest_target: Dictionary = {}
	var closest_distance := INF
	for candidate in candidates:
		var path_target := candidate.get("path_target", null) as Node2D
		if path_target == null:
			continue

		var distance := global_position.distance_to(path_target.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_target = candidate
	return closest_target


func _resolve_node_target(root: Node) -> Dictionary:
	var root_2d := root as Node2D
	if not root_2d:
		return {}

	var target_points := _get_target_points(root)
	if not target_points.is_empty():
		var point := _select_target_point(target_points)
		if not point:
			return {}
		var damage_receiver := _get_damage_receiver_for_target_point(root, point)
		if not _is_damage_target_valid(damage_receiver):
			return {}
		if not _is_point_in_target_range(point.global_position):
			return {}
		return {
			"target_root": root_2d,
			"path_target": point,
			"damage_target": damage_receiver,
		}

	var damage_target := _get_default_damage_receiver(root)
	if not _is_damage_target_valid(damage_target):
		return {}
	if not _is_point_in_target_range(root_2d.global_position):
		return {}
	return {
		"target_root": root_2d,
		"path_target": root_2d,
		"damage_target": damage_target,
	}


func _get_target_points(root: Node) -> Array[Node2D]:
	var points: Array[Node2D] = []
	if root.has_method("get_enemy_target_points"):
		for point in root.get_enemy_target_points():
			var point_2d := point as Node2D
			if point_2d and _is_target_point_enabled(point_2d):
				points.append(point_2d)
		return points

	var exposed_points: Variant = root.get("enemy_target_points")
	if exposed_points is Array:
		for point in exposed_points:
			var point_2d := point as Node2D
			if point_2d and _is_target_point_enabled(point_2d):
				points.append(point_2d)
	return points


func _select_target_point(points: Array[Node2D]) -> Node2D:
	if points.is_empty():
		return null

	match data.target_point_selection_mode:
		EnemyData.TargetSelectionMode.ORDER:
			return points.front()
		EnemyData.TargetSelectionMode.CLOSEST:
			var closest_point: Node2D = null
			var closest_distance := INF
			for point in points:
				var distance := global_position.distance_to(point.global_position)
				if distance < closest_distance:
					closest_distance = distance
					closest_point = point
			return closest_point
		_:
			return points.pick_random()


func _get_damage_receiver_for_target_point(root: Node, point: Node2D) -> Node2D:
	if point.has_method("get_damage_receiver"):
		return point.get_damage_receiver() as Node2D
	if root.has_method("get_damage_receiver_for_target_point"):
		return root.get_damage_receiver_for_target_point(point) as Node2D
	return _get_default_damage_receiver(root)


func _get_default_damage_receiver(root: Node) -> Node2D:
	if root.has_method("get_hitbox"):
		return root.get_hitbox() as Node2D
	return root as Node2D


func _is_target_point_enabled(point: Node2D) -> bool:
	if point.has_method("is_target_enabled"):
		return point.is_target_enabled()
	return is_instance_valid(point)


func _is_damage_target_valid(target: Node2D) -> bool:
	if not target or not is_instance_valid(target):
		return false
	if target.has_method("is_valid_target"):
		return target.is_valid_target()
	return true


func _is_point_in_target_range(point_global_position: Vector2) -> bool:
	return data.target_range <= 0.0 or global_position.distance_to(point_global_position) <= data.target_range


func _get_target_acquire_interval() -> float:
	return maxf(data.target_acquire_interval, 0.05)


func _get_proximity_switch_interval() -> float:
	return maxf(data.proximity_switch_interval, 0.05)


# -- Death -------------------------------------------------------------------

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
	if state != State.DEATH:
		return
	_death_phase = DeathPhase.PAUSED
	position = _death_shake_origin
	velocity = Vector2.ZERO


func _launch_death_pop() -> void:
	if state != State.DEATH:
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
