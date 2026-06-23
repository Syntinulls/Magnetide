extends Control
class_name ThreatUI

## Horizontal, top-center threat bar with 10 segments.
##
## The gradient background (green -> red -> purple) is always visible. A ticker
## below the bar tracks the continuous threat position and shows the current
## threat level number. The divider lines and the darkened locked region (beyond
## the cap) are drawn by the Dividers overlay (see threat_dividers.gd).

@onready var _bar: Control = $MarginContainer
@onready var _gradient_bg: TextureRect = $MarginContainer/GradientBG
@onready var _overlay: ThreatDividers = $MarginContainer/Dividers
@onready var _ticker: Node2D = $MarginContainer/Ticker
@onready var _ticker_color: Sprite2D = $MarginContainer/Ticker/Color
@onready var _ticker_label: Label = $MarginContainer/Ticker/Label

var _threat_manager: ThreatManager = null
var _segment_count: int = ThreatManager.LEVEL_COUNT
var _current_threat: float = 0.0
var _cap_stage: int = 0
var _gradient: Gradient = null


func _ready() -> void:
	_segment_count = ThreatManager.LEVEL_COUNT
	if _ticker_label and Magnetide and Magnetide.has_method("apply_digital_font"):
		Magnetide.apply_digital_font(_ticker_label)
	if _bar and not _bar.resized.is_connected(_refresh_layout):
		_bar.resized.connect(_refresh_layout)
	_update_ticker_level(0)
	call_deferred("_refresh_layout")
	call_deferred("_connect_threat_manager")


func _connect_threat_manager() -> void:
	if Magnetide and Magnetide.level and "threat" in Magnetide.level and Magnetide.level.threat:
		_threat_manager = Magnetide.level.threat
		_threat_manager.threat_changed.connect(_on_threat_changed)
		_threat_manager.threat_level_changed.connect(_on_threat_level_changed)
		_threat_manager.cap_raised.connect(_on_cap_raised)
		_threat_manager.cap_reached.connect(_on_cap_reached)
		_current_threat = _threat_manager.current_threat
		_cap_stage = _threat_manager.threat_level_cap
		_update_ticker_level(_threat_manager.threat_level)
		_refresh_layout()


## Gradient texture size in the bar's local space (top-left origin), shared by
## the divider overlay and the ticker so they stay aligned to the gradient.
func _bar_geometry() -> Dictionary:
	return {
		"width": _bar.size.x if _bar else 0.0,
		"height": _bar.size.y if _bar else 0.0,
	}


func _refresh_layout() -> void:
	var geo := _bar_geometry()
	if _overlay:
		_overlay.configure(_segment_count, geo.width, geo.height)
		_overlay.set_reachable_segments(_cap_stage + 1)
	_position_ticker(geo)


func _position_ticker(geo: Dictionary) -> void:
	if not _ticker:
		return
	var ratio := clampf(_current_threat / ThreatManager.MAX_THREAT, 0.0, 1.0)
	_ticker.position.x = ratio * geo.width
	_update_ticker_color(ratio)


## Tint the ticker fill to the gradient color at the current threat position.
func _update_ticker_color(ratio: float) -> void:
	if not _ticker_color:
		return
	var gradient := _get_gradient()
	if gradient:
		_ticker_color.modulate = gradient.sample(clampf(ratio, 0.0, 1.0))


func _get_gradient() -> Gradient:
	if _gradient == null and _gradient_bg and _gradient_bg.texture is GradientTexture2D:
		_gradient = (_gradient_bg.texture as GradientTexture2D).gradient
	return _gradient


func _on_threat_changed(new_value: float) -> void:
	_current_threat = new_value
	_position_ticker(_bar_geometry())


func _on_threat_level_changed(new_level: int) -> void:
	_update_ticker_level(new_level)


func _on_cap_raised(new_cap: int) -> void:
	_cap_stage = new_cap
	if _overlay:
		_overlay.set_reachable_segments(_cap_stage + 1)


func _on_cap_reached() -> void:
	if _threat_manager and _overlay:
		_cap_stage = _threat_manager.threat_level_cap
		_overlay.set_reachable_segments(_cap_stage + 1)


func _update_ticker_level(stage_index: int) -> void:
	if _ticker_label:
		_ticker_label.text = str(stage_index + 1)
