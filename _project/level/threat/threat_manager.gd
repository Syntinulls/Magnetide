extends Node
class_name ThreatManager

signal threat_changed(new_value: float)
signal threat_level_changed(new_level: int)

const MAX_THREAT: float = 100.0
const LEVEL_COUNT: int = 5

var current_threat: float = 0.0:
	set(value):
		var old_level := threat_level
		current_threat = clampf(value, 0.0, MAX_THREAT)
		threat_changed.emit(current_threat)
		var new_level := threat_level
		if new_level != old_level:
			threat_level_changed.emit(new_level)

var threat_level: int:
	get:
		if current_threat >= MAX_THREAT:
			return 4
		return int(current_threat / 25.0)

var threat_ratio: float:
	get:
		return current_threat / MAX_THREAT


func add_threat(amount: float) -> void:
	current_threat += amount


func reset() -> void:
	current_threat = 0.0
