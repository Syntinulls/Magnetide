extends Area2D
class_name MagnetLever

signal lever_flipped()

var _is_available: bool = false
var _player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_available(false)


func _process(_delta: float) -> void:
	if not _is_available or not _player_in_range:
		return

	if Input.is_action_just_pressed("interact"):
		lever_flipped.emit()
		set_available(false)


func set_available(available: bool) -> void:
	_is_available = available
	visible = available


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = true


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = false
