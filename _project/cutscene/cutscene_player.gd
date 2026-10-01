extends Node
class_name CutscenePlayer

## Runs in-run cutscenes and is the directing API they are written against.
##
## play() wraps a CutsceneBehavior in a session — HUD hidden, player locked, player
## and ship protected, letterbox in, each per the cutscene's options — and undoes all
## of it when the script returns. One cutscene plays at a time.
##
## Every helper below is awaitable, so a cutscene reads as a linear script. To run
## several at once, start them without awaiting and then await wait() (or the last
## one). The overlay sits on canvas layer 9: above the world and the storm vignette,
## below the HUD layer, so the pause menu still draws over a letterboxed or faded
## screen.

signal cutscene_started(cutscene: CutsceneBehavior)
signal cutscene_finished(cutscene: CutsceneBehavior)

const CONTEXT_PLAYER := &"player"
const CONTEXT_SHIP := &"ship"
const CONTEXT_LEVEL := &"level"
const CAPTION_SOURCE := &"cutscene"
const CAPTION_PRIORITY := 200

@export var letterbox_seconds: float = 0.5
@export var hud_fade_seconds: float = 0.3

## Debug: cutscenes jump to their end state (skip_to_end) instead of playing.
var skip_enabled: bool = false

var _active: CutsceneBehavior = null
var _letterbox_tween: Tween = null
var _fade_tween: Tween = null
var _saved_player_combat_disabled: bool = false
var _saved_ship_invulnerable: bool = false

@onready var _letterbox_top: ColorRect = $Overlay/LetterboxTop
@onready var _letterbox_bottom: ColorRect = $Overlay/LetterboxBottom
@onready var _fade: ColorRect = $Overlay/Fade

var camera: LevelCamera:
	get:
		var level := Magnetide.level as Level
		return level.camera if level else null


func _ready() -> void:
	_letterbox_top.scale.y = 0.0
	_letterbox_bottom.scale.y = 0.0
	_fade.color.a = 0.0


func is_playing() -> bool:
	return _active != null


## Run `cutscene` inside a session. `extra_context` adds actors beyond the player,
## ship and level (e.g. &"boss"). Returns when the cutscene's script does.
func play(cutscene: CutsceneBehavior, extra_context: Dictionary = {}) -> void:
	if cutscene == null:
		return
	if _active != null:
		push_warning("CutscenePlayer: %s requested while %s is playing; ignored." % [cutscene.resource_path, _active.resource_path])
		return

	_active = cutscene
	var context := _build_context(extra_context)
	_begin_session(cutscene)
	cutscene_started.emit(cutscene)
	if skip_enabled:
		cutscene.skip_to_end(self, context)
	else:
		await cutscene.play(self, context)
	if not cutscene.hold_session_at_end:
		_end_session(cutscene)
	_active = null
	cutscene_finished.emit(cutscene)


# -- Timing ------------------------------------------------------------------

## Pauses with the game (a paused tree holds the cutscene where it is).
func wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds, false).timeout


# -- Camera ------------------------------------------------------------------

func camera_move_to(
	global_target: Vector2,
	seconds: float,
	trans: Tween.TransitionType = Tween.TRANS_SINE
) -> void:
	if camera == null:
		return
	await camera.tween_position(global_target, seconds, trans).finished


func camera_zoom_to(zoom: float, seconds: float, trans: Tween.TransitionType = Tween.TRANS_SINE) -> void:
	if camera == null:
		return
	await camera.tween_zoom(Vector2(zoom, zoom), seconds, trans).finished


## Fire-and-forget; the shake decays on its own.
func camera_shake(strength: float, seconds: float) -> void:
	if camera:
		camera.shake(strength, seconds)


## Ease the camera back to its resting framing.
func camera_reset(seconds: float) -> void:
	if camera == null:
		return
	await camera.reset(seconds).finished


# -- Actors ------------------------------------------------------------------

func move_actor_to(
	actor: Node2D,
	global_target: Vector2,
	seconds: float,
	trans: Tween.TransitionType = Tween.TRANS_SINE,
	ease_type: Tween.EaseType = Tween.EASE_IN_OUT
) -> void:
	if actor == null:
		return
	var tween := actor.create_tween()
	tween.tween_property(actor, "global_position", global_target, maxf(seconds, 0.001)) \
		.set_trans(trans).set_ease(ease_type)
	await tween.finished


## Walk the player to a ship-local x and return on arrival.
func walk_player_to(local_x: float, speed: float = 160.0) -> void:
	var player := Magnetide.player as Player
	if player == null:
		return
	player.start_cinematic_walk(local_x, speed)
	if player.is_cinematic_walk_active():
		await player.cinematic_walk_finished


## Play `animation` on an AnimationPlayer or AnimatedSprite2D. With `wait`, returns
## when it finishes; a looping animation never finishes, so it is never waited on.
func play_animation(target: Node, animation: StringName, wait_for_end: bool = true) -> void:
	if target is AnimationPlayer:
		var anim_player := target as AnimationPlayer
		anim_player.play(animation)
		var anim := anim_player.get_animation(animation)
		if wait_for_end and anim and anim.loop_mode == Animation.LOOP_NONE:
			await anim_player.animation_finished
	elif target is AnimatedSprite2D:
		var sprite := target as AnimatedSprite2D
		sprite.play(animation)
		var frames := sprite.sprite_frames
		if wait_for_end and frames and frames.has_animation(animation) and not frames.get_animation_loop(animation):
			await sprite.animation_finished


func tween_level_speed(target: float, seconds: float) -> void:
	var level := Magnetide.level as Level
	if level == null:
		return
	await level.tween_level_speed(target, seconds).finished


# -- Presentation ------------------------------------------------------------

## Headline (+ optional second line) in the HUD's event text for `seconds`.
func show_caption(
	text: String,
	subtext: String = "",
	seconds: float = 2.0,
	style: EventTextDisplay.Style = EventTextDisplay.Style.NORMAL
) -> void:
	var event_text := _get_event_text()
	if event_text == null:
		return
	event_text.show_message(CAPTION_SOURCE, text, subtext, CAPTION_PRIORITY, style)
	await wait(seconds)
	event_text.clear(CAPTION_SOURCE)


## Fade the screen to `color` (its alpha is the target opacity).
func fade_out(color: Color = Color.BLACK, seconds: float = 0.5) -> void:
	_kill(_fade_tween)
	_fade.color = Color(color, _fade.color.a)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", color.a, maxf(seconds, 0.001)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _fade_tween.finished


func fade_in(seconds: float = 0.5) -> void:
	_kill(_fade_tween)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 0.0, maxf(seconds, 0.001)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _fade_tween.finished


func set_letterbox(shown: bool, seconds: float) -> void:
	_kill(_letterbox_tween)
	# The bottom bar grows upward from the screen edge.
	_letterbox_bottom.pivot_offset = Vector2(0.0, _letterbox_bottom.size.y)
	var target := 1.0 if shown else 0.0
	_letterbox_tween = create_tween().set_parallel(true)
	_letterbox_tween.tween_property(_letterbox_top, "scale:y", target, maxf(seconds, 0.001)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_letterbox_tween.tween_property(_letterbox_bottom, "scale:y", target, maxf(seconds, 0.001)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _letterbox_tween.finished


# -- Session -----------------------------------------------------------------

func _build_context(extra_context: Dictionary) -> Dictionary:
	var context := {
		CONTEXT_PLAYER: Magnetide.player,
		CONTEXT_SHIP: Magnetide.ship,
		CONTEXT_LEVEL: Magnetide.level,
	}
	context.merge(extra_context, true)
	return context


func _begin_session(cutscene: CutsceneBehavior) -> void:
	var game_ui := Magnetide.game_ui as GameUI
	if cutscene.hide_hud and game_ui:
		game_ui.set_hud_hidden(true, hud_fade_seconds)
	if cutscene.letterbox:
		set_letterbox(true, letterbox_seconds)
	var player := Magnetide.player as Player
	if cutscene.lock_player and player:
		player.set_cinematic_lock(true)
	if cutscene.protect_player_and_ship:
		var ship := Magnetide.ship as Ship
		if player:
			_saved_player_combat_disabled = player.combat_disabled
			player.combat_disabled = true
		if ship:
			_saved_ship_invulnerable = ship.invulnerable
			ship.invulnerable = true


func _end_session(cutscene: CutsceneBehavior) -> void:
	var game_ui := Magnetide.game_ui as GameUI
	if cutscene.hide_hud and game_ui:
		game_ui.set_hud_hidden(false, hud_fade_seconds)
	if cutscene.letterbox:
		set_letterbox(false, letterbox_seconds)
	var player := Magnetide.player as Player
	if cutscene.lock_player and player:
		player.set_cinematic_lock(false)
	if cutscene.protect_player_and_ship:
		var ship := Magnetide.ship as Ship
		if player:
			player.combat_disabled = _saved_player_combat_disabled
		if ship:
			ship.invulnerable = _saved_ship_invulnerable


func _get_event_text() -> EventTextDisplay:
	var game_ui := Magnetide.game_ui
	if game_ui == null:
		return null
	return game_ui.get_node_or_null("EventTextDisplay") as EventTextDisplay


func _kill(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()
