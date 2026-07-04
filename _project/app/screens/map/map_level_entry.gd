extends Resource
class_name MapLevelEntry

@export var level_definition: LevelDefinition = null
@export var display_name_override: String = ""
@export var banner_texture: Texture2D = null
@export_range(1, 3) var threat_icons: int = 1
@export var locked: bool = false
@export var locked_label: String = "LOCKED"


func get_display_name() -> String:
	if not display_name_override.is_empty():
		return display_name_override
	if level_definition != null:
		return level_definition.display_name
	return "Unknown Level"
