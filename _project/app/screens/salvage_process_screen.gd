extends Control
class_name SalvageProcessScreen

signal start_requested
signal main_menu_requested

var _run_result: RunResult = null

@onready var _summary_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SummaryLabel
@onready var _start_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/StartButton
@onready var _menu_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/MenuButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_update_summary()


func set_run_result(result: RunResult) -> void:
	_run_result = result
	_update_summary()


func _update_summary() -> void:
	if _summary_label == null:
		return
	if _run_result == null:
		_summary_label.text = "Salvage processing will be implemented later."
		return

	_summary_label.text = "\n".join([
		"Salvage processing placeholder",
		"Reason: %s" % _run_result.get_end_reason_text(),
		"Stored Items: %d" % _run_result.salvage_items_collected,
		"Enemies Killed: %d" % _run_result.enemies_killed,
	])


func _on_start_pressed() -> void:
	start_requested.emit()


func _on_menu_pressed() -> void:
	main_menu_requested.emit()
