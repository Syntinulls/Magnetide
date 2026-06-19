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
const PLAYER_AUGMENT_ICON_SIZE := Vector2(44.0, 44.0)
const PLAYER_AUGMENT_TOOLTIP_OFFSET := Vector2(0.0, 52.0)

@onready var _player_health_bar: TextureProgressBar = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/MarginContainer/PlayerHPBar
@onready var _player_shield_container: Control = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/ShieldIcon
@onready var _player_shield_pulse_container: MarginContainer = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/ShieldIcon/ShieldPulseMarginContainer
@onready var _player_shield_icon: TextureRect = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/ShieldIcon/ShieldPulseMarginContainer/ShieldTexture
@onready var _player_shield_label: Label = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/ShieldIcon/ShieldPulseMarginContainer/ShieldCountLabel
@onready var _player_augment_icons: HBoxContainer = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/PlayerAugmentIcons
@onready var _player_augment_tooltip: ColorRect = $PlayerAugmentTooltip
@onready var _player_augment_tooltip_name: Label = $PlayerAugmentTooltip/NameLabel
@onready var _player_augment_tooltip_body: Label = $PlayerAugmentTooltip/BodyLabel
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
var _displayed_player_augment_key: String = ""


func _ready() -> void:
	if _scrap_count_label:
		Magnetide.apply_digital_font(_scrap_count_label)
	if _player_shield_label:
		Magnetide.apply_digital_font(_player_shield_label)
	if _player_augment_tooltip:
		_player_augment_tooltip.visible = false
	set_run_scrap_metal_count(0)
	call_deferred("_bind_to_active_run_controller")
	call_deferred("_bind_to_active_player")
	_update_health_ui()
	_refresh_player_augment_icons(true)


func _process(_delta: float) -> void:
	_bind_to_active_run_controller()
	_bind_to_active_player()
	_update_scrap_counter()
	_update_health_ui()
	_refresh_player_augment_icons()


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
	_refresh_player_augment_icons(true)


func _refresh_player_augment_icons(force: bool = false) -> void:
	if _player_augment_icons == null:
		return

	var loadout := _get_active_run_loadout()
	var augments := _get_equipped_player_augments(loadout)
	var augment_key := _build_player_augment_key(loadout, augments)
	if not force and augment_key == _displayed_player_augment_key:
		return
	_displayed_player_augment_key = augment_key

	for child in _player_augment_icons.get_children():
		child.queue_free()

	_player_augment_icons.visible = not augments.is_empty()
	if augments.is_empty():
		_hide_player_augment_tooltip()
		return

	for augment in augments:
		var button := _create_player_augment_icon_button(augment, loadout)
		_player_augment_icons.add_child(button)


func _get_active_run_loadout() -> RunLoadout:
	if _bound_run_controller != null and is_instance_valid(_bound_run_controller):
		if _bound_run_controller.has_method("get_run_loadout"):
			return _bound_run_controller.call("get_run_loadout") as RunLoadout
	var run := Magnetide.run as RunController
	if run != null and run.has_method("get_run_loadout"):
		return run.call("get_run_loadout") as RunLoadout
	return null


func _get_equipped_player_augments(loadout: RunLoadout) -> Array[AugmentData]:
	var augments: Array[AugmentData] = []
	if loadout == null:
		return augments
	for augment in loadout.player_augments:
		if augment != null:
			augments.append(augment)
	return augments


func _build_player_augment_key(loadout: RunLoadout, augments: Array[AugmentData]) -> String:
	if loadout == null or augments.is_empty():
		return ""
	var parts := PackedStringArray()
	for augment in augments:
		parts.append("%s:%d" % [
			_get_augment_key(augment),
			loadout.get_item_level(augment),
		])
	return "|".join(parts)


func _create_player_augment_icon_button(augment: AugmentData, loadout: RunLoadout) -> Button:
	var button := Button.new()
	button.custom_minimum_size = PLAYER_AUGMENT_ICON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.text = ""
	button.icon = _get_augment_icon(augment)
	button.expand_icon = true
	button.clip_text = true
	button.add_theme_constant_override("icon_max_width", int(PLAYER_AUGMENT_ICON_SIZE.x))
	button.mouse_entered.connect(_show_player_augment_tooltip.bind(button, augment, loadout))
	button.mouse_exited.connect(_hide_player_augment_tooltip)
	button.focus_entered.connect(_show_player_augment_tooltip.bind(button, augment, loadout))
	button.focus_exited.connect(_hide_player_augment_tooltip)
	return button


func _show_player_augment_tooltip(button: Control, augment: AugmentData, loadout: RunLoadout) -> void:
	if _player_augment_tooltip == null or augment == null:
		return

	_player_augment_tooltip_name.text = _get_augment_name(augment)
	_player_augment_tooltip_body.text = _build_player_augment_tooltip_text(augment, loadout)
	_player_augment_tooltip.visible = true

	var target_position := button.get_global_rect().position + PLAYER_AUGMENT_TOOLTIP_OFFSET
	var viewport_size := get_viewport_rect().size
	var tooltip_size := _player_augment_tooltip.size
	if tooltip_size.x <= 0.0 or tooltip_size.y <= 0.0:
		tooltip_size = Vector2(300.0, 158.0)
	target_position.x = clampf(target_position.x, 0.0, maxf(viewport_size.x - tooltip_size.x, 0.0))
	target_position.y = clampf(target_position.y, 0.0, maxf(viewport_size.y - tooltip_size.y, 0.0))
	_player_augment_tooltip.position = target_position


func _hide_player_augment_tooltip() -> void:
	if _player_augment_tooltip != null:
		_player_augment_tooltip.visible = false


func _build_player_augment_tooltip_text(augment: AugmentData, loadout: RunLoadout) -> String:
	var lines := PackedStringArray()
	var description := _get_augment_description(augment)
	if not description.is_empty():
		lines.append(description)

	var gains := _get_augment_gains(augment, loadout)
	if not gains.is_empty():
		if not lines.is_empty():
			lines.append("")
		lines.append(gains)
	return "\n".join(lines)


func _get_augment_gains(augment: AugmentData, loadout: RunLoadout) -> String:
	if augment == null:
		return ""
	var state := _get_augment_state(augment, loadout)
	if augment.has_method("get_current_effect_summary"):
		return String(augment.call("get_current_effect_summary", state))
	return ""


func _get_augment_state(augment: AugmentData, loadout: RunLoadout) -> Resource:
	if augment == null or loadout == null or not _has_property(augment, "item_id"):
		return null
	return loadout.get_item_state(augment.get("item_id") as StringName)


func _get_augment_name(augment: AugmentData) -> String:
	if augment != null and augment.has_method("get_display_name"):
		return String(augment.call("get_display_name"))
	if augment != null and not augment.display_name.is_empty():
		return augment.display_name
	return "Augment"


func _get_augment_description(augment: AugmentData) -> String:
	if augment == null or not _has_property(augment, "description"):
		return ""
	return String(augment.get("description"))


func _get_augment_icon(augment: AugmentData) -> Texture2D:
	if augment != null and augment.has_method("get_icon"):
		return augment.call("get_icon") as Texture2D
	if augment != null and _has_property(augment, "icon"):
		return augment.get("icon") as Texture2D
	return null


func _get_augment_key(augment: AugmentData) -> String:
	if augment == null:
		return ""
	if _has_property(augment, "item_id"):
		return String(augment.get("item_id"))
	if not augment.resource_path.is_empty():
		return augment.resource_path
	return str(augment.get_instance_id())


func _has_property(resource: Resource, property_name: String) -> bool:
	if resource == null:
		return false
	for property in resource.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


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
