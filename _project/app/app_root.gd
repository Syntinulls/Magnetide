extends Node
class_name AppRoot

const RunControllerScript := preload("res://_project/run/run_controller.gd")

@export var default_level: LevelDefinition
@export var default_run_loadout: RunLoadout
@export var main_menu_scene: PackedScene
@export var salvage_process_scene: PackedScene

var _active_screen: Control = null
var _active_level: Node = null
var _active_run_controller: RunController = null

@onready var _run_root: Node = $RunRoot
@onready var _screen_root: Control = $ScreenCanvas/ScreenRoot


func _ready() -> void:
	Magnetide.register_app_root(self)
	_show_main_menu()


func start_run(level_definition: LevelDefinition = null, run_loadout: RunLoadout = null) -> void:
	if level_definition == null:
		level_definition = default_level
	if run_loadout == null:
		run_loadout = default_run_loadout

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
	if screen and screen.has_signal("start_requested"):
		screen.start_requested.connect(_on_main_menu_start_requested)


func _show_salvage_process_screen(result: RunResult) -> void:
	var screen := _show_screen(salvage_process_scene)
	if screen == null:
		return
	if screen.has_method("set_run_result"):
		screen.set_run_result(result)
	if screen.has_signal("start_requested"):
		screen.start_requested.connect(_on_salvage_screen_start_requested)
	if screen.has_signal("main_menu_requested"):
		screen.main_menu_requested.connect(_on_salvage_screen_main_menu_requested)


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


func _on_main_menu_start_requested() -> void:
	start_run(default_level)


func _on_salvage_screen_start_requested() -> void:
	start_run(default_level)


func _on_salvage_screen_main_menu_requested() -> void:
	_show_main_menu()


func _on_run_finished(result: RunResult) -> void:
	_clear_run()
	_show_salvage_process_screen(result)
