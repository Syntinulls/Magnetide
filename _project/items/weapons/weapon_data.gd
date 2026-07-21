extends HeldItemData
class_name WeaponData
@export var damage: float = 10.0
@export var fire_rate: float = 5.0
@export var bullet_speed: float = 1800.0
@export var pierce: int = 1:
	set(value):
		pierce = maxi(value, 1)
@export var bullet_sprite: Texture2D
@export var fire_behavior: Resource = null

@export_group("Projectile Physics")
## Downward acceleration applied to this weapon's projectiles (px/s^2). 0 = straight-
## line bullet; a positive value arcs the shot (grenade launcher).
@export var projectile_gravity: float = 0.0

@export_group("Impact")
## When true, hitting an enemy deals this weapon's damage (and pierce) directly. Turn it
## off for weapons whose damage comes entirely from their impact effect — the grenade
## launcher, where only the explosion hurts.
@export var impact_damage: bool = true
## Optional effect spawned where a projectile lands (e.g. an explosion). Spawned on the
## first enemy the projectile touches; the effect owns its own area/animation and inherits
## this weapon's damage.
@export var impact_effect: PackedScene = null

@export_group("Fire Sound")
## Sound(s) played when this weapon fires. When more than one is supplied, one is
## chosen at random per shot to avoid repetition. Leave empty to use the default.
@export var fire_sfx: Array[AudioStream] = []
## Volume of the fire sound, in decibels (0 = unchanged, negative = quieter).
@export var fire_sfx_volume_db: float = 0.0
## Sound(s) played when firing the final round in the magazine. Leave empty to reuse
## the normal fire sound; set it to distinguish the last shot before a reload.
@export var last_shot_sfx: Array[AudioStream] = []
## Volume of the last-shot sound, in decibels (0 = unchanged, negative = quieter).
@export var last_shot_sfx_volume_db: float = 0.0
@export_group("Bullet Spread")
## Minimum spread cone width, in degrees. 0 = perfectly accurate.
@export_range(0.0, 90.0, 0.1, "degrees") var bullet_spread_min: float = 0.0:
	set(value):
		bullet_spread_min = maxf(value, 0.0)
## Maximum spread cone width, in degrees. Clamped to be >= bullet_spread_min.
@export_range(0.0, 90.0, 0.1, "degrees") var bullet_spread_max: float = 0.0:
	set(value):
		bullet_spread_max = maxf(value, 0.0)

@export_group("Ammo")
## Rounds available before a reload is required.
@export var magazine_size: int = 30:
	set(value):
		magazine_size = maxi(value, 1)
## Rounds consumed per shot (per trigger pull, not per pellet).
@export var ammo_consumption: int = 1:
	set(value):
		ammo_consumption = maxi(value, 1)
## Seconds to refill the magazine to full.
@export var reload_time: float = 1.5:
	set(value):
		reload_time = maxf(value, 0.0)
## Sound played when a reload begins for this weapon.
@export var reload_sfx: AudioStream = preload("res://_project/audio/sfx/rifle_reload.ogg")
## Volume of the reload sound, in decibels (0 = unchanged, negative = quieter).
@export var reload_sfx_volume_db: float = 0.0


## Per-bullet angular offset in radians. Rolls a spread magnitude in
## [bullet_spread_min, bullet_spread_max] degrees, then a random angle within
## that cone (±magnitude/2). Returns 0 when spread is disabled (0/0).
func roll_bullet_spread_offset() -> float:
	var lo := maxf(bullet_spread_min, 0.0)
	var hi := maxf(bullet_spread_max, lo)
	if hi <= 0.0:
		return 0.0
	var magnitude := randf_range(lo, hi)
	return deg_to_rad(randf_range(-magnitude * 0.5, magnitude * 0.5))
