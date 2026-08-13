extends Control
class_name GameUI

const MAGAZINE_READY_COLOR := Color("dbdbdb")
const MAGAZINE_RELOADING_COLOR := Color("ffd24a")
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
const AUGMENT_ICON_SIZE := Vector2(44.0, 44.0)
const AUGMENT_TOOLTIP_OFFSET := Vector2(0.0, 52.0)
const AUGMENT_BORDER_TEXTURE: Texture2D = preload("res://_project/common/sprites/panel_border.png")
const AUGMENT_BG_COLOR := Color("5f6969")
## Border thickness in the panel_border nine-patch; icons inset by this much.
const AUGMENT_BORDER_INSET := 6
## Gray background inset so it doesn't show in the border's rounded corners.
const AUGMENT_BG_INSET := 4

## Interlevel window announcements. The window is the run's one departure
## opportunity, so its subtext spells out every option the player has.
const WINDOW_EVENT_SOURCE := &"threat_window"
## The post-advance banner owns a separate source from the window: they overlap
## whenever a level fills within the banner's lifetime, and sharing a key let the
## banner's timeout clear the newer window's headline out from under it.
const LEVEL_BANNER_SOURCE := &"threat_level"
const WINDOW_PRIORITY := 100
## Below the window, so an open window always outranks a still-fading banner.
const LEVEL_BANNER_PRIORITY := 90
const WINDOW_NORMAL_TEXT := "NEW THREATS APPROACHING"
const WINDOW_STORM_TEXT := "STORM IMMINENT"
const WINDOW_TERMINAL_TEXT := "MAXIMUM THREAT"
const LEVEL_ADVANCED_TEXT := "THREAT LEVEL %d"
const LEVEL_BANNER_SECONDS := 2.0

@onready var _player_health_bar: TextureProgressBar = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/MarginContainer/PlayerHPBar
@onready var _player_shield_container: Control = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/ShieldIcon
@onready var _player_shield_pulse_container: MarginContainer = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/ShieldIcon/ShieldPulseMarginContainer
@onready var _player_shield_icon: TextureRect = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/ShieldIcon/ShieldPulseMarginContainer/ShieldTexture
@onready var _player_shield_label: Label = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/ShieldIcon/ShieldPulseMarginContainer/ShieldCountLabel
@onready var _augment_icons: HBoxContainer = $PlayerStatus/HBoxContainer/PlayerBars/HealthShieldRow/AugmentIcons
@onready var _augment_tooltip: ColorRect = $AugmentTooltip
@onready var _augment_tooltip_name: Label = $AugmentTooltip/NameLabel
@onready var _augment_tooltip_body: Label = $AugmentTooltip/BodyLabel
@onready var _hotbar_item_name_label: Label = $PlayerStatus/HBoxContainer/PlayerBars/ItemSlotContainer/Hotbar/HotbarItemName
@onready var _scrap_counter: HBoxContainer = $PlayerStatus/HBoxContainer/PlayerBars/HBoxContainer/VBoxContainer/ScrapCounterMargin/ScrapCounter
@onready var _scrap_icon: TextureRect = $PlayerStatus/HBoxContainer/PlayerBars/HBoxContainer/VBoxContainer/ScrapCounterMargin/ScrapCounter/ScrapIcon
@onready var _scrap_count_label: Label = $PlayerStatus/HBoxContainer/PlayerBars/HBoxContainer/VBoxContainer/ScrapCounterMargin/ScrapCounter/ScrapCountLabel
@onready var _magazine_row: MarginContainer = $PlayerStatus/HBoxContainer/PlayerBars/HBoxContainer/VBoxContainer/MagazineCounterMargin
@onready var _magazine_label: Label = $PlayerStatus/HBoxContainer/PlayerBars/HBoxContainer/VBoxContainer/MagazineCounterMargin/MagazineCounter/MagazineLabel
@onready var _ship_hull_rect: TextureRect = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipHPHull
@onready var _ship_magnet_rect: TextureRect = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipHPMagnet
@onready var _ship_integrity_label: Label = $TopRight_UI/VBoxContainer/ShipHealthUI/ShipIntegrityLabel
@onready var _event_text: EventTextDisplay = $EventTextDisplay

var _bound_run_controller: RunController = null
var _bound_player: Player = null
var _bound_threat: ThreatManager = null
var _displayed_scrap_count: int = 0
var _scrap_pulse_tween: Tween = null
var _shield_was_broken: bool = false
var _displayed_shield_count: int = -1
var _shield_pulse_tween: Tween = null
var _shield_broken_loop_tween: Tween = null
var _shield_break_shake_tween: Tween = null
var _displayed_augment_key: String = ""
var _displayed_hotbar_item_name: String = ""
## Seconds left on the transient "THREAT LEVEL N" banner shown after advancing.
var _level_banner_remaining: float = 0.0


func _ready() -> void:
	if _scrap_count_label:
		Magnetide.apply_digital_font(_scrap_count_label)
	if _magazine_label:
		Magnetide.apply_digital_font(_magazine_label)
	if _player_shield_label:
		Magnetide.apply_digital_font(_player_shield_label)
	if _hotbar_item_name_label:
		Magnetide.apply_label_font(_hotbar_item_name_label)
		_hotbar_item_name_label.text = ""
	if _augment_tooltip:
		_augment_tooltip.visible = false
	if _augment_tooltip_name:
		Magnetide.apply_label_font(_augment_tooltip_name)
	if _augment_tooltip_body:
		Magnetide.apply_label_font(_augment_tooltip_body)
	set_run_scrap_metal_count(0)
	call_deferred("_bind_to_active_run_controller")
	call_deferred("_bind_to_active_player")
	_update_health_ui()
	_refresh_augment_icons(true)

	var pause_menu := PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)


func stop_for_run_end() -> void:
	if _event_text:
		_event_text.clear(WINDOW_EVENT_SOURCE)
		_event_text.clear(LEVEL_BANNER_SOURCE)


func _process(delta: float) -> void:
	_bind_to_active_run_controller()
	_bind_to_active_player()
	_bind_to_threat()
	_update_threat_event_text(delta)
	_update_scrap_counter()
	_update_magazine_counter()
	_update_health_ui()
	_update_hotbar_item_name()
	_refresh_augment_icons()


func _bind_to_threat() -> void:
	var threat := _get_active_threat()
	if threat == _bound_threat:
		return

	if _bound_threat and is_instance_valid(_bound_threat):
		_bound_threat.window_opened.disconnect(_on_window_opened)
		_bound_threat.window_closed.disconnect(_on_window_closed)
		_bound_threat.level_advanced.disconnect(_on_level_advanced)

	_bound_threat = threat
	if _bound_threat:
		_bound_threat.window_opened.connect(_on_window_opened)
		_bound_threat.window_closed.connect(_on_window_closed)
		_bound_threat.level_advanced.connect(_on_level_advanced)


func _get_active_threat() -> ThreatManager:
	if Magnetide and Magnetide.level and "threat" in Magnetide.level:
		return Magnetide.level.threat as ThreatManager
	return null


func _on_window_opened(_seconds: float, is_storm_gate: bool) -> void:
	if not _event_text or not _bound_threat:
		return
	var headline := WINDOW_STORM_TEXT if is_storm_gate else WINDOW_NORMAL_TEXT
	var style := EventTextDisplay.Style.CRITICAL if is_storm_gate else EventTextDisplay.Style.WARNING
	if _bound_threat.is_terminal_window:
		headline = WINDOW_TERMINAL_TEXT
		style = EventTextDisplay.Style.CRITICAL
	_event_text.show_message(WINDOW_EVENT_SOURCE, headline, _window_subtext(), WINDOW_PRIORITY, style)


func _on_window_closed() -> void:
	if _event_text:
		_event_text.clear(WINDOW_EVENT_SOURCE)


func _on_level_advanced(new_cap: int) -> void:
	if not _event_text:
		return
	_level_banner_remaining = LEVEL_BANNER_SECONDS
	_event_text.show_message(
		LEVEL_BANNER_SOURCE,
		LEVEL_ADVANCED_TEXT % (new_cap + 1),
		"",
		LEVEL_BANNER_PRIORITY,
		EventTextDisplay.Style.NORMAL
	)


## The window's live detail line: just the countdown. What the player can do is
## communicated by the lever and pylons pulsing in the world, not spelled out here.
## The threat manager owns the clock; this only renders it. Once it expires the line
## drops, leaving the headline — which is what the player sees when a departure hold
## is holding the window open past zero.
func _window_subtext() -> String:
	if _bound_threat == null or _bound_threat.is_terminal_window:
		return ""
	var remaining := int(ceil(_bound_threat.window_seconds_remaining))
	return "%ds" % remaining if remaining > 0 else ""


func _update_threat_event_text(delta: float) -> void:
	if _event_text == null or _bound_threat == null:
		return
	if _level_banner_remaining > 0.0:
		_level_banner_remaining -= delta
		if _level_banner_remaining <= 0.0:
			_event_text.clear(LEVEL_BANNER_SOURCE)
	if _bound_threat.is_departure_window_open:
		_event_text.set_subtext(WINDOW_EVENT_SOURCE, _window_subtext())


func _update_health_ui() -> void:
	_update_player_health(Magnetide.player as Player)
	_update_integrity_display(Magnetide.ship as Ship)


func _update_player_health(player: Player) -> void:
	if not _player_health_bar:
		return

	var max_health := 1.0
	var current_health := 0.0
	if player and player.health:
		max_health = maxf(player.health.max_health, 1.0)
		current_health = clampf(player.health.current_health, 0.0, max_health)

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
	if player and player.health:
		max_shield = maxf(player.health.max_shield, 0.0)
		current_shield = clampi(player.health.current_shield, 0, roundi(max_shield))
		shield_broken = player.health.is_shield_broken()

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


## Shows the name of the hotbar's currently selected item, centered below it.
func _update_hotbar_item_name() -> void:
	if _hotbar_item_name_label == null:
		return
	var name_text := ""
	var hotbar := Magnetide.hotbar
	if hotbar and hotbar.has_method("get_selected_item_data"):
		var data: Variant = hotbar.get_selected_item_data()
		if data != null and "display_name" in data:
			name_text = String(data.display_name)
	if name_text != _displayed_hotbar_item_name:
		_displayed_hotbar_item_name = name_text
		_hotbar_item_name_label.text = name_text


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


## Magazine readout ("[icon] current / max"), shown above the scrap counter only
## while a magazine weapon is equipped. Amber while a reload is in progress.
func _update_magazine_counter() -> void:
	if _magazine_row == null:
		return
	var player := Magnetide.player as Player
	var weapon: HeldItemBehavior = player.equipment.current_behavior if player and player.equipment else null
	var show_row: bool = weapon != null and weapon.has_method("has_ammo_display") and weapon.call("has_ammo_display")
	_magazine_row.visible = show_row
	if not show_row:
		return
	if _magazine_label:
		_magazine_label.text = "%d / %d" % [weapon.call("get_current_ammo"), weapon.call("get_current_magazine_size")]
		var reloading: bool = weapon.call("is_reloading")
		_magazine_label.add_theme_color_override(
			"font_color",
			MAGAZINE_RELOADING_COLOR if reloading else MAGAZINE_READY_COLOR
		)


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
	if _bound_player and is_instance_valid(_bound_player) and _bound_player.health:
		if _bound_player.health.shield_changed.is_connected(update_callable):
			_bound_player.health.shield_changed.disconnect(update_callable)

	_bound_player = player
	if _bound_player:
		if not _bound_player.health.shield_changed.is_connected(update_callable):
			_bound_player.health.shield_changed.connect(update_callable)
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
	_refresh_augment_icons(true)


func _refresh_augment_icons(force: bool = false) -> void:
	if _augment_icons == null:
		return

	var loadout := _get_active_run_loadout()
	var augments := _get_equipped_augments(loadout)
	var augment_key := _build_augment_key(loadout, augments)
	if not force and augment_key == _displayed_augment_key:
		return
	_displayed_augment_key = augment_key

	for child in _augment_icons.get_children():
		child.queue_free()

	_augment_icons.visible = not augments.is_empty()
	if augments.is_empty():
		_hide_augment_tooltip()
		return

	for augment in augments:
		var button := _create_augment_icon_button(augment, loadout)
		_augment_icons.add_child(button)


func _get_active_run_loadout() -> RunLoadout:
	if _bound_run_controller != null and is_instance_valid(_bound_run_controller):
		if _bound_run_controller.has_method("get_run_loadout"):
			return _bound_run_controller.call("get_run_loadout") as RunLoadout
	var run := Magnetide.run as RunController
	if run != null and run.has_method("get_run_loadout"):
		return run.call("get_run_loadout") as RunLoadout
	return null


func _get_equipped_augments(loadout: RunLoadout) -> Array[AugmentData]:
	if loadout == null:
		return []
	return loadout.get_equipped_augments()


func _build_augment_key(loadout: RunLoadout, augments: Array[AugmentData]) -> String:
	if loadout == null or augments.is_empty():
		return ""
	var parts := PackedStringArray()
	for augment in augments:
		parts.append("%s:%d" % [
			_get_augment_key(augment),
			loadout.get_item_level(augment),
		])
	return "|".join(parts)


func _create_augment_icon_button(augment: AugmentData, loadout: RunLoadout) -> Button:
	var button := Button.new()
	button.custom_minimum_size = AUGMENT_ICON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.text = ""
	button.clip_text = true
	# Transparent button chrome; the cell is composited from the child layers.
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("disabled", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)

	# Gray background, inset so it never shows in the rounded border's corners.
	var background := ColorRect.new()
	background.color = AUGMENT_BG_COLOR
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset_full_rect(background, AUGMENT_BG_INSET)
	button.add_child(background)

	# Augment icon, inset within the border frame.
	var icon_rect := TextureRect.new()
	icon_rect.texture = _get_augment_icon(augment)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset_full_rect(icon_rect, AUGMENT_BORDER_INSET)
	button.add_child(icon_rect)

	# Nine-patch border drawn on top; its transparent center shows the icon/bg.
	var border := NinePatchRect.new()
	border.texture = AUGMENT_BORDER_TEXTURE
	border.patch_margin_left = AUGMENT_BORDER_INSET
	border.patch_margin_top = AUGMENT_BORDER_INSET
	border.patch_margin_right = AUGMENT_BORDER_INSET
	border.patch_margin_bottom = AUGMENT_BORDER_INSET
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(border)
	button.mouse_entered.connect(_show_augment_tooltip.bind(button, augment, loadout))
	button.mouse_exited.connect(_hide_augment_tooltip)
	button.focus_entered.connect(_show_augment_tooltip.bind(button, augment, loadout))
	button.focus_exited.connect(_hide_augment_tooltip)
	return button


func _inset_full_rect(control: Control, inset: int) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = inset
	control.offset_top = inset
	control.offset_right = -inset
	control.offset_bottom = -inset


func _show_augment_tooltip(button: Control, augment: AugmentData, loadout: RunLoadout) -> void:
	if _augment_tooltip == null or augment == null:
		return

	_augment_tooltip_name.text = _get_augment_name(augment)
	_augment_tooltip_body.text = _build_augment_tooltip_text(augment, loadout)
	_resize_augment_tooltip()
	_augment_tooltip.visible = true

	var target_position := button.get_global_rect().position + AUGMENT_TOOLTIP_OFFSET
	var viewport_size := get_viewport_rect().size
	var tooltip_size := _augment_tooltip.size
	if tooltip_size.x <= 0.0 or tooltip_size.y <= 0.0:
		tooltip_size = Vector2(300.0, 158.0)
	target_position.x = clampf(target_position.x, 0.0, maxf(viewport_size.x - tooltip_size.x, 0.0))
	target_position.y = clampf(target_position.y, 0.0, maxf(viewport_size.y - tooltip_size.y, 0.0))
	_augment_tooltip.position = target_position


func _hide_augment_tooltip() -> void:
	if _augment_tooltip != null:
		_augment_tooltip.visible = false


## Grow the tooltip panel to fit the wrapped body text so the description never
## spills outside the panel bounds.
func _resize_augment_tooltip() -> void:
	var body := _augment_tooltip_body
	if body == null or _augment_tooltip == null:
		return
	var font := body.get_theme_font("font")
	if font == null:
		return
	var font_size := body.get_theme_font_size("font_size")
	var text_size := font.get_multiline_string_size(
		body.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		body.size.x,
		font_size
	)
	var body_height := ceilf(text_size.y) + 4.0
	body.size = Vector2(body.size.x, body_height)
	# Panel height = body's top offset + measured body height + bottom margin.
	var panel_height := body.position.y + body_height + 12.0
	_augment_tooltip.size = Vector2(_augment_tooltip.size.x, panel_height)


func _build_augment_tooltip_text(augment: AugmentData, loadout: RunLoadout) -> String:
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
	if augment == null or loadout == null or not Utils.has_property(augment, "item_id"):
		return null
	return loadout.get_item_state(augment.get("item_id") as StringName)


func _get_augment_name(augment: AugmentData) -> String:
	if augment != null and augment.has_method("get_display_name"):
		return String(augment.call("get_display_name"))
	if augment != null and not augment.display_name.is_empty():
		return augment.display_name
	return "Augment"


func _get_augment_description(augment: AugmentData) -> String:
	if augment == null or not Utils.has_property(augment, "description"):
		return ""
	return String(augment.get("description"))


func _get_augment_icon(augment: AugmentData) -> Texture2D:
	if augment != null and augment.has_method("get_icon"):
		return augment.call("get_icon") as Texture2D
	if augment != null and Utils.has_property(augment, "icon"):
		return augment.get("icon") as Texture2D
	return null


func _get_augment_key(augment: AugmentData) -> String:
	if augment == null:
		return ""
	if Utils.has_property(augment, "item_id"):
		return String(augment.get("item_id"))
	if not augment.resource_path.is_empty():
		return augment.resource_path
	return str(augment.get_instance_id())



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


## The hull and magnet sprites share the ship's single integrity pool, so both
## tint from the same ratio behind one percentage readout.
func _update_integrity_display(source: Node) -> void:
	if not _ship_hull_rect or not _ship_magnet_rect or not _ship_integrity_label:
		return

	var max_health := 0.0
	var current_health := 0.0
	if source:
		max_health = float(source.get("max_health"))
		current_health = float(source.get("current_health"))

	var ratio := _get_health_ratio(current_health, max_health)
	var tint := DAMAGED_INTEGRITY_COLOR.lerp(HEALTHY_INTEGRITY_COLOR, ratio)
	_ship_hull_rect.modulate = tint
	_ship_magnet_rect.modulate = tint
	_ship_integrity_label.text = _format_percent(ratio)


func _get_health_ratio(current_health: float, max_health: float) -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(current_health / max_health, 0.0, 1.0)


func _format_percent(ratio: float) -> String:
	return "%d%%" % roundi(clampf(ratio, 0.0, 1.0) * 100.0)
