extends Sprite2D
class_name WarningIcon

enum Phase { OFF, YELLOW, ORANGE, RED }

const ORANGE_BLINK_RATE: float = 3.0
const RED_BLINK_RATE: float = 8.0

const ALERT_YELLOW: Texture2D = preload("res://_project/ui/sprites/alert_y.png")
const ALERT_ORANGE: Texture2D = preload("res://_project/ui/sprites/alert_o.png")
const ALERT_RED: Texture2D = preload("res://_project/ui/sprites/alert_r.png")

var current_phase: Phase = Phase.YELLOW
var _blink_timer: float = 0.0
var _blink_visible: bool = true


func _ready() -> void:
	set_phase(Phase.OFF)


func _process(delta: float) -> void:
	if current_phase == Phase.OFF or current_phase == Phase.YELLOW:
		return

	var rate := ORANGE_BLINK_RATE if current_phase == Phase.ORANGE else RED_BLINK_RATE
	_blink_timer += delta
	var blink_interval := 1.0 / rate
	if _blink_timer >= blink_interval:
		_blink_timer -= blink_interval
		_blink_visible = not _blink_visible
		visible = _blink_visible


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
			texture = ALERT_YELLOW
		Phase.ORANGE:
			visible = true
			texture = ALERT_ORANGE
		Phase.RED:
			visible = true
			texture = ALERT_RED
