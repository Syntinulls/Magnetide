extends HeldItemBehavior
class_name WeaponBehavior

## Category-level weapon handling: trigger/reload input, fire cooldown, the
## per-slot magazine, and fire/reload audio. The per-weapon firing pattern
## stays in WeaponData.fire_behavior; this class is what pulls its trigger.

const RELOAD_BAR_COLOR: Color = Color("ffffff")
const RELOAD_BAR_TEXT: String = "Reloading..."
const FALLBACK_SHOOT_SFX: Array[String] = [
	"weapons/machine_gun_shot_1.ogg",
	"weapons/machine_gun_shot_2.ogg",
	"weapons/machine_gun_shot_3.ogg"
]
const ProjectileScript: Script = preload("res://_project/combat/projectile.gd")
const FallbackBulletTexture: Texture2D = preload("res://icon.svg")

var _fire_cooldown: float = 0.0
var _ammo: int = 0
## Reload progress in seconds. Valid only while _is_reloading; it persists
## across weapon switches so a reload resumes from where it left off rather
## than restarting.
var _reload_elapsed: float = 0.0
var _is_reloading: bool = false
## True while the trigger is down *and* the weapon can actually fire. Drives the
## start/stop one-shots and the held fire loop, so it never latches on for a
## trigger pull that produces no shots (empty magazine, mid-reload).
var _is_firing: bool = false

var weapon: WeaponData:
	get:
		return data as WeaponData


func setup(for_player: Player, for_data: HeldItemData) -> void:
	super.setup(for_player, for_data)
	_ammo = weapon.magazine_size if weapon else 0


func process_input(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if player.combat_disabled:
		_set_firing(false)
		return
	_process_reload(delta)
	if Input.is_action_just_pressed("reload"):
		_try_manual_reload()
	# Cannot shoot while reloading, and never past an empty magazine.
	if is_reloading():
		_set_firing(false)
		return
	_set_firing(Input.is_action_pressed("shoot") and get_current_ammo() > 0)
	if _is_firing and _fire_cooldown <= 0.0:
		shoot()


## Input is blocked (cutscene, UI capture): the trigger is effectively released,
## so a held fire loop must not keep burning.
func process_blocked(_delta: float) -> void:
	_set_firing(false)


func unequipped() -> void:
	_set_firing(false)
	# Hide the reload bar; progress is preserved and resumes on reselect.
	player.progress_bar.clear(&"reload")


func on_run_end() -> void:
	_cancel_firing()
	_is_reloading = false
	_reload_elapsed = 0.0
	_fire_cooldown = 0.0
	player.progress_bar.clear(&"reload")


func shoot() -> void:
	var wpn := weapon
	if not wpn:
		return
	_fire_cooldown = 1.0 / maxf(wpn.fire_rate, 0.01)
	if player.muzzle_effect:
		player.muzzle_effect.play_effect(wpn.get_muzzle_effect_type(), _fire_cooldown)
	_play_fire_sfx(wpn)
	if wpn.fire_behavior and wpn.fire_behavior.has_method("fire"):
		wpn.fire_behavior.fire(self, wpn)
	else:
		fire_weapon_projectile(get_weapon_aim_direction(), wpn)
	_consume_ammo_for_shot(wpn)


func get_weapon_aim_direction() -> Vector2:
	return player.get_aim_direction()


func fire_weapon_projectile(direction: Vector2, weapon_data: WeaponData) -> Node2D:
	if weapon_data == null:
		return null

	var bullet_direction := direction.normalized()
	if bullet_direction.length_squared() <= 0.0001:
		bullet_direction = get_weapon_aim_direction()
	bullet_direction = bullet_direction.rotated(weapon_data.roll_bullet_spread_offset())

	var sprite_value: Variant = weapon_data.bullet_sprite if weapon_data.bullet_sprite else FallbackBulletTexture
	if weapon_data.bullet_sprite_frames != null:
		sprite_value = weapon_data.bullet_sprite_frames

	var world_root := Magnetide.world_root
	if world_root:
		return ProjectileScript.spawn(world_root, {
			&"global_position": _get_bullet_spawn_position(),
			&"direction": bullet_direction,
			&"sprite": sprite_value,
			&"visual_material": weapon_data.projectile_material,
			&"damage": weapon_data.damage * player.outgoing_damage_multiplier,
			&"speed": weapon_data.bullet_speed,
			&"lifetime": weapon_data.bullet_lifetime,
			&"collision_layer": 1 << PhysicsLayers.SALVAGE_ITEMS,
			&"collision_mask": 1 << PhysicsLayers.ENEMIES,
			&"source": player,
			&"inherited_velocity": Vector2(
				player.velocity.x if weapon_data.inherit_shooter_velocity_x else 0.0,
				player.velocity.y if weapon_data.inherit_shooter_velocity_y else 0.0
			),
			&"pierce": weapon_data.pierce,
			&"gravity": weapon_data.projectile_gravity,
			&"impact_damage": weapon_data.impact_damage,
			&"impact_effect": weapon_data.impact_effect,
			&"destroy_on_contact": weapon_data.destroy_on_contact,
			&"contact_effect": weapon_data.contact_effect,
			&"projectile_behavior": weapon_data.projectile_behavior,
			&"collision_size": weapon_data.bullet_collision_size,
		})
	return null


## True when this weapon uses a magazine (drives the HUD ammo readout).
func has_ammo_display() -> bool:
	return weapon != null and weapon.magazine_size > 0


func get_current_magazine_size() -> int:
	return weapon.magazine_size if weapon else 0


func get_current_ammo() -> int:
	return _ammo


func is_reloading() -> bool:
	return _is_reloading


## Reseeds the magazine to full and cancels any reload in progress (debug panel).
func refill_ammo() -> void:
	_ammo = get_current_magazine_size()
	_is_reloading = false
	_reload_elapsed = 0.0
	player.progress_bar.clear(&"reload")


## Bullets normally spawn at the muzzle, but an enemy hitbox between the
## player's center and the muzzle (a latched worm) would sit behind the spawn
## point and be impossible to hit. In that case the bullet spawns at the
## player's center so it overlaps the enemy on its first physics frame.
func _get_bullet_spawn_position() -> Vector2:
	var space_state := player.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(player.global_position, player.muzzle.global_position, 4)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	# A latched enemy's hitbox usually contains the ray origin itself.
	query.hit_from_inside = true
	if space_state.intersect_ray(query).is_empty():
		return player.muzzle.global_position
	return player.global_position


## Manual reload (R). Ignored if a reload is already running or the magazine is
## already full.
func _try_manual_reload() -> void:
	var wpn := weapon
	if wpn == null or wpn.magazine_size <= 0:
		return
	if is_reloading():
		return
	if get_current_ammo() >= wpn.magazine_size:
		return
	_is_reloading = true
	_reload_elapsed = 0.0
	_play_reload_sfx(wpn)


## Spends ammo for a shot that just fired. Drains whatever remains even when it
## is less than the per-shot cost, then kicks off an automatic reload at empty.
func _consume_ammo_for_shot(wpn: WeaponData) -> void:
	if wpn == null or wpn.magazine_size <= 0:
		return
	_ammo -= mini(_ammo, wpn.ammo_consumption)
	if _ammo <= 0:
		_ammo = 0
		_is_reloading = true  # auto-reload begins next frame
		_reload_elapsed = 0.0
		_play_reload_sfx(wpn)


func _process_reload(delta: float) -> void:
	if not _is_reloading:
		return
	var wpn := weapon
	if wpn == null or wpn.magazine_size <= 0:
		_is_reloading = false
		player.progress_bar.clear(&"reload")
		return
	var reload_time := maxf(wpn.reload_time, 0.0)
	_reload_elapsed += delta
	if _reload_elapsed >= reload_time:
		_ammo = wpn.magazine_size
		_is_reloading = false
		_reload_elapsed = 0.0
		player.progress_bar.clear(&"reload")
		return
	player.progress_bar.request(
		&"reload",
		clampf(_reload_elapsed / maxf(reload_time, 0.01), 0.0, 1.0),
		RELOAD_BAR_COLOR,
		RELOAD_BAR_TEXT,
		PlayerProgressBarController.PRIORITY_RELOAD
	)


## Enters or leaves the firing state, firing the start/stop one-shots and the held
## fire loop on the edges. Safe to call every frame; only transitions do anything.
##
## Each edge cuts the other's audio short so the weapon always sounds like it is
## doing what the trigger says: tapping fire plays the start and stop sounds back
## to back rather than holding a 1.5s ignition after release, and re-firing during
## a stop tail drops the tail instead of layering under the new burst.
func _set_firing(firing: bool) -> void:
	if _is_firing == firing:
		return
	_is_firing = firing
	var wpn := weapon
	if wpn == null:
		return
	if firing:
		_stop_sfx(wpn.fire_stop_sfx)
		_play_edge_sfx(wpn.fire_start_sfx, wpn.fire_start_sfx_volume_db)
		_start_fire_loop_sfx(wpn)
	else:
		_stop_fire_loop_sfx(wpn)
		_stop_sfx(wpn.fire_start_sfx)
		_play_edge_sfx(wpn.fire_stop_sfx, wpn.fire_stop_sfx_volume_db)


## Drops the firing state without the stop one-shot — run teardown, where the tail
## would play over the results screen.
func _cancel_firing() -> void:
	if not _is_firing:
		return
	_is_firing = false
	var wpn := weapon
	_stop_fire_loop_sfx(wpn)
	if wpn:
		_stop_sfx(wpn.fire_start_sfx)


func _play_edge_sfx(stream: AudioStream, volume_db: float) -> void:
	if Magnetide.sfx == null or stream == null:
		return
	Magnetide.sfx.play(stream, volume_db)


func _stop_sfx(stream: AudioStream) -> void:
	if Magnetide.sfx == null or stream == null:
		return
	Magnetide.sfx.stop(stream)


func _start_fire_loop_sfx(wpn: WeaponData) -> void:
	if Magnetide.sfx == null or wpn == null:
		return
	var stream := wpn.get_fire_loop_sfx()
	if stream == null:
		return
	Magnetide.sfx.play_loop(stream, _get_fire_loop_sfx_key(), wpn.fire_sfx_volume_db)


func _stop_fire_loop_sfx(wpn: WeaponData) -> void:
	if Magnetide.sfx == null or wpn == null:
		return
	var stream := wpn.get_fire_loop_sfx()
	if stream == null:
		return
	Magnetide.sfx.stop_loop(stream, _get_fire_loop_sfx_key())


## One loop player per equipment slot, so two slots holding the same weapon (or a
## weapon swap mid-burst) never fight over the same playback.
func _get_fire_loop_sfx_key() -> String:
	return "weapon_fire:%s" % get_instance_id()


func _play_fire_sfx(wpn: WeaponData) -> void:
	if Magnetide.sfx == null or wpn == null:
		return
	# A looping weapon holds one continuous sound for the whole burst instead.
	if wpn.fire_sfx_loop:
		return
	var use_last := get_current_ammo() <= wpn.ammo_consumption and not wpn.last_shot_sfx.is_empty()
	var pool := wpn.last_shot_sfx if use_last else wpn.fire_sfx
	if pool.is_empty():
		_play_fallback_shoot_sfx()
		return
	var stream: AudioStream = pool[randi() % pool.size()]
	if stream == null:
		return
	var volume_db := wpn.last_shot_sfx_volume_db if use_last else wpn.fire_sfx_volume_db
	Magnetide.sfx.play(stream, volume_db)


func _play_fallback_shoot_sfx() -> void:
	if not Magnetide.sfx or FALLBACK_SHOOT_SFX.is_empty():
		return
	Magnetide.sfx.play(FALLBACK_SHOOT_SFX[randi() % FALLBACK_SHOOT_SFX.size()])


func _play_reload_sfx(wpn: WeaponData) -> void:
	if Magnetide.sfx == null or wpn == null or wpn.reload_sfx == null:
		return
	Magnetide.sfx.play(wpn.reload_sfx, wpn.reload_sfx_volume_db)
