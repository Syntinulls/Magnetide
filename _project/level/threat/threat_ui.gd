extends Control
class_name ThreatUI

const LEVEL_COLORS: Array[Color] = [
	Color("f0d23c"),  # 0
	Color("e6964b"),  # 1
	Color("d75555"),  # 2
	Color("cd5abe"),  # 3
	Color("785fbe"),  # 4
]

@onready var _bar: TextureProgressBar = $Bar
@onready var _ticker: Node2D = $Ticker

var _threat_manager: ThreatManager = null
var _current_level: int = 0
var _ticker_bottom_y: float = 0.0
var _ticker_top_y: float = 0.0


func _ready() -> void:
	var progress_tex := _bar.texture_progress
	var half_height := progress_tex.get_height() * 0.5
	var offset_y := _bar.texture_progress_offset.y
	_ticker_bottom_y = half_height + offset_y
	_ticker_top_y = -half_height + offset_y
	_bar.max_value = ThreatManager.MAX_THREAT
	_update_icons()
	_update_bar_color()
	_update_display(0.0)
	call_deferred("_connect_threat_manager")


func _connect_threat_manager() -> void:
	if Magnetide and Magnetide.level and "threat" in Magnetide.level and Magnetide.level.threat:
		_threat_manager = Magnetide.level.threat
		_threat_manager.threat_changed.connect(_on_threat_changed)
		_threat_manager.threat_level_changed.connect(_on_threat_level_changed)


func _on_threat_changed(new_value: float) -> void:
	_update_display(new_value)


func _on_threat_level_changed(new_level: int) -> void:
	_current_level = new_level
	_update_bar_color()

func _update_icons():
	var idx = 0
	for child in $Icons.get_children():
		var icon_color: Sprite2D = child.get_child(0)
		icon_color.modulate = LEVEL_COLORS[idx]
		idx += 1

func _update_bar_color() -> void:
	if _bar:
		_bar.tint_progress = LEVEL_COLORS[_current_level]


func _update_display(threat: float) -> void:
	var ratio := threat / ThreatManager.MAX_THREAT

	if _bar:
		_bar.value = threat

	if _ticker:
		_ticker.position.y = lerpf(_ticker_bottom_y, _ticker_top_y, ratio)
