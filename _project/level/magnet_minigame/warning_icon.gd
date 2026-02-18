extends Sprite2D
class_name WarningIcon

enum Phase { OFF, GREEN, YELLOW, RED }

const YELLOW_BLINK_RATE: float = 3.0
const RED_BLINK_RATE: float = 8.0

var current_phase: Phase = Phase.GREEN
var _blink_timer: float = 0.0
var _blink_visible: bool = true


func _ready() -> void:
	set_phase(Phase.OFF)


func _process(delta: float) -> void:
	if current_phase == Phase.OFF or current_phase == Phase.GREEN:
		return

	var rate := YELLOW_BLINK_RATE if current_phase == Phase.YELLOW else RED_BLINK_RATE
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
		Phase.GREEN:
			visible = true
			modulate = Color.GREEN
		Phase.YELLOW:
			visible = true
			modulate = Color.YELLOW
		Phase.RED:
			visible = true
			modulate = Color.RED
