extends Control
class_name StationScreen

signal map_requested
signal main_menu_requested

const StorageSlotScene := preload("res://_project/app/screens/station_storage_slot.tscn")
const StationUpgradeSlotScript := preload("res://_project/app/screens/station_upgrade_slot.gd")
const StationUpgradeSlotScene := preload("res://_project/app/screens/station_upgrade_slot.tscn")
const SlottableCatalogEntryScript := preload("res://_project/items/slottable_catalog_entry.gd")
## Accent color for the research-points readout (formerly borrowed from SalvageItemData.ARTIFACT_COLOR).
const RESEARCH_POINTS_COLOR: Color = Color("4fffe8")
const DEFAULT_AUGMENT_ICON: Texture2D = preload("res://_project/ui/sprites/ui_icon_player.png")
const DEFAULT_HEALTH_ICON: Texture2D = preload("res://_project/ui/sprites/ui_icon_health.png")
const DEFAULT_SHIELD_ICON: Texture2D = preload("res://_project/ui/sprites/ui_icon_shield.png")
const DEFAULT_UPGRADE_ICON: Texture2D = preload("res://_project/ui/sprites/ui_icon_upgrade.png")
const DEFAULT_SHIP_ICON: Texture2D = preload("res://_project/ui/sprites/ui_icon_ship.png")
const DEFAULT_MAGNET_ICON: Texture2D = preload("res://_project/ui/sprites/ui_icon_magnet.png")
const DEFAULT_CAPACITY_ICON: Texture2D = preload("res://_project/ui/sprites/ui_icon_crate.png")

@export var page_pan_duration: float = 0.35
@export var run_loadout: RunLoadout = null
const EquipmentCatalogEntryScript := preload("res://_project/items/equipment/equipment_catalog_entry.gd")

@export var weapon_catalog: Array[Resource] = []
@export var player_augment_catalog: Array[Resource] = []

const ACTIVE_TICK_COLOR := Color(0.82, 0.87, 0.95, 1.0)
const INACTIVE_TICK_COLOR := Color(0.35, 0.4, 0.5, 1.0)
const LOCKED_ENTRY_MODULATE := Color(0.58, 0.62, 0.68, 1.0)
const UNLOCKED_ENTRY_MODULATE := Color.WHITE
const EQUIPPED_ENTRY_TEXT_COLOR := Color(0.55, 1.0, 0.55, 1.0)
const WEAPON_LIST_ENTRY_SIZE := Vector2(178.0, 38.0)
const DYNAMIC_ENTRY_ICON_FRAME_SIZE := Vector2(62.0, 30.0)
const WEAPON_LIST_ENTRY_ICON_MAX_WIDTH := 62
const WEAPON_LIST_ENTRY_ICON_MAX_HEIGHT := 30
const WEAPON_LIST_ENTRY_FONT_SIZE := 20
const DYNAMIC_ENTRY_LEVEL_FONT_SIZE := 16
# Dynamic-slot item list auto-width. The center list panel grows to fit the
# widest entry name so it never gets ellipsized; the other panels keep their
# size (the detail panel just shifts right).
const DYNAMIC_ENTRY_ROW_MARGIN := 10.0        # EntryRow left+right inset (per side)
const DYNAMIC_ENTRY_ROW_SEPARATION := 8.0     # gap between row children
const DYNAMIC_ENTRY_UNLOCK_WIDTH := 62.0      # trailing "Unlock" button (locked)
const DYNAMIC_ENTRY_LEVEL_WIDTH := 46.0       # trailing level label (unlocked)
const DYNAMIC_ENTRY_NAME_SLACK := 8.0         # breathing room so nothing clips
const DYNAMIC_LIST_PANEL_MARGIN := 14.0       # ItemList inset within its panel (per side)
const DYNAMIC_DETAIL_GAP := 12.0              # gap between list panel and detail panel
const DYNAMIC_LIST_MIN_WIDTH := 232.0         # original ItemList width (never shrink below)
const DYNAMIC_LIST_MAX_WIDTH := 560.0
const DYNAMIC_ENTRY_LEVEL_COLOR := Color(0.68, 0.72, 0.78, 1.0)
const PLAYER_SHIELD_SLOT_ID := &"player_shield"
const PLAYER_SHIELD_UNLOCK_RESEARCH_ID := &"player_shield"
const PLAYER_SHIELD_RESEARCH_POINT_COST := 1
const UPGRADE_POPUP_MIN_WIDTH := 260.0
const UPGRADE_POPUP_MAX_WIDTH := 430.0
const UPGRADE_POPUP_HORIZONTAL_PADDING := 24.0
const UPGRADE_POPUP_TOP_PADDING := 12.0
const UPGRADE_POPUP_BOTTOM_PADDING := 14.0
const UPGRADE_POPUP_TITLE_GAP := 10.0
const UPGRADE_POPUP_SECTION_GAP := 20.0
const UPGRADE_POPUP_OFFSET := Vector2(96.0, -145.0)
const WEAPON_STAT_PROPERTIES: Array[String] = ["damage", "fire_rate", "pierce"]
const STORAGE_STAT_PROPERTIES: Array[String] = ["rarity", "weight", "value"]

var _save_data: Resource = null
var _run_loadout: RunLoadout = null
var _current_page_index: int = 0
var _is_panning: bool = false
var _page_tween: Tween = null
var _is_ready: bool = false
var _research_points_label: Label = null
var _station_slots: Dictionary = {}
var _static_slot_icons: Dictionary = {}
var _player_augment_1_row: HBoxContainer = null
var _player_augment_2_row: HBoxContainer = null
var _player_augment_1_button: Button = null
var _player_augment_2_button: Button = null
var _ship_augment_button: Button = null
var _magnet_augment_button: Button = null
var _ship_integrity_upgrade_button: Button = null
var _storage_size_upgrade_button: Button = null
var _magnet_integrity_upgrade_button: Button = null
var _magnet_capacity_upgrade_button: Button = null
var _active_dynamic_slot_id: StringName = &""
var _active_dynamic_slot_kind: StringName = &""
var _active_dynamic_slot_button: Button = null
var _active_player_augment_index: int = -1
var _active_detail_entry: Resource = null

@onready var _page_viewport: Control = $PageViewport
@onready var _page_container: Control = $PageViewport/PageContainer
@onready var _top_bar: Control = $TopBar
@onready var _player_page: Control = $PageViewport/PageContainer/PlayerPage
@onready var _map_button: Button = $TopBar/MapButton
@onready var _menu_button: Button = $TopBar/MenuButton
@onready var _pan_to_ship_button: Button = $PageViewport/PageContainer/PlayerPage/PanToShipButton
@onready var _pan_to_player_button: Button = $PageViewport/PageContainer/ShipPage/PanToPlayerButton
@onready var _weapon_button: Button = get_node_or_null("PageViewport/PageContainer/PlayerPage/UpgradeLayer/TopUpgradeLayout/LeftPanel/SlotColumns/EquipmentColumn/WeaponRow/EquipmentButton") as Button
@onready var _magnet_button: Button = get_node_or_null("PageViewport/PageContainer/PlayerPage/UpgradeLayer/TopUpgradeLayout/LeftPanel/SlotColumns/EquipmentColumn/MagnetRow/EquipmentButton") as Button
@onready var _weapon_row: HBoxContainer = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/TopUpgradeLayout/LeftPanel/SlotColumns/EquipmentColumn/WeaponRow
@onready var _magnet_row: HBoxContainer = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/TopUpgradeLayout/LeftPanel/SlotColumns/EquipmentColumn/MagnetRow
@onready var _health_row: HBoxContainer = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/TopUpgradeLayout/LeftPanel/SlotColumns/LeftColumn/StaticPair/HealthRow
@onready var _shield_row: HBoxContainer = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/TopUpgradeLayout/LeftPanel/SlotColumns/LeftColumn/StaticPair/ShieldRow
@onready var _left_slot_stack: VBoxContainer = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/TopUpgradeLayout/LeftPanel/SlotColumns/EquipmentColumn
@onready var _right_slot_stack: VBoxContainer = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/TopUpgradeLayout/LeftPanel/SlotColumns/LeftColumn/AugmentPair
@onready var _ship_integrity_row: HBoxContainer = $PageViewport/PageContainer/ShipPage/UpgradeLayer/TopUpgradeLayout/RightPanel/SlotColumns/ShipColumn/ShipPair/ShipIntegrityRow
@onready var _storage_size_row: HBoxContainer = $PageViewport/PageContainer/ShipPage/UpgradeLayer/TopUpgradeLayout/RightPanel/SlotColumns/ShipColumn/ShipPair/StorageSizeRow
@onready var _magnet_integrity_row: HBoxContainer = $PageViewport/PageContainer/ShipPage/UpgradeLayer/TopUpgradeLayout/RightPanel/SlotColumns/ShipColumn/MagnetPair/MagnetIntegrityRow
@onready var _magnet_capacity_row: HBoxContainer = $PageViewport/PageContainer/ShipPage/UpgradeLayer/TopUpgradeLayout/RightPanel/SlotColumns/ShipColumn/MagnetPair/MagnetCapacityRow
@onready var _ship_augment_row: HBoxContainer = $PageViewport/PageContainer/ShipPage/UpgradeLayer/TopUpgradeLayout/RightPanel/SlotColumns/AugmentColumn/ShipAugmentRow
@onready var _magnet_augment_row: HBoxContainer = $PageViewport/PageContainer/ShipPage/UpgradeLayer/TopUpgradeLayout/RightPanel/SlotColumns/AugmentColumn/MagnetAugmentRow
@onready var _player_preview_stage: PreviewStage = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/PlayerPreviewStage
@onready var _ship_preview_stage: PreviewStage = $PageViewport/PageContainer/ShipPage/ShipPreviewStage
@onready var _weapon_upgrade_button: Button = get_node_or_null("PageViewport/PageContainer/PlayerPage/UpgradeLayer/TopUpgradeLayout/LeftPanel/SlotColumns/EquipmentColumn/WeaponRow/UpgradeButton") as Button
@onready var _magnet_upgrade_button: Button = get_node_or_null("PageViewport/PageContainer/PlayerPage/UpgradeLayer/TopUpgradeLayout/LeftPanel/SlotColumns/EquipmentColumn/MagnetRow/UpgradeButton") as Button
@onready var _health_upgrade_button: Button = get_node_or_null("PageViewport/PageContainer/PlayerPage/UpgradeLayer/TopUpgradeLayout/LeftPanel/SlotColumns/LeftColumn/StaticPair/HealthRow/UpgradeButton") as Button
@onready var _shield_upgrade_button: Button = get_node_or_null("PageViewport/PageContainer/PlayerPage/UpgradeLayer/TopUpgradeLayout/LeftPanel/SlotColumns/LeftColumn/StaticPair/ShieldRow/UpgradeButton") as Button
@onready var _weapon_popup: Control = $PageViewport/PageContainer/PlayerPage/DynamicSlotPopup
@onready var _weapon_popup_current_cutout: ColorRect = $PageViewport/PageContainer/PlayerPage/DynamicSlotPopup/CurrentItemPanel/CurrentIconFrame
@onready var _weapon_popup_current_stats: Label = $PageViewport/PageContainer/PlayerPage/DynamicSlotPopup/CurrentItemPanel/CurrentStatsLabel
@onready var _weapon_list_title: Label = $PageViewport/PageContainer/PlayerPage/DynamicSlotPopup/ItemListPanel/ItemListTitle
@onready var _weapon_list: VBoxContainer = $PageViewport/PageContainer/PlayerPage/DynamicSlotPopup/ItemListPanel/ItemList
@onready var _weapon_popup_stats_panel: Control = $PageViewport/PageContainer/PlayerPage/DynamicSlotPopup/ItemDetailPanel
@onready var _weapon_popup_stats_name: Label = $PageViewport/PageContainer/PlayerPage/DynamicSlotPopup/ItemDetailPanel/NameLabel
@onready var _weapon_popup_stats_body: Label = $PageViewport/PageContainer/PlayerPage/DynamicSlotPopup/ItemDetailPanel/BodyLabel
@onready var _weapon_popup_stats_status: Label = $PageViewport/PageContainer/PlayerPage/DynamicSlotPopup/ItemDetailPanel/StatusLabel
@onready var _upgrade_cost_popup: Control = $PageViewport/PageContainer/PlayerPage/UpgradeCostPopup
@onready var _stats_title_label: Label = $SharedBottomArea/StatsPanel/TitleLabel
@onready var _stats_body_label: Label = $SharedBottomArea/StatsPanel/BodyLabel
@onready var _storage_grid: GridContainer = $SharedBottomArea/StoragePanel/StorageScroll/StorageGrid
@onready var _storage_scrap_count_label: Label = $SharedBottomArea/StoragePanel/ScrapCounter/ScrapCountLabel
@onready var _storage_detail_panel: Control = $SharedBottomArea/StorageDetailPanel
@onready var _storage_detail_icon: TextureRect = $SharedBottomArea/StorageDetailPanel/ItemIcon
@onready var _storage_detail_name: Label = $SharedBottomArea/StorageDetailPanel/NameLabel
@onready var _storage_detail_body: Label = $SharedBottomArea/StorageDetailPanel/BodyLabel

var _weapon_popup_current_icon: Button = null


func _ready() -> void:
	_is_ready = true
	if _run_loadout == null:
		_run_loadout = run_loadout
	if _run_loadout:
		_run_loadout.prepare_for_run()

	_ensure_research_points_display()
	_ensure_station_header()
	_apply_fonts(self)
	_weapon_popup.visible = false
	_weapon_popup_stats_panel.visible = false
	_weapon_popup_stats_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weapon_popup_stats_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrade_cost_popup.visible = false
	_storage_detail_panel.visible = false
	_weapon_popup.z_index = 30
	_upgrade_cost_popup.z_index = 5
	_configure_dynamic_popup_mouse_blocking()
	_configure_upgrade_popup_layout()
	_ensure_weapon_popup_current_icon()
	_install_compact_slot_rows()
	if _weapon_button != null:
		_weapon_button.z_index = 3

	_map_button.pressed.connect(_on_map_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_pan_to_ship_button.pressed.connect(_on_pan_to_ship_pressed)
	_pan_to_player_button.pressed.connect(_on_pan_to_player_pressed)
	if _weapon_button != null:
		_weapon_button.pressed.connect(_toggle_weapon_popup)
	if _magnet_button != null:
		_magnet_button.pressed.connect(_close_weapon_popup)
	if _player_augment_1_button != null:
		_player_augment_1_button.pressed.connect(_toggle_player_augment_popup.bind(&"PlayerAugment1", 0))
	if _player_augment_2_button != null:
		_player_augment_2_button.pressed.connect(_toggle_player_augment_popup.bind(&"PlayerAugment2", 1))
	if _ship_augment_button != null:
		_ship_augment_button.pressed.connect(_toggle_owner_augment_popup.bind(&"ShipAugment", &"ship_augment", "Ship Augments"))
	if _magnet_augment_button != null:
		_magnet_augment_button.pressed.connect(_toggle_owner_augment_popup.bind(&"MagnetAugment", &"magnet_augment", "Magnet Augments"))

	_connect_upgrade_button(_weapon_upgrade_button, &"weapon_damage")
	_connect_upgrade_button(_magnet_upgrade_button, &"magnet_tool_pull")
	_connect_upgrade_button(_health_upgrade_button, &"player_health")
	_connect_upgrade_button(_shield_upgrade_button, &"player_shield")
	_connect_upgrade_button(_ship_integrity_upgrade_button, &"ship_hull")
	_connect_upgrade_button(_storage_size_upgrade_button, &"ship_storage_size")
	_connect_upgrade_button(_magnet_integrity_upgrade_button, &"ship_magnet_health")
	_connect_upgrade_button(_magnet_capacity_upgrade_button, &"ship_magnet_capacity")

	_populate_storage_slots(_get_storage_entries())

	_layout_pages()
	_update_pan_buttons()
	_refresh_loadout_ui()


func set_run_loadout(loadout: RunLoadout) -> void:
	_run_loadout = loadout
	run_loadout = loadout
	_sync_research_unlocks_to_loadout()
	if _run_loadout:
		_run_loadout.prepare_for_run()
	if _is_ready:
		_refresh_loadout_ui()


func set_save_data(save_data: Resource) -> void:
	_save_data = save_data
	if _save_data != null:
		set_run_loadout(_save_data.get("current_run_loadout") as RunLoadout)
	elif _is_ready:
		_refresh_loadout_ui()


func _sync_research_unlocks_to_loadout() -> void:
	if _run_loadout == null:
		return
	var save_data := _save_data as AppSaveData
	if save_data == null:
		return
	for slot_id in _get_unlockable_static_slot_ids():
		if save_data.is_research_unlocked(_get_static_slot_unlock_research_id(slot_id)):
			_run_loadout.set_slot_unlocked(slot_id, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_layout_pages()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _weapon_popup.visible and not _weapon_popup.get_global_rect().has_point(event.global_position):
			if _active_dynamic_slot_button == null or not _active_dynamic_slot_button.get_global_rect().has_point(event.global_position):
				_close_weapon_popup()


func _layout_pages() -> void:
	if _page_viewport == null or _page_container == null:
		return

	_page_container.position = Vector2(-_get_page_width() * _current_page_index, 0.0)
	if _weapon_popup != null and _weapon_popup.visible:
		_position_weapon_popup()


func _get_page_width() -> float:
	if _player_page != null and _player_page.size.x > 0.0:
		return _player_page.size.x
	return size.x


func _install_compact_slot_rows() -> void:
	if _left_slot_stack != null:
		_left_slot_stack.add_theme_constant_override("separation", 22)
	if _right_slot_stack != null:
		_right_slot_stack.add_theme_constant_override("separation", 22)

	_static_slot_icons[&"weapon"] = _get_row_slot_icon(_weapon_row, _weapon_button)
	_static_slot_icons[&"magnet_tool"] = _get_row_slot_icon(_magnet_row, _magnet_button)
	_static_slot_icons[&"player_health"] = DEFAULT_HEALTH_ICON
	_static_slot_icons[&"player_shield"] = DEFAULT_SHIELD_ICON
	_static_slot_icons[&"ship_integrity"] = DEFAULT_SHIP_ICON
	_static_slot_icons[&"ship_storage_size"] = DEFAULT_CAPACITY_ICON
	_static_slot_icons[&"magnet_integrity"] = DEFAULT_MAGNET_ICON
	_static_slot_icons[&"magnet_capacity"] = DEFAULT_CAPACITY_ICON

	_player_augment_1_row = _create_compact_row(_right_slot_stack, "PlayerAugment1Row")
	_player_augment_2_row = _create_compact_row(_right_slot_stack, "PlayerAugment2Row")

	_install_compact_slot_row(_weapon_row, &"weapon", true)
	_install_compact_slot_row(_magnet_row, &"magnet_tool", false)
	_install_compact_slot_row(_health_row, &"player_health", false)
	_install_compact_slot_row(_shield_row, &"player_shield", false)
	_install_compact_slot_row(_player_augment_1_row, &"PlayerAugment1", true)
	_install_compact_slot_row(_player_augment_2_row, &"PlayerAugment2", true)
	_install_compact_slot_row(_ship_integrity_row, &"ship_integrity", false)
	_install_compact_slot_row(_storage_size_row, &"ship_storage_size", false)
	_install_compact_slot_row(_magnet_integrity_row, &"magnet_integrity", false)
	_install_compact_slot_row(_magnet_capacity_row, &"magnet_capacity", false)
	_install_compact_slot_row(_ship_augment_row, &"ShipAugment", true)
	_install_compact_slot_row(_magnet_augment_row, &"MagnetAugment", true)

	_weapon_button = _get_compact_slot_select_button(&"weapon")
	_magnet_button = _get_compact_slot_select_button(&"magnet_tool")
	_player_augment_1_button = _get_compact_slot_select_button(&"PlayerAugment1")
	_player_augment_2_button = _get_compact_slot_select_button(&"PlayerAugment2")
	_ship_augment_button = _get_compact_slot_select_button(&"ShipAugment")
	_magnet_augment_button = _get_compact_slot_select_button(&"MagnetAugment")
	_weapon_upgrade_button = _get_compact_slot_upgrade_button(&"weapon")
	_magnet_upgrade_button = _get_compact_slot_upgrade_button(&"magnet_tool")
	_health_upgrade_button = _get_compact_slot_upgrade_button(&"player_health")
	_shield_upgrade_button = _get_compact_slot_upgrade_button(&"player_shield")
	_ship_integrity_upgrade_button = _get_compact_slot_upgrade_button(&"ship_integrity")
	_storage_size_upgrade_button = _get_compact_slot_upgrade_button(&"ship_storage_size")
	_magnet_integrity_upgrade_button = _get_compact_slot_upgrade_button(&"magnet_integrity")
	_magnet_capacity_upgrade_button = _get_compact_slot_upgrade_button(&"magnet_capacity")


func _create_compact_row(parent: VBoxContainer, row_name: String) -> HBoxContainer:
	if parent == null:
		return null
	var existing := parent.get_node_or_null(row_name) as HBoxContainer
	if existing != null:
		return existing

	var row := HBoxContainer.new()
	row.name = row_name
	row.custom_minimum_size = Vector2(0.0, 112.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)
	return row


func _configure_upgrade_popup_layout() -> void:
	if _upgrade_cost_popup == null:
		return
	_upgrade_cost_popup.custom_minimum_size = Vector2.ZERO
	var title := _upgrade_cost_popup.get_node_or_null("TitleLabel") as Label
	var credits := _upgrade_cost_popup.get_node_or_null("CreditsLabel") as Label
	var secondary := _upgrade_cost_popup.get_node_or_null("SecondaryLabel") as RichTextLabel
	if title:
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
	if credits:
		credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if secondary:
		secondary.bbcode_enabled = true
		secondary.fit_content = true
		secondary.scroll_active = false
		secondary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Mirror the sibling label's font/color so the requirement text measures
		# and reads identically, just with per-line green/red coloring on top.
		if credits:
			secondary.add_theme_font_override("normal_font", credits.get_theme_font("font"))
			secondary.add_theme_font_size_override("normal_font_size", credits.get_theme_font_size("font_size"))
			secondary.add_theme_color_override("default_color", credits.get_theme_color("font_color"))
	_resize_upgrade_cost_popup()


func _resize_upgrade_cost_popup() -> void:
	if _upgrade_cost_popup == null:
		return

	var title := _upgrade_cost_popup.get_node_or_null("TitleLabel") as Label
	var credits := _upgrade_cost_popup.get_node_or_null("CreditsLabel") as Label
	var secondary := _upgrade_cost_popup.get_node_or_null("SecondaryLabel") as Control
	var labels: Array = []
	for label in [title, credits, secondary]:
		if label != null:
			labels.append(label)

	var popup_width := _get_upgrade_popup_width(labels)
	var content_width := popup_width - (UPGRADE_POPUP_HORIZONTAL_PADDING * 2.0)
	var cursor_y := UPGRADE_POPUP_TOP_PADDING

	if title != null:
		var title_height := maxf(32.0, _get_label_text_height(title, content_width))
		title.position = Vector2(UPGRADE_POPUP_HORIZONTAL_PADDING, cursor_y)
		title.size = Vector2(content_width, title_height)
		title.visible = true
		cursor_y += title_height + UPGRADE_POPUP_TITLE_GAP

	if credits != null:
		var credits_height := _get_label_text_height(credits, content_width)
		credits.visible = credits_height > 0.0
		if credits.visible:
			credits.position = Vector2(UPGRADE_POPUP_HORIZONTAL_PADDING, cursor_y)
			credits.size = Vector2(content_width, credits_height)
			cursor_y += credits_height

	if secondary != null:
		var secondary_height := _get_label_text_height(secondary, content_width)
		secondary.visible = secondary_height > 0.0
		if secondary.visible:
			if credits != null and credits.visible:
				cursor_y += UPGRADE_POPUP_SECTION_GAP
			secondary.position = Vector2(UPGRADE_POPUP_HORIZONTAL_PADDING, cursor_y)
			secondary.size = Vector2(content_width, secondary_height)
			cursor_y += secondary_height

	var popup_height := cursor_y + UPGRADE_POPUP_BOTTOM_PADDING
	_upgrade_cost_popup.size = Vector2(popup_width, popup_height)


func _get_upgrade_popup_width(labels: Array) -> float:
	var content_width := 0.0
	for label in labels:
		content_width = maxf(content_width, _get_label_natural_text_width(label as Control))
	var popup_width := content_width + (UPGRADE_POPUP_HORIZONTAL_PADDING * 2.0)
	return clampf(popup_width, UPGRADE_POPUP_MIN_WIDTH, UPGRADE_POPUP_MAX_WIDTH)


func _get_label_natural_text_width(label: Control) -> float:
	var text := _text_widget_plain_text(label)
	if text.is_empty():
		return 0.0
	var font := _text_widget_font(label)
	var font_size := _text_widget_font_size(label)
	if font == null:
		return 0.0
	var widest := 0.0
	for line in text.split("\n", false):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	return widest


func _get_label_text_height(label: Control, width: float) -> float:
	var text := _text_widget_plain_text(label)
	if text.is_empty():
		return 0.0
	var font := _text_widget_font(label)
	var font_size := _text_widget_font_size(label)
	if font == null:
		return 0.0
	var h_align := HORIZONTAL_ALIGNMENT_LEFT
	if label is Label:
		h_align = (label as Label).horizontal_alignment
	var text_size := font.get_multiline_string_size(text, h_align, width, font_size)
	return ceilf(text_size.y) + 2.0


## Plain text / font accessors that work for both Label and RichTextLabel (the
## latter reports BBCode-stripped text and uses the "normal_font" theme items).
func _text_widget_plain_text(widget: Control) -> String:
	if widget is RichTextLabel:
		return (widget as RichTextLabel).get_parsed_text()
	if widget is Label:
		return (widget as Label).text
	return ""


func _text_widget_font(widget: Control) -> Font:
	if widget is RichTextLabel:
		return widget.get_theme_font("normal_font")
	if widget is Label:
		return widget.get_theme_font("font")
	return null


func _text_widget_font_size(widget: Control) -> int:
	if widget is RichTextLabel:
		return widget.get_theme_font_size("normal_font_size")
	if widget is Label:
		return widget.get_theme_font_size("font_size")
	return 16


func _configure_dynamic_popup_mouse_blocking() -> void:
	if _weapon_popup == null:
		return

	_weapon_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var blocker := _weapon_popup.get_node_or_null("MouseBlocker") as Control
	if blocker != null:
		blocker.mouse_filter = Control.MOUSE_FILTER_STOP

	for panel_name in [
		"CurrentItemPanel",
		"ItemListPanel",
		"ItemDetailPanel",
	]:
		var panel := _weapon_popup.get_node_or_null(panel_name) as Control
		if panel != null:
			panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _ensure_weapon_popup_current_icon() -> void:
	if _weapon_popup_current_cutout == null:
		return
	_weapon_popup_current_cutout.color = Color(0.09, 0.12, 0.17, 0.96)
	_weapon_popup_current_cutout.position = Vector2(0.0, 0.0)
	_weapon_popup_current_cutout.size = Vector2(76.0, 66.0)
	_weapon_popup_current_cutout.custom_minimum_size = Vector2(76.0, 66.0)
	_weapon_popup_current_icon = _weapon_popup_current_cutout.get_node_or_null("CurrentIcon") as Button
	if _weapon_popup_current_icon != null:
		return

	_weapon_popup_current_icon = Button.new()
	_weapon_popup_current_icon.name = "CurrentIcon"
	_weapon_popup_current_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_popup_current_icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_weapon_popup_current_icon.position = Vector2(0.0, 0.0)
	_weapon_popup_current_icon.size = Vector2(76.0, 66.0)
	_weapon_popup_current_icon.custom_minimum_size = Vector2(76.0, 66.0)
	_weapon_popup_current_icon.expand_icon = true
	_weapon_popup_current_cutout.add_child(_weapon_popup_current_icon)


func _install_compact_slot_row(row: HBoxContainer, slot_id: StringName, can_select: bool) -> void:
	if row == null:
		return

	row.custom_minimum_size = Vector2(0.0, 112.0)
	row.add_theme_constant_override("separation", 0)
	var slot := _get_compact_slot_for_row(row)
	if slot == null:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
		slot = StationUpgradeSlotScene.instantiate() as StationUpgradeSlot
		if slot == null:
			slot = StationUpgradeSlotScript.new() as StationUpgradeSlot
		slot.name = "%sSlot" % String(slot_id).capitalize().replace(" ", "")
		row.add_child(slot)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_station_slots[slot_id] = slot
	slot.setup(slot_id, "Loading", null, 0, 0, can_select, _get_upgrade_icon())


func _get_row_button_icon(row: HBoxContainer, button_name: String) -> Texture2D:
	if row == null:
		return null
	var button := row.get_node_or_null(button_name) as Button
	if button == null:
		return null
	return button.icon


func _get_row_slot_icon(row: HBoxContainer, fallback_button: Button = null) -> Texture2D:
	var slot := _get_compact_slot_for_row(row)
	if slot != null:
		var select_button := slot.get_select_button()
		if select_button != null and select_button.icon != null:
			return select_button.icon
	if fallback_button != null:
		return fallback_button.icon
	return null


func _get_compact_slot_select_button(slot_id: StringName) -> Button:
	var slot := _station_slots.get(slot_id, null) as StationUpgradeSlot
	return slot.get_select_button() if slot != null else null


func _get_compact_slot_upgrade_button(slot_id: StringName) -> Button:
	var slot := _station_slots.get(slot_id, null) as StationUpgradeSlot
	return slot.get_upgrade_button() if slot != null else null


func _get_upgrade_icon() -> Texture2D:
	if _weapon_upgrade_button != null and _weapon_upgrade_button.icon != null:
		return _weapon_upgrade_button.icon
	if _magnet_upgrade_button != null and _magnet_upgrade_button.icon != null:
		return _magnet_upgrade_button.icon
	if _health_upgrade_button != null and _health_upgrade_button.icon != null:
		return _health_upgrade_button.icon
	if _shield_upgrade_button != null and _shield_upgrade_button.icon != null:
		return _shield_upgrade_button.icon
	return DEFAULT_UPGRADE_ICON


func _connect_upgrade_button(button: Button, upgrade_id: StringName) -> void:
	if button == null:
		return
	button.mouse_entered.connect(_show_upgrade_cost_popup.bind(button, upgrade_id))
	button.mouse_exited.connect(_hide_upgrade_cost_popup)
	button.focus_entered.connect(_show_upgrade_cost_popup.bind(button, upgrade_id))
	button.focus_exited.connect(_hide_upgrade_cost_popup)
	button.pressed.connect(_on_upgrade_pressed.bind(upgrade_id))


func _show_upgrade_cost_popup(button: Button, upgrade_id: StringName) -> void:
	if _weapon_popup != null and _weapon_popup.visible:
		return

	var upgrade := _get_upgrade(upgrade_id)
	if upgrade == null:
		return

	var static_slot_id := _get_unlockable_static_slot_id_for_upgrade(upgrade_id)
	if static_slot_id != &"" and not _is_static_slot_unlocked(static_slot_id):
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/TitleLabel.text = _get_static_slot_display_name(static_slot_id)
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/CreditsLabel.text = _build_static_slot_unlock_detail_text(static_slot_id)
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/SecondaryLabel.text = _build_static_slot_unlock_cost_text(static_slot_id)
	elif _is_upgrade_maxed(upgrade_id):
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/TitleLabel.text = "MAX LEVEL"
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/CreditsLabel.text = ""
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/SecondaryLabel.text = ""
	else:
		var current_level := _get_upgrade_current_level(upgrade_id)
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/TitleLabel.text = "Lv %d -> %d" % [
			current_level,
			current_level + 1,
		]
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/CreditsLabel.text = _build_upgrade_gain_text(upgrade_id)
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/SecondaryLabel.text = _build_upgrade_requirement_text(upgrade_id)
	var button_rect := button.get_global_rect()
	var page_rect := _player_page.get_global_rect()
	_resize_upgrade_cost_popup()
	_upgrade_cost_popup.position = (button_rect.position - page_rect.position) + UPGRADE_POPUP_OFFSET
	_upgrade_cost_popup.visible = true


func _hide_upgrade_cost_popup() -> void:
	_upgrade_cost_popup.visible = false


func _get_unlockable_static_slot_ids() -> Array[StringName]:
	var slot_ids: Array[StringName] = []
	slot_ids.append(PLAYER_SHIELD_SLOT_ID)
	return slot_ids


func _get_unlockable_static_slot_id_for_upgrade(upgrade_id: StringName) -> StringName:
	match upgrade_id:
		&"player_shield":
			return PLAYER_SHIELD_SLOT_ID
	return &""


func _is_static_slot_unlockable(slot_id: StringName) -> bool:
	return _get_unlockable_static_slot_ids().has(slot_id)


func _is_static_slot_unlocked(slot_id: StringName) -> bool:
	if not _is_static_slot_unlockable(slot_id):
		return true
	if _run_loadout != null and _run_loadout.is_slot_unlocked(slot_id, false):
		return true
	var save_data := _save_data as AppSaveData
	return save_data != null and save_data.is_research_unlocked(_get_static_slot_unlock_research_id(slot_id))


func _get_static_slot_unlock_research_id(slot_id: StringName) -> StringName:
	if slot_id == PLAYER_SHIELD_SLOT_ID:
		return PLAYER_SHIELD_UNLOCK_RESEARCH_ID
	return &""


func _get_static_slot_unlock_research_point_cost(slot_id: StringName) -> int:
	if slot_id == PLAYER_SHIELD_SLOT_ID:
		return PLAYER_SHIELD_RESEARCH_POINT_COST
	return 0


func _get_static_slot_unlock_title(slot_id: StringName) -> String:
	if slot_id == PLAYER_SHIELD_SLOT_ID:
		return "Unlock Shield"
	return "Unlock Slot"


func _get_static_slot_display_name(slot_id: StringName) -> String:
	if slot_id == PLAYER_SHIELD_SLOT_ID:
		return "Player Shield"
	return "Static Slot"


func _get_static_slot_description(slot_id: StringName) -> String:
	if slot_id == PLAYER_SHIELD_SLOT_ID:
		return "Adds rechargeable shield hits that absorb damage before health is lost."
	return ""


func _get_static_slot_unlock_gain_text(slot_id: StringName) -> String:
	if slot_id == PLAYER_SHIELD_SLOT_ID:
		return "+2 Shield Hits"
	return ""


func _build_static_slot_unlock_detail_text(slot_id: StringName) -> String:
	var lines := PackedStringArray()
	var description := _get_static_slot_description(slot_id)
	if not description.is_empty():
		lines.append(description)
	var gains := _get_static_slot_unlock_gain_text(slot_id)
	if not gains.is_empty():
		if not lines.is_empty():
			lines.append("")
		lines.append(gains)
	return "\n".join(lines)


func _build_static_slot_unlock_cost_text(slot_id: StringName) -> String:
	var cost := _get_static_slot_unlock_research_point_cost(slot_id)
	return "Unlock Cost\n%s" % _format_research_point_cost_text(cost)


func _unlock_static_slot(slot_id: StringName) -> void:
	if not _is_static_slot_unlockable(slot_id):
		return
	var cost := _get_static_slot_unlock_research_point_cost(slot_id)
	var research_id := _get_static_slot_unlock_research_id(slot_id)
	var save_data := _save_data as AppSaveData
	if save_data != null:
		if not save_data.can_spend_research_points(cost):
			return
		if not save_data.spend_research_points(cost):
			return
		save_data.unlock_research_id(research_id)

	if _run_loadout != null:
		_run_loadout.set_slot_unlocked(slot_id, true)
		_run_loadout.prepare_for_run()

	_save_current_game()
	_refresh_loadout_ui()
	if _upgrade_cost_popup.visible:
		var button := _get_upgrade_button(_get_static_slot_upgrade_id(slot_id))
		if button:
			_show_upgrade_cost_popup(button, _get_static_slot_upgrade_id(slot_id))


func _get_static_slot_upgrade_id(slot_id: StringName) -> StringName:
	if slot_id == PLAYER_SHIELD_SLOT_ID:
		return &"player_shield"
	return &""


func _on_map_pressed() -> void:
	map_requested.emit()


func _on_menu_pressed() -> void:
	main_menu_requested.emit()


func _on_pan_to_ship_pressed() -> void:
	_pan_to_page(1)


func _on_pan_to_player_pressed() -> void:
	_pan_to_page(0)


func _pan_to_page(page_index: int) -> void:
	if _is_panning or page_index == _current_page_index:
		return

	_is_panning = true
	_close_weapon_popup()
	_hide_upgrade_cost_popup()
	_hide_storage_detail()
	_clear_stats_panel()
	_pan_to_ship_button.visible = false
	_pan_to_player_button.visible = false
	_current_page_index = clampi(page_index, 0, 1)

	if _page_tween != null:
		_page_tween.kill()

	var target_position := Vector2(-_get_page_width() * _current_page_index, 0.0)
	_page_tween = create_tween()
	_page_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_page_tween.tween_property(_page_container, "position", target_position, page_pan_duration)
	await _page_tween.finished

	_is_panning = false
	_refresh_stats_panel()
	_update_pan_buttons()


func _update_pan_buttons() -> void:
	_pan_to_ship_button.visible = _current_page_index == 0 and not _is_panning
	_pan_to_player_button.visible = _current_page_index == 1 and not _is_panning


func _refresh_stats_panel() -> void:
	if _current_page_index == 0:
		_stats_title_label.text = "Player Loadout"
		_stats_body_label.text = _build_player_stats_text()
	else:
		_stats_title_label.text = "Ship Stats"
		_stats_body_label.text = _build_ship_stats_text()


func _clear_stats_panel() -> void:
	_stats_title_label.text = ""
	_stats_body_label.text = ""


func _refresh_storage_scrap_counter() -> void:
	if not _storage_scrap_count_label:
		return
	var scrap_count := 0
	var save_data := _save_data as AppSaveData
	if save_data:
		scrap_count = save_data.total_scrap_metal
	_storage_scrap_count_label.text = str(scrap_count)


func _ensure_research_points_display() -> void:
	if _research_points_label != null or _top_bar == null:
		return

	var panel := ColorRect.new()
	panel.name = "ResearchPointsPanel"
	panel.color = Color(0.09, 0.12, 0.17, 0.88)
	panel.custom_minimum_size = Vector2(260.0, 60.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -292.0
	panel.offset_top = 24.0
	panel.offset_right = -24.0
	panel.offset_bottom = 84.0
	_top_bar.add_child(panel)

	_research_points_label = Label.new()
	_research_points_label.name = "ResearchPointsLabel"
	_research_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_research_points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_research_points_label.add_theme_color_override("font_color", RESEARCH_POINTS_COLOR)
	_research_points_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_research_points_label.add_theme_constant_override("outline_size", 4)
	_research_points_label.add_theme_font_size_override("font_size", 34)
	_research_points_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_research_points_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_research_points_label)
	_refresh_research_points_display()


## Persistent "Space Station" title to the right of the Menu button. Lives on
## the TopBar (a sibling of the page viewport), so it stays put when panning
## between the player and ship pages.
func _ensure_station_header() -> void:
	if _top_bar == null:
		return
	if _top_bar.get_node_or_null("StationHeaderLabel") != null:
		return

	var header := Label.new()
	header.name = "StationHeaderLabel"
	header.text = "Space Station"
	header.add_theme_color_override("font_color", Color.WHITE)
	header.add_theme_font_size_override("font_size", 56)
	Magnetide.apply_label_font(header)
	header.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Right of the 160x60 Menu button (at x24..184, y24..84), vertically centered.
	header.position = Vector2(208.0, 24.0)
	header.custom_minimum_size = Vector2(0.0, 60.0)
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(header)


func _refresh_research_points_display() -> void:
	if _research_points_label == null:
		return
	var points := 0
	var save_data := _save_data as AppSaveData
	if save_data:
		points = save_data.research_points
	_research_points_label.text = "RESEARCH: %d" % points


func _toggle_weapon_popup() -> void:
	_toggle_dynamic_slot_popup(&"weapon", _weapon_button, &"weapon", -1, "Weapons")


func _toggle_player_augment_popup(slot_id: StringName, augment_index: int) -> void:
	var button := _get_compact_slot_select_button(slot_id)
	_toggle_dynamic_slot_popup(slot_id, button, &"player_augment", augment_index, "Augments")


func _toggle_owner_augment_popup(slot_id: StringName, slot_kind: StringName, list_title: String) -> void:
	var button := _get_compact_slot_select_button(slot_id)
	_toggle_dynamic_slot_popup(slot_id, button, slot_kind, 0, list_title)


func _toggle_dynamic_slot_popup(
	slot_id: StringName,
	button: Button,
	slot_kind: StringName,
	augment_index: int,
	list_title: String
) -> void:
	if button == null:
		return

	var should_show := not _weapon_popup.visible or _active_dynamic_slot_id != slot_id
	_active_dynamic_slot_id = slot_id
	_active_dynamic_slot_kind = slot_kind
	_active_dynamic_slot_button = button
	_active_player_augment_index = augment_index
	_weapon_popup.visible = should_show
	_weapon_popup_stats_panel.visible = false
	_active_detail_entry = null
	if _weapon_list_title != null:
		_weapon_list_title.text = list_title
	if should_show:
		_hide_upgrade_cost_popup()
		_hide_storage_detail()
		_position_weapon_popup()
		_populate_dynamic_item_list()
		_refresh_current_dynamic_item_stats()


func _close_weapon_popup() -> void:
	_weapon_popup.visible = false
	_weapon_popup_stats_panel.visible = false
	_active_dynamic_slot_id = &""
	_active_dynamic_slot_kind = &""
	_active_dynamic_slot_button = null
	_active_player_augment_index = -1
	_active_detail_entry = null


func _position_weapon_popup() -> void:
	if _weapon_popup == null or _active_dynamic_slot_button == null or _player_page == null:
		return

	var button_rect := _active_dynamic_slot_button.get_global_rect()
	var page_rect := _player_page.get_global_rect()
	_weapon_popup.position = button_rect.position - page_rect.position


func _show_dynamic_item_stats(entry: Resource) -> void:
	var item_data := _catalog_entry_item_data(entry)
	if entry == null or item_data == null:
		return

	_active_detail_entry = entry
	_weapon_popup_stats_name.text = _catalog_entry_display_name(entry)
	_weapon_popup_stats_body.text = _format_catalog_item_stats(entry)
	_update_dynamic_item_status(entry)
	_weapon_popup_stats_panel.visible = true


func _hide_dynamic_item_stats(entry: Resource) -> void:
	if _active_detail_entry != entry:
		return
	_active_detail_entry = null
	_weapon_popup_stats_panel.visible = false
	_weapon_popup_stats_status.visible = false


func _show_weapon_stats(entry: Resource) -> void:
	_show_dynamic_item_stats(entry)


func _update_dynamic_item_status(entry: Resource) -> void:
	if _weapon_popup_stats_status == null:
		return
	if _is_catalog_entry_equipped(entry):
		_weapon_popup_stats_status.text = "EQUIPPED"
		_weapon_popup_stats_status.add_theme_color_override("font_color", EQUIPPED_ENTRY_TEXT_COLOR)
		_weapon_popup_stats_status.visible = true
		return
	if _catalog_entry_locked(entry):
		_weapon_popup_stats_status.text = "LOCKED\nUNLOCK: %s" % _catalog_entry_unlock_cost_text(entry)
		_weapon_popup_stats_status.add_theme_color_override("font_color", DYNAMIC_ENTRY_LEVEL_COLOR)
		_weapon_popup_stats_status.visible = true
		return
	_weapon_popup_stats_status.text = ""
	_weapon_popup_stats_status.visible = false


func _equip_dynamic_item_from_popup(entry: Resource) -> void:
	if entry == null or _catalog_entry_locked(entry) or _run_loadout == null:
		return

	match _active_dynamic_slot_kind:
		&"weapon":
			var weapon_data := _catalog_entry_equipment(entry) as WeaponData
			if weapon_data == null:
				return
			_run_loadout.equip_weapon(weapon_data)
		&"player_augment":
			var augment_data := _catalog_entry_item_data(entry) as AugmentData
			if augment_data == null:
				return
			_run_loadout.equip_player_augment(_active_player_augment_index, augment_data)
		&"ship_augment":
			var ship_augment_data := _catalog_entry_item_data(entry) as AugmentData
			if ship_augment_data == null:
				return
			_run_loadout.equip_ship_augment(_active_player_augment_index, ship_augment_data)
		&"magnet_augment":
			var magnet_augment_data := _catalog_entry_item_data(entry) as AugmentData
			if magnet_augment_data == null:
				return
			_run_loadout.equip_magnet_augment(_active_player_augment_index, magnet_augment_data)
		_:
			return

	_save_current_game()
	_refresh_loadout_ui()
	_close_weapon_popup()


func _equip_weapon_from_popup(entry: Resource) -> void:
	_equip_dynamic_item_from_popup(entry)


func _populate_storage_slots(storage_entries: Array[Dictionary]) -> void:
	for child in _storage_grid.get_children():
		child.queue_free()

	for entry in storage_entries:
		var item_data := entry.get("item_data", null) as SalvageItemData
		var quantity := maxi(int(entry.get("quantity", 1)), 1)
		if item_data == null:
			continue

		var slot := StorageSlotScene.instantiate() as StationStorageSlot
		if slot == null:
			continue
		_storage_grid.add_child(slot)
		slot.setup(item_data, quantity)
		slot.item_hovered.connect(_show_storage_detail)
		slot.item_unhovered.connect(_hide_storage_detail)


func _show_storage_detail(_slot: StationStorageSlot, item_data: SalvageItemData, quantity: int) -> void:
	if item_data == null:
		_hide_storage_detail()
		return

	_storage_detail_icon.texture = item_data.sprite
	_storage_detail_name.text = item_data.item_name if not item_data.item_name.is_empty() else "Unknown Item"
	_storage_detail_body.text = _build_storage_detail_text(item_data, quantity)
	_storage_detail_panel.visible = true


func _hide_storage_detail(_slot: StationStorageSlot = null) -> void:
	_storage_detail_panel.visible = false


func _build_storage_detail_text(item_data: SalvageItemData, quantity: int) -> String:
	return "QUANTITY: %d\n%s\n\nRecovered station material." % [
		quantity,
		_format_resource_stats(item_data, STORAGE_STAT_PROPERTIES),
	]


func _refresh_loadout_ui() -> void:
	if _run_loadout:
		_run_loadout.prepare_for_run()
	_update_equipment_buttons()
	_update_augment_slots()
	_update_upgrade_rows()
	_update_previews()
	if _weapon_popup != null and _weapon_popup.visible:
		_populate_dynamic_item_list()
	_populate_storage_slots(_get_storage_entries())
	_refresh_current_dynamic_item_stats()
	_refresh_stats_panel()
	_refresh_storage_scrap_counter()
	_refresh_research_points_display()


func _update_equipment_buttons() -> void:
	if _run_loadout == null:
		return

	var weapon := _run_loadout.equipped_weapon
	if weapon and _has_compact_slot(&"weapon"):
		_refresh_compact_slot(
			&"weapon",
			_get_equipment_name(weapon),
			_get_equipment_icon(weapon),
			&"weapon_damage",
			true
		)
	elif weapon:
		_weapon_button.icon = _get_equipment_icon(weapon)
		_weapon_button.text = ""

	var magnet_tool := _run_loadout.equipped_magnet_tool
	if magnet_tool and _has_compact_slot(&"magnet_tool"):
		_refresh_compact_slot(
			&"magnet_tool",
			_get_equipment_name(magnet_tool),
			_get_equipment_icon(magnet_tool),
			&"magnet_tool_pull",
			false
		)
	elif magnet_tool:
		_magnet_button.icon = _get_equipment_icon(magnet_tool)


func _update_previews() -> void:
	if _run_loadout == null:
		return
	if _player_preview_stage != null:
		_player_preview_stage.set_loadout(_run_loadout)
	if _ship_preview_stage != null:
		_ship_preview_stage.set_loadout(_run_loadout)


func _update_augment_slots() -> void:
	_refresh_augment_slot(&"PlayerAugment1", _get_player_augment(0), _get_player_augment_slot_name(0), DEFAULT_AUGMENT_ICON)
	_refresh_augment_slot(&"PlayerAugment2", _get_player_augment(1), _get_player_augment_slot_name(1), DEFAULT_AUGMENT_ICON)
	_refresh_augment_slot(&"ShipAugment", _get_ship_augment(0), "Ship Augment", DEFAULT_SHIP_ICON)
	_refresh_augment_slot(&"MagnetAugment", _get_magnet_augment(0), "Magnet Augment", DEFAULT_MAGNET_ICON)


func _refresh_augment_slot(slot_id: StringName, augment: AugmentData, empty_name: String, empty_icon: Texture2D) -> void:
	var slot := _station_slots.get(slot_id, null) as StationUpgradeSlot
	if slot == null:
		return

	if augment == null:
		slot.setup(slot_id, empty_name, empty_icon, 0, 0, true, _get_upgrade_icon())
		slot.set_level_text("None")
		return

	var level := _run_loadout.get_item_level(augment) if _run_loadout != null else 0
	slot.setup(
		slot_id,
		_get_upgradeable_item_name(augment),
		_get_upgradeable_item_icon(augment, empty_icon),
		level,
		int(augment.max_level),
		true,
		_get_upgrade_icon()
	)


func _get_player_augment_slot_name(augment_index: int) -> String:
	return "Augment %d" % (augment_index + 1)


func _update_upgrade_rows() -> void:
	_refresh_compact_slot(
		&"player_health",
		"Health",
		_static_slot_icons.get(&"player_health", null) as Texture2D,
		&"player_health",
		false
	)
	_refresh_compact_slot(
		&"player_shield",
		"Shield",
		_static_slot_icons.get(&"player_shield", null) as Texture2D,
		&"player_shield",
		false
	)
	_refresh_compact_slot(
		&"ship_integrity",
		"Integrity",
		_static_slot_icons.get(&"ship_integrity", null) as Texture2D,
		&"ship_hull",
		false
	)
	_refresh_compact_slot(
		&"ship_storage_size",
		"Storage Size",
		_static_slot_icons.get(&"ship_storage_size", null) as Texture2D,
		&"ship_storage_size",
		false
	)
	_refresh_compact_slot(
		&"magnet_integrity",
		"Integrity",
		_static_slot_icons.get(&"magnet_integrity", null) as Texture2D,
		&"ship_magnet_health",
		false
	)
	_refresh_compact_slot(
		&"magnet_capacity",
		"Capacity",
		_static_slot_icons.get(&"magnet_capacity", null) as Texture2D,
		&"ship_magnet_capacity",
		false
	)
	_set_upgrade_row_level(_weapon_row, &"weapon_damage")
	_set_upgrade_row_level(_magnet_row, &"magnet_tool_pull")
	_set_upgrade_row_level(_health_row, &"player_health")
	_set_upgrade_row_level(_shield_row, &"player_shield")


func _set_upgrade_row_level(row: HBoxContainer, upgrade_id: StringName) -> void:
	if row == null:
		return
	var slot := _get_compact_slot_for_row(row)
	if slot != null:
		slot.set_level(_get_upgrade_current_level(upgrade_id), _get_upgrade_current_max_level(upgrade_id))
		return

	var level := _get_upgrade_current_level(upgrade_id)
	var max_level := _get_upgrade_current_max_level(upgrade_id)
	var tick_index := 0
	for child in row.get_children():
		if child is ColorRect and String(child.name).begins_with("Tick"):
			tick_index += 1
			var tick := child as ColorRect
			tick.visible = tick_index <= max_level
			tick.color = ACTIVE_TICK_COLOR if tick_index <= level else INACTIVE_TICK_COLOR


func _on_upgrade_pressed(upgrade_id: StringName) -> void:
	if _weapon_popup != null and _weapon_popup.visible:
		return
	if _run_loadout == null:
		return
	var static_slot_id := _get_unlockable_static_slot_id_for_upgrade(upgrade_id)
	if static_slot_id != &"" and not _is_static_slot_unlocked(static_slot_id):
		_unlock_static_slot(static_slot_id)
		return
	if _get_upgrade(upgrade_id) == null:
		return
	if _is_upgrade_maxed(upgrade_id):
		return
	var level_cost: Resource = _run_loadout.get_upgrade_next_level_cost(upgrade_id)
	if _save_data != null and not bool(_save_data.call("spend_level_cost", level_cost)):
		return
	_run_loadout.increase_upgrade(upgrade_id)
	_save_current_game()
	_refresh_loadout_ui()
	if _upgrade_cost_popup.visible:
		var button := _get_upgrade_button(upgrade_id)
		if button:
			_show_upgrade_cost_popup(button, upgrade_id)


func _populate_weapon_list() -> void:
	_populate_dynamic_item_list()


func _populate_dynamic_item_list() -> void:
	if _weapon_list == null:
		return

	for child in _weapon_list.get_children():
		child.queue_free()

	var entries := _get_active_catalog_entries()
	var font := Magnetide.label_font
	var max_needed_width := 0.0
	for entry in entries:
		if entry == null or _catalog_entry_item_data(entry) == null:
			continue

		var button := Button.new()
		button.custom_minimum_size = WEAPON_LIST_ENTRY_SIZE
		button.size_flags_horizontal = Control.SIZE_FILL
		var is_locked := _catalog_entry_locked(entry)
		var can_unlock := _can_unlock_catalog_entry(entry)
		button.modulate = UNLOCKED_ENTRY_MODULATE
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		Magnetide.apply_label_font(button)
		_configure_dynamic_entry_button(button, entry, is_locked, can_unlock)
		_weapon_list.add_child(button)
		_connect_dynamic_entry_detail_hover(button, entry)
		if not is_locked:
			button.pressed.connect(_equip_dynamic_item_from_popup.bind(entry))
		max_needed_width = maxf(max_needed_width, _measure_dynamic_entry_width(entry, is_locked, font))

	_apply_dynamic_list_width(max_needed_width)


## Width an entry button needs to show its full name alongside the fixed icon and
## trailing level/unlock element (see _configure_dynamic_entry_button layout).
func _measure_dynamic_entry_width(entry: Resource, is_locked: bool, font: Font) -> float:
	if font == null:
		return 0.0
	var name_width := font.get_string_size(
		_catalog_entry_display_name(entry),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		WEAPON_LIST_ENTRY_FONT_SIZE
	).x
	var trailing := DYNAMIC_ENTRY_UNLOCK_WIDTH if is_locked else DYNAMIC_ENTRY_LEVEL_WIDTH
	return DYNAMIC_ENTRY_ROW_MARGIN * 2.0 \
		+ DYNAMIC_ENTRY_ICON_FRAME_SIZE.x \
		+ DYNAMIC_ENTRY_ROW_SEPARATION * 2.0 \
		+ name_width \
		+ trailing \
		+ DYNAMIC_ENTRY_NAME_SLACK


## Resize only the center list panel to `content_width`, shifting the detail panel
## right and growing the popup container. Other panels keep their size.
func _apply_dynamic_list_width(content_width: float) -> void:
	var list_panel := _weapon_popup.get_node_or_null("ItemListPanel") as Control
	if list_panel == null or _weapon_list == null:
		return

	var list_width := clampf(content_width, DYNAMIC_LIST_MIN_WIDTH, DYNAMIC_LIST_MAX_WIDTH)
	var panel_width := list_width + DYNAMIC_LIST_PANEL_MARGIN * 2.0

	list_panel.size = Vector2(panel_width, list_panel.size.y)
	_weapon_list.size = Vector2(list_width, _weapon_list.size.y)
	if _weapon_list_title != null:
		_weapon_list_title.size = Vector2(list_width, _weapon_list_title.size.y)
	for child in _weapon_list.get_children():
		if child is Control:
			var entry_control := child as Control
			entry_control.custom_minimum_size = Vector2(list_width, entry_control.custom_minimum_size.y)

	# Detail panel keeps its size; it just moves to sit after the wider list.
	if _weapon_popup_stats_panel != null:
		var detail_width := _weapon_popup_stats_panel.size.x
		var detail_left := list_panel.position.x + panel_width + DYNAMIC_DETAIL_GAP
		_weapon_popup_stats_panel.position = Vector2(detail_left, _weapon_popup_stats_panel.position.y)
		_weapon_popup.size = Vector2(detail_left + detail_width, _weapon_popup.size.y)


func _connect_dynamic_entry_detail_hover(control: Control, entry: Resource) -> void:
	if control == null:
		return
	control.mouse_entered.connect(_show_dynamic_item_stats.bind(entry))
	control.mouse_exited.connect(_hide_dynamic_item_stats.bind(entry))
	control.focus_entered.connect(_show_dynamic_item_stats.bind(entry))
	control.focus_exited.connect(_hide_dynamic_item_stats.bind(entry))


func _get_active_catalog_entries() -> Array[Resource]:
	match _active_dynamic_slot_kind:
		&"player_augment":
			return _get_player_augment_catalog_entries()
		&"ship_augment", &"magnet_augment":
			# No ship/magnet augments are available yet, so present an empty list.
			return []
	return _get_weapon_catalog_entries()


func _get_dynamic_entry_icon_max_width(icon: Texture2D) -> int:
	if icon == null:
		return WEAPON_LIST_ENTRY_ICON_MAX_WIDTH
	var icon_size := icon.get_size()
	if icon_size.x <= 0.0 or icon_size.y <= 0.0:
		return WEAPON_LIST_ENTRY_ICON_MAX_WIDTH
	var width_for_height := int(roundf(WEAPON_LIST_ENTRY_ICON_MAX_HEIGHT * (icon_size.x / icon_size.y)))
	return clampi(width_for_height, 1, WEAPON_LIST_ENTRY_ICON_MAX_WIDTH)


func _configure_dynamic_entry_button(button: Button, entry: Resource, is_locked: bool, _can_unlock: bool) -> void:
	button.text = ""
	button.icon = null
	button.expand_icon = false
	button.clip_text = true
	button.add_theme_constant_override("h_separation", 0)
	button.add_theme_font_size_override("font_size", WEAPON_LIST_ENTRY_FONT_SIZE)

	var row := HBoxContainer.new()
	row.name = "EntryRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10.0
	row.offset_top = 4.0
	row.offset_right = -10.0
	row.offset_bottom = -4.0
	row.add_theme_constant_override("separation", 8)
	button.add_child(row)

	var icon_frame := Control.new()
	icon_frame.name = "IconFrame"
	icon_frame.custom_minimum_size = DYNAMIC_ENTRY_ICON_FRAME_SIZE
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_frame)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _catalog_entry_icon(entry)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = LOCKED_ENTRY_MODULATE if is_locked else UNLOCKED_ENTRY_MODULATE
	icon_frame.add_child(icon)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = _catalog_entry_display_name(entry)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", WEAPON_LIST_ENTRY_FONT_SIZE)
	Magnetide.apply_label_font(name_label)
	if is_locked:
		name_label.add_theme_color_override("font_color", LOCKED_ENTRY_MODULATE)
		name_label.add_theme_color_override("font_hover_color", LOCKED_ENTRY_MODULATE)
		name_label.add_theme_color_override("font_pressed_color", LOCKED_ENTRY_MODULATE)
		name_label.add_theme_color_override("font_focus_color", LOCKED_ENTRY_MODULATE)
	elif _is_catalog_entry_equipped(entry):
		name_label.add_theme_color_override("font_color", EQUIPPED_ENTRY_TEXT_COLOR)
	row.add_child(name_label)

	if is_locked:
		var unlock_button := Button.new()
		unlock_button.name = "UnlockButton"
		unlock_button.custom_minimum_size = Vector2(62.0, 28.0)
		unlock_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		unlock_button.mouse_filter = Control.MOUSE_FILTER_STOP
		unlock_button.text = "Unlock"
		unlock_button.disabled = false
		unlock_button.clip_text = true
		unlock_button.add_theme_font_size_override("font_size", 16)
		_set_button_font_color(unlock_button, Color.WHITE)
		Magnetide.apply_label_font(unlock_button)
		_connect_dynamic_entry_detail_hover(unlock_button, entry)
		unlock_button.pressed.connect(_on_dynamic_entry_unlock_pressed.bind(entry))
		row.add_child(unlock_button)

	var level_label := Label.new()
	level_label.name = "LevelLabel"
	level_label.custom_minimum_size = Vector2(46.0, 0.0)
	level_label.visible = not is_locked
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.text = _get_catalog_entry_level_text(entry)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_color_override("font_color", LOCKED_ENTRY_MODULATE if is_locked else DYNAMIC_ENTRY_LEVEL_COLOR)
	level_label.add_theme_font_size_override("font_size", DYNAMIC_ENTRY_LEVEL_FONT_SIZE)
	Magnetide.apply_label_font(level_label)
	row.add_child(level_label)


func _set_button_font_color(button: Button, color: Color) -> void:
	if button == null:
		return
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_focus_color", color)
	button.add_theme_color_override("font_disabled_color", color)


func _on_dynamic_entry_unlock_pressed(entry: Resource) -> void:
	if _can_unlock_catalog_entry(entry):
		_unlock_catalog_entry(entry)


func _get_weapon_catalog_entries() -> Array[Resource]:
	var entries: Array[Resource] = []
	for entry in weapon_catalog:
		if entry != null and _catalog_entry_equipment(entry) is WeaponData:
			entries.append(entry)

	if _run_loadout != null and _run_loadout.equipped_weapon != null:
		var has_equipped_weapon := false
		for entry in entries:
			if _same_equipment_data(_catalog_entry_equipment(entry), _run_loadout.equipped_weapon):
				has_equipped_weapon = true
				break
		if not has_equipped_weapon:
			var equipped_entry := EquipmentCatalogEntryScript.new()
			equipped_entry.set("equipment_data", _run_loadout.equipped_weapon)
			equipped_entry.set("locked", false)
			entries.insert(0, equipped_entry)

	entries.sort_custom(func(a: Resource, b: Resource) -> bool:
		var order_a := int(a.get("research_unlock_order")) if a != null else 0
		var order_b := int(b.get("research_unlock_order")) if b != null else 0
		return order_a < order_b
	)
	return entries


func _get_player_augment_catalog_entries() -> Array[Resource]:
	var entries: Array[Resource] = []
	for entry in player_augment_catalog:
		var augment := _catalog_entry_item_data(entry) as AugmentData
		if augment == null:
			continue
		entries.append(entry)
		_ensure_catalog_item_state(entry)

	var equipped_augment := _get_player_augment(_active_player_augment_index)
	if equipped_augment != null:
		var has_equipped_augment := false
		for entry in entries:
			if _same_upgradeable_item(_catalog_entry_item_data(entry), equipped_augment):
				has_equipped_augment = true
				break
		if not has_equipped_augment:
			var equipped_entry := SlottableCatalogEntryScript.new()
			equipped_entry.set("item_data", equipped_augment)
			equipped_entry.set("locked", false)
			entries.insert(0, equipped_entry)

	entries.sort_custom(func(a: Resource, b: Resource) -> bool:
		var order_a := int(a.get("research_unlock_order")) if a != null and _has_property(a, "research_unlock_order") else 0
		var order_b := int(b.get("research_unlock_order")) if b != null and _has_property(b, "research_unlock_order") else 0
		return order_a < order_b
	)
	return entries


func _get_catalog_entry_text(entry: Resource) -> String:
	return _catalog_entry_display_name(entry)


func _get_weapon_entry_text(entry: Resource) -> String:
	return _get_catalog_entry_text(entry)


func _catalog_entry_equipment(entry: Resource) -> EquipmentData:
	if entry == null:
		return null
	return entry.get("equipment_data") as EquipmentData


func _catalog_entry_item_data(entry: Resource) -> Resource:
	if entry == null:
		return null
	if _has_property(entry, "item_data"):
		return entry.get("item_data") as Resource
	return _catalog_entry_equipment(entry)


func _catalog_entry_locked(entry: Resource) -> bool:
	if entry == null or not bool(entry.get("locked")):
		_ensure_catalog_item_state(entry)
		return false
	var save_data := _save_data as AppSaveData
	if save_data == null:
		return not _is_catalog_item_state_unlocked(entry)
	var unlock_id := _catalog_entry_unlock_id(entry)
	if save_data.is_research_unlocked(unlock_id):
		if _run_loadout != null:
			_run_loadout.set_item_unlocked(_catalog_entry_item_data(entry), true)
		return false
	return not _is_catalog_item_state_unlocked(entry)


func _can_unlock_catalog_entry(entry: Resource) -> bool:
	if entry == null or not _catalog_entry_locked(entry):
		return false
	var save_data := _save_data as AppSaveData
	if save_data == null:
		return false
	if not _is_next_locked_catalog_entry(entry):
		return false
	var cost := _catalog_entry_research_cost(entry)
	return cost > 0 and save_data.can_spend_research_points(cost)


func _unlock_catalog_entry(entry: Resource) -> void:
	var save_data := _save_data as AppSaveData
	if save_data == null or not _can_unlock_catalog_entry(entry):
		return

	var cost := _catalog_entry_research_cost(entry)
	if not save_data.spend_research_points(cost):
		return

	save_data.unlock_research_id(_catalog_entry_unlock_id(entry))
	if _run_loadout != null:
		_run_loadout.set_item_unlocked(_catalog_entry_item_data(entry), true)
	_save_current_game()
	_refresh_loadout_ui()
	_show_dynamic_item_stats(entry)


func _unlock_weapon_entry(entry: Resource) -> void:
	_unlock_catalog_entry(entry)


func _is_next_locked_catalog_entry(entry: Resource) -> bool:
	var group := _catalog_entry_unlock_group(entry)
	for candidate in _get_active_catalog_entries():
		if _catalog_entry_unlock_group(candidate) != group:
			continue
		if _catalog_entry_locked(candidate):
			return candidate == entry
	return false


func _catalog_entry_unlock_id(entry: Resource) -> StringName:
	if entry != null and entry.has_method("get_research_unlock_id"):
		return entry.call("get_research_unlock_id")
	var item_data := _catalog_entry_item_data(entry)
	if item_data != null and _has_property(item_data, "item_id"):
		return item_data.get("item_id") as StringName
	if entry != null and _catalog_entry_equipment(entry) != null:
		var equipment := _catalog_entry_equipment(entry)
		if not equipment.resource_path.is_empty():
			return StringName(equipment.resource_path)
	return &""


func _catalog_entry_unlock_group(entry: Resource) -> StringName:
	if entry == null:
		return &""
	if not _has_property(entry, "research_unlock_group"):
		return &""
	return entry.get("research_unlock_group") as StringName


func _catalog_entry_research_cost(entry: Resource) -> int:
	if entry == null:
		return 0
	if not _has_property(entry, "research_point_cost"):
		return 0
	return maxi(int(entry.get("research_point_cost")), 0)


func _catalog_entry_display_name(entry: Resource) -> String:
	if entry != null and entry.has_method("get_display_name"):
		return String(entry.call("get_display_name"))
	var item_data := _catalog_entry_item_data(entry)
	if item_data != null and item_data.has_method("get_display_name"):
		return String(item_data.call("get_display_name"))
	var equipment_data := _catalog_entry_equipment(entry)
	return _get_equipment_name(equipment_data)


func _catalog_entry_icon(entry: Resource) -> Texture2D:
	if entry != null and entry.has_method("get_icon"):
		return entry.call("get_icon") as Texture2D
	var item_data := _catalog_entry_item_data(entry)
	if item_data != null:
		return _get_upgradeable_item_icon(item_data, null)
	return _get_equipment_icon(_catalog_entry_equipment(entry))


func _catalog_entry_unlock_cost_text(entry: Resource) -> String:
	var research_cost := _catalog_entry_research_cost(entry)
	if research_cost > 0:
		return _format_research_point_cost_text(research_cost)
	var costs := _catalog_entry_unlock_costs(entry)
	if not costs.is_empty():
		return _format_salvage_costs_text(costs)
	return "No unlock cost"


func _catalog_entry_unlock_costs(entry: Resource) -> Array:
	if entry == null or not _has_property(entry, "unlock_cost"):
		return []
	return entry.get("unlock_cost") as Array


func _get_catalog_entry_level_text(entry: Resource) -> String:
	var progress := _get_catalog_entry_level_progress(entry)
	var max_level := int(progress.get("max_level", 0))
	if max_level <= 0:
		return "Active"
	return "Lv %d/%d" % [
		int(progress.get("level", 0)),
		max_level,
	]


func _get_catalog_entry_detail_level_text(entry: Resource) -> String:
	var progress := _get_catalog_entry_level_progress(entry)
	var max_level := int(progress.get("max_level", 0))
	if max_level <= 0:
		return "LEVEL: ACTIVE"
	return "LEVEL: %d/%d" % [
		int(progress.get("level", 0)),
		max_level,
	]


func _get_catalog_entry_level_progress(entry: Resource) -> Dictionary:
	var item_data := _catalog_entry_item_data(entry)
	if item_data == null:
		return {"level": 0, "max_level": 0}

	if _has_property(item_data, "max_level"):
		return {
			"level": _run_loadout.get_item_level(item_data) if _run_loadout != null else 0,
			"max_level": int(item_data.get("max_level")),
		}

	if item_data is EquipmentData and _run_loadout != null:
		var upgrade_id := &"weapon_damage" if item_data is WeaponData else &"magnet_tool_pull"
		return {
			"level": _run_loadout.get_equipment_item_level(item_data),
			"max_level": _run_loadout.get_upgrade_max_level(upgrade_id),
		}

	return {"level": 0, "max_level": 0}


func _apply_catalog_entry_button_colors(button: Button, entry: Resource, is_locked: bool) -> void:
	if button == null or is_locked or not _is_catalog_entry_equipped(entry):
		return
	button.add_theme_color_override("font_color", EQUIPPED_ENTRY_TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", EQUIPPED_ENTRY_TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", EQUIPPED_ENTRY_TEXT_COLOR)
	button.add_theme_color_override("font_focus_color", EQUIPPED_ENTRY_TEXT_COLOR)


func _same_equipment_data(left: EquipmentData, right: EquipmentData) -> bool:
	if left == null or right == null:
		return false
	if left == right:
		return true
	return not left.resource_path.is_empty() and left.resource_path == right.resource_path


func _same_upgradeable_item(left: Resource, right: Resource) -> bool:
	if left == null or right == null:
		return false
	if left == right:
		return true
	if _has_property(left, "item_id") and _has_property(right, "item_id"):
		return left.get("item_id") == right.get("item_id")
	return false


func _is_catalog_entry_equipped(entry: Resource) -> bool:
	if _run_loadout == null or entry == null:
		return false
	match _active_dynamic_slot_kind:
		&"weapon":
			return _same_equipment_data(_catalog_entry_equipment(entry), _run_loadout.equipped_weapon)
		&"player_augment":
			var item_data := _catalog_entry_item_data(entry)
			for augment in _run_loadout.player_augments:
				if _same_upgradeable_item(augment, item_data):
					return true
		&"ship_augment":
			var ship_item_data := _catalog_entry_item_data(entry)
			for augment in _run_loadout.ship_augments:
				if _same_upgradeable_item(augment, ship_item_data):
					return true
		&"magnet_augment":
			var magnet_item_data := _catalog_entry_item_data(entry)
			for augment in _run_loadout.magnet_augments:
				if _same_upgradeable_item(augment, magnet_item_data):
					return true
	return false


func _ensure_catalog_item_state(entry: Resource) -> void:
	if _run_loadout == null or entry == null:
		return
	var item_data := _catalog_entry_item_data(entry)
	if item_data == null or not _has_property(item_data, "item_id"):
		return
	var state := _run_loadout.get_or_create_item_state(item_data.get("item_id") as StringName)
	if state == null:
		return
	var default_unlocked := not bool(entry.get("locked"))
	var save_data := _save_data as AppSaveData
	if save_data != null and save_data.is_research_unlocked(_catalog_entry_unlock_id(entry)):
		default_unlocked = true
	if default_unlocked and _has_property(state, "unlocked"):
		state.set("unlocked", true)


func _is_catalog_item_state_unlocked(entry: Resource) -> bool:
	if _run_loadout == null:
		return false
	var item_data := _catalog_entry_item_data(entry)
	return _run_loadout.is_item_unlocked(item_data, false)


func _format_catalog_item_stats(entry: Resource) -> String:
	var item_data := _catalog_entry_item_data(entry)
	if item_data == null:
		return ""
	var lines := PackedStringArray()
	var description := _get_catalog_entry_description(item_data)
	if not description.is_empty():
		lines.append(description)

	if item_data is WeaponData:
		var stats := _format_resource_stats(_get_weapon_preview(item_data as WeaponData), WEAPON_STAT_PROPERTIES)
		if not stats.is_empty():
			lines.append(stats)
	elif item_data is AugmentData:
		var state := _get_item_state_for_data(item_data)
		if item_data.has_method("get_current_effect_summary"):
			var summary := String(item_data.call("get_current_effect_summary", state))
			if not summary.is_empty():
				lines.append(summary)

	# Locked items are always level 0, and the "LOCKED" status already conveys
	# that, so omit the redundant level line (it can otherwise overlap the status).
	if not _catalog_entry_locked(entry):
		lines.append("")
		lines.append(_get_catalog_entry_detail_level_text(entry))
	return "\n".join(lines)


func _get_catalog_entry_description(item_data: Resource) -> String:
	if item_data == null:
		return ""
	if _has_property(item_data, "description"):
		return String(item_data.get("description"))
	return ""


func _get_item_state_for_data(item_data: Resource) -> Resource:
	if _run_loadout == null or item_data == null or not _has_property(item_data, "item_id"):
		return null
	return _run_loadout.get_item_state(item_data.get("item_id") as StringName)


func _get_current_dynamic_item() -> Resource:
	if _run_loadout == null:
		return null
	match _active_dynamic_slot_kind:
		&"weapon":
			return _run_loadout.equipped_weapon
		&"player_augment", &"ship_augment", &"magnet_augment":
			return _get_owner_augment(_active_dynamic_slot_kind, _active_player_augment_index)
	return null


func _refresh_current_dynamic_item_stats() -> void:
	if _weapon_popup_current_stats == null:
		return
	var item_data := _get_current_dynamic_item()
	if item_data == null:
		_weapon_popup_current_stats.text = ""
		if _weapon_popup_current_icon != null:
			_weapon_popup_current_icon.icon = null
		return

	if _weapon_popup_current_icon != null:
		if item_data is EquipmentData:
			_weapon_popup_current_icon.icon = _get_equipment_icon(item_data as EquipmentData)
		else:
			_weapon_popup_current_icon.icon = _get_upgradeable_item_icon(item_data, null)

	var body := ""
	if item_data is WeaponData:
		body = _format_weapon_stats(_get_weapon_preview(item_data as WeaponData))
	elif item_data is AugmentData:
		var state := _get_item_state_for_data(item_data)
		if item_data.has_method("get_current_effect_summary"):
			body = String(item_data.call("get_current_effect_summary", state))
	var item_name := _get_upgradeable_item_name(item_data)
	if item_data is EquipmentData:
		item_name = _get_equipment_name(item_data as EquipmentData)
	_weapon_popup_current_stats.text = "%s\n%s" % [item_name, body]


func _refresh_current_weapon_stats() -> void:
	if _active_dynamic_slot_kind != &"weapon":
		_refresh_current_dynamic_item_stats()
		return
	if _weapon_popup_current_stats == null:
		return
	if _run_loadout == null or _run_loadout.equipped_weapon == null:
		_weapon_popup_current_stats.text = ""
		if _weapon_popup_current_icon != null:
			_weapon_popup_current_icon.icon = null
		return

	var weapon := _run_loadout.get_upgraded_weapon_preview()
	if _weapon_popup_current_icon != null:
		_weapon_popup_current_icon.icon = _get_equipment_icon(_run_loadout.equipped_weapon)
	_weapon_popup_current_stats.text = "%s\n%s" % [
		_get_equipment_name(_run_loadout.equipped_weapon),
		_format_weapon_stats(weapon),
	]


func _get_upgrade(upgrade_id: StringName) -> Resource:
	if _run_loadout == null:
		return null
	return _run_loadout.get_upgrade(upgrade_id)


## Context-aware level for an upgrade (equipment upgrades resolve per equipped item).
func _get_upgrade_current_level(upgrade_id: StringName) -> int:
	return _run_loadout.get_upgrade_level(upgrade_id) if _run_loadout != null else 0


func _get_upgrade_current_max_level(upgrade_id: StringName) -> int:
	return _run_loadout.get_upgrade_max_level(upgrade_id) if _run_loadout != null else 0


func _is_upgrade_maxed(upgrade_id: StringName) -> bool:
	return _run_loadout != null and _run_loadout.is_upgrade_maxed(upgrade_id)


func _has_compact_slot(slot_id: StringName) -> bool:
	return _station_slots.has(slot_id) and _station_slots[slot_id] is StationUpgradeSlot


func _refresh_compact_slot(
	slot_id: StringName,
	item_name: String,
	icon: Texture2D,
	upgrade_id: StringName,
	can_select: bool
) -> void:
	var slot := _station_slots.get(slot_id, null) as StationUpgradeSlot
	if slot == null:
		return

	var level := _get_upgrade_current_level(upgrade_id)
	var max_level := _get_upgrade_current_max_level(upgrade_id)
	slot.setup(slot_id, item_name, icon, level, max_level, can_select, _get_upgrade_icon())
	if _is_static_slot_unlockable(slot_id):
		slot.set_unlock_mode(not _is_static_slot_unlocked(slot_id), "Unlock")


func _get_compact_slot_for_row(row: HBoxContainer) -> StationUpgradeSlot:
	if row == null:
		return null
	for child in row.get_children():
		if child is StationUpgradeSlot:
			return child as StationUpgradeSlot
	return null


func _get_upgrade_display_name(upgrade: Resource) -> String:
	if upgrade != null and upgrade.has_method("get_display_name"):
		return String(upgrade.call("get_display_name"))
	return "Upgrade"


func _get_upgrade_button(upgrade_id: StringName) -> Button:
	match upgrade_id:
		&"weapon_damage":
			return _weapon_upgrade_button
		&"magnet_tool_pull":
			return _magnet_upgrade_button
		&"player_health":
			return _health_upgrade_button
		&"player_shield":
			return _shield_upgrade_button
		&"ship_hull":
			return _ship_integrity_upgrade_button
		&"ship_storage_size":
			return _storage_size_upgrade_button
		&"ship_magnet_health":
			return _magnet_integrity_upgrade_button
		&"ship_magnet_capacity":
			return _magnet_capacity_upgrade_button
	return null


func _get_storage_entries() -> Array[Dictionary]:
	if _save_data == null:
		return []
	if not _save_data.has_method("get_storage_entries"):
		return []
	return _save_data.call("get_storage_entries")


func _save_current_game() -> void:
	if _save_data != null and _save_data.has_method("save_to_disk"):
		_save_data.call("save_to_disk")


## Green when the player owns enough of a requirement, red otherwise. Used to
## color-code each part / scrap line in the upgrade cost popup (a RichTextLabel).
const REQUIREMENT_MET_COLOR := "5af03c"
const REQUIREMENT_UNMET_COLOR := "ff5c5c"


func _colorize_requirement(text: String, met: bool) -> String:
	return "[color=#%s]%s[/color]" % [REQUIREMENT_MET_COLOR if met else REQUIREMENT_UNMET_COLOR, text]


func _build_upgrade_requirement_text(upgrade_id: StringName) -> String:
	if _run_loadout == null:
		return "Requires: No cost"

	var level_cost: Resource = _run_loadout.get_upgrade_next_level_cost(upgrade_id)
	if level_cost == null:
		return "Requires: No cost"
	if not _has_property(level_cost, "costs"):
		return "Requires: No cost"

	var lines := PackedStringArray(["Requires"])
	var cost_text := _format_salvage_costs_text(level_cost.get("costs") as Array, true)
	if cost_text.is_empty() or cost_text == "No cost":
		lines.append("No cost")
	else:
		lines.append(cost_text)

	var scrap_section := _build_scrap_cost_section(level_cost, true)
	if not scrap_section.is_empty():
		lines.append("")
		lines.append(scrap_section)
	return "\n".join(lines)


## Separate "Scrap Metal" cost block for the upgrade popup (owned / required).
func _build_scrap_cost_section(level_cost: Resource, colorize: bool = false) -> String:
	if level_cost == null or not _has_property(level_cost, "scrap_cost"):
		return ""
	var scrap_required := int(level_cost.get("scrap_cost"))
	if scrap_required <= 0:
		return ""
	var owned := 0
	var save_data := _save_data as AppSaveData
	if save_data != null:
		owned = save_data.total_scrap_metal
	# Only the amount row is color-coded; the "Scrap Metal" heading stays neutral.
	var amount := "x%d (%d / %d)" % [scrap_required, owned, scrap_required]
	if colorize:
		amount = _colorize_requirement(amount, owned >= scrap_required)
	return "Scrap Metal\n%s" % amount


func _format_research_point_cost_text(required: int) -> String:
	var owned := 0
	var save_data := _save_data as AppSaveData
	if save_data != null:
		owned = save_data.research_points
	return "%d RP (%d / %d)" % [required, owned, required]


func _format_salvage_costs_text(costs: Array, colorize: bool = false) -> String:
	var lines := PackedStringArray()
	for cost in costs:
		var line := _format_salvage_cost_text(cost, colorize)
		if not line.is_empty():
			lines.append(line)
	if lines.is_empty():
		return "No cost"
	return "\n".join(lines)


func _format_salvage_cost_text(cost: Variant, colorize: bool = false) -> String:
	if cost == null:
		return ""
	if not (cost is Resource):
		return str(cost)
	var cost_resource := cost as Resource
	var item_data := cost_resource.get("item_data") as SalvageItemData if _has_property(cost_resource, "item_data") else null
	var quantity := int(cost_resource.get("quantity")) if _has_property(cost_resource, "quantity") else 0
	if item_data == null or quantity <= 0:
		if cost_resource.has_method("get_display_text"):
			return String(cost_resource.call("get_display_text"))
		return str(cost_resource)
	var owned := _get_owned_salvage_quantity(item_data)
	var item_name := item_data.item_name if not item_data.item_name.is_empty() else "Unknown"
	var line := "x%d %s (%d / %d)" % [quantity, item_name, owned, quantity]
	if colorize:
		return _colorize_requirement(line, owned >= quantity)
	return line


func _get_owned_salvage_quantity(item_data: SalvageItemData) -> int:
	if item_data == null:
		return 0
	if _save_data != null and _save_data.has_method("get_storage_quantity"):
		return int(_save_data.call("get_storage_quantity", item_data))
	return 0


func _build_upgrade_gain_text(upgrade_id: StringName) -> String:
	var upgrade := _get_upgrade(upgrade_id)
	if upgrade == null or _run_loadout == null:
		return ""
	# Storage size grows both dimensions from a per-level table, so describe the
	# resulting rectangle rather than a scalar "+N".
	if upgrade_id == &"ship_storage_size":
		return _build_storage_size_gain_text()
	return _run_loadout.get_upgrade_next_gain_text(upgrade_id, _get_upgrade_stat_name(upgrade))


func _build_storage_size_gain_text() -> String:
	if _run_loadout.is_upgrade_maxed(&"ship_storage_size"):
		return "MAX LEVEL"
	var next_level := _run_loadout.get_upgrade_level(&"ship_storage_size") + 1
	var next_size: Vector2 = _run_loadout.get_storage_size_for_level(next_level)
	return "%d×%d Storage" % [int(next_size.x), int(next_size.y)]


func _get_upgrade_stat_name(upgrade: Resource) -> String:
	if upgrade == null:
		return ""
	var target_property := String(upgrade.get("target_property"))
	match target_property:
		"player_max_health":
			return "Health"
		"player_max_shield":
			return "Shield Hit"
		"damage":
			return "Damage"
		"fire_rate":
			return "Fire Rate"
		"pull_max_speed":
			return "Pull Speed"
		"ship_max_health":
			return "Ship Integrity"
		"magnet_hold_capacity":
			return "Magnet Capacity"
		"magnet_max_health":
			return "Magnet Integrity"
	return _prettify_property_name(target_property).capitalize()


func _get_weapon_preview(weapon_data: WeaponData) -> WeaponData:
	if _run_loadout == null:
		return weapon_data
	return _run_loadout.get_upgraded_weapon_preview(weapon_data)


func _get_equipment_icon(equipment_data: EquipmentData) -> Texture2D:
	if equipment_data == null:
		return null
	if equipment_data.hotbar_icon:
		return equipment_data.hotbar_icon
	if equipment_data is WeaponData:
		return (equipment_data as WeaponData).weapon_sprite
	if equipment_data is MagnetToolData:
		return (equipment_data as MagnetToolData).weapon_sprite
	return null


func _get_equipment_name(equipment_data: EquipmentData) -> String:
	if equipment_data != null and not equipment_data.display_name.is_empty():
		return equipment_data.display_name
	return "Unknown Equipment"


func _get_player_augment(index: int) -> AugmentData:
	if _run_loadout == null:
		return null
	if index < 0 or index >= _run_loadout.player_augments.size():
		return null
	return _run_loadout.player_augments[index] as AugmentData


func _get_ship_augment(index: int) -> AugmentData:
	if _run_loadout == null:
		return null
	if index < 0 or index >= _run_loadout.ship_augments.size():
		return null
	return _run_loadout.ship_augments[index] as AugmentData


func _get_magnet_augment(index: int) -> AugmentData:
	if _run_loadout == null:
		return null
	if index < 0 or index >= _run_loadout.magnet_augments.size():
		return null
	return _run_loadout.magnet_augments[index] as AugmentData


func _get_owner_augment(slot_kind: StringName, index: int) -> AugmentData:
	match slot_kind:
		&"player_augment":
			return _get_player_augment(index)
		&"ship_augment":
			return _get_ship_augment(index)
		&"magnet_augment":
			return _get_magnet_augment(index)
	return null


func _get_upgradeable_item_name(item_data: Resource) -> String:
	if item_data == null:
		return "Empty"
	if item_data.has_method("get_display_name"):
		return String(item_data.call("get_display_name"))
	if _has_property(item_data, "display_name"):
		var display_name := String(item_data.get("display_name"))
		if not display_name.is_empty():
			return display_name
	return "Item"


func _get_upgradeable_item_icon(item_data: Resource, fallback: Texture2D = null) -> Texture2D:
	if item_data == null:
		return fallback
	if item_data.has_method("get_icon"):
		var method_icon := item_data.call("get_icon") as Texture2D
		if method_icon != null:
			return method_icon
	if _has_property(item_data, "icon"):
		var property_icon := item_data.get("icon") as Texture2D
		if property_icon != null:
			return property_icon
	return fallback


func _build_player_stats_text() -> String:
	if _run_loadout == null:
		return "No run loadout assigned"

	var lines := PackedStringArray([
		"HEALTH: %s" % _stringify_stat_value(_run_loadout.player_max_health),
		"SHIELD HITS: %s" % _stringify_stat_value(_run_loadout.player_max_shield),
		"EQUIPPED WEAPON: %s" % _get_equipment_name(_run_loadout.equipped_weapon),
		"EQUIPPED TOOL: %s" % _get_equipment_name(_run_loadout.equipped_magnet_tool),
	])
	return "\n".join(lines)


func _build_ship_stats_text() -> String:
	if _run_loadout == null:
		return "No run loadout assigned"

	var lines := PackedStringArray([
		"SHIP",
		"  Integrity: %s" % _stringify_stat_value(_run_loadout.ship_max_health),
		"  Storage Size: %d×%d" % [int(_run_loadout.ship_storage_area_size.x), int(_run_loadout.ship_storage_area_size.y)],
		"",
		"MAGNET",
		"  Integrity: %s" % _stringify_stat_value(_run_loadout.magnet_max_health),
		"  Capacity: %s" % _stringify_stat_value(_run_loadout.magnet_hold_capacity),
	])
	return "\n".join(lines)


func _format_weapon_stats(weapon: WeaponData) -> String:
	# Current-item panel shows stats only. Upgrade cost lives on the upgrade
	# button popup, not here.
	return _format_resource_stats(weapon, WEAPON_STAT_PROPERTIES)


func _format_resource_stats(resource: Resource, property_names: Array[String]) -> String:
	if resource == null:
		return "No stats available"

	var lines := PackedStringArray()
	for property_name in property_names:
		if not _has_property(resource, property_name):
			continue
		lines.append("%s: %s" % [
			_prettify_property_name(property_name),
			_stringify_stat_value(resource.get(property_name)),
		])

	if lines.is_empty():
		return "No stats available"
	return "\n".join(lines)


func _is_exported_stat_property(property: Dictionary) -> bool:
	var usage := int(property.get("usage", 0))
	return (usage & PROPERTY_USAGE_EDITOR) != 0


func _has_property(resource: Resource, property_name: String) -> bool:
	for property in resource.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _prettify_property_name(property_name: String) -> String:
	return property_name.replace("_", " ").to_upper()


func _stringify_stat_value(value: Variant) -> String:
	match typeof(value):
		TYPE_FLOAT:
			return _format_float(float(value))
		TYPE_INT:
			return str(int(value))
		TYPE_BOOL:
			return "YES" if bool(value) else "NO"
		TYPE_VECTOR2:
			var vector_value: Vector2 = value
			return "%s x %s" % [_format_float(vector_value.x), _format_float(vector_value.y)]
		TYPE_STRING, TYPE_STRING_NAME:
			return str(value)
		TYPE_OBJECT:
			return _stringify_object_stat(value)
		TYPE_ARRAY:
			return _stringify_array_stat(value)
	return str(value)


func _stringify_object_stat(value: Variant) -> String:
	if value == null:
		return "NONE"
	if value is Texture2D:
		var texture := value as Texture2D
		return texture.resource_path.get_file() if not texture.resource_path.is_empty() else "Texture"
	if value is EquipmentData:
		return _get_equipment_name(value as EquipmentData)
	if value is SalvageItemData:
		var item := value as SalvageItemData
		return item.item_name if not item.item_name.is_empty() else "Unknown Item"
	if value is Resource:
		var resource := value as Resource
		if resource.has_method("get_display_text"):
			return String(resource.call("get_display_text"))
		if not resource.resource_path.is_empty():
			return resource.resource_path.get_file().get_basename().capitalize()
		return resource.get_class()
	return str(value)


func _stringify_array_stat(value: Variant) -> String:
	var array_value := value as Array
	if array_value.is_empty():
		return "NONE"

	var parts := PackedStringArray()
	for item in array_value:
		parts.append(_stringify_stat_value(item))
	return ", ".join(parts)


func _format_float(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value


func _apply_fonts(node: Node) -> void:
	if node is Label or node is Button:
		var control := node as Control
		Magnetide.apply_label_font(control)
	for child in node.get_children():
		_apply_fonts(child)
