extends Control

const HEALTHY_INTEGRITY_COLOR := Color("9bff63")
const DAMAGED_INTEGRITY_COLOR := Color("ff7c7c")

@onready var _player_health_bar: TextureProgressBar = $PlayerStatus/HBoxContainer/PlayerBars/MarginContainer/PlayerHPBar
@onready var _player_shield_container: Control = $PlayerStatus/HBoxContainer/PlayerBars/ShieldMarginContainer
@onready var _player_shield_bar: TextureProgressBar = $PlayerStatus/HBoxContainer/PlayerBars/ShieldMarginContainer/PlayerShieldBar
@onready var _scrap_count_label: Label = $PlayerStatus/HBoxContainer/PlayerBars/ScrapCounterMargin/ScrapCounter/ScrapCountLabel
@onready var _ship_hull_rect: TextureRect = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipHPHull
@onready var _ship_magnet_rect: TextureRect = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipHPMagnet
@onready var _ship_hull_label: Label = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipHullIntegrityLabel
@onready var _ship_magnet_label: Label = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipMagnetIntegrityLabel

var _bound_run_controller: RunController = null


func _ready() -> void:
	if _scrap_count_label:
		Magnetide.apply_digital_font(_scrap_count_label)
	set_run_scrap_metal_count(0)
	call_deferred("_bind_to_active_run_controller")
	_update_health_ui()


func _process(_delta: float) -> void:
	_bind_to_active_run_controller()
	_update_scrap_counter()
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

	_update_player_shield(player)


func _update_player_shield(player: Player) -> void:
	if not _player_shield_bar:
		return

	var max_shield := 0.0
	var current_shield := 0.0
	if player:
		max_shield = maxf(player.max_shield, 0.0)
		current_shield = clampf(player.current_shield, 0.0, max_shield)

	var shield_enabled := max_shield > 0.0
	if _player_shield_container:
		_player_shield_container.visible = shield_enabled
	_player_shield_bar.visible = shield_enabled
	if not shield_enabled:
		_player_shield_bar.value = 0.0
		return

	_player_shield_bar.min_value = 0.0
	_player_shield_bar.max_value = max_shield
	_player_shield_bar.value = current_shield


func _update_scrap_counter() -> void:
	if not _scrap_count_label:
		return
	if _bound_run_controller and is_instance_valid(_bound_run_controller):
		set_run_scrap_metal_count(_bound_run_controller.scrap_metal_collected)
		return
	var run := Magnetide.run as RunController
	if run:
		set_run_scrap_metal_count(run.scrap_metal_collected)
		return
	set_run_scrap_metal_count(0)


func _bind_to_active_run_controller() -> void:
	var run := Magnetide.run as RunController
	if run == _bound_run_controller:
		return
	bind_run_controller(run)


func bind_run_controller(run_controller: RunController) -> void:
	var update_callable := Callable(self, "set_run_scrap_metal_count")
	if _bound_run_controller and is_instance_valid(_bound_run_controller):
		if _bound_run_controller.scrap_metal_count_changed.is_connected(update_callable):
			_bound_run_controller.scrap_metal_count_changed.disconnect(update_callable)

	_bound_run_controller = run_controller
	if _bound_run_controller:
		if not _bound_run_controller.scrap_metal_count_changed.is_connected(update_callable):
			_bound_run_controller.scrap_metal_count_changed.connect(update_callable)
		set_run_scrap_metal_count(_bound_run_controller.scrap_metal_collected)
	else:
		set_run_scrap_metal_count(0)


func set_run_scrap_metal_count(scrap_count: int) -> void:
	if _scrap_count_label:
		_scrap_count_label.text = str(maxi(scrap_count, 0))


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
