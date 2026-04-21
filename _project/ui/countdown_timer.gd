extends Label
class_name CountdownTimer

@export var start_time_seconds: float = 600.0
@export var final_stretch_seconds: float = 60.0

var _time_remaining: float = 0.0
var _is_running: bool = false

var time_remaining: float:
	get:
		return _time_remaining

var time_until_final_stretch: float:
	get:
		return maxf(start_time_seconds - final_stretch_seconds, 1.0)


func _ready() -> void:
	_time_remaining = start_time_seconds
	_is_running = true
	_update_display()


func _process(delta: float) -> void:
	if not _is_running:
		return
	
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		_time_remaining = 0.0
		_is_running = false
	
	_update_display()


func _update_display() -> void:
	var minutes := int(_time_remaining) / 60
	var seconds := int(_time_remaining) % 60
	text = "%d:%02d" % [minutes, seconds]


func stop_timer() -> void:
	_is_running = false
