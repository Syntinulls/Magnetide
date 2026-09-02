extends LeverModifierBehavior
class_name MinesModifierBehavior

## "Mines!" (negative): a threat-scaled number of yellow zones secretly arm as
## mines, marked by a centered icon. Pressing a mined yellow is treated exactly
## like pressing red -- instant fail with the full red treatment, except that the
## mined zone is what blinks rather than the reds -- but reads
## "Boom!" instead of "MISS". Clean yellows still resolve as "CLOSE".
##
## The one board that keeps the icon-sized min_zone_width_ratio on its clusters:
## its icons sit in the yellows the board itself sizes, so the guarantee has to
## come from the floor rather than from whatever the threat taper happens to leave.
## The cost is that its greens ride that floor at high threat instead of tapering
## -- a wider safe target on the board whose yellows can kill, which is a fair
## trade. Author min_zone_width_ratio down on the .tres to give that up.

## Mined yellow zones at threat stage 0 and stage 9; clamped to the number of
## yellow zones on the board.
@export var mines_min: int = 1
@export var mines_max: int = 4
@export var mine_icon: Texture2D = preload("res://_project/level/lever_minigame/modifiers/mines/sprites/mine.png")
@export var fail_text: String = "Boom!"

var _mined_zones: Array[LeverMinigame.Zone] = []


func on_minigame_started(_minigame: LeverMinigame, _threat_level: int) -> void:
	_mined_zones.clear()


func modify_zones(minigame: LeverMinigame, threat_level: int) -> void:
	var yellows: Array[LeverMinigame.Zone] = []
	for zone in minigame.get_zones():
		if zone.type == LeverMinigame.ZoneType.YELLOW:
			yellows.append(zone)
	var count := clampi(minigame.scale_for_threat(threat_level, mines_min, mines_max), 0, yellows.size())
	yellows.shuffle()
	for i in range(count):
		yellows[i].icon = mine_icon
		_mined_zones.append(yellows[i])


func handle_press(minigame: LeverMinigame, zone: LeverMinigame.Zone) -> bool:
	if not _mined_zones.has(zone):
		return false
	# The mine that went off is the only thing that blinks: the board is otherwise
	# clean, and blinking every red would blame zones the player never touched.
	var offending: Array[LeverMinigame.Zone] = [zone]
	minigame.fail_minigame(fail_text, minigame.zone_color_red, offending)
	return true
