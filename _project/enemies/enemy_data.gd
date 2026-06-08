extends Resource
class_name EnemyData

enum TargetCategory {
	PLAYER,
	MAGNET,
	SHIP,
}

enum TargetPointSelectionMode {
	RANDOM,
	CLOSEST,
}

@export var enemy_name: String = ""

@export_group("Stats")
## Maximum health points.
@export var max_health: float = 50.0
## Damage dealt per attack hit.
@export var damage: float = 5.0
## Movement speed in pixels per second.
@export var movement_speed: float = 100.0
## Legacy field kept for compatibility. Target acquisition no longer uses range.
@export var detection_range: float = 500.0
## Distance at which the enemy stops moving and begins attacking.
@export var attack_range: float = 50.0
## Seconds between each attack hit while in range.
@export var attack_interval: float = 1.0
## Legacy cleanup time kept for compatibility with existing enemy resources.
@export var death_linger_time: float = 1.5

@export_group("Hitbox")
## Rectangle size used for the enemy damage hitbox.
@export var hitbox_size: Vector2 = Vector2(40.0, 40.0)

@export_group("Targeting")
@export var initial_target_priorities: Array[TargetCategory] = [TargetCategory.PLAYER]
@export var damaged_target_priorities: Array[TargetCategory] = []
@export var retarget_on_damage: bool = false
@export var retarget_on_health_threshold: bool = false
@export_range(0.0, 1.0, 0.01) var retarget_health_threshold: float = 0.3
@export var structure_point_selection_mode: TargetPointSelectionMode = TargetPointSelectionMode.RANDOM

@export_group("Move Animation")
@export var move_spritesheet: Texture2D
@export var move_frames: int = 1
@export var move_fps: float = 8.0

@export_group("Attack Animation")
@export var attack_spritesheet: Texture2D
@export var attack_frames: int = 1
@export var attack_fps: float = 8.0

@export_group("Death Animation")
@export var death_spritesheet: Texture2D
@export var death_frames: int = 1
@export var death_fps: float = 1.0

@export_group("Death Sequence")
@export var death_shake_duration: float = 0.5
@export var death_shake_distance: float = 8.0
@export var death_shake_steps: int = 28
@export var death_pause_duration: float = 0.5
@export var death_pop_velocity_x_range: Vector2 = Vector2(-80.0, 80.0)
@export var death_pop_up_velocity_range: Vector2 = Vector2(520.0, 760.0)
@export var death_pop_gravity: float = 1400.0
@export var death_pop_rotation_velocity_range: Vector2 = Vector2(-10.0, 10.0)
@export var death_pop_despawn_margin: float = 128.0
@export var death_pop_max_time: float = 4.0
