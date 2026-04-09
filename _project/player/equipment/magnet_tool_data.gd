extends EquipmentData
class_name MagnetToolData

## Sprite shown on player arm when equipped
@export var weapon_sprite: Texture2D
## Distance from muzzle to the magnet tool hold point
@export var hold_distance: float = 30.0
## Time in seconds to hold right-click to repel an item
@export var repel_hold_time: float = 0.8
## Impulse force applied when repelling an item
@export var repel_impulse_force: float = 2400.0
## Base speed items are pulled toward the magnet tool
@export var pull_base_speed: float = 133.0
## Max speed items are pulled toward the magnet tool
@export var pull_max_speed: float = 1000.0
## Time for pull speed to ramp from base to max
@export var pull_ramp_time: float = 0.6

@export_group("Positioning")
@export var weapon_offset: Vector2 = Vector2(-15.125, 0.0)
@export var weapon_rotation: float = -0.14660765
@export var muzzle_position: Vector2 = Vector2(-55.915, -4.695)
