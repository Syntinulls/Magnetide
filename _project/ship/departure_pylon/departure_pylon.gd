extends InteractionHitbox
class_name DeparturePylon

signal departure_requested(pylon: DeparturePylon)

const DEPART_BAR_TEXT: String = "Departing..."

@export var hold_duration: float = 1.0

var _hold_elapsed: float = 0.0
var _is_holding: bool = false
## Unique claim key so two pylons never clear each other's shared-bar claim.
var _bar_source: StringName = &""


func _ready() -> void:
	super._ready()
	_bar_source = StringName("depart_%d" % get_instance_id())
	player_exited.connect(_cancel_hold)
	set_process(true)


func _process(delta: float) -> void:
	# Arming is a run-state question, not a proximity one: the pylons must announce
	# that departure is possible from across the ship, or a player who has never
	# departed has no way to learn the window exists. Proximity still drives the
	# separate steady highlight and the control prompt.
	_notify_ship_armed(_is_departure_available())

	var can_interact := _can_interact()
	# The ship coordinates the shared prompt + generator-sprite highlight, OR-ing
	# both pylons so either one triggers them.
	_notify_ship_departure(can_interact)

	if not can_interact:
		_cancel_hold()
		return

	if Input.is_action_pressed("interact"):
		_hold_elapsed += delta
		_set_departure_hold(true)
		_update_progress_bar()
		if _hold_elapsed >= hold_duration:
			_cancel_hold()
			departure_requested.emit(self)
	else:
		_cancel_hold()


## Drives the shared player progress bar (anchored above the player's head).
func _update_progress_bar() -> void:
	var player := Magnetide.player as Player
	if player == null or not player.has_method("request_progress_bar"):
		return
	var progress := clampf(_hold_elapsed / maxf(hold_duration, 0.01), 0.0, 1.0)
	player.request_progress_bar(
		_bar_source,
		progress,
		Player.DEPART_BAR_COLOR,
		DEPART_BAR_TEXT,
		Player.PROGRESS_BAR_PRIORITY_DEPART
	)


func stop_for_run_end() -> void:
	_cancel_hold()
	set_process(false)
	monitoring = false
	_notify_ship_departure(false)
	_notify_ship_armed(false)


func _notify_ship_departure(active: bool) -> void:
	var ship := get_parent() as Ship
	if ship and ship.has_method("set_departure_pylon_active"):
		ship.set_departure_pylon_active(self, active)


## Whether the run currently permits departing at all, ignoring where the player is.
func _is_departure_available() -> bool:
	var player := Magnetide.player as Player
	if player and not player.input_enabled:
		return false

	var run := Magnetide.run
	if run == null:
		return false
	if run.has_method("can_accept_departure_request") and not run.can_accept_departure_request():
		return false

	return true


func _can_interact() -> bool:
	return is_player_in_range and _is_departure_available()


func _notify_ship_armed(armed: bool) -> void:
	var ship := get_parent() as Ship
	if ship and ship.has_method("set_departure_armed"):
		ship.set_departure_armed(self, armed)


func _cancel_hold() -> void:
	_hold_elapsed = 0.0
	_set_departure_hold(false)
	var player := Magnetide.player as Player
	if player and player.has_method("clear_progress_bar"):
		player.clear_progress_bar(_bar_source)


## Report an in-progress hold so an expiring window waits for it instead of
## auto-continuing — a hold started in the window's last second still departs.
func _set_departure_hold(held: bool) -> void:
	if _is_holding == held:
		return
	_is_holding = held
	var level := Magnetide.level
	if level and "threat" in level and level.threat:
		level.threat.set_departure_hold(held)
