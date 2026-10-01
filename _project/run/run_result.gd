extends Resource
class_name RunResult

enum EndReason {
	VOLUNTARY_DEPARTURE,
	PLAYER_DESTROYED,
	SHIP_DESTROYED,
	## The level's boss was beaten; the ship departs with its cargo.
	BOSS_DEFEATED,
}

var level_id: StringName = &""
var level_display_name: String = ""
var elapsed_seconds: float = 0.0
var salvage_items_collected: int = 0
var scrap_metal_collected: int = 0
var enemies_killed: int = 0
var end_reason: EndReason = EndReason.VOLUNTARY_DEPARTURE
var stored_loot: Array[SalvageItemData] = []


func get_end_reason_text() -> String:
	match end_reason:
		EndReason.PLAYER_DESTROYED:
			return "Ended because the player died. Scrap and salvage were lost."
		EndReason.SHIP_DESTROYED:
			return "Ended because the ship was destroyed. Scrap and salvage were lost."
		EndReason.BOSS_DEFEATED:
			return "Ended by defeating the boss. Recovered cargo secured."
		_:
			return "Ended by ship departure. Recovered cargo secured."


## True when the run ended by leaving the level (departure or boss victory), which
## keeps its scrap and cargo; false for a loss.
func keeps_loot() -> bool:
	return reason_keeps_loot(end_reason)


## Builds the run-stats dictionary consumed by RunSummaryPopup.setup().
## items_salvaged is supplied by the salvage screen, not tracked on the run.
func to_stats_dict(items_salvaged: int = 0) -> Dictionary:
	return {
		"time_elapsed": elapsed_seconds,
		"enemies_killed": enemies_killed,
		"collected_items": salvage_items_collected,
		"scrap_collected": scrap_metal_collected,
		"items_salvaged": items_salvaged,
	}


static func reason_keeps_loot(reason: EndReason) -> bool:
	return reason == EndReason.VOLUNTARY_DEPARTURE or reason == EndReason.BOSS_DEFEATED
