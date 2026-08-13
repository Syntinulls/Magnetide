extends HeldItemBehavior
class_name RepairGunBehavior

## Hold-LMB repair loop: while the beam holds on the hull with enough in-run
## scrap and the ship below max integrity, the "Repairing" bar advances at the
## tool's repair_rate; each completed cycle spends scrap and restores integrity.
## Any dropout (release, miss, broke, full) resets progress to zero — unlike
## reload, repair progress is never preserved.

const REPAIR_BAR_COLOR: Color = Color("9bff63")
const REPAIR_BAR_TEXT: String = "Repairing..."
const NO_SCRAP_TEXT: String = "No Scrap"
const FULLY_REPAIRED_TEXT: String = "Fully Repaired"

## Cycle progress (0..1); resets to 0 whenever the beam drops.
var _repair_progress: float = 0.0
## One refusal cue per press: set when one shows, cleared on release.
var _refusal_shown: bool = false

var tool: RepairGunData:
	get:
		return data as RepairGunData


func process_input(delta: float) -> void:
	var gun := tool
	if gun == null:
		_stop_repair(false)
		return
	if not Input.is_action_pressed("shoot"):
		_refusal_shown = false
		_stop_repair(true)
		return
	var contact := _find_repairable_contact(gun)
	if contact.is_empty():
		_stop_repair(true)
		return
	var ship := contact["ship"] as Ship
	var contact_point: Vector2 = contact["position"]
	var run := Magnetide.run as RunController
	if run == null:
		_stop_repair(true)
		return
	# Missing scrap outranks a full hull: it is the condition the player can act on.
	if run.scrap_metal_collected < gun.repair_cost:
		_refuse(contact_point, NO_SCRAP_TEXT, DamageNumber.DENIED_COLOR)
		_stop_repair(true)
		return
	if ship.current_health >= ship.max_health:
		_refuse(contact_point, FULLY_REPAIRED_TEXT, DamageNumber.HEAL_COLOR)
		_stop_repair(true)
		return
	player.repair_beam.update_beam(contact_point)
	_repair_progress += delta * gun.repair_rate
	if _repair_progress >= 1.0:
		_repair_progress = 0.0
		if run.spend_scrap_metal(gun.repair_cost):
			ship.repair(gun.repair_amount, contact_point)
	player.progress_bar.request(
		&"repair",
		_repair_progress,
		REPAIR_BAR_COLOR,
		REPAIR_BAR_TEXT,
		PlayerProgressBarController.PRIORITY_REPAIR
	)


## Tell the player why the beam refused: a popup plus one pass of the beam's contact
## effects at the spot on the hull they aimed at, once per press rather than every
## frame they keep holding it down.
func _refuse(contact_point: Vector2, text: String, color: Color) -> void:
	if _refusal_shown:
		return
	_refusal_shown = true
	DamageNumber.spawn_text(contact_point, text, color)
	if player.repair_beam:
		player.repair_beam.flash_once(contact_point)


## A repair beam must never freeze on-screen while input is captured.
func process_blocked(_delta: float) -> void:
	_refusal_shown = false
	if _repair_progress > 0.0 or (player.repair_beam and player.repair_beam.is_active()):
		_stop_repair(false)


func unequipped() -> void:
	_refusal_shown = false
	_stop_repair(false)


## Raycast from the muzzle along the aim direction for a repairable surface (the
## ship's hull hitbox). Areas-only on layer 1 skips the Boundaries body outright;
## other layer-1 areas (the magnet hitbox) are excluded and recast past. Returns
## {} on miss, else { "ship": Ship, "position": Vector2 }.
func _find_repairable_contact(gun: RepairGunData) -> Dictionary:
	var space_state := player.get_world_2d().direct_space_state
	var from := player.muzzle.global_position
	var to := from + player.get_aim_direction() * gun.beam_range
	var exclude: Array[RID] = []
	for _attempt in 4:
		var query := PhysicsRayQueryParameters2D.create(from, to, 1, exclude)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		# Aiming steeply down can start the ray inside the hull polygon; report
		# that as a hit at the ray origin (normal == ZERO) instead of nothing.
		query.hit_from_inside = true
		var result := space_state.intersect_ray(query)
		if result.is_empty():
			return {}
		var collider := result.get("collider") as Node
		if collider is Hitbox:
			var target_owner := (collider as Hitbox).get_target_owner()
			if target_owner is Ship:
				var hit_position := from if Vector2(result["normal"]) == Vector2.ZERO else Vector2(result["position"])
				return {"ship": target_owner, "position": hit_position}
		exclude.append(result["rid"])
	return {}


func _stop_repair(dissipate: bool) -> void:
	_repair_progress = 0.0
	player.progress_bar.clear(&"repair")
	if player.repair_beam == null:
		return
	if dissipate:
		player.repair_beam.stop_dissipate()
	else:
		player.repair_beam.stop_immediate()
