extends Resource
class_name LeverModifierBehavior

## Base for lever minigame modifiers: authored .tres strategy resources rolled
## by LeverModifierWeights at each attempt. A modifier owns the board it plays on
## and hooks into press handling, the countdown, the per-frame tick, and the
## post-close moment; the minigame never branches on modifier identity, so all
## modifier-specific zones, text, and rewards live in the subclass. Instances are
## shared across attempts -- reset any per-attempt state in on_minigame_started.
## See specs/lever_minigame_modifier_boards_spec.md.

## Banner text popped via show_info when the minigame opens, e.g. "Bonus!".
@export var display_name: String = ""
@export var display_color: Color = Color.WHITE
## Floor on every zone width this modifier's board builds, as a ratio of the bar
## width, overriding the minigame's own min_zone_width_ratio. Zero inherits it,
## which is what a board that centers icons in its zones wants: the default is
## sized so an icon renders at its native height. A board that draws no icons
## (Invert, Ambush) sets a smaller one of its own, so its zones keep tapering with
## threat instead of every colour bottoming out on the same icon-sized floor.
@export var min_zone_width_ratio: float = 0.0


## Called from start_minigame before zones build; reset per-attempt state here.
func on_minigame_started(_minigame: LeverMinigame, _threat_level: int) -> void:
	pass


## Lays out the board: which zones exist, how wide they are, and how many
## objectives they answer to. Place only the zones that mean something -- the
## minigame fills every span left over with red afterwards. The default is the
## standard threat-scaled green/yellow clusters; override to shift the count
## range, reshape a cluster, or replace the board outright.
func build_board(minigame: LeverMinigame, threat_level: int) -> void:
	minigame.build_default_board(threat_level, minigame.zones_min, minigame.zones_max)


## Called after the board is closed (every gap filled with red) but before any
## zone control is built: insert special zones (insert_special_zone) or tag
## existing ones (icon, custom_color) here.
func modify_zones(_minigame: LeverMinigame, _threat_level: int) -> void:
	pass


## The countdown has just started: every zone is revealed and the board is
## finished being assembled. Where anything that should read as the puzzle itself,
## rather than as the board building, gets going (Gate's keys start cycling here).
func on_countdown_started(_minigame: LeverMinigame, _threat_level: int) -> void:
	pass


## The "Go!" moment: the countdown has finished and the reticle starts moving
## this frame. Where a modifier locks in anything it was teasing during setup.
func on_countdown_finished(_minigame: LeverMinigame, _threat_level: int) -> void:
	pass


## Every frame the minigame is active, at wall-clock delta -- the minigame runs
## under a heavy Engine.time_scale slowdown, so this is already divided out.
func on_process(_minigame: LeverMinigame, _real_delta: float) -> void:
	pass


## Called first for every press on a zone; return true to consume the press and
## skip the default green/yellow/red routing.
func handle_press(_minigame: LeverMinigame, _zone: LeverMinigame.Zone) -> bool:
	return false


## Called once after the minigame UI has closed and its presentation effects are
## unwound (never on cancel); outside-world consequences go here.
func on_minigame_closed(_minigame: LeverMinigame, _success: bool) -> void:
	pass
