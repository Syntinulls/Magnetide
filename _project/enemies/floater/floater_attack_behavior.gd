extends AttackBehavior
class_name FloaterAttackBehavior

## Coil -> explode, once. Entered when the Floater reaches its target point, and committed
## from then on so the base state machine never hands it back to the move behavior. The
## burst spawns the explosion effect (whose scene mask decides who nearby it hurts), hits
## the ship target directly, fans pines over the upper half-circle and sends the Floater
## into retreat.
##
## The ship takes the burst through deal_damage_to_current_target rather than through the
## explosion's area query: the magnet's hitbox shares the ship's layer and forwards its
## damage to the hull, so an area hit could land on the hull twice.

## Seconds the Floater holds the coiled pose before it bursts.
@export var coil_duration: float = 1.0

@export_group("Explosion")
## Blast effect spawned at the Floater, handed the burst damage (EnemyData.damage).
@export var explosion_scene: PackedScene
@export var explode_sfx: AudioStream

@export_group("Pines")
## Texture used for each pine; the art points up, as Projectile expects.
@export var pine_sprite: Texture2D
@export_range(1, 32) var pine_count: int = 6
## Spread of the fan in degrees, centered straight up; 180 runs from horizontal left to
## horizontal right with both ends included.
@export_range(0.0, 360.0) var pine_arc_degrees: float = 180.0
## Damage per pine before threat scaling.
@export var pine_damage: float = 8.0
@export var pine_speed: float = 900.0
## Downward acceleration in px/s², so the fan arcs over and rains down.
@export var pine_gravity: float = 1200.0
@export var pine_lifetime: float = 4.0
## Distance from the Floater's center at which each pine appears.
@export var pine_spawn_offset: float = 40.0
@export var pine_collision_size: Vector2 = Vector2(20.0, 30.0)
## Collision mask the pines scan for. Must include the player Hitbox layer.
@export_flags_2d_physics var pine_collision_mask: int = 1 << PhysicsLayers.PLAYER_HITBOX

var _committed: bool = false
var _timer: float = 0.0


func can_attack(enemy: Enemy) -> bool:
	if _committed:
		return true
	return enemy.has_valid_target() and enemy.get_distance_to_target() <= enemy.get_attack_range()


func register_states(_enemy: Enemy) -> void:
	add_state(&"coil")
	add_state(&"explode")


## No state until ATTACK begins: setup() enters the initial state immediately, which would
## start the coil squash at spawn.
func get_initial_state(_enemy: Enemy) -> StringName:
	return &""


func on_enter_attack(enemy: Enemy) -> void:
	_committed = true
	request_state(enemy, &"coil")


func on_enter_state(enemy: Enemy, state_name: StringName) -> void:
	match state_name:
		&"coil":
			_timer = coil_duration
			enemy.set_desired_velocity(Vector2.ZERO)
			enemy.play_enemy_animation(Floater.ANIM_COIL)
			var floater := enemy as Floater
			if floater:
				floater.play_coil_squash()
		&"explode":
			_explode(enemy)


func update_state(enemy: Enemy, delta: float, state_name: StringName) -> void:
	if state_name != &"coil":
		return
	enemy.set_desired_velocity(Vector2.ZERO)
	_timer -= delta
	if _timer <= 0.0:
		request_state(enemy, &"explode")


func _explode(enemy: Enemy) -> void:
	var floater := enemy as Floater
	if floater:
		floater.release_squash()
	var world_root := Magnetide.world_root
	if world_root != null:
		_spawn_explosion(enemy, world_root)
		_launch_pines(enemy, world_root)
	enemy.deal_damage_to_current_target()
	if explode_sfx and Magnetide.sfx:
		Magnetide.sfx.play(explode_sfx)
	enemy.retreat()


func _spawn_explosion(enemy: Enemy, world_root: Node) -> void:
	if explosion_scene == null:
		return
	var effect := explosion_scene.instantiate()
	# Position and configure before add_child: adding to the tree runs the effect's
	# _ready() synchronously, and it reads both to place and power its blast.
	if effect is Node2D:
		(effect as Node2D).global_position = enemy.global_position
	if effect.has_method("configure"):
		effect.call("configure", {
			&"damage": enemy.get_contact_damage(),
			&"source": enemy,
		})
	world_root.add_child(effect)


func _launch_pines(enemy: Enemy, world_root: Node) -> void:
	if pine_sprite == null or pine_count <= 0:
		return
	# Angles are in screen space (y down), so -PI/2 is straight up and the fan runs
	# left -> up -> right.
	var first_angle := -PI / 2.0
	var step := 0.0
	if pine_count > 1:
		var arc := deg_to_rad(pine_arc_degrees)
		first_angle -= arc / 2.0
		step = arc / float(pine_count - 1)
	for i in pine_count:
		var direction := Vector2.from_angle(first_angle + step * float(i))
		Projectile.spawn(world_root, {
			&"global_position": enemy.global_position + direction * pine_spawn_offset,
			&"direction": direction,
			&"sprite": pine_sprite,
			&"damage": pine_damage * enemy.damage_scale,
			&"speed": pine_speed,
			&"lifetime": pine_lifetime,
			&"gravity": pine_gravity,
			&"collision_size": pine_collision_size,
			&"collision_layer": 0,
			&"collision_mask": pine_collision_mask,
			&"source": enemy,
		})
