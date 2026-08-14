extends Resource
class_name ProjectileBehavior

## Per-projectile motion/tick strategy. The projectile duplicates the authored
## resource in configure() so overrides may keep per-projectile state (spin,
## phase timers) without sharing it across shots.


## Called once when the projectile enters the tree. Roll per-projectile state here.
func setup(_projectile: Projectile) -> void:
	pass


## Velocity for the current frame. Default: linear flight at constant speed.
func get_velocity(projectile: Projectile, _elapsed: float) -> Vector2:
	return projectile.direction * projectile.speed


## Per-frame hook driven by the projectile's elapsed lifetime; use it to evolve
## the visual (scale, modulate, spin) as the projectile ages.
func tick(_projectile: Projectile, _elapsed: float, _delta: float) -> void:
	pass
