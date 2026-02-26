extends Control
class_name DepartureTimerUI

signal timer_expired()

## Total duration of the departure timer in seconds.
@export var duration: float = 30.0

var _time_remaining: float = 0.0
var _is_running: bool = false
var _label: Label = null
var _bar_bg: ColorRect = null
var _bar_fill: ColorRect = null
var _container: VBoxContainer = null

var time_remaining: float:
	get:
		return _time_remaining


func _ready() -> void:
	_build_ui()
	visible = false
	set_process(false)


func start(custom_duration: float = -1.0) -> void:
	if custom_duration > 0.0:
		duration = custom_duration
	_time_remaining = duration
	_is_running = true
	visible = true
	set_process(true)
	_update_display()


func stop() -> void:
	_is_running = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not _is_running:
		return

	_time_remaining -= delta
	if _time_remaining <= 0.0:
		_time_remaining = 0.0
		_is_running = false
		_update_display()
		timer_expired.emit()
		return

	_update_display()


func _update_display() -> void:
	if _label:
		var secs := ceili(_time_remaining)
		_label.text = str(secs)

	if _bar_fill and _bar_bg and duration > 0.0:
		var ratio := _time_remaining / duration
		_bar_fill.size.x = _bar_bg.size.x * ratio

		# Color shifts from white -> yellow -> red as time runs out
		if ratio > 0.5:
			_bar_fill.color = Color(1.0, 1.0, 1.0)
		elif ratio > 0.2:
			var t := (ratio - 0.2) / 0.3
			_bar_fill.color = Color(1.0, lerp(0.6, 1.0, t), lerp(0.0, 1.0, t))
		else:
			var t := ratio / 0.2
			_bar_fill.color = Color(1.0, lerp(0.0, 0.6, t), 0.0)


func _build_ui() -> void:
	# Use explicit positioning at top center
	custom_minimum_size = Vector2(240.0, 60.0)
	size = Vector2(240.0, 60.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_container = VBoxContainer.new()
	_container.size = Vector2(240.0, 60.0)
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)

	# Timer label
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 28)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(_label)

	# Progress bar background
	_bar_bg = ColorRect.new()
	_bar_bg.custom_minimum_size = Vector2(200.0, 12.0)
	_bar_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(_bar_bg)

	# Progress bar fill
	_bar_fill = ColorRect.new()
	_bar_fill.size = Vector2(200.0, 12.0)
	_bar_fill.color = Color.WHITE
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bg.add_child(_bar_fill)
