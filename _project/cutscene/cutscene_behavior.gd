extends Resource
class_name CutsceneBehavior

## One scripted cutscene. Subclasses override play() as a coroutine written against
## the CutscenePlayer's directing API; their tuning lives in exports on the .tres.
## CutscenePlayer.play() wraps the script in a session that applies the options
## below before it starts and undoes them when it ends.

@export_group("Session")
## Fade out the in-run HUD (the pause menu and event text stay available).
@export var hide_hud: bool = true
## Slide cinematic bars in from the top and bottom edges.
@export var letterbox: bool = true
## Stop gameplay input reaching the player and put the held item away.
@export var lock_player: bool = true
## The player and ship take no damage while the cutscene runs.
@export var protect_player_and_ship: bool = true
## Leave the session applied when the cutscene ends, for cutscenes that end the
## run (departure) — the next screen replaces the level, so nothing is restored.
@export var hold_session_at_end: bool = false


## The cutscene script. `context` holds the actors it directs, keyed by the
## CutscenePlayer.CONTEXT_* names plus whatever the caller added (a boss, ...).
func play(_director: CutscenePlayer, _context: Dictionary) -> void:
	pass


## Put every actor straight into the state play() would leave it in. Called instead
## of play() while cutscenes are being skipped (debug panel).
func skip_to_end(_director: CutscenePlayer, _context: Dictionary) -> void:
	pass
