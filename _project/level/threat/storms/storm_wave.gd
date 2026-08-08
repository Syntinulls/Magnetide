extends Resource
class_name StormWave

## One wave of a storm: an ordered list of enemy batches plus its pacing. A wave is
## complete once every enemy it spawned is gone, killed or despawned.

@export var batches: Array[StormWaveBatch] = []
## Seconds between one batch spawning and the next.
@export_range(0.0, 60.0, 0.1, "or_greater") var batch_interval_seconds: float = 3.0
## Seconds after this wave clears before the next one starts.
@export_range(0.0, 60.0, 0.1, "or_greater") var next_wave_delay_seconds: float = 5.0


## Total enemies this wave spawns across all batches.
func get_enemy_count() -> int:
	var total := 0
	for batch in batches:
		if batch != null and batch.profile != null:
			total += batch.count
	return total
