extends AttackBehavior
class_name MosquitoAttackBehavior

## Windup -> shoot -> recover firing loop. Gated on the Mosquito holding position,
## so the base Enemy state machine only enters ATTACK once the mosquito has settled
## at hover range. On the shoot frame it spawns a needle Projectile aimed at the
## current target; the body sprite drives the windup/shoot animations while the
## wings keep flapping independently.

## Seconds the body winds up before the needle is released.
@export var windup_time: float = 0.5
## Seconds the mosquito recovers after firing before the next windup begins.
@export var recover_time: float = 0.6

@export_group("Needle")
## Texture used for the spawned needle projectile. Left unset = no projectile
## (safe no-op) until the art is assigned.
@export var needle_sprite: Texture2D
## Needle travel speed in pixels/second.
@export var needle_speed: float = 600.0
## Needle lifetime in seconds before it despawns.
@export var needle_lifetime: float = 4.0
## Extra distance ahead of the muzzle (toward the target) the needle spawns from.
@export var needle_spawn_offset: float = 24.0
## Collision mask the needle scans for. Must include the player Hitbox layer.
@export_flags_2d_physics var needle_collision_mask: int = 8

var _timer: float = 0.0


func can_attack(enemy: Enemy) -> bool:
	var mosquito := enemy as Mosquito
	return mosquito != null and enemy.has_valid_target() and mosquito.is_holding_position()


func register_states(_enemy: Enemy) -> void:
	add_state(&"windup")
	add_state(&"shoot")
	add_state(&"recover")


func get_initial_state(_enemy: Enemy) -> StringName:
	return &"windup"


func on_enter_attack(enemy: Enemy) -> void:
	request_state(enemy, &"windup")


func on_enter_state(enemy: Enemy, state_name: StringName) -> void:
	match state_name:
		&"windup":
			_timer = windup_time
			enemy.set_desired_velocity(Vector2.ZERO)
			enemy.play_enemy_animation(Mosquito.ANIM_WINDUP)
		&"shoot":
			enemy.play_enemy_animation(Mosquito.ANIM_SHOOT)
			_fire_needle(enemy)
		&"recover":
			_timer = recover_time


func update_state(enemy: Enemy, delta: float, state_name: StringName) -> void:
	enemy.set_desired_velocity(Vector2.ZERO)
	enemy.face_current_target()

	match state_name:
		&"windup":
			_timer -= delta
			if _timer <= 0.0:
				request_state(enemy, &"shoot")
		&"shoot":
			request_state(enemy, &"recover")
		&"recover":
			_timer -= delta
			if _timer <= 0.0:
				request_state(enemy, &"windup")


func _fire_needle(enemy: Enemy) -> void:
	if needle_sprite == null:
		return
	var direction := enemy.get_direction_to_target()
	if direction == Vector2.ZERO:
		return
	var world_root := Magnetide.world_root
	if world_root == null:
		return

	var origin := enemy.global_position
	if enemy.has_method("get_muzzle_global_position"):
		origin = enemy.get_muzzle_global_position()

	Projectile.spawn(world_root, {
		&"global_position": origin + direction * needle_spawn_offset,
		&"direction": direction,
		&"sprite": needle_sprite,
		&"damage": enemy.data.damage * enemy.damage_scale,
		&"speed": needle_speed,
		&"lifetime": needle_lifetime,
		&"collision_layer": 0,
		&"collision_mask": needle_collision_mask,
		&"source": enemy,
	})
