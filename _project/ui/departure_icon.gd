extends Control
class_name DepartureIcon

signal timer_expired()

enum Phase { OFF, YELLOW, ORANGE, RED }

const ORANGE_BLINK_RATE: float = 3.0
const RED_BLINK_RATE: float = 8.0

const ALERT_YELLOW: Texture2D = preload("res://_project/ui/sprites/alert_departure_y.png")
const ALERT_ORANGE: Texture2D = preload("res://_project/ui/sprites/alert_departure_o.png")
const ALERT_RED: Texture2D = preload("res://_project/ui/sprites/alert_departure_r.png")

var current_phase: Phase = Phase.OFF
var _blink_timer: float = 0.0
var _blink_visible: bool = true
var _time_remaining: float = 0.0
var _duration: float = 30.0
var _is_running: bool = false

@onready var _icon: TextureRect = $Icon
@onready var _label: Label = $Label

var time_remaining: float:
	get:
		return _time_remaining


func _ready() -> void:
	visible = false  # Start hidden, only show when parked/looting
	set_process(false)


func _process(delta: float) -> void:
	# Handle blinking
	if current_phase == Phase.ORANGE or current_phase == Phase.RED:
		var rate := ORANGE_BLINK_RATE if current_phase == Phase.ORANGE else RED_BLINK_RATE
		_blink_timer += delta
		var blink_interval := 1.0 / rate
		if _blink_timer >= blink_interval:
			_blink_timer -= blink_interval
			_blink_visible = not _blink_visible
			_icon.visible = _blink_visible
	
	# Handle countdown
	if _is_running:
		_time_remaining -= delta
		if _time_remaining <= 0.0:
			_time_remaining = 0.0
			_is_running = false
			_update_display()
			timer_expired.emit()
			return
		_update_display()
		_update_phase_from_time()


func _update_display() -> void:
	if _label:
		_label.text = "Departure in %.1fs" % _time_remaining


func _update_phase_from_time() -> void:
	if _duration <= 0.0:
		return
	var ratio := _time_remaining / _duration
	if ratio > 0.4:
		set_phase(Phase.YELLOW)
	elif ratio > 0.15:
		set_phase(Phase.ORANGE)
	else:
		set_phase(Phase.RED)


func start(duration: float) -> void:
	_duration = duration
	_time_remaining = duration
	_is_running = true
	set_phase(Phase.YELLOW)
	set_process(true)
	_update_display()


func stop() -> void:
	_is_running = false
	set_phase(Phase.OFF)
	set_process(false)


func set_phase(phase: Phase) -> void:
	if phase == current_phase:
		return
	current_phase = phase
	_blink_timer = 0.0
	_blink_visible = true

	match phase:
		Phase.OFF:
			visible = false
		Phase.YELLOW:
			visible = true
			if _icon:
				_icon.visible = true
				_icon.texture = ALERT_YELLOW
		Phase.ORANGE:
			visible = true
			if _icon:
				_icon.visible = true
				_icon.texture = ALERT_ORANGE
		Phase.RED:
			visible = true
			if _icon:
				_icon.visible = true
				_icon.texture = ALERT_RED
