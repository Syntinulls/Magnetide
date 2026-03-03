extends Control
class_name ThreatUI

@onready var _bar: TextureProgressBar = $Bar
@onready var _ticker: Node2D = $Ticker

var _threat_manager: ThreatManager = null
var _ticker_bottom_y: float = 0.0
var _ticker_top_y: float = 0.0


func _ready() -> void:
	var progress_tex := _bar.texture_progress
	var half_height := progress_tex.get_height() * 0.5
	var offset_y := _bar.texture_progress_offset.y
	_ticker_bottom_y = half_height + offset_y
	_ticker_top_y = -half_height + offset_y
	_bar.max_value = ThreatManager.MAX_THREAT
	_update_display(0.0)
	call_deferred("_connect_threat_manager")


func _connect_threat_manager() -> void:
	if Magnetide and Magnetide.level and "threat" in Magnetide.level and Magnetide.level.threat:
		_threat_manager = Magnetide.level.threat
		_threat_manager.threat_changed.connect(_on_threat_changed)


func _on_threat_changed(new_value: float) -> void:
	_update_display(new_value)


func _update_display(threat: float) -> void:
	var ratio := threat / ThreatManager.MAX_THREAT

	if _bar:
		_bar.value = threat

	if _ticker:
		_ticker.position.y = lerpf(_ticker_bottom_y, _ticker_top_y, ratio)
