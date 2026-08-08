extends Resource
class_name StormData

## One authored storm: the threat level it gates, its waves, and its weather.
##
## Storms are the run's progression gates. A level with a storm authored against it
## runs that storm when its interlevel window resolves by continuing; clearing the
## storm is what unlocks the next threat level.

@export var id: StringName = &""
## Announcement headline while this storm runs.
@export var display_name: String = "ACID STORM"
## Threat level (1-10) this storm gates. The storm runs when that level's window
## resolves by continuing, before the cap rises.
@export_range(1, 10, 1) var gate_after_level: int = 3
@export var waves: Array[StormWave] = []
## Environment effect applied for the storm's duration. Null = waves only.
@export var weather: StormWeatherEffect

@export_group("Pacing")
## Seconds the storm's name shows before the first wave spawns.
@export_range(0.0, 30.0, 0.1, "or_greater") var intro_seconds: float = 2.0
## Seconds the cleared message shows before the next threat level unlocks.
@export_range(0.0, 30.0, 0.1, "or_greater") var outro_seconds: float = 2.5

@export_group("Difficulty")
## Threat level used to scale wave enemies' health and damage. 0 uses the run's
## current threat level, which is what makes the same authored wave harder at a
## later gate.
@export_range(0, 10, 1) var enemy_stat_level: int = 0


func get_wave_count() -> int:
	return waves.size()


func get_wave(index: int) -> StormWave:
	if index < 0 or index >= waves.size():
		return null
	return waves[index]
