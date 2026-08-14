extends ProjectileBehavior
class_name FlameProjectileBehavior

## Flamethrower flame motion/visuals: a short full-speed burst out of the muzzle,
## then a sharp falloff to a drift. The visual grows linearly over the flame's
## lifetime, shifts color along color_ramp, and spins at a per-flame random
## speed and direction.

## Seconds at full bullet speed before the falloff begins.
@export var burst_duration: float = 0.12
## Seconds over which speed decays from full down to min_speed.
@export var falloff_duration: float = 1.0
## Drift speed the flame settles at after the falloff.
@export var min_speed: float = 250.0
## Sprite scale at spawn, so flames are visible right out of the muzzle.
@export var min_visual_scale: float = 0.7
## Sprite scale at end of lifetime.
@export var max_visual_scale: float = 2.0
## Spin speed range, radians/second. Direction is rolled per flame.
@export var spin_speed_min: float = 2.0
@export var spin_speed_max: float = 5.0
## Flame color over normalized lifetime: yellow-white -> yellow -> orange -> dark gray.
@export var color_ramp: Gradient = null

var _spin: float = 0.0


func setup(_projectile: Projectile) -> void:
	_spin = randf_range(spin_speed_min, spin_speed_max) * (1.0 if randf() < 0.5 else -1.0)


func get_velocity(projectile: Projectile, elapsed: float) -> Vector2:
	return projectile.direction * _current_speed(projectile, elapsed)


func tick(projectile: Projectile, elapsed: float, delta: float) -> void:
	var visual := projectile.visual
	if visual == null:
		return
	var growth := clampf(elapsed / maxf(projectile.lifetime, 0.01), 0.0, 1.0)
	visual.scale = Vector2.ONE * lerpf(min_visual_scale, max_visual_scale, growth)
	if color_ramp != null:
		visual.modulate = color_ramp.sample(clampf(elapsed / maxf(projectile.lifetime, 0.01), 0.0, 1.0))
	visual.rotation += _spin * delta


## Speed over elapsed lifetime: constant burst, then a sharp (cubic ease-out)
## decay to min_speed.
func _current_speed(projectile: Projectile, elapsed: float) -> float:
	if elapsed <= burst_duration:
		return projectile.speed
	var t := clampf((elapsed - burst_duration) / maxf(falloff_duration, 0.01), 0.0, 1.0)
	return lerpf(projectile.speed, min_speed, 1.0 - pow(1.0 - t, 3.0))
