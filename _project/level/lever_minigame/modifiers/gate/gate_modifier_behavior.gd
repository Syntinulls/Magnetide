extends LeverModifierBehavior
class_name GateModifierBehavior

## "Gate!" (negative): replaces the board outright. A threat-scaled run of blue
## key zones sits on the left, a single purple gate zone on the right, and red
## everywhere else -- two objectives, so two lights: one centered under the whole
## key run, one under the gate. Threat adds keys and nothing else: the zones hold
## their authored width at every stage, because a key is read by the colour of
## the icon inside it and a zone that shrank with threat would shrink the icon
## with it.
##
## The gate's colour is drawn during setup and shown fixed from the moment its
## padlock appears, so the player has the whole countdown to take it in. Every key
## opens on a colour of its own too, but holds it while the board assembles: the
## keys only start turning over once the countdown begins and the whole board --
## keys, gate and every red -- is on show, so the cycling reads as the puzzle
## starting rather than as more of the board arriving. From there the keys cycle
## their icon through the candidate colours, and on "Go!" they lock:
## each takes a different one, and exactly one is dealt the gate's. That key is
## the only one that opens it -- pressing any other key, pressing red, or letting
## either objective slip past fails the attempt. Hitting the right key flips the
## gate's padlock open and pulses the gate once, and the pull is won by hitting
## the gate after it -- which is what lights it for good.

@export var key_color: Color = Color("4a90d9")
@export var gate_color: Color = Color("785fbe")
## Key zones at threat stage 0 and stage 9; capped by the candidate colours,
## since every key must take a different one.
@export var keys_min: int = 2
@export var keys_max: int = 4
## Full widths as a ratio of the bar width, held at every threat: these zones are
## read by the icon they carry, not aimed at like a green, so they stay wide
## enough for that icon to fill the bar's height. Threat adds keys instead.
@export var key_width_ratio: float = 0.09
@export var gate_width_ratio: float = 0.11
## The key run is spread between these two ratios; the gate sits centered on
## gate_center_ratio, after every key. Gate keeps its own start margin rather
## than borrowing the default board's: that one has to clear a green's yellows
## and the minimum-width red beyond them, while a key run only has to leave red
## at the bar's edge.
@export var key_span_start_ratio: float = 0.10
@export var key_span_end_ratio: float = 0.70
@export var gate_center_ratio: float = 0.88
## Minimum distance between key centers as a ratio of the bar width.
@export var min_key_spacing_ratio: float = 0.14
@export var key_icon: Texture2D = preload("res://_project/level/lever_minigame/modifiers/gate/sprites/key.png")
@export var gate_locked_icon: Texture2D = preload("res://_project/common/sprites/icon_lock.png")
@export var gate_unlocked_icon: Texture2D = preload("res://_project/common/sprites/icon_lock_open.png")
## The colours a key or the gate can lock into. Keys take unique ones, so this
## also caps how many keys a board can carry.
@export var candidate_colors: Array[Color] = [
	Color("d1493f"), Color("e08a3c"), Color("e8c14b"), Color("58c05c")
]
## Seconds each colour holds while the icons cycle before the lock-in.
@export var color_cycle_time: float = 0.5
@export var wrong_key_text: String = "Wrong Key!"
@export var unlocked_text: String = "Unlocked!"

var _key_zones: Array[LeverMinigame.Zone] = []
var _gate_zone: LeverMinigame.Zone = null
## Index into candidate_colors, drawn at setup: the colour the gate shows all
## attempt, and the one key that opens it.
var _gate_color_index: int = 0
var _gate_key_index: int = -1
var _colors_locked := false
## Set when the countdown starts; until then the keys hold their opening colours.
var _cycling := false
## The icon rects only exist once the board is built, so the opening colours go on
## at the first tick there is anything to paint.
var _icons_painted := false
var _cycle_elapsed: float = 0.0
var _cycle_step: int = 0


func on_minigame_started(_minigame: LeverMinigame, _threat_level: int) -> void:
	_key_zones.clear()
	_gate_zone = null
	_gate_key_index = -1
	_colors_locked = false
	_cycling = false
	_icons_painted = false
	_cycle_elapsed = 0.0
	# Random opening step, so the arrangement the keys hold through the reveal is
	# a different one each attempt rather than always the authored order.
	_cycle_step = randi() % maxi(candidate_colors.size(), 1)
	_gate_color_index = randi() % maxi(candidate_colors.size(), 1)


func build_board(minigame: LeverMinigame, threat_level: int) -> void:
	var half_key := key_width_ratio * 0.5
	var half_gate := gate_width_ratio * 0.5
	var key_count := clampi(
		minigame.scale_for_threat(threat_level, keys_min, keys_max), 1, candidate_colors.size()
	)
	# generate_centers spreads over the whole bar, so sample it then compress the
	# result into the key span, leaving the right end of the bar for the gate.
	var span_scale := key_span_end_ratio - key_span_start_ratio
	var centers := minigame.generate_centers(
		key_count, min_key_spacing_ratio / maxf(span_scale, 0.01), key_span_start_ratio
	)
	var last_edge := 0.0
	for center in centers:
		var placed: float = key_span_start_ratio + center * span_scale
		var zone := minigame.append_zone(
			LeverMinigame.ZoneType.SPECIAL, placed - half_key, placed + half_key
		)
		zone.custom_color = key_color
		zone.icon = key_icon
		_key_zones.append(zone)
		last_edge = zone.end_ratio
	# One objective for the whole key run: its light sits centered under it, and
	# its deadline is the last key, so sweeping past them all without finding the
	# right one is an ordinary miss.
	var key_span_center: float = (_key_zones[0].start_ratio + last_edge) * 0.5
	var keys_objective := minigame.add_objective(key_span_center, last_edge)
	for zone in _key_zones:
		zone.objective_index = keys_objective
	var gate_objective := minigame.add_objective(gate_center_ratio, gate_center_ratio + half_gate)
	_gate_zone = minigame.append_zone(
		LeverMinigame.ZoneType.SPECIAL,
		gate_center_ratio - half_gate,
		gate_center_ratio + half_gate,
		gate_objective
	)
	_gate_zone.custom_color = gate_color
	_gate_zone.icon = gate_locked_icon


func on_process(minigame: LeverMinigame, real_delta: float) -> void:
	if _colors_locked or candidate_colors.is_empty() or _gate_zone == null:
		return
	if not _icons_painted:
		_paint_keys(minigame)
		# The gate never cycles -- its colour is settled before the countdown even
		# starts. Painted with the keys so it doesn't show unmodulated either.
		minigame.set_zone_icon_modulate(_gate_zone, candidate_colors[_gate_color_index])
		_icons_painted = true
		return
	if not _cycling:
		return
	_cycle_elapsed += real_delta
	if _cycle_elapsed < color_cycle_time:
		return
	_cycle_elapsed -= color_cycle_time
	_cycle_step += 1
	_paint_keys(minigame)


## Staggered offsets so the keys read as independently unresolved rather than one
## bar of colour moving in lockstep.
func _paint_keys(minigame: LeverMinigame) -> void:
	for i in range(_key_zones.size()):
		minigame.set_zone_icon_modulate(_key_zones[i], _cycled_color(_cycle_step + i))


func on_countdown_started(_minigame: LeverMinigame, _threat_level: int) -> void:
	_cycling = true
	_cycle_elapsed = 0.0


func on_countdown_finished(minigame: LeverMinigame, _threat_level: int) -> void:
	var pool: Array[int] = []
	for i in range(candidate_colors.size()):
		pool.append(i)
	pool.shuffle()
	# The gate's colour is already on show, so one key has to be dealt it -- with
	# fewer keys than candidates the shuffle alone could leave it out entirely.
	# Swapping it into the opening key's slot keeps every key colour distinct.
	_gate_key_index = randi() % _key_zones.size()
	var gate_slot := pool.find(_gate_color_index)
	pool[gate_slot] = pool[_gate_key_index]
	pool[_gate_key_index] = _gate_color_index
	for i in range(_key_zones.size()):
		minigame.set_zone_icon_modulate(_key_zones[i], candidate_colors[pool[i]])
	_colors_locked = true


func handle_press(minigame: LeverMinigame, zone: LeverMinigame.Zone) -> bool:
	if zone == _gate_zone:
		minigame.resolve_objective(zone, true)
		return true
	var key_index := _key_zones.find(zone)
	if key_index < 0:
		return false
	if key_index != _gate_key_index:
		# The key that was wrong blinks, in its own colour, rather than every red:
		# the mistake was a colour match, and that is what has to read back.
		var offending: Array[LeverMinigame.Zone] = [zone]
		minigame.fail_minigame(wrong_key_text, minigame.zone_color_red, offending)
		return true
	minigame.resolve_objective(zone, true)
	minigame.set_zone_icon(_gate_zone, gate_unlocked_icon)
	# One pulse as the padlock springs open, then straight back to resting: the
	# gate is unlocked, not answered. It only lights for good once it is hit.
	minigame.flash_zone(_gate_zone)
	minigame.show_info(unlocked_text, gate_color)
	return true


func _cycled_color(step: int) -> Color:
	return candidate_colors[step % candidate_colors.size()]
