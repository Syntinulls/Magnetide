extends InteractionHitbox
class_name DeparturePylon

signal departure_requested(pylon: DeparturePylon)

const HoldProgressPopupScene := preload("res://_project/ui/hold_progress_popup.tscn")

@export var hold_duration: float = 1.0

var _hold_elapsed: float = 0.0
var _progress_popup: HoldProgressPopup = null

@onready var _ui_anchor: Node2D = $UIAnchor


func _ready() -> void:
	super._ready()
	player_exited.connect(_cancel_hold)
	set_process(true)
	call_deferred("_ensure_progress_popup")


func _process(delta: float) -> void:
	if _progress_popup == null:
		_ensure_progress_popup()

	var can_interact := _can_interact()
	# The ship coordinates the shared prompt + generator-sprite highlight, OR-ing
	# both pylons so either one triggers them.
	_notify_ship_departure(can_interact)

	if not can_interact:
		_cancel_hold()
		return

	if Input.is_action_pressed("interact"):
		_hold_elapsed += delta
		if _progress_popup:
			_progress_popup.set_progress(_hold_elapsed / maxf(hold_duration, 0.01))
		if _hold_elapsed >= hold_duration:
			_cancel_hold()
			departure_requested.emit(self)
	else:
		_cancel_hold()


func stop_for_run_end() -> void:
	_cancel_hold()
	set_process(false)
	monitoring = false
	_notify_ship_departure(false)


func _notify_ship_departure(active: bool) -> void:
	var ship := get_parent() as Ship
	if ship and ship.has_method("set_departure_pylon_active"):
		ship.set_departure_pylon_active(self, active)


func _ensure_progress_popup() -> void:
	if _progress_popup != null:
		return
	var game_ui := Magnetide.game_ui
	if game_ui == null:
		return

	_progress_popup = HoldProgressPopupScene.instantiate() as HoldProgressPopup
	game_ui.add_child(_progress_popup)
	var anchor := _ui_anchor if _ui_anchor else self
	_progress_popup.attach_to_target(anchor)


func _can_interact() -> bool:
	if not is_player_in_range:
		return false

	var player := Magnetide.player as Player
	if player and not player.input_enabled:
		return false

	var run := Magnetide.run
	if run == null:
		return false
	if run.has_method("can_accept_departure_request") and not run.can_accept_departure_request():
		return false

	return true


func _cancel_hold() -> void:
	_hold_elapsed = 0.0
	if _progress_popup:
		_progress_popup.hide_progress()
