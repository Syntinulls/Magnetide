extends Resource
class_name EnemyData

@export var enemy_name: String = ""

@export_group("Stats")
## Maximum health points.
@export var max_health: float = 50.0
## Damage dealt per attack hit.
@export var damage: float = 5.0
## Movement speed in pixels per second.
@export var movement_speed: float = 100.0
## Maximum distance at which the enemy can detect targets.
@export var detection_range: float = 500.0
## Distance at which the enemy stops moving and begins attacking.
@export var attack_range: float = 50.0
## Seconds between each attack hit while in range.
@export var attack_interval: float = 1.0
## Health ratio (0-1) at which the enemy may retarget to a higher-priority node.
@export var retarget_health_ratio: float = 0.3
## Seconds the corpse lingers after death before being freed.
@export var death_linger_time: float = 1.5
## Radius of the collision circle.
@export var collision_radius: float = 20.0

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
