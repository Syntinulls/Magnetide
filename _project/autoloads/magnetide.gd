extends Node

const DIGITAL_FONT: Font = preload("res://_project/ui/fonts/Maneuver-Bold.otf")
const LABEL_FONT: Font = preload("res://_project/ui/fonts/Super Wonder.ttf")
const SFX_PLAYER_SCRIPT: Script = preload("res://_project/audio/sfx_player.gd")

var _active_app_root: Node = null
var _active_run: Node = null
var _active_level: Node = null
var _active_world_root: Node = null
var _active_game_ui: Control = null
var _active_ship: Node2D = null
var _active_player: Node2D = null
var _active_magnet: Magnet = null
var _sfx = null


func _ready() -> void:
	_sfx = SFX_PLAYER_SCRIPT.new()
	_sfx.name = "SfxPlayer"
	add_child(_sfx)


func register_app_root(app_root: Node) -> void:
	_active_app_root = app_root


func register_run_context(
	run: Node,
	level_node: Node,
	world_root_node: Node,
	game_ui_node: Control,
	ship_node: Node2D,
	player_node: Node2D,
	magnet_node: Magnet
) -> void:
	_active_run = run
	_active_level = level_node
	_active_world_root = world_root_node
	_active_game_ui = game_ui_node
	_active_ship = ship_node
	_active_player = player_node
	_active_magnet = magnet_node


func clear_run_context(run: Node = null) -> void:
	if run != null and _active_run != null and run != _active_run:
		return

	_active_run = null
	_active_level = null
	_active_world_root = null
	_active_game_ui = null
	_active_ship = null
	_active_player = null
	_active_magnet = null


func apply_digital_font(control: Control) -> void:
	if control == null:
		return
	control.add_theme_font_override("font", DIGITAL_FONT)


func apply_label_font(control: Control) -> void:
	if control == null:
		return
	control.add_theme_font_override("font", LABEL_FONT)


var app_root: Node:
	get:
		return _active_app_root

var digital_font: Font:
	get:
		return DIGITAL_FONT

var label_font: Font:
	get:
		return LABEL_FONT

var sfx:
	get:
		return _sfx

var run: Node:
	get:
		return _active_run

var level: Node:
	get:
		if _active_level and is_instance_valid(_active_level):
			return _active_level
		return get_tree().current_scene

var ship: Node2D:
	get:
		if _active_ship and is_instance_valid(_active_ship):
			return _active_ship
		var lvl := level
		if lvl:
			return lvl.get_node_or_null("Ship") as Node2D
		return null

var player: Node2D:
	get:
		if _active_player and is_instance_valid(_active_player):
			return _active_player
		var s := ship
		if s:
			return s.get_node_or_null("Player") as Node2D
		return null

var magnet: Magnet:
	get:
		if _active_magnet and is_instance_valid(_active_magnet):
			return _active_magnet
		var s := ship
		if s:
			return s.get_node_or_null("Magnet") as Magnet
		return null

var world_root: Node:
	get:
		if _active_world_root and is_instance_valid(_active_world_root):
			return _active_world_root
		var lvl := level
		if lvl:
			return lvl
		return get_tree().current_scene

var game_ui: Control:
	get:
		if _active_game_ui and is_instance_valid(_active_game_ui):
			return _active_game_ui
		var lvl = level
		if lvl and "ui_root" in lvl and lvl.ui_root:
			return lvl.ui_root.get_node_or_null("GameUI") as Control
		return null

var hotbar: Hotbar:
	get:
		var ui := game_ui
		if ui:
			return ui.get_node_or_null("PlayerStatus/HBoxContainer/PlayerBars/ItemSlotContainer/Hotbar") as Hotbar
		return null
