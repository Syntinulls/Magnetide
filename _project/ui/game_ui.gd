extends Control

const HEALTHY_INTEGRITY_COLOR := Color("9bff63")
const DAMAGED_INTEGRITY_COLOR := Color("ff7c7c")

@onready var _player_health_bar: TextureProgressBar = $PlayerStatus/HBoxContainer/PlayerBars/MarginContainer/PlayerHPBar
@onready var _ship_hull_rect: TextureRect = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipHPHull
@onready var _ship_magnet_rect: TextureRect = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipHPMagnet
@onready var _ship_hull_label: Label = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipHullIntegrityLabel
@onready var _ship_magnet_label: Label = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipMagnetIntegrityLabel


func _ready() -> void:
	_update_health_ui()


func _process(_delta: float) -> void:
	_update_health_ui()


func _update_health_ui() -> void:
	_update_player_health(Magnetide.player as Player)
	_update_integrity_display(
		Magnetide.ship as Ship,
		_ship_hull_rect,
		_ship_hull_label
	)
	_update_integrity_display(
		Magnetide.magnet as Magnet,
		_ship_magnet_rect,
		_ship_magnet_label
	)


func _update_player_health(player: Player) -> void:
	if not _player_health_bar:
		return

	var max_health := 1.0
	var current_health := 0.0
	if player:
		max_health = maxf(player.max_health, 1.0)
		current_health = clampf(player.current_health, 0.0, max_health)

	_player_health_bar.min_value = 0.0
	_player_health_bar.max_value = max_health
	_player_health_bar.value = current_health


func _update_integrity_display(source: Node, rect: TextureRect, label: Label) -> void:
	if not rect or not label:
		return

	var max_health := 0.0
	var current_health := 0.0
	if source:
		max_health = float(source.get("max_health"))
		current_health = float(source.get("current_health"))

	var ratio := _get_health_ratio(current_health, max_health)
	rect.modulate = DAMAGED_INTEGRITY_COLOR.lerp(HEALTHY_INTEGRITY_COLOR, ratio)
	label.text = _format_percent(ratio)


func _get_health_ratio(current_health: float, max_health: float) -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(current_health / max_health, 0.0, 1.0)


func _format_percent(ratio: float) -> String:
	return "%d%%" % roundi(clampf(ratio, 0.0, 1.0) * 100.0)
