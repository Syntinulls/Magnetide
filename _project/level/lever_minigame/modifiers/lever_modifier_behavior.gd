extends Resource
class_name LeverModifierBehavior

## Base for lever minigame modifiers: authored .tres strategy resources rolled
## by LeverModifierWeights at each attempt. A modifier hooks into zone building,
## press handling, and the post-close moment; the minigame never branches on
## modifier identity, so all modifier-specific zones, text, and rewards live in
## the subclass. Instances are shared across attempts -- reset any per-attempt
## state in on_minigame_started. See specs/lever_minigame_modifiers_spec.md.

## Banner text popped via show_info when the minigame opens, e.g. "Bonus!".
@export var display_name: String = ""
@export var display_color: Color = Color.WHITE


## Called from start_minigame before zones build; reset per-attempt state here.
func on_minigame_started(_minigame: LeverMinigame, _threat_level: int) -> void:
	pass


## Called at the end of _build_zones, after the base ratio layout exists but
## before any zone controls are built: insert special zones (split_zone) or tag
## existing ones (icon, custom_color) here.
func modify_zones(_minigame: LeverMinigame, _threat_level: int) -> void:
	pass


## Called first for every press on a zone; return true to consume the press and
## skip the default green/yellow/red routing.
func handle_press(_minigame: LeverMinigame, _zone: LeverMinigame.Zone) -> bool:
	return false


## Called once after the minigame UI has closed and its presentation effects are
## unwound (never on cancel); outside-world consequences go here.
func on_minigame_closed(_minigame: LeverMinigame, _success: bool) -> void:
	pass
