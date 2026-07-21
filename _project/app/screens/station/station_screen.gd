extends Control
class_name StationScreen

signal map_requested
signal main_menu_requested

const StorageSlotScene := preload("res://_project/app/screens/station/station_storage_slot.tscn")
const UpgradeCatalogEntryScript := preload("res://_project/items/upgrade_catalog_entry.gd")

@export var page_pan_duration: float = 0.35
@export var run_loadout: RunLoadout = null

const LOCKED_ENTRY_MODULATE := Color(0.58, 0.62, 0.68, 1.0)
## Icons of locked entries whose unlock dependencies aren't met are rendered as a
## solid-black silhouette (RGB multiplied to zero, alpha shape preserved).
const HIDDEN_ENTRY_ICON_MODULATE := Color(0.0, 0.0, 0.0, 1.0)
## Name shown for a hidden (dependency-not-met) entry in place of its real name.
const HIDDEN_ENTRY_NAME := "???"
const UNLOCKED_ENTRY_MODULATE := Color.WHITE
const EQUIPPED_ENTRY_TEXT_COLOR := Color(0.55, 1.0, 0.55, 1.0)
const WEAPON_LIST_ENTRY_SIZE := Vector2(178.0, 52.0)
const DYNAMIC_ENTRY_ICON_FRAME_SIZE := Vector2(62.0, 44.0)
const WEAPON_LIST_ENTRY_ICON_MAX_WIDTH := 62
const WEAPON_LIST_ENTRY_ICON_MAX_HEIGHT := 30
const WEAPON_LIST_ENTRY_FONT_SIZE := 20
const DYNAMIC_ENTRY_LEVEL_FONT_SIZE := 16
const DYNAMIC_ENTRY_ROW_MARGIN := 10.0        # EntryRow left+right inset (per side)
const DYNAMIC_ENTRY_ROW_SEPARATION := 8.0     # gap between row children
const DYNAMIC_ENTRY_UNLOCK_WIDTH := 44.0      # trailing lock-unlock icon button (locked)
const DYNAMIC_ENTRY_UNLOCK_ICON_SIZE := 44.0  # square lock-unlock icon button
const DYNAMIC_ENTRY_UNLOCK_ICON_INSET := 4.0  # lock texture inset within its button
const DYNAMIC_ENTRY_LEVEL_WIDTH := 46.0       # trailing level label (unlocked)
const DYNAMIC_ENTRY_NAME_SLACK := 8.0         # breathing room so nothing clips
const DYNAMIC_ENTRY_SEPARATION := 8.0         # authored ItemList vertical gap between rows
const DYNAMIC_LIST_PANEL_MARGIN := 14.0       # ItemList inset within its panel (per side)
const DYNAMIC_LIST_VIEWPORT_HEIGHT := 226.0   # authored ItemListScroll height (never changes)
const DYNAMIC_LIST_SCROLLBAR_ALLOWANCE := 16.0 # extra width when a vertical scrollbar shows
const DYNAMIC_PANEL_GAP := 12.0               # gap between adjacent popup panels
const DYNAMIC_LIST_MIN_WIDTH := 232.0         # original ItemList width (never shrink below)
const DYNAMIC_LIST_MAX_WIDTH := 560.0
## Gap between the slot's icon and the left edge of the popup, so the popup opens directly
## to the right of the slot (which stays visible and reads as the current item).
const POPUP_SLOT_MARGIN := 12.0
const DETAIL_PANEL_MIN_WIDTH := 300.0         # original ItemDetailPanel width
const DETAIL_PANEL_MAX_WIDTH := 620.0
const DETAIL_PANEL_H_MARGIN := 18.0           # header/body inset per side
const DETAIL_BODY_TOP_INSET := 66.0           # body column top (below the header)
const DETAIL_BODY_BOTTOM_INSET := 14.0        # body column bottom margin
const DETAIL_HEADER_FONT_SIZE := 28
const DETAIL_EQUIPPED_FONT_SIZE := 20
const DETAIL_EQUIPPED_SEPARATION := 8.0
const DETAIL_EQUIPPED_RIGHT_MARGIN := 12.0     # gap between EQUIPPED and panel edge
const DYNAMIC_ENTRY_LEVEL_COLOR := Color(0.68, 0.72, 0.78, 1.0)

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
## Rarity -> Count-label node path, relative to the authored ResearchPointsDisplay.
const _RESEARCH_COUNT_NODES := {
	SalvageItemData.ItemRarity.COMMON: "Row/Common/Count",
	SalvageItemData.ItemRarity.RARE: "Row/Rare/Count",
	SalvageItemData.ItemRarity.EPIC: "Row/Epic/Count",
}
@onready var _research_points_display: ColorRect = $TopBar/ResearchPointsDisplay
var _station_slots: Dictionary = {}
## slot_id -> RunUpgrade id, built at discovery from each authored slot's upgrade.
var _slot_upgrade_ids: Dictionary = {}
var _active_dynamic_slot_id: StringName = &""
var _active_dynamic_slot_kind: StringName = &""
var _active_dynamic_slot_button: Button = null
var _active_player_augment_index: int = -1
var _active_detail_entry: Resource = null
## Widest entry width measured on the last list population, reused by the panel
## layout pass so it can size the list panel without re-measuring every entry.
var _dynamic_list_content_width: float = DYNAMIC_LIST_MIN_WIDTH

@onready var _page_viewport: Control = $PageViewport
@onready var _page_container: Control = $PageViewport/PageContainer
@onready var _top_bar: Control = $TopBar
@onready var _player_page: Control = $PageViewport/PageContainer/PlayerPage
@onready var _map_button: Button = $TopBar/MapButton
@onready var _menu_button: Button = $TopBar/MenuButton
@onready var _pan_to_ship_button: Button = $PageViewport/PageContainer/PlayerPage/PanToShipButton
@onready var _pan_to_player_button: Button = $PageViewport/PageContainer/ShipPage/PanToPlayerButton
@onready var _player_preview_stage: PreviewStage = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/PlayerPreviewStage
@onready var _ship_preview_stage: PreviewStage = $PageViewport/PageContainer/ShipPage/ShipPreviewStage
@onready var _dynamic_slot_popup: Control = $DynamicSlotPopup
@onready var _dynamic_item_list_title: Label = $DynamicSlotPopup/ItemListPanel/ItemListTitle
@onready var _dynamic_item_list_scroll: ScrollContainer = $DynamicSlotPopup/ItemListPanel/ItemListScroll
@onready var _dynamic_item_list: VBoxContainer = $DynamicSlotPopup/ItemListPanel/ItemListScroll/ItemList
## Primary detail panel (the hovered item). The comparison panel (the equipped item,
## shown only when hovering a different item) mirrors its structure.
@onready var _dynamic_slot_popup_stats_panel: Control = $DynamicSlotPopup/ItemDetailPanel
@onready var _dynamic_slot_popup_compare_panel: Control = $DynamicSlotPopup/ItemDetailPanelCompare
@onready var _upgrade_cost_popup: Control = $PageViewport/PageContainer/PlayerPage/UpgradeCostPopup
@onready var _stats_title_label: Label = $SharedBottomArea/StatsPanel/TitleLabel
@onready var _stats_body_label: Label = $SharedBottomArea/StatsPanel/BodyLabel
@onready var _storage_grid: GridContainer = $SharedBottomArea/StoragePanel/StorageScroll/StorageGrid
@onready var _storage_scrap_count_label: Label = $SharedBottomArea/StoragePanel/ScrapCounter/ScrapCountLabel
@onready var _storage_detail_icon: TextureRect = $SharedBottomArea/StorageDetailPanel/ItemIcon
@onready var _storage_detail_name: Label = $SharedBottomArea/StorageDetailPanel/NameLabel
@onready var _storage_detail_body: Label = $SharedBottomArea/StorageDetailPanel/BodyLabel


func _ready() -> void:
	_is_ready = true
	if _run_loadout == null:
		_run_loadout = run_loadout
	if _run_loadout:
		_run_loadout.prepare_for_run()

	_refresh_research_points_display()
	_ensure_station_header()
	Magnetide.apply_label_fonts(self)
	_dynamic_slot_popup.visible = false
	_dynamic_slot_popup_stats_panel.visible = false
	_dynamic_slot_popup_compare_panel.visible = false
	_upgrade_cost_popup.visible = false
	_clear_storage_detail()
	_dynamic_slot_popup.z_index = 30
	_upgrade_cost_popup.z_index = 5
	_configure_dynamic_popup_mouse_blocking()
	_configure_upgrade_popup_layout()
	_discover_slots()
	_sync_research_unlocks_to_loadout()

	_map_button.pressed.connect(_on_map_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_pan_to_ship_button.pressed.connect(_on_pan_to_ship_pressed)
	_pan_to_player_button.pressed.connect(_on_pan_to_player_pressed)

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
	for slot_id in _station_slots:
		var slot := _station_slots[slot_id] as UpgradeSlot
		if slot == null or not slot.locked:
			continue
		if save_data.is_research_unlocked(_get_static_slot_unlock_research_id(slot_id)):
			_run_loadout.set_slot_unlocked(slot_id, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_layout_pages()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_add_research_points"):
		if not (event is InputEventKey and event.echo):
			_debug_grant_research_points()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _dynamic_slot_popup.visible and not _dynamic_slot_popup.get_global_rect().has_point(event.global_position):
			if _active_dynamic_slot_button == null or not _active_dynamic_slot_button.get_global_rect().has_point(event.global_position):
				_close_dynamic_slot_popup()


## Debug ("P"): grant one research point of every rarity, then refresh the UI so
## the readout and unlock affordability update immediately.
func _debug_grant_research_points() -> void:
	var save_data := _save_data as AppSaveData
	if save_data == null:
		return
	save_data.add_research_points(SalvageItemData.ItemRarity.COMMON, 1)
	save_data.add_research_points(SalvageItemData.ItemRarity.RARE, 1)
	save_data.add_research_points(SalvageItemData.ItemRarity.EPIC, 1)
	_refresh_loadout_ui()


func _layout_pages() -> void:
	if _page_viewport == null or _page_container == null:
		return

	_page_container.position = Vector2(-_get_page_width() * _current_page_index, 0.0)
	if _dynamic_slot_popup != null and _dynamic_slot_popup.visible:
		_position_dynamic_slot_popup()


func _get_page_width() -> float:
	if _player_page != null and _player_page.size.x > 0.0:
		return _player_page.size.x
	return size.x


## Discover every authored UpgradeSlot and index it by its own slot_id. Slots
## self-configure from their exports (@export config, applied in _ready); code only
## builds the lookup maps and caches the buttons the popup/pan wiring still references.
func _discover_slots() -> void:
	for slot in _find_all_upgrade_slots():
		var sid: StringName = slot.slot_id
		if sid == &"":
			continue
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_station_slots[sid] = slot
		var uid: StringName = slot.get_upgrade_id()
		if uid != &"":
			_slot_upgrade_ids[sid] = uid
		if not slot.upgrade_requested.is_connected(_on_slot_upgrade_pressed):
			slot.upgrade_requested.connect(_on_slot_upgrade_pressed)
		if slot is DynamicUpgradeSlot:
			if not slot.selection_requested.is_connected(_on_slot_selected):
				slot.selection_requested.connect(_on_slot_selected)
			var select_button := slot.get_select_button()
			if select_button != null:
				select_button.z_index = 3
		_connect_slot_upgrade(sid)


## Opens the item-selection popup for a dynamic slot, driven entirely by that slot's
## authored kind / index / catalog / title — no per-slot code.
func _on_slot_selected(slot_id: StringName) -> void:
	var slot := _station_slots.get(slot_id, null) as DynamicUpgradeSlot
	if slot == null:
		return
	var title := slot.popup_title if not slot.popup_title.is_empty() else slot.display_name
	_toggle_dynamic_slot_popup(slot_id, slot.get_select_button(), slot.slot_kind, slot.slot_index, title)


func _find_all_upgrade_slots() -> Array[UpgradeSlot]:
	var slots: Array[UpgradeSlot] = []
	_collect_upgrade_slots(self, slots)
	return slots


func _collect_upgrade_slots(node: Node, out: Array[UpgradeSlot]) -> void:
	for child in node.get_children():
		if child is UpgradeSlot:
			out.append(child)
		else:
			_collect_upgrade_slots(child, out)


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
	if _dynamic_slot_popup == null:
		return

	# The popup is a top-level node, so it already wins input over the rest of the
	# screen by tree order. Panels stay STOP so they block click-through and so the
	# detail panel's body can receive scroll input.
	_dynamic_slot_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var blocker := _dynamic_slot_popup.get_node_or_null("MouseBlocker") as Control
	if blocker != null:
		blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	for panel_name in ["ItemListPanel", "ItemDetailPanel", "ItemDetailPanelCompare"]:
		var panel := _dynamic_slot_popup.get_node_or_null(panel_name) as Control
		if panel != null:
			panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _get_compact_slot_select_button(slot_id: StringName) -> Button:
	var slot := _station_slots.get(slot_id, null) as UpgradeSlot
	return slot.get_select_button() if slot != null else null


func _get_compact_slot_upgrade_button(slot_id: StringName) -> Button:
	var slot := _station_slots.get(slot_id, null) as UpgradeSlot
	return slot.get_upgrade_button() if slot != null else null


## Wire one dynamic slot's upgrade button. All slots use this same path; the
## generic handlers below dispatch to the appropriate upgrade mechanism.
func _connect_slot_upgrade(slot_id: StringName) -> void:
	var button := _get_compact_slot_upgrade_button(slot_id)
	if button == null:
		return
	button.mouse_entered.connect(_show_slot_cost_popup.bind(button, slot_id))
	button.mouse_exited.connect(_hide_upgrade_cost_popup)
	button.focus_entered.connect(_show_slot_cost_popup.bind(button, slot_id))
	button.focus_exited.connect(_hide_upgrade_cost_popup)


func _on_slot_upgrade_pressed(slot_id: StringName) -> void:
	if _slot_upgrade_ids.has(slot_id):
		_on_upgrade_pressed(_slot_upgrade_ids[slot_id])
		return
	var item := _slot_item(slot_id)
	if item is AugmentData:
		_on_augment_upgrade_pressed(slot_id)
	elif item != null and item.upgrade_data != null:
		_on_upgrade_pressed(item.item_id)


func _show_slot_cost_popup(button: Button, slot_id: StringName) -> void:
	if _slot_upgrade_ids.has(slot_id):
		_show_upgrade_cost_popup(button, _slot_upgrade_ids[slot_id])
		return
	var item := _slot_item(slot_id)
	if item is AugmentData:
		_show_augment_cost_popup(button, slot_id)
	elif item != null and item.upgrade_data != null:
		_show_upgrade_cost_popup(button, item.item_id)


## The item a slot currently upgrades: a static slot's fixed item, or a dynamic slot's equipped
## catalog item.
func _slot_item(slot_id: StringName) -> ItemData:
	var slot: UpgradeSlot = _station_slots.get(slot_id, null)
	if slot is StaticUpgradeSlot:
		return (slot as StaticUpgradeSlot).item
	if slot is DynamicUpgradeSlot:
		return _get_equipped_item_for_slot(slot) as ItemData
	return null


func _show_upgrade_cost_popup(button: Button, upgrade_id: StringName) -> void:
	if _dynamic_slot_popup != null and _dynamic_slot_popup.visible:
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


func _get_unlockable_static_slot_id_for_upgrade(upgrade_id: StringName) -> StringName:
	for sid in _station_slots:
		var slot := _station_slots[sid] as UpgradeSlot
		if slot != null and slot.locked and _slot_upgrade_ids.get(sid, &"") == upgrade_id:
			return sid
	return &""


func _is_static_slot_unlockable(slot_id: StringName) -> bool:
	var slot := _station_slots.get(slot_id, null) as UpgradeSlot
	return slot != null and slot.locked


func _is_static_slot_unlocked(slot_id: StringName) -> bool:
	if not _is_static_slot_unlockable(slot_id):
		return true
	if _run_loadout != null and _run_loadout.is_slot_unlocked(slot_id, false):
		return true
	var save_data := _save_data as AppSaveData
	return save_data != null and save_data.is_research_unlocked(_get_static_slot_unlock_research_id(slot_id))


func _get_static_slot_unlock_research_id(slot_id: StringName) -> StringName:
	var slot := _station_slots.get(slot_id, null) as UpgradeSlot
	return slot.unlock_research_id if slot != null else &""


func _get_static_slot_unlock_research_cost(slot_id: StringName) -> Dictionary:
	var slot := _station_slots.get(slot_id, null) as UpgradeSlot
	return slot.get_unlock_cost() if slot != null else {}


func _get_static_slot_unlock_title(slot_id: StringName) -> String:
	var slot := _station_slots.get(slot_id, null) as UpgradeSlot
	return "Unlock %s" % slot.display_name if slot != null else "Unlock Slot"


func _get_static_slot_display_name(slot_id: StringName) -> String:
	var slot := _station_slots.get(slot_id, null) as UpgradeSlot
	return slot.display_name if slot != null else "Static Slot"


func _get_static_slot_description(slot_id: StringName) -> String:
	var slot := _station_slots.get(slot_id, null) as UpgradeSlot
	return slot.unlock_description if slot != null else ""


func _get_static_slot_unlock_gain_text(slot_id: StringName) -> String:
	var slot := _station_slots.get(slot_id, null) as UpgradeSlot
	return slot.unlock_gain_text if slot != null else ""


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
	var cost := _get_static_slot_unlock_research_cost(slot_id)
	return "Unlock Cost\n%s" % _format_research_cost_text(cost, true)


func _unlock_static_slot(slot_id: StringName) -> void:
	if not _is_static_slot_unlockable(slot_id):
		return
	var cost := _get_static_slot_unlock_research_cost(slot_id)
	var research_id := _get_static_slot_unlock_research_id(slot_id)
	var save_data := _save_data as AppSaveData
	if save_data != null:
		if not save_data.spend_research_cost(cost):
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
	return _slot_upgrade_ids.get(slot_id, &"")


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
	_close_dynamic_slot_popup()
	_hide_upgrade_cost_popup()
	_clear_storage_detail()
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
	header.position = Vector2(208.0, 24.0)
	header.custom_minimum_size = Vector2(0.0, 60.0)
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(header)


func _refresh_research_points_display() -> void:
	if _research_points_display == null:
		return
	var save_data := _save_data as AppSaveData
	for rarity in _RESEARCH_COUNT_NODES:
		var label := _research_points_display.get_node(_RESEARCH_COUNT_NODES[rarity]) as Label
		label.text = str(save_data.get_research_points(rarity)) if save_data != null else "0"


func _toggle_dynamic_slot_popup(
	slot_id: StringName,
	button: Button,
	slot_kind: StringName,
	augment_index: int,
	list_title: String
) -> void:
	if button == null:
		return

	var should_show := not _dynamic_slot_popup.visible or _active_dynamic_slot_id != slot_id
	_active_dynamic_slot_id = slot_id
	_active_dynamic_slot_kind = slot_kind
	_active_dynamic_slot_button = button
	_active_player_augment_index = augment_index
	_dynamic_slot_popup.visible = should_show
	_dynamic_slot_popup_stats_panel.visible = false
	_dynamic_slot_popup_compare_panel.visible = false
	_active_detail_entry = null
	if _dynamic_item_list_title != null:
		_dynamic_item_list_title.text = list_title
	if should_show:
		_hide_upgrade_cost_popup()
		_clear_storage_detail()
		_position_dynamic_slot_popup()
		_populate_dynamic_item_list()
		# Always open scrolled to the top, regardless of where the list was left last time.
		# The deferred set re-applies it once the container has sorted its freshly-added rows.
		if _dynamic_item_list_scroll != null:
			_dynamic_item_list_scroll.scroll_vertical = 0
			_dynamic_item_list_scroll.set_deferred("scroll_vertical", 0)
		# Re-run the layout once the list container has sorted its freshly-added rows,
		# so the panels are aligned on the first show rather than only after a re-open.
		call_deferred("_layout_dynamic_popup_panels")


func _close_dynamic_slot_popup() -> void:
	_dynamic_slot_popup.visible = false
	_dynamic_slot_popup_stats_panel.visible = false
	_dynamic_slot_popup_compare_panel.visible = false
	_active_dynamic_slot_id = &""
	_active_dynamic_slot_kind = &""
	_active_dynamic_slot_button = null
	_active_player_augment_index = -1
	_active_detail_entry = null


func _position_dynamic_slot_popup() -> void:
	if _dynamic_slot_popup == null or _active_dynamic_slot_button == null:
		return

	# The popup is a top-level child (so it renders on top of everything and wins input).
	# Open it directly to the right of the slot's icon — the slot stays visible to the left
	# and reads as the current item — aligned to the icon's top.
	var button_rect := _active_dynamic_slot_button.get_global_rect()
	_dynamic_slot_popup.global_position = Vector2(button_rect.end.x + POPUP_SLOT_MARGIN, button_rect.position.y)


func _show_dynamic_item_stats(entry: Resource) -> void:
	var item_data := _catalog_entry_item_data(entry)
	if entry == null or item_data == null:
		return

	_active_detail_entry = entry
	_render_detail_panel(_dynamic_slot_popup_stats_panel, entry)
	_dynamic_slot_popup_stats_panel.visible = true

	# QoL comparison: when hovering an item that isn't the one equipped in THIS slot, show
	# the slot's equipped item in a second panel to its right for a side-by-side read. A
	# hidden (masked) entry, or hovering this slot's own equipped item, shows no comparison.
	var compare_entry := _get_equipped_catalog_entry()
	var show_compare := compare_entry != null \
		and not _is_catalog_entry_hidden(entry) \
		and not _is_catalog_entry_equipped_in_active_slot(entry)
	if show_compare:
		_render_detail_panel(_dynamic_slot_popup_compare_panel, compare_entry)
	_dynamic_slot_popup_compare_panel.visible = show_compare

	_layout_detail_panels()
	# Re-fit deferred so the body columns re-apply their margins once the rich-text rows
	# have sorted to the new width — otherwise the first hover shows wrong body margins.
	call_deferred("_refit_detail_panels", entry)


## The catalog entry for the item equipped in the CURRENTLY-OPEN slot (not one merely
## equipped in another slot of the same kind), or null if this slot is empty. Feeds the
## comparison panel.
func _get_equipped_catalog_entry() -> Resource:
	var equipped_item := _active_slot_equipped_item()
	if equipped_item == null:
		return null
	for entry in _get_active_catalog_entries():
		if _catalog_entry_matches_item(entry, equipped_item):
			return entry
	return null


## The item equipped in the currently-open dynamic slot (by kind + this slot's index), or
## null if the slot is empty.
func _active_slot_equipped_item() -> Resource:
	var slot := _station_slots.get(_active_dynamic_slot_id, null) as DynamicUpgradeSlot
	if slot == null:
		return null
	return _get_equipped_item_for_slot(slot)


## True when `entry`'s item is the one equipped in the currently-open slot specifically —
## unlike _is_catalog_entry_equipped, which matches equipment in any slot of the kind.
func _is_catalog_entry_equipped_in_active_slot(entry: Resource) -> bool:
	return _catalog_entry_matches_item(entry, _active_slot_equipped_item())


func _catalog_entry_matches_item(entry: Resource, item: Resource) -> bool:
	if item == null:
		return false
	var item_data := _catalog_entry_item_data(entry)
	if item_data == null:
		return false
	if item_data is HeldItemData and item is HeldItemData:
		return _same_equipment_data(item_data as HeldItemData, item as HeldItemData)
	return ItemData.is_same_item(item_data as ItemData, item as ItemData)


## Populate one detail panel's labels for `entry` (masking a still-hidden entry) and size
## it to fit. Works for either the primary (hovered) or comparison (equipped) panel.
func _render_detail_panel(panel: Control, entry: Resource) -> void:
	if panel == null or entry == null:
		return
	var name_label := panel.get_node_or_null("HeaderRow/NameLabel") as Label
	var equipped_label := panel.get_node_or_null("HeaderRow/EquippedLabel") as Label
	var desc_label := panel.get_node_or_null("BodyColumn/DescriptionLabel") as RichTextLabel
	var status_label := panel.get_node_or_null("BodyColumn/StatusLabel") as RichTextLabel
	# A hidden entry keeps its identity masked: no name, stats, or description are
	# revealed until its unlock dependency is met.
	if _is_catalog_entry_hidden(entry):
		if name_label != null:
			name_label.text = HIDDEN_ENTRY_NAME
		if equipped_label != null:
			equipped_label.visible = false
		if desc_label != null:
			desc_label.text = "Locked. Unlock the previous weapon to reveal this one."
		if status_label != null:
			status_label.text = "[color=#%s]LOCKED[/color]\n%s" % [
				DYNAMIC_ENTRY_LEVEL_COLOR.to_html(false),
				_colorize_requirement("Requires the previous weapon", false),
			]
	else:
		if name_label != null:
			name_label.text = _catalog_entry_display_name(entry)
		# EQUIPPED lives in the header (right of the name) so it's always visible and
		# never pushed off-screen by a long description.
		if equipped_label != null:
			equipped_label.visible = _is_catalog_entry_equipped(entry)
		# Description (scrolls / expands vertically) and a pinned status row below it.
		if desc_label != null:
			desc_label.text = _format_catalog_item_description(entry)
		if status_label != null:
			status_label.text = _build_catalog_status_row(entry)
	_size_detail_panel(panel, entry)


## Re-fit the currently-shown detail panels. Called deferred after a hover so the body
## columns re-apply their margins once the rich-text rows have sorted to the new width.
func _refit_detail_panels(entry: Resource) -> void:
	if entry != _active_detail_entry:
		return
	if _dynamic_slot_popup == null or not _dynamic_slot_popup.visible:
		return
	if _dynamic_slot_popup_stats_panel == null or not _dynamic_slot_popup_stats_panel.visible:
		return
	_size_detail_panel(_dynamic_slot_popup_stats_panel, entry)
	if _dynamic_slot_popup_compare_panel != null and _dynamic_slot_popup_compare_panel.visible:
		var compare_entry := _get_equipped_catalog_entry()
		if compare_entry != null:
			_size_detail_panel(_dynamic_slot_popup_compare_panel, compare_entry)
	_layout_detail_panels()


## Size one detail panel so the item name (plus the EQUIPPED badge) fits at full width
## without ellipsis; the description wraps to that width. Height is never touched. The
## popup width is finalized separately in _layout_detail_panels.
func _size_detail_panel(panel: Control, entry: Resource) -> void:
	if panel == null:
		return
	var equipped := _is_catalog_entry_equipped(entry)
	var font := Magnetide.label_font
	var content_width := 0.0
	if font != null:
		content_width = font.get_string_size(
			_catalog_entry_visible_name(entry), HORIZONTAL_ALIGNMENT_LEFT, -1.0, DETAIL_HEADER_FONT_SIZE
		).x
		if equipped:
			content_width += DETAIL_EQUIPPED_SEPARATION + DETAIL_EQUIPPED_RIGHT_MARGIN + font.get_string_size(
				"EQUIPPED", HORIZONTAL_ALIGNMENT_LEFT, -1.0, DETAIL_EQUIPPED_FONT_SIZE
			).x

	var detail_width := clampf(
		content_width + DETAIL_PANEL_H_MARGIN * 2.0, DETAIL_PANEL_MIN_WIDTH, DETAIL_PANEL_MAX_WIDTH
	)
	panel.size = Vector2(detail_width, panel.size.y)

	var inner_width := detail_width - DETAIL_PANEL_H_MARGIN * 2.0
	var header := panel.get_node_or_null("HeaderRow") as Control
	if header != null:
		# Pull the header (and thus the right-aligned EQUIPPED badge) in a little so
		# it isn't flush against the panel edge.
		var header_width := inner_width - (DETAIL_EQUIPPED_RIGHT_MARGIN if equipped else 0.0)
		header.size = Vector2(header_width, header.size.y)
	var body := panel.get_node_or_null("BodyColumn") as Control
	if body != null:
		# Fixed height (never read back its own grown size) so the VBox stays bounded:
		# the description fills panel_height - status_height and scrolls past that.
		var body_height := panel.size.y - DETAIL_BODY_TOP_INSET - DETAIL_BODY_BOTTOM_INSET
		body.size = Vector2(inner_width, body_height)


## Bottom status row of the detail panel: for a locked item, LOCKED + the RP
## unlock requirement (colored by affordability); otherwise the LEVEL: x/X line.
## EQUIPPED is shown separately in the header.
func _build_catalog_status_row(entry: Resource) -> String:
	if _catalog_entry_locked(entry):
		# "LOCKED" stays neutral; the unlock requirement is colored green/red.
		return "[color=#%s]LOCKED[/color]\n%s" % [
			DYNAMIC_ENTRY_LEVEL_COLOR.to_html(false),
			_build_unlock_requirement_bbcode(entry),
		]
	return "[color=#%s]%s[/color]" % [
		DYNAMIC_ENTRY_LEVEL_COLOR.to_html(false),
		_get_catalog_entry_detail_level_text(entry),
	]


## "UNLOCK:" followed by one requirement row per required rarity, each colored
## green (that rarity's balance covers it) or red (it doesn't).
func _build_unlock_requirement_bbcode(entry: Resource) -> String:
	var research_cost := _catalog_entry_research_cost(entry)
	if not research_cost.is_empty():
		return "UNLOCK:\n" + _format_research_cost_text(research_cost, true)
	var costs := _catalog_entry_unlock_costs(entry)
	if not costs.is_empty():
		return "UNLOCK: " + _format_salvage_costs_text(costs, true)
	return "UNLOCK: No unlock cost"


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
	_close_dynamic_slot_popup()


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
		slot.item_unhovered.connect(_clear_storage_detail)


func _show_storage_detail(_slot: StationStorageSlot, item_data: SalvageItemData, quantity: int) -> void:
	if item_data == null:
		_clear_storage_detail()
		return

	_storage_detail_icon.texture = item_data.sprite
	_storage_detail_name.text = item_data.item_name if not item_data.item_name.is_empty() else "Unknown Item"
	_storage_detail_body.text = _build_storage_detail_text(item_data, quantity)


## Blanks the always-visible detail panel; no item hovered means empty icon and text.
func _clear_storage_detail(_slot: StationStorageSlot = null) -> void:
	_storage_detail_icon.texture = null
	_storage_detail_name.text = ""
	_storage_detail_body.text = ""


func _build_storage_detail_text(item_data: SalvageItemData, quantity: int) -> String:
	return "QUANTITY: %d\n%s\n\nRecovered station material." % [
		quantity,
		_format_resource_stats(item_data, STORAGE_STAT_PROPERTIES),
	]


func _refresh_loadout_ui() -> void:
	if _run_loadout:
		_run_loadout.prepare_for_run()
	_refresh_all_slots()
	_update_previews()
	if _dynamic_slot_popup != null and _dynamic_slot_popup.visible:
		_populate_dynamic_item_list()
	_populate_storage_slots(_get_storage_entries())
	_refresh_stats_panel()
	_refresh_storage_scrap_counter()
	_refresh_research_points_display()


## Reactive pass: every slot updates from live state via its own authored config.
## Static slots pull their level from the loadout (keyed by their upgrade id) and their
## unlock state; dynamic slots reflect the currently-equipped item (name/icon/level).
func _refresh_all_slots() -> void:
	for sid in _station_slots:
		var slot := _station_slots[sid] as UpgradeSlot
		if slot == null:
			continue
		if slot is DynamicUpgradeSlot:
			_refresh_dynamic_slot(sid, slot)
		else:
			_refresh_static_slot(sid, slot)


func _refresh_static_slot(sid: StringName, slot: UpgradeSlot) -> void:
	if slot.locked:
		var unlocked := _is_static_slot_unlocked(sid)
		slot.set_unlock_mode(not unlocked)
		if not unlocked:
			return
	var uid: StringName = _slot_upgrade_ids.get(sid, &"")
	if uid != &"":
		slot.set_level(_get_upgrade_current_level(uid), _get_upgrade_current_max_level(uid))


func _refresh_dynamic_slot(_sid: StringName, slot: DynamicUpgradeSlot) -> void:
	var item := _get_equipped_item_for_slot(slot)
	if item == null:
		slot.set_current_name(slot.display_name)
		slot.set_current_icon(slot.static_icon)
		slot.set_level_text("None")
		return
	slot.set_current_name(_get_dynamic_item_name(item))
	slot.set_current_icon(_get_dynamic_item_icon(item, slot.static_icon))
	var idata := item as ItemData
	if idata != null and idata.upgrade_data != null and _run_loadout != null:
		slot.set_level(_run_loadout.get_upgrade_level(idata.item_id), idata.get_max_level())
	else:
		slot.set_level(0, 0)


## The item currently equipped in a dynamic slot, dispatched on its authored kind.
func _get_equipped_item_for_slot(slot: DynamicUpgradeSlot) -> Resource:
	if _run_loadout == null:
		return null
	match slot.slot_kind:
		&"weapon":
			return _run_loadout.equipped_weapon
		&"player_augment":
			return _get_player_augment(slot.slot_index)
		&"ship_augment":
			return _get_ship_augment(slot.slot_index)
		&"magnet_augment":
			return _get_magnet_augment(slot.slot_index)
	return null


func _get_dynamic_item_name(item: Resource) -> String:
	if item is HeldItemData:
		return _get_equipment_name(item)
	return _get_upgradeable_item_name(item)


func _get_dynamic_item_icon(item: Resource, fallback: Texture2D) -> Texture2D:
	if item is HeldItemData:
		return _get_equipment_icon(item)
	return _get_upgradeable_item_icon(item, fallback)


func _update_previews() -> void:
	if _run_loadout == null:
		return
	if _player_preview_stage != null:
		_player_preview_stage.set_loadout(_run_loadout)
	if _ship_preview_stage != null:
		_ship_preview_stage.set_loadout(_run_loadout)


func _on_upgrade_pressed(upgrade_id: StringName) -> void:
	if _dynamic_slot_popup != null and _dynamic_slot_popup.visible:
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


# ---------------------------------------------------------------------------
# Augment level upgrades (per-item level, spent from the same cost popup UI).
# ---------------------------------------------------------------------------

func _get_augment_for_slot(slot_id: StringName) -> AugmentData:
	var slot := _station_slots.get(slot_id, null) as DynamicUpgradeSlot
	if slot == null:
		return null
	return _get_equipped_item_for_slot(slot) as AugmentData


func _on_augment_upgrade_pressed(slot_id: StringName) -> void:
	if _dynamic_slot_popup != null and _dynamic_slot_popup.visible:
		return
	if _run_loadout == null:
		return
	var augment := _get_augment_for_slot(slot_id)
	if augment == null:
		return
	var cost: Resource = _run_loadout.get_augment_next_level_cost(augment)
	if cost == null:
		return
	if _save_data != null and not bool(_save_data.call("spend_level_cost", cost)):
		return
	_run_loadout.increase_augment_level(augment)
	_save_current_game()
	_refresh_loadout_ui()
	if _upgrade_cost_popup.visible:
		var button := _get_compact_slot_upgrade_button(slot_id)
		if button:
			_show_augment_cost_popup(button, slot_id)


func _show_augment_cost_popup(button: Button, slot_id: StringName) -> void:
	if _dynamic_slot_popup != null and _dynamic_slot_popup.visible:
		return
	var augment := _get_augment_for_slot(slot_id)
	if augment == null:
		return
	var title := _upgrade_cost_popup.get_node_or_null("TitleLabel") as Label
	var credits := _upgrade_cost_popup.get_node_or_null("CreditsLabel") as Label
	var secondary := _upgrade_cost_popup.get_node_or_null("SecondaryLabel") as RichTextLabel
	var level := _run_loadout.get_item_level(augment)
	var max_lvl := augment.get_max_level()
	if level >= max_lvl:
		if title: title.text = "MAX LEVEL"
		if credits: credits.text = ""
		if secondary: secondary.text = ""
	else:
		if title: title.text = "Lv %d -> %d" % [level, level + 1]
		if credits: credits.text = _build_augment_gain_text(augment)
		if secondary: secondary.text = _build_augment_requirement_text(augment)
	var button_rect := button.get_global_rect()
	var page_rect := _player_page.get_global_rect()
	_resize_upgrade_cost_popup()
	_upgrade_cost_popup.position = (button_rect.position - page_rect.position) + UPGRADE_POPUP_OFFSET
	_upgrade_cost_popup.visible = true


func _build_augment_gain_text(augment: AugmentData) -> String:
	if augment == null:
		return ""
	var state := _get_item_state_for_data(augment)
	if augment.has_method("get_next_level_gain_summary"):
		return String(augment.call("get_next_level_gain_summary", state))
	return ""


func _build_augment_requirement_text(augment: AugmentData) -> String:
	if augment == null or _run_loadout == null:
		return "Requires: No cost"
	var cost: Resource = _run_loadout.get_augment_next_level_cost(augment)
	if cost == null:
		return "Requires: No cost"
	var lines := PackedStringArray(["Requires"])
	if Utils.has_property(cost, "costs"):
		var salvage := _format_salvage_costs_text(cost.get("costs") as Array, true)
		if not (salvage.is_empty() or salvage == "No cost"):
			lines.append(salvage)
	var scrap := _build_scrap_cost_section(cost, true)
	if not scrap.is_empty():
		if lines.size() > 1:
			lines.append("")
		lines.append(scrap)
	if lines.size() == 1:
		lines.append("No cost")
	return "\n".join(lines)


func _populate_dynamic_item_list() -> void:
	if _dynamic_item_list == null:
		return

	for child in _dynamic_item_list.get_children():
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
		var is_hidden := _is_catalog_entry_hidden(entry)
		button.modulate = UNLOCKED_ENTRY_MODULATE
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		Magnetide.apply_label_font(button)
		_configure_dynamic_entry_button(button, entry, is_locked, is_hidden)
		_dynamic_item_list.add_child(button)
		_connect_dynamic_entry_detail_hover(button, entry)
		if not is_locked:
			button.pressed.connect(_equip_dynamic_item_from_popup.bind(entry))
		max_needed_width = maxf(max_needed_width, _measure_dynamic_entry_width(entry, font))

	_dynamic_list_content_width = max_needed_width
	_layout_dynamic_popup_panels()


## Width an entry button needs to show its full name alongside the fixed icon and
## trailing level/unlock element (see _configure_dynamic_entry_button layout).
func _measure_dynamic_entry_width(entry: Resource, font: Font) -> float:
	if font == null:
		return 0.0
	var name_width := font.get_string_size(
		_catalog_entry_visible_name(entry),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		WEAPON_LIST_ENTRY_FONT_SIZE
	).x
	# Locked entries (masked or not) carry the trailing Unlock button; unlocked ones
	# carry the level readout.
	var trailing := DYNAMIC_ENTRY_LEVEL_WIDTH if not _catalog_entry_locked(entry) else DYNAMIC_ENTRY_UNLOCK_WIDTH
	return DYNAMIC_ENTRY_ROW_MARGIN * 2.0 \
		+ DYNAMIC_ENTRY_ICON_FRAME_SIZE.x \
		+ DYNAMIC_ENTRY_ROW_SEPARATION * 2.0 \
		+ name_width \
		+ trailing \
		+ DYNAMIC_ENTRY_NAME_SLACK


## Lay the popup panels out left-to-right, each sized horizontally to its own content and
## never in height. Widths come from font metrics (not from container layout that only
## settles a frame later), so the arrangement is correct on the very first show — no need
## to re-open the popup for it to align. The region over the slot is left transparent so
## the slot itself reads as the current item.
##   • Item-list panel: fits the widest entry (measured at population) and the title.
##   • Detail panel: anchored right of the list at its minimum width; it grows per hovered
##     item in _size_detail_panel, and _layout_detail_panels adds the comparison panel and
##     keeps the popup width in sync.
func _layout_dynamic_popup_panels() -> void:
	if _dynamic_slot_popup == null or not _dynamic_slot_popup.visible:
		return
	var list_panel := _dynamic_slot_popup.get_node_or_null("ItemListPanel") as Control
	if list_panel == null or _dynamic_item_list == null:
		return

	var content_width := _dynamic_list_content_width
	if _dynamic_item_list_title != null:
		content_width = maxf(content_width, _get_label_natural_text_width(_dynamic_item_list_title))
	var list_width := clampf(content_width, DYNAMIC_LIST_MIN_WIDTH, DYNAMIC_LIST_MAX_WIDTH)
	# Reserve room for a vertical scrollbar only when the rows actually overflow the
	# fixed viewport, so the list panel keeps sizing to its content.
	var entry_count := _dynamic_item_list.get_child_count()
	var content_height := 0.0
	if entry_count > 0:
		content_height = entry_count * WEAPON_LIST_ENTRY_SIZE.y + (entry_count - 1) * DYNAMIC_ENTRY_SEPARATION
	var scroll_width := list_width
	if content_height > DYNAMIC_LIST_VIEWPORT_HEIGHT:
		scroll_width += DYNAMIC_LIST_SCROLLBAR_ALLOWANCE
	var list_panel_width := scroll_width + DYNAMIC_LIST_PANEL_MARGIN * 2.0
	# The list is the leftmost content; the popup itself is positioned just to the right of
	# the slot (see _position_dynamic_slot_popup), so the list starts flush at its left.
	var list_left := 0.0

	list_panel.position = Vector2(list_left, list_panel.position.y)
	list_panel.size = Vector2(list_panel_width, list_panel.size.y)
	if _dynamic_item_list_scroll != null:
		_dynamic_item_list_scroll.size = Vector2(scroll_width, DYNAMIC_LIST_VIEWPORT_HEIGHT)
	if _dynamic_item_list_title != null:
		_dynamic_item_list_title.size = Vector2(scroll_width, _dynamic_item_list_title.size.y)
	# Rows keep the measured content width; with a scrollbar the viewport gives them
	# exactly that (scroll_width - scrollbar), so text never slips under the scrollbar.
	for child in _dynamic_item_list.get_children():
		if child is Control:
			var entry_control := child as Control
			entry_control.custom_minimum_size = Vector2(list_width, entry_control.custom_minimum_size.y)

	# Anchor the primary detail panel to the right of the list. It keeps its current
	# (possibly hover-grown) width while showing so a refresh doesn't collapse it; the
	# comparison panel and final popup width are finalized in _layout_detail_panels.
	if _dynamic_slot_popup_stats_panel != null:
		var detail_left := list_left + list_panel_width + DYNAMIC_PANEL_GAP
		if not _dynamic_slot_popup_stats_panel.visible:
			_dynamic_slot_popup_stats_panel.size = Vector2(
				DETAIL_PANEL_MIN_WIDTH, _dynamic_slot_popup_stats_panel.size.y
			)
		_dynamic_slot_popup_stats_panel.position = Vector2(detail_left, _dynamic_slot_popup_stats_panel.position.y)
	_layout_detail_panels()


## Position the comparison panel to the right of the primary detail panel (only when it's
## shown) and grow the popup to enclose whichever panels are visible. The primary panel's
## left edge is set by _layout_dynamic_popup_panels; this only reads it.
func _layout_detail_panels() -> void:
	var primary := _dynamic_slot_popup_stats_panel
	if primary == null:
		return
	var right_edge := primary.position.x + primary.size.x
	var compare := _dynamic_slot_popup_compare_panel
	if compare != null and compare.visible:
		compare.position = Vector2(right_edge + DYNAMIC_PANEL_GAP, primary.position.y)
		right_edge = compare.position.x + compare.size.x
	if _dynamic_slot_popup != null:
		_dynamic_slot_popup.size = Vector2(right_edge, _dynamic_slot_popup.size.y)


func _connect_dynamic_entry_detail_hover(control: Control, entry: Resource) -> void:
	if control == null:
		return
	# Only show/update on hover; the detail stays visible (updating as other
	# entries are hovered) so the player can move onto it to scroll long text.
	# It's cleared when the popup closes / a different slot is opened.
	control.mouse_entered.connect(_show_dynamic_item_stats.bind(entry))
	control.focus_entered.connect(_show_dynamic_item_stats.bind(entry))


## The authored catalog (item list) of the dynamic slot whose popup is currently open.
func _active_slot_catalog() -> Array[UpgradeCatalogEntry]:
	var slot := _station_slots.get(_active_dynamic_slot_id, null) as DynamicUpgradeSlot
	if slot == null:
		return []
	return slot.catalog


func _get_active_catalog_entries() -> Array[Resource]:
	match _active_dynamic_slot_kind:
		&"player_augment":
			return _get_player_augment_catalog_entries()
		&"ship_augment", &"magnet_augment":
			# There is no ship/magnet augment catalog to list.
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


func _configure_dynamic_entry_button(button: Button, entry: Resource, is_locked: bool, is_hidden: bool) -> void:
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
	if is_hidden:
		icon.modulate = HIDDEN_ENTRY_ICON_MODULATE
	else:
		icon.modulate = UNLOCKED_ENTRY_MODULATE
	icon_frame.add_child(icon)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = _catalog_entry_visible_name(entry)
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
		unlock_button.custom_minimum_size = Vector2(DYNAMIC_ENTRY_UNLOCK_ICON_SIZE, DYNAMIC_ENTRY_UNLOCK_ICON_SIZE)
		unlock_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		unlock_button.mouse_filter = Control.MOUSE_FILTER_STOP
		# Enabled only once the dependency chain is satisfied; a hidden entry keeps a
		# greyed, non-interactive lock icon until its predecessor is unlocked.
		unlock_button.disabled = is_hidden
		_connect_dynamic_entry_detail_hover(unlock_button, entry)
		unlock_button.pressed.connect(_on_dynamic_entry_unlock_pressed.bind(entry))
		row.add_child(unlock_button)

		# The RP-unlock affordance is a lock-open icon. A nested TextureRect (rather than
		# Button.expand_icon) fills the button reliably regardless of the theme's content
		# margins, so the icon reads at a legible size in the small trailing button.
		var lock_icon := TextureRect.new()
		lock_icon.name = "LockIcon"
		lock_icon.texture = UpgradeSlot.UNLOCK_ICON
		lock_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_icon.offset_left = DYNAMIC_ENTRY_UNLOCK_ICON_INSET
		lock_icon.offset_top = DYNAMIC_ENTRY_UNLOCK_ICON_INSET
		lock_icon.offset_right = -DYNAMIC_ENTRY_UNLOCK_ICON_INSET
		lock_icon.offset_bottom = -DYNAMIC_ENTRY_UNLOCK_ICON_INSET
		lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_icon.self_modulate = LOCKED_ENTRY_MODULATE if is_hidden else Color.WHITE
		unlock_button.add_child(lock_icon)

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
	for entry in _active_slot_catalog():
		if entry != null and _catalog_entry_equipment(entry) is WeaponData:
			entries.append(entry)

	if _run_loadout != null and _run_loadout.equipped_weapon != null:
		var has_equipped_weapon := false
		for entry in entries:
			if _same_equipment_data(_catalog_entry_equipment(entry), _run_loadout.equipped_weapon):
				has_equipped_weapon = true
				break
		if not has_equipped_weapon:
			var equipped_entry := UpgradeCatalogEntryScript.new()
			equipped_entry.set("item_data", _run_loadout.equipped_weapon)
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
	for entry in _active_slot_catalog():
		var augment := _catalog_entry_item_data(entry) as AugmentData
		if augment == null:
			continue
		entries.append(entry)
		_ensure_catalog_item_state(entry)

	var equipped_augment := _get_player_augment(_active_player_augment_index)
	if equipped_augment != null:
		var has_equipped_augment := false
		for entry in entries:
			if ItemData.is_same_item(_catalog_entry_item_data(entry) as ItemData, equipped_augment):
				has_equipped_augment = true
				break
		if not has_equipped_augment:
			var equipped_entry := UpgradeCatalogEntryScript.new()
			equipped_entry.set("item_data", equipped_augment)
			equipped_entry.set("locked", false)
			entries.insert(0, equipped_entry)

	entries.sort_custom(func(a: Resource, b: Resource) -> bool:
		var order_a := int(a.get("research_unlock_order")) if a != null and Utils.has_property(a, "research_unlock_order") else 0
		var order_b := int(b.get("research_unlock_order")) if b != null and Utils.has_property(b, "research_unlock_order") else 0
		return order_a < order_b
	)
	return entries


func _catalog_entry_item_data(entry: Resource) -> Resource:
	if entry == null:
		return null
	return entry.get("item_data") as Resource


func _catalog_entry_equipment(entry: Resource) -> HeldItemData:
	return _catalog_entry_item_data(entry) as HeldItemData


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
	return not cost.is_empty() and save_data.can_afford_research_cost(cost)


func _unlock_catalog_entry(entry: Resource) -> void:
	var save_data := _save_data as AppSaveData
	if save_data == null or not _can_unlock_catalog_entry(entry):
		return

	var cost := _catalog_entry_research_cost(entry)
	if not save_data.spend_research_cost(cost):
		return

	save_data.unlock_research_id(_catalog_entry_unlock_id(entry))
	if _run_loadout != null:
		_run_loadout.set_item_unlocked(_catalog_entry_item_data(entry), true)
	_save_current_game()
	_refresh_loadout_ui()
	_show_dynamic_item_stats(entry)


func _is_next_locked_catalog_entry(entry: Resource) -> bool:
	var group := _catalog_entry_unlock_group(entry)
	for candidate in _get_active_catalog_entries():
		if _catalog_entry_unlock_group(candidate) != group:
			continue
		if _catalog_entry_locked(candidate):
			return candidate == entry
	return false


## An entry's unlock dependency is the item immediately before it in its unlock
## group (ordered by research_unlock_order): it can only be revealed once that
## predecessor is unlocked. The first entry in a group has no dependency, and a
## non-locked entry is trivially satisfied. Items in single-item groups (e.g. the
## augments, each in their own group) therefore always have their deps met.
func _are_catalog_entry_dependencies_met(entry: Resource) -> bool:
	if entry == null:
		return false
	var group := _catalog_entry_unlock_group(entry)
	var order := _catalog_entry_unlock_order(entry)
	var predecessor: Resource = null
	var predecessor_order := 0
	for candidate in _get_active_catalog_entries():
		if candidate == entry or _catalog_entry_unlock_group(candidate) != group:
			continue
		var candidate_order := _catalog_entry_unlock_order(candidate)
		if candidate_order >= order:
			continue
		if predecessor == null or candidate_order > predecessor_order:
			predecessor = candidate
			predecessor_order = candidate_order
	if predecessor == null:
		return true
	return not _catalog_entry_locked(predecessor)


## A locked entry whose dependency chain isn't satisfied yet. It is listed with
## its identity masked (silhouette icon + "???" name) and a disabled unlock button
## until the previous item in its group is unlocked.
func _is_catalog_entry_hidden(entry: Resource) -> bool:
	return _catalog_entry_locked(entry) and not _are_catalog_entry_dependencies_met(entry)


func _catalog_entry_unlock_order(entry: Resource) -> int:
	if entry == null or not Utils.has_property(entry, "research_unlock_order"):
		return 0
	return int(entry.get("research_unlock_order"))


## The name shown in the item list / detail header: real name unless the entry is
## still hidden behind its unlock dependencies, in which case it reads "???".
func _catalog_entry_visible_name(entry: Resource) -> String:
	if _is_catalog_entry_hidden(entry):
		return HIDDEN_ENTRY_NAME
	return _catalog_entry_display_name(entry)


func _catalog_entry_unlock_id(entry: Resource) -> StringName:
	if entry != null and entry.has_method("get_research_unlock_id"):
		return entry.call("get_research_unlock_id")
	var item_data := _catalog_entry_item_data(entry)
	if item_data != null and Utils.has_property(item_data, "item_id"):
		return item_data.get("item_id") as StringName
	if entry != null and _catalog_entry_equipment(entry) != null:
		var equipment := _catalog_entry_equipment(entry)
		if not equipment.resource_path.is_empty():
			return StringName(equipment.resource_path)
	return &""


func _catalog_entry_unlock_group(entry: Resource) -> StringName:
	if entry == null:
		return &""
	if not Utils.has_property(entry, "research_unlock_group"):
		return &""
	return entry.get("research_unlock_group") as StringName


func _catalog_entry_research_cost(entry: Resource) -> Dictionary:
	if entry != null and entry.has_method("get_research_cost"):
		return entry.call("get_research_cost")
	return {}


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
	if not research_cost.is_empty():
		return _format_research_cost_text(research_cost, false)
	var costs := _catalog_entry_unlock_costs(entry)
	if not costs.is_empty():
		return _format_salvage_costs_text(costs)
	return "No unlock cost"


func _catalog_entry_unlock_costs(entry: Resource) -> Array:
	if entry == null or not Utils.has_property(entry, "unlock_cost"):
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
	var item_data := _catalog_entry_item_data(entry) as ItemData
	if item_data == null or item_data.upgrade_data == null or _run_loadout == null:
		return {"level": 0, "max_level": 0}
	return {
		"level": _run_loadout.get_upgrade_level(item_data.item_id),
		"max_level": item_data.get_max_level(),
	}


func _same_equipment_data(left: HeldItemData, right: HeldItemData) -> bool:
	if left == null or right == null:
		return false
	if left == right:
		return true
	return not left.resource_path.is_empty() and left.resource_path == right.resource_path


func _is_catalog_entry_equipped(entry: Resource) -> bool:
	if _run_loadout == null or entry == null:
		return false
	match _active_dynamic_slot_kind:
		&"weapon":
			return _same_equipment_data(_catalog_entry_equipment(entry), _run_loadout.equipped_weapon)
		&"player_augment":
			var item_data := _catalog_entry_item_data(entry)
			for augment in _run_loadout.player_augments:
				if ItemData.is_same_item(augment, item_data as ItemData):
					return true
		&"ship_augment":
			var ship_item_data := _catalog_entry_item_data(entry)
			for augment in _run_loadout.ship_augments:
				if ItemData.is_same_item(augment, ship_item_data as ItemData):
					return true
		&"magnet_augment":
			var magnet_item_data := _catalog_entry_item_data(entry)
			for augment in _run_loadout.magnet_augments:
				if ItemData.is_same_item(augment, magnet_item_data as ItemData):
					return true
	return false


func _ensure_catalog_item_state(entry: Resource) -> void:
	if _run_loadout == null or entry == null:
		return
	var item_data := _catalog_entry_item_data(entry)
	if item_data == null or not Utils.has_property(item_data, "item_id"):
		return
	var state := _run_loadout.get_or_create_item_state(item_data.get("item_id") as StringName)
	if state == null:
		return
	var default_unlocked := not bool(entry.get("locked"))
	var save_data := _save_data as AppSaveData
	if save_data != null and save_data.is_research_unlocked(_catalog_entry_unlock_id(entry)):
		default_unlocked = true
	if default_unlocked and Utils.has_property(state, "unlocked"):
		state.set("unlocked", true)


func _is_catalog_item_state_unlocked(entry: Resource) -> bool:
	if _run_loadout == null:
		return false
	var item_data := _catalog_entry_item_data(entry)
	return _run_loadout.is_item_unlocked(item_data, false)


## Description block (item description + its stats / current-effect summary) for
## the expanding description label. Level / locked status live in the status row.
func _format_catalog_item_description(entry: Resource) -> String:
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

	return "\n".join(lines)


func _get_catalog_entry_description(item_data: Resource) -> String:
	if item_data == null:
		return ""
	if Utils.has_property(item_data, "description"):
		return String(item_data.get("description"))
	return ""


func _get_item_state_for_data(item_data: Resource) -> Resource:
	if _run_loadout == null or item_data == null or not Utils.has_property(item_data, "item_id"):
		return null
	return _run_loadout.get_item_state(item_data.get("item_id") as StringName)


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


func _get_upgrade_button(upgrade_id: StringName) -> Button:
	for sid in _station_slots:
		if _slot_upgrade_ids.get(sid, &"") == upgrade_id:
			var slot := _station_slots[sid] as UpgradeSlot
			return slot.get_upgrade_button() if slot != null else null
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
	if not Utils.has_property(level_cost, "costs"):
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
	if level_cost == null or not Utils.has_property(level_cost, "scrap_cost"):
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


## One text row per required rarity, e.g. "1x Common RP (0 / 1)". When colorize
## is set, each row is green/red by whether that rarity's balance covers it.
func _format_research_cost_text(cost: Dictionary, colorize: bool = false) -> String:
	if cost.is_empty():
		return "Free"
	var save_data := _save_data as AppSaveData
	var lines := PackedStringArray()
	for rarity in cost:
		var required := int(cost[rarity])
		var owned := save_data.get_research_points(int(rarity)) if save_data != null else 0
		var line := "%dx %s RP (%d / %d)" % [
			required, SalvageItemData.get_name_for_rarity(int(rarity)), owned, required,
		]
		if colorize:
			line = _colorize_requirement(line, owned >= required)
		lines.append(line)
	return "\n".join(lines)


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
	var item_data := cost_resource.get("item_data") as SalvageItemData if Utils.has_property(cost_resource, "item_data") else null
	var quantity := int(cost_resource.get("quantity")) if Utils.has_property(cost_resource, "quantity") else 0
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
	# Each effect labels itself from its own target_property; no per-upgrade mapping.
	return _run_loadout.get_upgrade_next_gain_text(upgrade_id, "")


func _build_storage_size_gain_text() -> String:
	if _run_loadout.is_upgrade_maxed(&"ship_storage_size"):
		return "MAX LEVEL"
	var next_level := _run_loadout.get_upgrade_level(&"ship_storage_size") + 1
	var next_size: Vector2 = _run_loadout.get_storage_size_for_level(next_level)
	return "%d×%d Storage" % [int(next_size.x), int(next_size.y)]


func _get_weapon_preview(weapon_data: WeaponData) -> WeaponData:
	if _run_loadout == null:
		return weapon_data
	return _run_loadout.get_upgraded_weapon_preview(weapon_data)


func _get_equipment_icon(equipment_data: HeldItemData) -> Texture2D:
	if equipment_data == null:
		return null
	if equipment_data.hotbar_icon:
		return equipment_data.hotbar_icon
	if equipment_data is WeaponData:
		return (equipment_data as WeaponData).weapon_sprite
	if equipment_data is MagnetToolData:
		return (equipment_data as MagnetToolData).weapon_sprite
	return null


func _get_equipment_name(equipment_data: HeldItemData) -> String:
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


func _get_upgradeable_item_name(item_data: Resource) -> String:
	if item_data == null:
		return "Empty"
	if item_data.has_method("get_display_name"):
		return String(item_data.call("get_display_name"))
	if Utils.has_property(item_data, "display_name"):
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
	if Utils.has_property(item_data, "icon"):
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


func _format_resource_stats(resource: Resource, property_names: Array[String]) -> String:
	if resource == null:
		return "No stats available"

	var lines := PackedStringArray()
	for property_name in property_names:
		if not Utils.has_property(resource, property_name):
			continue
		lines.append("%s: %s" % [
			_prettify_property_name(property_name),
			_stringify_stat_value(resource.get(property_name)),
		])

	if lines.is_empty():
		return "No stats available"
	return "\n".join(lines)


func _prettify_property_name(property_name: String) -> String:
	return property_name.replace("_", " ").to_upper()


func _stringify_stat_value(value: Variant) -> String:
	match typeof(value):
		TYPE_FLOAT:
			return Utils.format_number(float(value))
		TYPE_INT:
			return str(int(value))
		TYPE_BOOL:
			return "YES" if bool(value) else "NO"
		TYPE_VECTOR2:
			var vector_value: Vector2 = value
			return "%s x %s" % [Utils.format_number(vector_value.x), Utils.format_number(vector_value.y)]
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
	if value is HeldItemData:
		return _get_equipment_name(value as HeldItemData)
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
