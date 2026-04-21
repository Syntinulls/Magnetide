extends Resource
class_name RunResult

enum EndReason {
	VOLUNTARY_DEPARTURE,
	PLAYER_DESTROYED,
	SHIP_DESTROYED,
}

var level_id: StringName = &""
var level_display_name: String = ""
var elapsed_seconds: float = 0.0
var salvage_items_collected: int = 0
var enemies_killed: int = 0
var end_reason: EndReason = EndReason.VOLUNTARY_DEPARTURE
var stored_loot: Array[SalvageItemData] = []


func get_end_reason_text() -> String:
	match end_reason:
		EndReason.PLAYER_DESTROYED:
			return "Player Destroyed"
		EndReason.SHIP_DESTROYED:
			return "Ship Destroyed"
		_:
			return "Voluntary Departure"
