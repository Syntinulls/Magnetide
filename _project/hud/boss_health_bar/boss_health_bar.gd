extends Control
class_name BossHealthBar

## HUD bar for the boss being fought: its name, its current phase, its total health,
## and a marker where each phase after the first begins. Hidden until bound; the boss
## encounter binds it when the fight starts and unbinds it when the fight ends.

@export var marker_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var marker_width: float = 4.0
@export var fade_seconds: float = 0.4

var _boss: Boss = null
## One marker per phase boundary, paired with the health ratio it sits at.
var _markers: Array[ColorRect] = []
var _marker_ratios: PackedFloat32Array = PackedFloat32Array()
var _fade_tween: Tween = null

@onready var _name_label: Label = %NameLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _bar: ProgressBar = %Bar
@onready var _markers_root: Control = %Markers


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	Magnetide.apply_label_fonts(self)
	_markers_root.resized.connect(_layout_markers)


func bind(boss: Boss) -> void:
	unbind()
	if boss == null:
		return
	_boss = boss
	_boss.health_changed.connect(_on_health_changed)
	_boss.phase_changed.connect(_on_phase_changed)
	_name_label.text = boss.get_display_name().to_upper()
	_rebuild_markers()
	_on_health_changed(boss.get_current_health(), boss.get_max_health())
	_on_phase_changed(boss.get_phase_index())
	_fade(true)


func unbind() -> void:
	if _boss and is_instance_valid(_boss):
		if _boss.health_changed.is_connected(_on_health_changed):
			_boss.health_changed.disconnect(_on_health_changed)
		if _boss.phase_changed.is_connected(_on_phase_changed):
			_boss.phase_changed.disconnect(_on_phase_changed)
	_boss = null
	_fade(false)


func _on_health_changed(current: float, maximum: float) -> void:
	_bar.value = current / maximum if maximum > 0.0 else 0.0


func _on_phase_changed(index: int) -> void:
	if _boss == null:
		return
	var count := _boss.get_phase_count()
	var phase := _boss.get_phase()
	var label := "PHASE %d / %d" % [index + 1, count] if count > 1 else ""
	if phase and not phase.display_name.is_empty():
		label = phase.display_name.to_upper() if label.is_empty() else "%s - %s" % [label, phase.display_name.to_upper()]
	_phase_label.text = label


## Markers are a runtime list (one per phase boundary of whichever boss is bound),
## so they are built here rather than authored.
func _rebuild_markers() -> void:
	for marker in _markers:
		marker.queue_free()
	_markers.clear()
	_marker_ratios = PackedFloat32Array()
	var ratios := _boss.get_phase_start_ratios()
	for i in range(1, ratios.size()):
		var marker := ColorRect.new()
		marker.color = marker_color
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_markers_root.add_child(marker)
		_markers.append(marker)
		_marker_ratios.append(ratios[i])
	_layout_markers()


func _layout_markers() -> void:
	var bar_size := _markers_root.size
	for i in _markers.size():
		var marker := _markers[i]
		marker.size = Vector2(marker_width, bar_size.y)
		marker.position = Vector2(bar_size.x * _marker_ratios[i] - marker_width * 0.5, 0.0)


func _fade(shown: bool) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if shown:
		visible = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0 if shown else 0.0, maxf(fade_seconds, 0.001))
	if not shown:
		_fade_tween.tween_callback(hide)
