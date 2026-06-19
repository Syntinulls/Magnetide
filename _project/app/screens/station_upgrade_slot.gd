extends VBoxContainer
class_name StationUpgradeSlot

signal selection_requested(slot_id: StringName)
signal upgrade_requested(slot_id: StringName)

const ACTIVE_TICK_COLOR := Color(0.82, 0.87, 0.95, 1.0)
const INACTIVE_TICK_COLOR := Color(0.35, 0.4, 0.5, 1.0)
const MAX_VISIBLE_TICKS := 5

@export var slot_id: StringName = &""

var _select_button: Button = null
var _icon_rect: TextureRect = null
var _name_label: Label = null
var _level_label: Label = null
var _header_row: HBoxContainer = null
var _tick_container: HBoxContainer = null
var _upgrade_button: Button = null
var _can_select: bool = false
var _is_unlock_mode: bool = false
var _upgrade_icon: Texture2D = null
var _built: bool = false


func _ready() -> void:
	_build_once()


func setup(
	id: StringName,
	item_name: String,
	icon: Texture2D,
	level: int,
	max_level: int,
	can_select: bool,
	upgrade_icon: Texture2D = null
) -> void:
	_build_once()
	slot_id = id
	_can_select = can_select
	_select_button.icon = icon
	_select_button.visible = can_select
	_select_button.disabled = false
	_select_button.mouse_filter = Control.MOUSE_FILTER_STOP if can_select else Control.MOUSE_FILTER_IGNORE
	_select_button.tooltip_text = item_name
	_icon_rect.texture = icon
	_icon_rect.visible = not can_select
	_name_label.text = item_name
	_is_unlock_mode = false
	_set_level(level, max_level)
	if upgrade_icon != null:
		_upgrade_icon = upgrade_icon
		_upgrade_button.icon = upgrade_icon
		_upgrade_button.text = ""
		_upgrade_button.expand_icon = true


func set_level(level: int, max_level: int) -> void:
	_build_once()
	_set_level(level, max_level)


func set_level_text(text: String) -> void:
	_build_once()
	_level_label.text = text


func set_unlock_mode(enabled: bool, button_text: String = "Unlock") -> void:
	_build_once()
	_is_unlock_mode = enabled
	if enabled:
		_level_label.text = "Locked"
		_tick_container.visible = false
		_upgrade_button.visible = true
		_upgrade_button.custom_minimum_size = Vector2(78.0, 52.0)
		_upgrade_button.text = button_text
		_upgrade_button.icon = null
		_upgrade_button.expand_icon = false
		_upgrade_button.disabled = false
	else:
		_upgrade_button.custom_minimum_size = Vector2(52.0, 52.0)
		_upgrade_button.text = ""
		_upgrade_button.icon = _upgrade_icon
		_upgrade_button.expand_icon = true


func get_select_button() -> Button:
	_build_once()
	return _select_button


func get_upgrade_button() -> Button:
	_build_once()
	return _upgrade_button


func _build_once() -> void:
	if _built:
		return
	_built = true

	_bind_existing_nodes()
	if _select_button != null \
		and _icon_rect != null \
		and _name_label != null \
		and _level_label != null \
		and _tick_container != null \
		and _upgrade_button != null:
		_connect_controls()
		_apply_local_fonts(self)
		return

	custom_minimum_size = Vector2(315.0, 112.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 2)

	_header_row = HBoxContainer.new()
	_header_row.name = "HeaderRow"
	_header_row.custom_minimum_size = Vector2(0.0, 42.0)
	_header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_header_row.add_theme_constant_override("separation", 8)
	add_child(_header_row)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 24)
	_header_row.add_child(_name_label)

	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.clip_text = true
	_level_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color(0.68, 0.75, 0.84, 1.0))
	_header_row.add_child(_level_label)

	var body_row := HBoxContainer.new()
	body_row.name = "BodyRow"
	body_row.custom_minimum_size = Vector2(0.0, 66.0)
	body_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	body_row.add_theme_constant_override("separation", 8)
	add_child(body_row)

	_select_button = Button.new()
	_select_button.name = "SelectButton"
	_select_button.custom_minimum_size = Vector2(76.0, 66.0)
	_select_button.expand_icon = true
	_select_button.mouse_filter = Control.MOUSE_FILTER_STOP
	body_row.add_child(_select_button)

	_icon_rect = TextureRect.new()
	_icon_rect.name = "StaticIcon"
	_icon_rect.custom_minimum_size = Vector2(76.0, 66.0)
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body_row.add_child(_icon_rect)

	_tick_container = HBoxContainer.new()
	_tick_container.name = "TickContainer"
	_tick_container.custom_minimum_size = Vector2(88.0, 34.0)
	_tick_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tick_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_tick_container.add_theme_constant_override("separation", 4)
	body_row.add_child(_tick_container)

	for index in range(MAX_VISIBLE_TICKS):
		var tick := ColorRect.new()
		tick.name = "Tick%d" % [index + 1]
		tick.custom_minimum_size = Vector2(12.0, 34.0)
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tick.color = INACTIVE_TICK_COLOR
		_tick_container.add_child(tick)

	_upgrade_button = Button.new()
	_upgrade_button.name = "UpgradeButton"
	_upgrade_button.custom_minimum_size = Vector2(52.0, 52.0)
	_upgrade_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_upgrade_button.expand_icon = true
	_upgrade_button.mouse_filter = Control.MOUSE_FILTER_STOP
	body_row.add_child(_upgrade_button)

	_connect_controls()
	_apply_local_fonts(self)


func _bind_existing_nodes() -> void:
	_header_row = get_node_or_null("HeaderRow") as HBoxContainer
	_name_label = get_node_or_null("HeaderRow/NameLabel") as Label
	_level_label = get_node_or_null("HeaderRow/LevelLabel") as Label
	_select_button = get_node_or_null("BodyRow/SelectButton") as Button
	_icon_rect = get_node_or_null("BodyRow/StaticIcon") as TextureRect
	_tick_container = get_node_or_null("BodyRow/TickContainer") as HBoxContainer
	_upgrade_button = get_node_or_null("BodyRow/UpgradeButton") as Button


func _connect_controls() -> void:
	if _select_button != null:
		var select_callable := Callable(self, "_on_select_pressed")
		if not _select_button.pressed.is_connected(select_callable):
			_select_button.pressed.connect(select_callable)
	if _upgrade_button != null:
		var upgrade_callable := Callable(self, "_on_upgrade_pressed")
		if not _upgrade_button.pressed.is_connected(upgrade_callable):
			_upgrade_button.pressed.connect(upgrade_callable)


func _on_select_pressed() -> void:
	if _can_select:
		selection_requested.emit(slot_id)


func _on_upgrade_pressed() -> void:
	upgrade_requested.emit(slot_id)


func _set_level(level: int, max_level: int) -> void:
	if _is_unlock_mode:
		set_unlock_mode(true)
		return

	var clamped_max := maxi(max_level, 0)
	var clamped_level := clampi(level, 0, clamped_max)
	if clamped_max <= 0:
		_level_label.text = "Active"
		_tick_container.visible = false
		_upgrade_button.visible = false
		return

	_level_label.text = "Lv %d/%d" % [clamped_level, clamped_max]
	_tick_container.visible = true
	_upgrade_button.visible = true
	for index in range(_tick_container.get_child_count()):
		var tick := _tick_container.get_child(index) as ColorRect
		if tick == null:
			continue
		tick.visible = index < mini(clamped_max, MAX_VISIBLE_TICKS)
		tick.color = ACTIVE_TICK_COLOR if index < clamped_level else INACTIVE_TICK_COLOR


func _apply_local_fonts(node: Node) -> void:
	if node is Label or node is Button:
		Magnetide.apply_label_font(node as Control)
	for child in node.get_children():
		_apply_local_fonts(child)
