extends EquipmentData
class_name WeaponData
@export var damage: float = 10.0
@export var fire_rate: float = 5.0
@export var bullet_speed: float = 1800.0
@export var pierce: int = 1:
	set(value):
		pierce = maxi(value, 1)
@export var bullet_sprite: Texture2D
@export var fire_behavior: Resource = null

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
