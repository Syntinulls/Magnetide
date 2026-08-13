extends Node
class_name PlayerProgressBarController

## Owns the shared progress bar anchored above the player's head. Mechanics
## (reload, repel, repair, departure holds) claim it by source; the
## highest-priority active claim is rendered, so concurrent mechanics never
## fight over the one bar.

## World offset (from the player origin) at which the shared bar is anchored.
const BAR_OFFSET_Y: float = -72.0
## Priorities decide which claim is rendered when several are active at once.
## Reload locks the player, so it outranks the optional repel/depart holds.
## Repair shares the repel tier: both are exclusive holds on different equipment.
const PRIORITY_DEPART: int = 10
const PRIORITY_REPEL: int = 20
const PRIORITY_REPAIR: int = 20
const PRIORITY_RELOAD: int = 30

const PlayerProgressBarScene: PackedScene = preload("res://_project/hud/player_progress_bar.tscn")

## Active claims keyed by source (StringName). Each entry is a dictionary
## { progress, color, text, priority }.
var _claims: Dictionary = {}
var _bar: PlayerProgressBar = null

@onready var _player: Player = owner as Player


func _ready() -> void:
	# GameUI may not have registered with Magnetide yet when the player enters
	# the tree, so bar creation must be deferred.
	call_deferred("_setup_bar")


## Show/refresh a claim on the shared bar.
func request(source: StringName, progress: float, fill_color: Color, text: String = "", priority: int = 0) -> void:
	_claims[source] = {
		"progress": clampf(progress, 0.0, 1.0),
		"color": fill_color,
		"text": text,
		"priority": priority,
	}
	_refresh()


## Drop a claim (the hold was released or completed). Hides the bar when no
## claims remain.
func clear(source: StringName) -> void:
	if _claims.erase(source):
		_refresh()


func clear_all() -> void:
	_claims.clear()
	if _bar:
		_bar.hide_bar()


func _setup_bar() -> void:
	var game_ui := Magnetide.game_ui
	if not game_ui:
		push_warning("PlayerProgressBarController: GameUI not found, progress bar will not be created")
		return

	_bar = PlayerProgressBarScene.instantiate() as PlayerProgressBar
	game_ui.add_child(_bar)
	_bar.attach_to_target(_player, Vector2(0.0, BAR_OFFSET_Y))


func _refresh() -> void:
	if _bar == null:
		return
	var best: Dictionary = {}
	var best_priority: int = -0x7FFFFFFF
	for source in _claims:
		var claim: Dictionary = _claims[source]
		if int(claim["priority"]) >= best_priority:
			best_priority = int(claim["priority"])
			best = claim
	if best.is_empty():
		_bar.hide_bar()
		return
	_bar.set_fill_color(best["color"])
	_bar.set_text(best["text"])
	_bar.set_progress(best["progress"])
	_bar.show_bar()
