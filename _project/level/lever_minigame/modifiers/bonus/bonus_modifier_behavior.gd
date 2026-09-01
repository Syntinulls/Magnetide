extends LeverModifierBehavior
class_name BonusModifierBehavior

## "Bonus!" (positive): adds one special blue zone centered in a random interior
## red gap -- between two adjacent green clusters, never the edge reds. Hitting
## it is optional; if it was hit and the attempt succeeds, a random amount of
## scrap flies to the HUD from above the screen center after the panel closes,
## exactly like the recycler award. A failed attempt forfeits the bonus.

@export var zone_color: Color = Color("4a90d9")
@export var zone_icon: Texture2D = preload("res://icon.svg")
## Full width of the bonus zone as a ratio of the bar width.
@export var zone_width_ratio: float = 0.04
@export var hit_text: String = "Bonus Hit!"
@export var scrap_min: int = 3
@export var scrap_max: int = 8
## Pause after the minigame closes before the scrap pickups appear, so the
## activation presentation (camera, vignette) finishes restoring first.
@export var award_delay: float = 0.4

var _bonus_zone: LeverMinigame.Zone = null
var _bonus_hit := false


func on_minigame_started(_minigame: LeverMinigame, _threat_level: int) -> void:
	_bonus_zone = null
	_bonus_hit = false


func modify_zones(minigame: LeverMinigame, _threat_level: int) -> void:
	var gaps := minigame.get_interior_red_zones()
	if gaps.is_empty():
		return
	# Prefer a gap wide enough for the authored width; insert_special_zone shrinks
	# the zone itself when every gap is too narrow.
	var eligible: Array[LeverMinigame.Zone] = []
	for zone in gaps:
		if zone.end_ratio - zone.start_ratio >= zone_width_ratio * 1.5:
			eligible.append(zone)
	var target: LeverMinigame.Zone = eligible.pick_random() if not eligible.is_empty() \
		else _widest(gaps)
	_bonus_zone = minigame.insert_special_zone(target, zone_width_ratio, zone_color, zone_icon)


func handle_press(minigame: LeverMinigame, zone: LeverMinigame.Zone) -> bool:
	if zone != _bonus_zone:
		return false
	if not _bonus_hit:
		_bonus_hit = true
		minigame.mark_zone_hit(zone)
		minigame.show_info(hit_text, zone_color)
	return true


func on_minigame_closed(minigame: LeverMinigame, success: bool) -> void:
	if not success or not _bonus_hit:
		return
	await minigame.get_tree().create_timer(award_delay).timeout
	var player := Magnetide.player
	if player == null or not is_instance_valid(player) or player.scrap_collector == null:
		return
	var origin := minigame.get_focus_world_position()
	var amount := randi_range(scrap_min, scrap_max)
	for i in range(amount):
		player.scrap_collector.collect_from(origin)


func _widest(zones: Array[LeverMinigame.Zone]) -> LeverMinigame.Zone:
	var widest: LeverMinigame.Zone = null
	for zone in zones:
		if widest == null or zone.end_ratio - zone.start_ratio > widest.end_ratio - widest.start_ratio:
			widest = zone
	return widest
