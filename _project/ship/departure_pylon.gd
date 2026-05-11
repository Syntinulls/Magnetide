extends Area2D
class_name DeparturePylon

signal departure_requested(pylon: DeparturePylon)

const HoldProgressPopupScene := preload("res://_project/ui/hold_progress_popup.tscn")

@export var hold_duration: float = 1.0

var _player_in_range: bool = false
var _hold_elapsed: float = 0.0
var _progress_popup: HoldProgressPopup = null

@onready var _ui_anchor: Node2D = $UIAnchor


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process(true)
	call_deferred("_ensure_progress_popup")


func _process(delta: float) -> void:
	if _progress_popup == null:
		_ensure_progress_popup()

	if not _can_interact():
		_cancel_hold()
		_set_highlight(false)
		return

	_set_highlight(true)

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
	_set_highlight(false)


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
	if not _player_in_range:
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


func _set_highlight(active: bool) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_in_range = false
		_cancel_hold()
