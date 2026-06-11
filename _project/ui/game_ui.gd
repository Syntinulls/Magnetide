extends Control

const HEALTHY_INTEGRITY_COLOR := Color("9bff63")
const DAMAGED_INTEGRITY_COLOR := Color("ff7c7c")
const SHIELD_READY_COLOR := Color("eaf6ff")
const SHIELD_BROKEN_COLOR := Color("ff7777")
const SHIELD_REGEN_PULSE_COLOR := Color("4db8ff")
const SHIELD_DAMAGE_PULSE_COLOR := Color("ff4f4f")
const SHIELD_DAMAGE_PULSE_SCALE := Vector2(0.9, 0.9)
const SHIELD_REGEN_PULSE_SCALE := Vector2(1.14, 1.14)
const SHIELD_BREAK_PULSE_SCALE := Vector2(0.78, 0.78)
const SHIELD_PULSE_UP_SECONDS := 0.12
const SHIELD_PULSE_DOWN_SECONDS := 0.28
const SHIELD_BROKEN_LOOP_PAUSE_SECONDS := 0.35
const SHIELD_BREAK_SHAKE_DEGREES := 8.0

@onready var _player_health_bar: TextureProgressBar = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/MarginContainer/PlayerHPBar
@onready var _player_shield_container: Control = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/ShieldIcon
@onready var _player_shield_pulse_container: MarginContainer = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/ShieldIcon/ShieldPulseMarginContainer
@onready var _player_shield_icon: TextureRect = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/ShieldIcon/ShieldPulseMarginContainer/ShieldTexture
@onready var _player_shield_label: Label = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/ShieldIcon/ShieldPulseMarginContainer/ShieldCountLabel
@onready var _scrap_counter: HBoxContainer = $PlayerStatus/HBoxContainer/PlayerBars/ScrapCounterMargin/ScrapCounter
@onready var _scrap_icon: TextureRect = $PlayerStatus/HBoxContainer/PlayerBars/ScrapCounterMargin/ScrapCounter/ScrapIcon
@onready var _scrap_count_label: Label = $PlayerStatus/HBoxContainer/PlayerBars/ScrapCounterMargin/ScrapCounter/ScrapCountLabel
@onready var _ship_hull_rect: TextureRect = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipHPHull
@onready var _ship_magnet_rect: TextureRect = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipHPMagnet
@onready var _ship_hull_label: Label = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipHullIntegrityLabel
@onready var _ship_magnet_label: Label = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipMagnetIntegrityLabel

var _bound_run_controller: RunController = null
var _bound_player: Player = null
var _displayed_scrap_count: int = 0
var _scrap_pulse_tween: Tween = null
var _shield_was_broken: bool = false
var _displayed_shield_count: int = -1
var _shield_pulse_tween: Tween = null
var _shield_broken_loop_tween: Tween = null
var _shield_break_shake_tween: Tween = null


func _ready() -> void:
	if _scrap_count_label:
		Magnetide.apply_digital_font(_scrap_count_label)
	if _player_shield_label:
		Magnetide.apply_digital_font(_player_shield_label)
	set_run_scrap_metal_count(0)
	call_deferred("_bind_to_active_run_controller")
	call_deferred("_bind_to_active_player")
	_update_health_ui()


func _process(_delta: float) -> void:
	_bind_to_active_run_controller()
	_bind_to_active_player()
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
	if not _player_shield_container:
		return

	var max_shield := 0.0
	var current_shield := 0
	var shield_broken := false
	if player:
		max_shield = maxf(player.max_shield, 0.0)
		current_shield = clampi(player.current_shield, 0, roundi(max_shield))
		shield_broken = player.is_shield_broken()

	var shield_enabled := max_shield > 0.0
	_player_shield_container.visible = shield_enabled
	if not shield_enabled:
		_shield_was_broken = false
		_displayed_shield_count = -1
		_stop_shield_broken_loop()
		return

	if _player_shield_label:
		_player_shield_label.text = str(current_shield)

	_displayed_shield_count = current_shield
	_shield_was_broken = shield_broken


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


func _bind_to_active_player() -> void:
	var player := Magnetide.player as Player
	if player == _bound_player:
		return
	bind_player(player)


func bind_player(player: Player) -> void:
	var update_callable := Callable(self, "_on_player_shield_changed")
	if _bound_player and is_instance_valid(_bound_player):
		if _bound_player.shield_changed.is_connected(update_callable):
			_bound_player.shield_changed.disconnect(update_callable)

	_bound_player = player
	if _bound_player:
		if not _bound_player.shield_changed.is_connected(update_callable):
			_bound_player.shield_changed.connect(update_callable)
		_update_player_shield(_bound_player)
	else:
		_displayed_shield_count = -1
		_shield_was_broken = false
		_stop_shield_broken_loop()


func _on_player_shield_changed(
	current: int,
	_maximum: int,
	broken: bool,
	delta: int
) -> void:
	if not _bound_player or not is_instance_valid(_bound_player):
		return
	var was_broken := _shield_was_broken
	_update_player_shield(_bound_player)
	if delta > 0:
		if was_broken and not broken:
			_stop_shield_broken_loop(false, true)
		_play_shield_point_regenerated_pulse()
	elif delta < 0:
		if current <= 0 or broken:
			_play_shield_break_pulse()
		else:
			_play_shield_point_consumed_pulse()


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
	var normalized_count := maxi(scrap_count, 0)
	var should_pulse := normalized_count > _displayed_scrap_count
	_displayed_scrap_count = normalized_count
	if _scrap_count_label:
		_scrap_count_label.text = str(normalized_count)
	if should_pulse:
		pulse_scrap_counter()


func get_scrap_icon_screen_center() -> Vector2:
	if _scrap_icon:
		return _scrap_icon.get_global_rect().get_center()
	if _scrap_counter:
		return _scrap_counter.get_global_rect().get_center()
	return Vector2.ZERO


func pulse_scrap_counter() -> void:
	var target := _scrap_counter as Control
	if target == null:
		return
	if _scrap_pulse_tween and _scrap_pulse_tween.is_valid():
		_scrap_pulse_tween.kill()
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2.ONE
	_scrap_pulse_tween = target.create_tween()
	_scrap_pulse_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scrap_pulse_tween.tween_property(target, "scale", Vector2(1.18, 1.18), 0.09)
	_scrap_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_scrap_pulse_tween.tween_property(target, "scale", Vector2.ONE, 0.16)


func _play_shield_point_consumed_pulse() -> void:
	_pulse_player_shield(SHIELD_DAMAGE_PULSE_COLOR, SHIELD_DAMAGE_PULSE_SCALE)


func _play_shield_point_regenerated_pulse() -> void:
	_pulse_player_shield(SHIELD_REGEN_PULSE_COLOR, SHIELD_REGEN_PULSE_SCALE)


func _play_shield_break_pulse() -> void:
	_pulse_player_shield(SHIELD_DAMAGE_PULSE_COLOR, SHIELD_BREAK_PULSE_SCALE, true)


func _pulse_player_shield(
	pulse_color: Color,
	pulse_scale: Vector2,
	start_broken_loop_after: bool = false
) -> void:
	var target := _get_player_shield_pulse_target()
	if target == null:
		return
	if _shield_pulse_tween and _shield_pulse_tween.is_valid():
		_shield_pulse_tween.kill()
	if start_broken_loop_after:
		_stop_shield_broken_loop(false, true)
	_set_player_shield_pulse_pivot(target)
	target.scale = Vector2.ONE
	target.modulate = Color.WHITE
	target.rotation_degrees = 0.0
	_reset_player_shield_label_animation()
	if start_broken_loop_after:
		_shake_player_shield_break(target)
	_shield_pulse_tween = target.create_tween()
	_shield_pulse_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shield_pulse_tween.tween_property(target, "scale", pulse_scale, SHIELD_PULSE_UP_SECONDS)
	_shield_pulse_tween.parallel().tween_property(target, "modulate", pulse_color, SHIELD_PULSE_UP_SECONDS)
	_shield_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_shield_pulse_tween.tween_property(target, "scale", Vector2.ONE, SHIELD_PULSE_DOWN_SECONDS)
	_shield_pulse_tween.parallel().tween_property(target, "modulate", Color.WHITE, SHIELD_PULSE_DOWN_SECONDS)
	if start_broken_loop_after:
		_shield_pulse_tween.finished.connect(_start_shield_broken_loop_if_needed)


func _start_shield_broken_loop_if_needed() -> void:
	if not _shield_was_broken:
		return
	_start_shield_broken_loop()


func _start_shield_broken_loop() -> void:
	var target := _get_player_shield_pulse_target()
	if target == null:
		return
	if _shield_broken_loop_tween and _shield_broken_loop_tween.is_valid():
		return
	_set_player_shield_pulse_pivot(target)
	target.scale = Vector2.ONE
	target.modulate = Color.WHITE
	target.rotation_degrees = 0.0
	_reset_player_shield_label_animation()
	_shield_broken_loop_tween = target.create_tween()
	_shield_broken_loop_tween.set_loops()
	_shield_broken_loop_tween.tween_interval(SHIELD_BROKEN_LOOP_PAUSE_SECONDS)
	_shield_broken_loop_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_shield_broken_loop_tween.tween_property(target, "modulate", SHIELD_DAMAGE_PULSE_COLOR, SHIELD_PULSE_UP_SECONDS)
	_shield_broken_loop_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_shield_broken_loop_tween.tween_property(target, "modulate", Color.WHITE, SHIELD_PULSE_DOWN_SECONDS)


func _stop_shield_broken_loop(reset_target: bool = true, stop_shake: bool = true) -> void:
	if _shield_broken_loop_tween and _shield_broken_loop_tween.is_valid():
		_shield_broken_loop_tween.kill()
	_shield_broken_loop_tween = null
	if stop_shake and _shield_break_shake_tween and _shield_break_shake_tween.is_valid():
		_shield_break_shake_tween.kill()
	if reset_target:
		var target := _get_player_shield_pulse_target()
		if target:
			target.scale = Vector2.ONE
			target.modulate = Color.WHITE
			target.rotation_degrees = 0.0
		_reset_player_shield_label_animation()


func _shake_player_shield_break(target: Control) -> void:
	if target == null:
		return
	if _shield_break_shake_tween and _shield_break_shake_tween.is_valid():
		_shield_break_shake_tween.kill()
	target.rotation_degrees = 0.0
	_shield_break_shake_tween = target.create_tween()
	_shield_break_shake_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_shield_break_shake_tween.tween_property(
		target,
		"rotation_degrees",
		-SHIELD_BREAK_SHAKE_DEGREES,
		0.045
	)
	_shield_break_shake_tween.tween_property(
		target,
		"rotation_degrees",
		SHIELD_BREAK_SHAKE_DEGREES * 0.8,
		0.06
	)
	_shield_break_shake_tween.tween_property(
		target,
		"rotation_degrees",
		-SHIELD_BREAK_SHAKE_DEGREES * 0.45,
		0.055
	)
	_shield_break_shake_tween.tween_property(target, "rotation_degrees", 0.0, 0.08)


func _get_player_shield_pulse_target() -> Control:
	if _player_shield_pulse_container:
		return _player_shield_pulse_container
	return _player_shield_container


func _set_player_shield_pulse_pivot(target: Control) -> void:
	if target == null:
		return
	if _player_shield_icon:
		var icon_center := _player_shield_icon.get_global_rect().get_center()
		target.pivot_offset = target.get_global_transform_with_canvas().affine_inverse() * icon_center
	else:
		target.pivot_offset = target.size * 0.5


func _reset_player_shield_label_animation() -> void:
	if not _player_shield_label:
		return
	_player_shield_label.scale = Vector2.ONE
	_player_shield_label.modulate = Color.WHITE


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
