extends VBoxContainer
class_name UpgradeSlot

## Base station upgrade-slot widget: header, icon, level ticks, and upgrade/unlock button.
## Subclasses specialize how the slot is filled — StaticUpgradeSlot owns one fixed upgrade,
## DynamicUpgradeSlot picks its item from a catalog. This base binds the authored scene nodes
## and drives all display; subclasses only add their exports and a few overrides.

signal selection_requested(slot_id: StringName)
signal upgrade_requested(slot_id: StringName)

const MAX_VISIBLE_TICKS := 5

const UPGRADE_ARROW: Texture2D = preload("res://_project/app/screens/station/sprites/upgrade_arrow.png")
const UPGRADE_ARROW_PRESSED: Texture2D = preload("res://_project/app/screens/station/sprites/upgrade_arrow_pressed.png")
const TICK_LIGHT_ON: Texture2D = preload("res://_project/app/screens/station/sprites/upgrade_light_on.png")
const TICK_LIGHT_OFF: Texture2D = preload("res://_project/app/screens/station/sprites/upgrade_light_off.png")
## Lock-open icon shown as the unlock affordance (static slots here, catalog entries in
## the station screen). Owned by the slot widgets; StationScreen reads it as UpgradeSlot.UNLOCK_ICON.
## The static-slot overlay is authored as UpgradeButton/UnlockIcon in upgrade_slot.tscn; code
## only toggles its visibility.
const UNLOCK_ICON: Texture2D = preload("res://_project/app/screens/station/sprites/icon_lock_open.png")

## Unique id for this slot (e.g. &"player_health", &"weapon"). Authored per instance.
@export var slot_id: StringName = &""
## Header label text (e.g. "Health", "Rifle"). Authored, never a runtime placeholder.
@export var display_name: String = "Item"
## Icon shown in a static slot, and the authored placeholder icon for a dynamic slot
## until code overrides it with the actually-equipped item at runtime.
@export var static_icon: Texture2D = null
## Which way this slot's popups (item list, detail/compare panels, cost popup) open. Slots on
## the left of a page open rightward; a slot on the right of a page sets this so its popups
## mirror and stack leftward instead of covering the page.
@export var popups_open_left: bool = false

@export_group("Progress")
## Display fallback until code supplies the live level. A static slot's `upgrade` overrides
## these; a dynamic slot's equipped item's upgrade does.
@export var level: int = 0
## 0 = no upgrade track (shows "Active", hides ticks/button).
@export var max_level: int = 5

@export_group("Lock")
## Authored locked state. Code overrides with the live unlock state at runtime.
@export var locked: bool = false
@export var unlock_research_id: StringName = &""
@export var unlock_research_group: StringName = &""
@export var unlock_research_order: int = 0
@export var unlock_cost_common: int = 0
@export var unlock_cost_rare: int = 0
@export var unlock_cost_epic: int = 0
## Shown in the unlock cost popup for a locked slot.
@export_multiline var unlock_description: String = ""
@export var unlock_gain_text: String = ""
@export_group("")

var _select_button: Button = null
var _static_slot: Panel = null
var _icon_rect: TextureRect = null
var _name_label: Label = null
var _level_label: Label = null
var _header_row: HBoxContainer = null
var _tick_column: VBoxContainer = null
var _tick_container: HBoxContainer = null
var _upgrade_button: Button = null
var _unlock_icon: TextureRect = null
var _upgrade_style_normal: StyleBox = null
var _upgrade_style_pressed: StyleBox = null
var _can_select: bool = false
var _is_unlock_mode: bool = false
var _built: bool = false


func _ready() -> void:
	_build_once()
	_apply_config()


## True when the slot's icon opens the item-selection popup (dynamic slots). Overridden.
func is_selectable() -> bool:
	return false


## The RunUpgrade id this slot drives (empty unless a static slot owns an upgrade). Overridden.
func get_upgrade_id() -> StringName:
	return &""


## Authored fallback level/max shown until live game state overrides them. Overridden.
func _authored_level() -> int:
	return level


func _authored_max() -> int:
	return max_level


## Applies the authored @export config to the widget. Runs on _ready; the reactive setters
## below then override only the parts that change with live game state.
func _apply_config() -> void:
	_build_once()
	var selectable := is_selectable()
	_can_select = selectable
	_name_label.text = display_name
	_select_button.icon = static_icon
	_select_button.visible = selectable
	_select_button.disabled = false
	_select_button.mouse_filter = Control.MOUSE_FILTER_STOP if selectable else Control.MOUSE_FILTER_IGNORE
	_select_button.tooltip_text = display_name
	_icon_rect.texture = static_icon
	_static_slot.visible = not selectable
	if locked:
		set_unlock_mode(true)
	else:
		_is_unlock_mode = false
		_set_level(_authored_level(), _authored_max())


## Reactive override: the actually-equipped item's name/icon for a dynamic slot.
func set_current_name(text: String) -> void:
	_build_once()
	_name_label.text = text


func set_current_icon(icon: Texture2D) -> void:
	_build_once()
	_select_button.icon = icon
	_icon_rect.texture = icon


## Non-zero authored unlock cost as a rarity -> amount map (empty when free).
func get_unlock_cost() -> Dictionary:
	return UpgradeCatalogEntry.build_research_cost(
		unlock_cost_common, unlock_cost_rare, unlock_cost_epic
	)


func set_level(to_level: int, to_max: int) -> void:
	_build_once()
	_set_level(to_level, to_max)


func set_level_text(text: String) -> void:
	_build_once()
	_level_label.text = text


func set_unlock_mode(enabled: bool) -> void:
	_build_once()
	_is_unlock_mode = enabled
	if enabled:
		_level_label.text = ""
		_tick_column.visible = false
		_upgrade_button.visible = true
		_upgrade_button.disabled = false
		# Drop the upgrade-arrow sprite styling so the unlock action reads as a plain themed
		# button, with the lock-open icon (an overlay TextureRect) carried on top of it.
		for state in ["normal", "hover", "focus", "disabled", "pressed"]:
			_upgrade_button.remove_theme_stylebox_override(state)
		_upgrade_button.remove_theme_font_size_override("font_size")
		_upgrade_button.text = ""
		_upgrade_button.icon = null
		_upgrade_button.expand_icon = false
		_upgrade_button.custom_minimum_size = Vector2(52.0, 52.0)
		if _unlock_icon != null:
			_unlock_icon.visible = true
	else:
		if _unlock_icon != null:
			_unlock_icon.visible = false
		_tick_column.visible = true
		_upgrade_button.remove_theme_font_size_override("font_size")
		_upgrade_button.text = ""
		_upgrade_button.custom_minimum_size = Vector2(52.0, 52.0)
		_upgrade_button.icon = UPGRADE_ARROW
		_upgrade_button.expand_icon = true
		if _upgrade_style_normal != null:
			_upgrade_button.add_theme_stylebox_override("normal", _upgrade_style_normal)
			_upgrade_button.add_theme_stylebox_override("hover", _upgrade_style_normal)
			_upgrade_button.add_theme_stylebox_override("focus", _upgrade_style_normal)
			_upgrade_button.add_theme_stylebox_override("disabled", _upgrade_style_normal)
		if _upgrade_style_pressed != null:
			_upgrade_button.add_theme_stylebox_override("pressed", _upgrade_style_pressed)


func get_select_button() -> Button:
	_build_once()
	return _select_button


func get_upgrade_button() -> Button:
	_build_once()
	return _upgrade_button


func _cache_upgrade_styles() -> void:
	if _upgrade_button == null:
		return
	if _upgrade_button.has_theme_stylebox_override("normal"):
		_upgrade_style_normal = _upgrade_button.get_theme_stylebox("normal")
	if _upgrade_button.has_theme_stylebox_override("pressed"):
		_upgrade_style_pressed = _upgrade_button.get_theme_stylebox("pressed")


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
		_cache_upgrade_styles()
		Magnetide.apply_label_fonts(self)
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

	var body_row := HBoxContainer.new()
	body_row.name = "BodyRow"
	body_row.custom_minimum_size = Vector2(0.0, 66.0)
	body_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	body_row.add_theme_constant_override("separation", 8)
	add_child(body_row)

	_select_button = Button.new()
	_select_button.name = "SelectButton"
	_select_button.custom_minimum_size = Vector2(80.0, 80.0)
	_select_button.expand_icon = true
	_select_button.mouse_filter = Control.MOUSE_FILTER_STOP
	body_row.add_child(_select_button)

	_static_slot = Panel.new()
	_static_slot.name = "StaticSlot"
	_static_slot.custom_minimum_size = Vector2(80.0, 80.0)
	_static_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_static_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_static_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_row.add_child(_static_slot)

	_icon_rect = TextureRect.new()
	_icon_rect.name = "StaticIcon"
	_icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_rect.offset_left = 10.0
	_icon_rect.offset_top = 8.0
	_icon_rect.offset_right = -10.0
	_icon_rect.offset_bottom = -8.0
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_static_slot.add_child(_icon_rect)

	_tick_column = VBoxContainer.new()
	_tick_column.name = "TickColumn"
	_tick_column.custom_minimum_size = Vector2(88.0, 66.0)
	_tick_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tick_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_tick_column.add_theme_constant_override("separation", 4)
	body_row.add_child(_tick_column)

	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.custom_minimum_size = Vector2(88.0, 24.0)
	_level_label.clip_text = true
	_level_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color(0.68, 0.75, 0.84, 1.0))
	_tick_column.add_child(_level_label)

	_tick_container = HBoxContainer.new()
	_tick_container.name = "TickContainer"
	_tick_container.custom_minimum_size = Vector2(88.0, 34.0)
	_tick_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tick_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_tick_container.add_theme_constant_override("separation", 4)
	_tick_column.add_child(_tick_container)

	for index in range(MAX_VISIBLE_TICKS):
		var tick := TextureRect.new()
		tick.name = "Tick%d" % [index + 1]
		tick.custom_minimum_size = Vector2(12.0, 34.0)
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tick.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tick.texture = TICK_LIGHT_OFF
		_tick_container.add_child(tick)

	var action_cell := CenterContainer.new()
	action_cell.name = "ActionCell"
	action_cell.custom_minimum_size = Vector2(88.0, 66.0)
	action_cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body_row.add_child(action_cell)

	_upgrade_button = Button.new()
	_upgrade_button.name = "UpgradeButton"
	_upgrade_button.custom_minimum_size = Vector2(52.0, 52.0)
	_upgrade_button.expand_icon = true
	_upgrade_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_button.icon = UPGRADE_ARROW
	action_cell.add_child(_upgrade_button)

	_connect_controls()
	_cache_upgrade_styles()
	Magnetide.apply_label_fonts(self)


func _bind_existing_nodes() -> void:
	_header_row = get_node_or_null("HeaderRow") as HBoxContainer
	_name_label = get_node_or_null("HeaderRow/NameLabel") as Label
	_level_label = get_node_or_null("BodyRow/TickColumn/LevelLabel") as Label
	_select_button = get_node_or_null("BodyRow/SelectButton") as Button
	_static_slot = get_node_or_null("BodyRow/StaticSlot") as Panel
	_icon_rect = get_node_or_null("BodyRow/StaticSlot/StaticIcon") as TextureRect
	_tick_column = get_node_or_null("BodyRow/TickColumn") as VBoxContainer
	_tick_container = get_node_or_null("BodyRow/TickColumn/TickContainer") as HBoxContainer
	_upgrade_button = get_node_or_null("BodyRow/ActionCell/UpgradeButton") as Button
	_unlock_icon = get_node_or_null("BodyRow/ActionCell/UpgradeButton/UnlockIcon") as TextureRect


func _connect_controls() -> void:
	if _select_button != null:
		var select_callable := Callable(self, "_on_select_pressed")
		if not _select_button.pressed.is_connected(select_callable):
			_select_button.pressed.connect(select_callable)
	if _upgrade_button != null:
		var upgrade_callable := Callable(self, "_on_upgrade_pressed")
		if not _upgrade_button.pressed.is_connected(upgrade_callable):
			_upgrade_button.pressed.connect(upgrade_callable)
		var down_callable := Callable(self, "_on_upgrade_button_down")
		if not _upgrade_button.button_down.is_connected(down_callable):
			_upgrade_button.button_down.connect(down_callable)
		var up_callable := Callable(self, "_on_upgrade_button_up")
		if not _upgrade_button.button_up.is_connected(up_callable):
			_upgrade_button.button_up.connect(up_callable)


func _on_select_pressed() -> void:
	if _can_select:
		selection_requested.emit(slot_id)


func _on_upgrade_pressed() -> void:
	upgrade_requested.emit(slot_id)


func _set_level(to_level: int, to_max: int) -> void:
	if _is_unlock_mode:
		set_unlock_mode(true)
		return

	var clamped_max := maxi(to_max, 0)
	var clamped_level := clampi(to_level, 0, clamped_max)
	if clamped_max <= 0:
		_level_label.text = "Active"
		_tick_container.visible = false
		_upgrade_button.visible = false
		return

	_level_label.text = "Lv %d/%d" % [clamped_level, clamped_max]
	_tick_container.visible = true
	_upgrade_button.visible = true
	for index in range(_tick_container.get_child_count()):
		var tick := _tick_container.get_child(index) as TextureRect
		if tick == null:
			continue
		tick.visible = index < mini(clamped_max, MAX_VISIBLE_TICKS)
		tick.texture = TICK_LIGHT_ON if index < clamped_level else TICK_LIGHT_OFF


func _on_upgrade_button_down() -> void:
	if not _is_unlock_mode:
		_upgrade_button.icon = UPGRADE_ARROW_PRESSED


func _on_upgrade_button_up() -> void:
	if not _is_unlock_mode:
		_upgrade_button.icon = UPGRADE_ARROW
