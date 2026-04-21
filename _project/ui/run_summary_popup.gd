extends Control
class_name RunSummaryPopup

signal continue_requested

var _run_result: RunResult = null

@onready var _reason_value: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Stats/ReasonValue
@onready var _time_value: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Stats/TimeValue
@onready var _salvage_value: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Stats/SalvageValue
@onready var _kills_value: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Stats/KillsValue
@onready var _continue_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_apply_result()


func setup(result: RunResult) -> void:
	_run_result = result
	_apply_result()


func _apply_result() -> void:
	if _run_result == null or _reason_value == null:
		return

	_reason_value.text = _run_result.get_end_reason_text()
	_time_value.text = _format_elapsed_time(_run_result.elapsed_seconds)
	_salvage_value.text = str(_run_result.salvage_items_collected)
	_kills_value.text = str(_run_result.enemies_killed)


func _format_elapsed_time(total_seconds: float) -> String:
	var seconds := maxi(int(round(total_seconds)), 0)
	var minutes := seconds / 60
	var remainder := seconds % 60
	return "%d:%02d" % [minutes, remainder]


func _on_continue_pressed() -> void:
	continue_requested.emit()
