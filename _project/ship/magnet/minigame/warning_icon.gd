extends Sprite2D
class_name WarningIcon

enum Phase { OFF, YELLOW, ORANGE, RED }

const ORANGE_BLINK_RATE: float = 3.0
const RED_BLINK_RATE: float = 8.0

const ALERT_YELLOW: Texture2D = preload("res://_project/ui/sprites/alert_y.png")
const ALERT_ORANGE: Texture2D = preload("res://_project/ui/sprites/alert_o.png")
const ALERT_RED: Texture2D = preload("res://_project/ui/sprites/alert_r.png")

## Scrap-proximity alarm played once each time the warning escalates to a stage.
const PROXIMITY_ALARM_SFX := {
	Phase.YELLOW: "scrap_proximity_alarm_1.ogg",
	Phase.ORANGE: "scrap_proximity_alarm_2.ogg",
	Phase.RED: "scrap_proximity_alarm_3.ogg",
}
const PROXIMITY_ALARM_VOLUME_DB := -3.0

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
	_play_proximity_alarm(phase)

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


func _play_proximity_alarm(phase: Phase) -> void:
	if not Magnetide.sfx or not PROXIMITY_ALARM_SFX.has(phase):
		return
	Magnetide.sfx.play(PROXIMITY_ALARM_SFX[phase], PROXIMITY_ALARM_VOLUME_DB)
