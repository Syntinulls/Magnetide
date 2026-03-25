extends Node

var level:
	get:
		return get_tree().current_scene

var ship: Node2D:
	get:
		var lvl = level
		if lvl:
			return lvl.get_node_or_null("Ship") as Node2D
		return null

var player: Node2D:
	get:
		var s = ship
		if s:
			return s.get_node_or_null("Player") as Node2D
		return null

var magnet: Magnet:
	get:
		var s = ship
		if s:
			return s.get_node_or_null("Magnet") as Magnet
		return null

var game_ui: Control:
	get:
		var lvl = level
		if lvl and "ui_root" in lvl and lvl.ui_root:
			return lvl.ui_root.get_node_or_null("GameUI") as Control
		return null

var hotbar: Hotbar:
	get:
		var ui = game_ui
		if ui:
			return ui.get_node_or_null("PlayerStatus/HBoxContainer/PlayerBars/ItemSlotContainer/Hotbar") as Hotbar
		return null
