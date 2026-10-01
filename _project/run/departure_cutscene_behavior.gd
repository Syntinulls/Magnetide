extends CutsceneBehavior
class_name DepartureCutsceneBehavior

## The ship leaving the level: the player walks to the ship's center while it brakes,
## then the ship rises with the camera leading it, raises its shield, boosts out of
## frame, and the screen fades to black. The run is over when it returns, so it holds
## its session (hold_session_at_end) rather than handing the HUD back.

const LEVEL_SPEED_EPSILON: float = 1.0

@export_group("Timing")
@export var decel_seconds: float = 2.25
@export var rise_seconds: float = 3.0
@export var boost_seconds: float = 1.35
@export var fade_seconds: float = 0.9

@export_group("Motion")
@export var player_walk_speed: float = 180.0
## How far the ship rises, in viewport heights.
@export var rise_viewport_ratio: float = 4.5
## How far ahead of the rising ship the camera settles, in viewport heights.
@export var camera_lead_viewport_ratio: float = 0.35
## How far the final boost carries the ship, in viewport heights.
@export var boost_viewport_ratio: float = 7.0
## Fraction of the boost distance the camera follows.
@export_range(0.0, 1.0, 0.01) var boost_camera_ratio: float = 0.22
## Point in the rise (0-1) where the departure shield appears.
@export_range(0.0, 1.0, 0.01) var shield_reveal_ratio: float = 0.75
## Point in the rise (0-1) where the lift thrusters switch to boost.
@export_range(0.0, 1.0, 0.01) var boost_thrust_start_ratio: float = 0.9


func play(director: CutscenePlayer, context: Dictionary) -> void:
	var player := context.get(CutscenePlayer.CONTEXT_PLAYER) as Player
	var ship := context.get(CutscenePlayer.CONTEXT_SHIP) as Ship
	var level := context.get(CutscenePlayer.CONTEXT_LEVEL) as Level
	var camera := director.camera
	if camera:
		camera.make_current()

	if player:
		player.start_cinematic_walk(0.0, player_walk_speed)
	if level:
		if level.level_speed > LEVEL_SPEED_EPSILON:
			await director.tween_level_speed(0.0, decel_seconds)
		level.level_speed = 0.0

	if player:
		if player.is_cinematic_walk_active():
			await player.cinematic_walk_finished
		player.stop_for_run_end()

	if ship:
		ship.lock_stored_items_for_departure()
		ship.set_departure_lift_thrusters(false)

	var viewport_height := maxf(director.get_viewport().get_visible_rect().size.y, 1.0)
	await _rise(director, ship, camera, viewport_height)
	await _boost(director, ship, camera, viewport_height)
	await director.fade_out(Color.BLACK, fade_seconds)


func skip_to_end(director: CutscenePlayer, context: Dictionary) -> void:
	var player := context.get(CutscenePlayer.CONTEXT_PLAYER) as Player
	var level := context.get(CutscenePlayer.CONTEXT_LEVEL) as Level
	if level:
		level.level_speed = 0.0
	if player:
		player.stop_for_run_end()
	director.fade_out(Color.BLACK, 0.0)


## The ship climbs while the camera eases into a lead above it; the shield and boost
## thrusters switch on at their authored points in the climb.
func _rise(director: CutscenePlayer, ship: Ship, camera: LevelCamera, viewport_height: float) -> void:
	if ship == null and camera == null:
		return
	var rise_distance := -viewport_height * rise_viewport_ratio
	var camera_lead := -viewport_height * camera_lead_viewport_ratio
	var ship_start_y := ship.global_position.y if ship else 0.0
	var camera_start := camera.global_position if camera else Vector2.ZERO

	var tween := director.create_tween().set_parallel(true)
	tween.tween_method(
		func(progress: float) -> void:
			if ship:
				ship.global_position.y = ship_start_y + rise_distance * progress
			if camera:
				var lead_progress := clampf(progress, 0.0, 1.0)
				var eased_lead := lead_progress * lead_progress * (3.0 - 2.0 * lead_progress)
				camera.move_to(Vector2(
					camera_start.x,
					camera_start.y + rise_distance * progress + camera_lead * eased_lead
				)),
		0.0,
		1.0,
		rise_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if ship:
		tween.tween_callback(ship.show_departure_shield).set_delay(rise_seconds * shield_reveal_ratio)
		tween.tween_callback(ship.set_departure_lift_thrusters.bind(true)) \
			.set_delay(rise_seconds * boost_thrust_start_ratio)
	await tween.finished


func _boost(director: CutscenePlayer, ship: Ship, camera: LevelCamera, viewport_height: float) -> void:
	if ship == null and camera == null:
		return
	var boost_distance := -viewport_height * boost_viewport_ratio
	var tween := director.create_tween().set_parallel(true)
	if ship:
		tween.tween_property(ship, "global_position:y", ship.global_position.y + boost_distance, boost_seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if camera:
		camera.move_to(camera.global_position)
		tween.tween_property(camera, "global_position:y", camera.global_position.y + boost_distance * boost_camera_ratio, boost_seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
