extends Node
class_name AppRoot

const RunControllerScript := preload("res://_project/run/run_controller.gd")
const AppSaveDataScript := preload("res://_project/app/app_save_data.gd")
const RunSummaryPopupScene := preload("res://_project/app/screens/salvage_results_popup.tscn")

@export var default_level: LevelDefinition
@export var default_run_loadout: RunLoadout
@export var main_menu_scene: PackedScene
@export var station_screen_scene: PackedScene
@export var map_screen_scene: PackedScene
@export var salvage_process_scene: PackedScene

var _active_screen: Control = null
var _active_level: Node = null
var _active_run_controller: RunController = null
var _save_data: Resource = null

@onready var _run_root: Node = $RunRoot
@onready var _screen_root: Control = $ScreenCanvas/ScreenRoot


func _ready() -> void:
	Magnetide.register_app_root(self)
	_save_data = AppSaveDataScript.load_or_create(default_run_loadout)
	_show_main_menu()


func start_run(level_definition: LevelDefinition = null, run_loadout: RunLoadout = null) -> void:
	if level_definition == null:
		level_definition = default_level
	if run_loadout == null:
		run_loadout = _get_current_run_loadout()

	if level_definition == null or level_definition.level_scene == null:
		push_error("AppRoot: Cannot start run without a valid LevelDefinition.")
		return

	_clear_screen()
	_clear_run()

	_active_level = level_definition.level_scene.instantiate()
	if run_loadout:
		run_loadout.apply_to_level(_active_level)
	_active_run_controller = RunControllerScript.new()

	var ship := _active_level.get_node_or_null("Ship") as Node2D
	var player := ship.get_node_or_null("Player") as Node2D if ship else null
	var magnet := ship.get_node_or_null("Magnet") as Magnet if ship else null
	var game_ui := _active_level.get_node_or_null("UICanvas/UIRoot/GameUI") as Control

	Magnetide.register_run_context(
		_active_run_controller,
		_active_level,
		_active_level,
		game_ui,
		ship,
		player,
		magnet
	)

	_run_root.add_child(_active_level)
	_run_root.add_child(_active_run_controller)
	_active_run_controller.run_finished.connect(_on_run_finished)
	_active_run_controller.start_run(level_definition, _active_level)


func _show_main_menu() -> void:
	_clear_run()
	var screen := _show_screen(main_menu_scene)
	if screen and screen.has_method("set_continue_available"):
		screen.set_continue_available(_has_continue_save())
	if screen and screen.has_signal("continue_requested"):
		screen.continue_requested.connect(_on_main_menu_continue_requested)
	if screen and screen.has_signal("new_game_requested"):
		screen.new_game_requested.connect(_on_main_menu_new_game_requested)


func _show_station_screen() -> void:
	_clear_run()
	var screen := _show_screen(station_screen_scene)
	if screen == null:
		return
	if screen.has_method("set_save_data"):
		screen.set_save_data(_save_data)
	elif screen.has_method("set_run_loadout"):
		screen.set_run_loadout(_get_current_run_loadout())
	if screen.has_signal("map_requested"):
		screen.map_requested.connect(_on_station_map_requested)
	if screen.has_signal("main_menu_requested"):
		screen.main_menu_requested.connect(_on_station_main_menu_requested)


func _show_map_screen() -> void:
	_clear_run()
	var screen := _show_screen(map_screen_scene)
	if screen == null:
		return
	if screen.has_method("set_default_level"):
		screen.set_default_level(default_level)
	if screen.has_signal("start_requested"):
		screen.start_requested.connect(_on_map_start_requested)
	if screen.has_signal("station_requested"):
		screen.station_requested.connect(_on_map_station_requested)


func _show_salvage_process_screen(result: RunResult) -> void:
	var screen := _show_screen(salvage_process_scene)
	if screen == null:
		return
	if screen.has_method("set_run_result"):
		screen.set_run_result(result)
	if screen.has_signal("start_requested"):
		screen.start_requested.connect(_on_salvage_screen_start_requested)
	if screen.has_signal("station_requested"):
		screen.station_requested.connect(_on_salvage_screen_station_requested)
	if screen.has_signal("main_menu_requested"):
		screen.main_menu_requested.connect(_on_salvage_screen_main_menu_requested)


func _show_death_summary_screen(result: RunResult) -> void:
	_clear_screen()

	var popup := RunSummaryPopupScene.instantiate() as SalvageResultsPopup
	if popup == null:
		_show_station_screen()
		return

	_active_screen = popup
	_screen_root.add_child(_active_screen)
	popup.setup(result, [], _build_run_stats(result, 0))
	popup.station_requested.connect(_on_death_summary_station_requested)


func _show_screen(scene: PackedScene) -> Control:
	if scene == null:
		return null

	_clear_screen()
	_active_screen = scene.instantiate() as Control
	if _active_screen == null:
		return null
	_screen_root.add_child(_active_screen)
	return _active_screen


func _clear_screen() -> void:
	if _active_screen and is_instance_valid(_active_screen):
		_active_screen.queue_free()
	_active_screen = null


func _clear_run() -> void:
	Magnetide.clear_run_context()

	if _active_run_controller and is_instance_valid(_active_run_controller):
		_active_run_controller.queue_free()
	if _active_level and is_instance_valid(_active_level):
		_active_level.queue_free()

	for child in _run_root.get_children():
		child.queue_free()

	_active_run_controller = null
	_active_level = null


func _on_main_menu_new_game_requested() -> void:
	if _save_data == null:
		_save_data = AppSaveDataScript.new()
	_save_data.reset_to_default(default_run_loadout)
	_show_station_screen()


func _on_main_menu_continue_requested() -> void:
	if _save_data == null:
		_save_data = AppSaveDataScript.load_or_create(default_run_loadout)
	_show_station_screen()


func _on_station_map_requested() -> void:
	_show_map_screen()


func _on_station_main_menu_requested() -> void:
	_show_main_menu()


func _on_map_start_requested(level_definition: LevelDefinition) -> void:
	start_run(level_definition, _get_current_run_loadout())


func _on_map_station_requested() -> void:
	_show_station_screen()


func _on_salvage_screen_start_requested() -> void:
	_collect_salvage_screen_storage()
	start_run(default_level, _get_current_run_loadout())


func _on_salvage_screen_station_requested() -> void:
	_collect_salvage_screen_storage()
	_show_station_screen()


func _on_salvage_screen_main_menu_requested() -> void:
	_collect_salvage_screen_storage()
	_show_station_screen()


func _on_run_finished(result: RunResult) -> void:
	if result == null:
		_show_station_screen()
		return

	if result.end_reason != RunResult.EndReason.VOLUNTARY_DEPARTURE:
		_show_death_summary_screen(result)
		return

	if _save_data and result and result.scrap_metal_collected > 0:
		_save_data.add_scrap_metal(result.scrap_metal_collected)
	_clear_run()
	_show_salvage_process_screen(result)


func _on_death_summary_station_requested() -> void:
	_show_station_screen()


func _collect_salvage_screen_storage() -> void:
	if _save_data == null or _active_screen == null:
		return
	if not _active_screen.has_method("get_final_storage_entries"):
		return
	_save_data.add_storage_entries(_active_screen.call("get_final_storage_entries"))


func _get_current_run_loadout() -> RunLoadout:
	if _save_data != null:
		return _save_data.get("current_run_loadout") as RunLoadout
	return default_run_loadout


func _build_run_stats(result: RunResult, items_salvaged: int = 0) -> Dictionary:
	return {
		"time_elapsed": result.elapsed_seconds if result != null else 0.0,
		"enemies_killed": result.enemies_killed if result != null else 0,
		"collected_items": result.salvage_items_collected if result != null else 0,
		"scrap_collected": result.scrap_metal_collected if result != null else 0,
		"items_salvaged": items_salvaged,
	}


func get_save_data() -> Resource:
	return _save_data


func _has_continue_save() -> bool:
	if _save_data == null:
		return false
	return bool(_save_data.call("has_continue_data", default_run_loadout))
