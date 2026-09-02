extends LeverModifierBehavior
class_name RecoverModifierBehavior

## "Recover!" (positive): a shorter board -- three clusters at most, even at max
## threat -- scattered with up to two optional blue recovery zones, each sitting
## in an interior red gap and marked by its own icon: one patches the player up,
## the other the ship's hull. Hitting them is optional and costs nothing to skip;
## every one that was hit pays out after a successful attempt, and a failed
## attempt forfeits them all. The amount restored scales with threat.

enum Kind { HEALTH, INTEGRITY }

## Clusters at threat stage 0 and stage 9; below the minigame's own range, so a
## Recover pull is shorter than a normal one at the same threat.
@export var cluster_min: int = 2
@export var cluster_max: int = 3
@export var zone_color: Color = Color("4a90d9")
## Recovery zones at threat stage 0 and stage 9, clamped to the interior red gaps
## the board actually has.
@export var zones_min: int = 1
@export var zones_max: int = 2
## Full width of a recovery zone as a ratio of the bar width, sized for its icon. insert_special_zone
## never takes it below this, so it survives landing in a tight gap -- which is
## why this board can author min_zone_width_ratio down to the no-icon floor and
## let its green/yellow clusters keep tapering with threat.
@export var zone_width_ratio: float = 0.05
@export var health_icon: Texture2D = preload("res://icon.svg")
@export var integrity_icon: Texture2D = preload("res://icon.svg")
@export var health_text: String = "Med Kit!"
@export var integrity_text: String = "Hull Patch!"
## Health restored at threat stage 0 and stage 9.
@export var health_amount_min: float = 10.0
@export var health_amount_max: float = 35.0
## Ship integrity restored at threat stage 0 and stage 9.
@export var integrity_amount_min: float = 20.0
@export var integrity_amount_max: float = 60.0
## Pause after the minigame closes before the recovery lands, so the activation
## presentation (camera, vignette) finishes restoring first.
@export var apply_delay: float = 0.4

## Zone -> Kind for the recovery zones on the board this attempt.
var _kinds_by_zone: Dictionary = {}
var _hit_zones: Array[LeverMinigame.Zone] = []
var _attempt_threat_level: int = 0


func on_minigame_started(_minigame: LeverMinigame, threat_level: int) -> void:
	_kinds_by_zone.clear()
	_hit_zones.clear()
	_attempt_threat_level = threat_level


func build_board(minigame: LeverMinigame, threat_level: int) -> void:
	minigame.build_default_board(threat_level, cluster_min, cluster_max)


func modify_zones(minigame: LeverMinigame, threat_level: int) -> void:
	var gaps := minigame.get_interior_red_zones()
	gaps.shuffle()
	var count := clampi(minigame.scale_for_threat(threat_level, zones_min, zones_max), 0, gaps.size())
	for i in range(count):
		var kind: Kind = Kind.HEALTH if randi() % 2 == 0 else Kind.INTEGRITY
		var zone := minigame.insert_special_zone(
			gaps[i], zone_width_ratio, zone_color, _icon_for(kind)
		)
		_kinds_by_zone[zone] = kind


func handle_press(minigame: LeverMinigame, zone: LeverMinigame.Zone) -> bool:
	if not _kinds_by_zone.has(zone):
		return false
	# Repeat presses on a zone already claimed are consumed and ignored.
	if not _hit_zones.has(zone):
		_hit_zones.append(zone)
		minigame.mark_zone_hit(zone)
		minigame.show_info(_text_for(_kinds_by_zone[zone]), zone_color)
	return true


func on_minigame_closed(minigame: LeverMinigame, success: bool) -> void:
	if not success or _hit_zones.is_empty():
		return
	await minigame.get_tree().create_timer(apply_delay).timeout
	for zone in _hit_zones:
		_apply(minigame, _kinds_by_zone[zone])


func _icon_for(kind: Kind) -> Texture2D:
	return health_icon if kind == Kind.HEALTH else integrity_icon


func _text_for(kind: Kind) -> String:
	return health_text if kind == Kind.HEALTH else integrity_text


func _amount_for(minigame: LeverMinigame, kind: Kind) -> float:
	if kind == Kind.HEALTH:
		return minigame.lerp_for_threat(_attempt_threat_level, health_amount_min, health_amount_max)
	return minigame.lerp_for_threat(_attempt_threat_level, integrity_amount_min, integrity_amount_max)


func _apply(minigame: LeverMinigame, kind: Kind) -> void:
	var amount := _amount_for(minigame, kind)
	if kind == Kind.HEALTH:
		var player := Magnetide.player
		if player and is_instance_valid(player):
			player.heal(amount)
		return
	var ship := Magnetide.ship as Ship
	if ship and is_instance_valid(ship):
		ship.repair(amount)
