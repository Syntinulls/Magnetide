extends Control
class_name StationScreen

signal map_requested
signal main_menu_requested

const StorageSlotScene := preload("res://_project/app/screens/station_storage_slot.tscn")

@export var page_pan_duration: float = 0.35
@export var run_loadout: RunLoadout = null
const EquipmentCatalogEntryScript := preload("res://_project/player/equipment/equipment_catalog_entry.gd")

@export var weapon_catalog: Array[Resource] = []

const ACTIVE_TICK_COLOR := Color(0.82, 0.87, 0.95, 1.0)
const INACTIVE_TICK_COLOR := Color(0.35, 0.4, 0.5, 1.0)
const LOCKED_ENTRY_MODULATE := Color(0.58, 0.62, 0.68, 1.0)
const UNLOCKED_ENTRY_MODULATE := Color.WHITE
const WEAPON_STAT_PROPERTIES: Array[String] = ["damage", "fire_rate", "pierce"]
const STORAGE_STAT_PROPERTIES: Array[String] = ["rarity", "weight", "value"]

var _save_data: Resource = null
var _run_loadout: RunLoadout = null
var _current_page_index: int = 0
var _is_panning: bool = false
var _page_tween: Tween = null
var _is_ready: bool = false
var _research_points_label: Label = null

@onready var _page_viewport: Control = $PageViewport
@onready var _page_container: Control = $PageViewport/PageContainer
@onready var _top_bar: Control = $TopBar
@onready var _player_page: Control = $PageViewport/PageContainer/PlayerPage
@onready var _ship_page: Control = $PageViewport/PageContainer/ShipPage
@onready var _map_button: Button = $TopBar/MapButton
@onready var _menu_button: Button = $TopBar/MenuButton
@onready var _pan_to_ship_button: Button = $PageViewport/PageContainer/PlayerPage/PanToShipButton
@onready var _pan_to_player_button: Button = $PageViewport/PageContainer/ShipPage/PanToPlayerButton
@onready var _weapon_button: Button = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/LeftUpgradeGroup/RowStack/WeaponRow/EquipmentButton
@onready var _magnet_button: Button = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/LeftUpgradeGroup/RowStack/MagnetRow/EquipmentButton
@onready var _weapon_row: HBoxContainer = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/LeftUpgradeGroup/RowStack/WeaponRow
@onready var _magnet_row: HBoxContainer = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/LeftUpgradeGroup/RowStack/MagnetRow
@onready var _health_row: HBoxContainer = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/RightUpgradeGroup/HealthRow
@onready var _shield_row: HBoxContainer = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/RightUpgradeGroup/ShieldRow
@onready var _weapon_upgrade_button: Button = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/LeftUpgradeGroup/RowStack/WeaponRow/UpgradeButton
@onready var _magnet_upgrade_button: Button = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/LeftUpgradeGroup/RowStack/MagnetRow/UpgradeButton
@onready var _health_upgrade_button: Button = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/RightUpgradeGroup/HealthRow/UpgradeButton
@onready var _shield_upgrade_button: Button = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/RightUpgradeGroup/ShieldRow/UpgradeButton
@onready var _weapon_popup: Control = $PageViewport/PageContainer/PlayerPage/WeaponEquipmentPopup
@onready var _weapon_popup_current_stats: Label = $PageViewport/PageContainer/PlayerPage/WeaponEquipmentPopup/EquipmentPanel/CurrentStatsLabel
@onready var _weapon_list: VBoxContainer = $PageViewport/PageContainer/PlayerPage/WeaponEquipmentPopup/EquipmentPanel/WeaponList
@onready var _weapon_popup_stats_panel: Control = $PageViewport/PageContainer/PlayerPage/WeaponEquipmentPopup/HoveredWeaponStatsPanel
@onready var _weapon_popup_stats_name: Label = $PageViewport/PageContainer/PlayerPage/WeaponEquipmentPopup/HoveredWeaponStatsPanel/NameLabel
@onready var _weapon_popup_stats_body: Label = $PageViewport/PageContainer/PlayerPage/WeaponEquipmentPopup/HoveredWeaponStatsPanel/BodyLabel
@onready var _upgrade_cost_popup: Control = $PageViewport/PageContainer/PlayerPage/UpgradeCostPopup
@onready var _stats_title_label: Label = $SharedBottomArea/StatsPanel/TitleLabel
@onready var _stats_body_label: Label = $SharedBottomArea/StatsPanel/BodyLabel
@onready var _storage_grid: GridContainer = $SharedBottomArea/StoragePanel/StorageScroll/StorageGrid
@onready var _storage_scrap_count_label: Label = $SharedBottomArea/StoragePanel/ScrapCounter/ScrapCountLabel
@onready var _storage_detail_panel: Control = $SharedBottomArea/StorageDetailPanel
@onready var _storage_detail_icon: TextureRect = $SharedBottomArea/StorageDetailPanel/ItemIcon
@onready var _storage_detail_name: Label = $SharedBottomArea/StorageDetailPanel/NameLabel
@onready var _storage_detail_body: Label = $SharedBottomArea/StorageDetailPanel/BodyLabel


func _ready() -> void:
	_is_ready = true
	if _run_loadout == null:
		_run_loadout = run_loadout
	if _run_loadout:
		_run_loadout.prepare_for_run()

	_configure_mouse_filters(self)
	_ensure_research_points_display()
	_apply_fonts(self)
	_weapon_popup.visible = false
	_weapon_popup_stats_panel.visible = false
	_upgrade_cost_popup.visible = false
	_storage_detail_panel.visible = false
	_weapon_popup.z_index = 2
	_weapon_button.z_index = 3
	_upgrade_cost_popup.z_index = 5

	_map_button.pressed.connect(_on_map_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_pan_to_ship_button.pressed.connect(_on_pan_to_ship_pressed)
	_pan_to_player_button.pressed.connect(_on_pan_to_player_pressed)
	_weapon_button.pressed.connect(_toggle_weapon_popup)
	_magnet_button.pressed.connect(_close_weapon_popup)

	_connect_upgrade_button(_weapon_upgrade_button, &"weapon_damage")
	_connect_upgrade_button(_magnet_upgrade_button, &"magnet_tool_pull")
	_connect_upgrade_button(_health_upgrade_button, &"player_health")
	_connect_upgrade_button(_shield_upgrade_button, &"player_shield")

	_populate_storage_slots(_get_storage_entries())

	_layout_pages()
	_update_pan_buttons()
	_refresh_loadout_ui()


func set_run_loadout(loadout: RunLoadout) -> void:
	_run_loadout = loadout
	run_loadout = loadout
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_layout_pages()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _weapon_popup.visible and not _weapon_popup.get_global_rect().has_point(event.global_position):
			if not _weapon_button.get_global_rect().has_point(event.global_position):
				_close_weapon_popup()


func _layout_pages() -> void:
	if _page_viewport == null or _page_container == null:
		return

	var page_size := size
	if page_size.x <= 0.0 or page_size.y <= 0.0:
		return

	_page_viewport.size = page_size
	_page_container.size = Vector2(page_size.x * 2.0, page_size.y)
	_player_page.size = page_size
	_ship_page.size = page_size
	_ship_page.position = Vector2(page_size.x, 0.0)
	_page_container.position = Vector2(-page_size.x * _current_page_index, 0.0)
	if _weapon_popup != null and _weapon_popup.visible:
		_position_weapon_popup()


func _connect_upgrade_button(button: Button, upgrade_id: StringName) -> void:
	if button == null:
		return
	button.mouse_entered.connect(_show_upgrade_cost_popup.bind(button, upgrade_id))
	button.mouse_exited.connect(_hide_upgrade_cost_popup)
	button.focus_entered.connect(_show_upgrade_cost_popup.bind(button, upgrade_id))
	button.focus_exited.connect(_hide_upgrade_cost_popup)
	button.pressed.connect(_on_upgrade_pressed.bind(upgrade_id))


func _show_upgrade_cost_popup(button: Button, upgrade_id: StringName) -> void:
	var upgrade := _get_upgrade(upgrade_id)
	if upgrade == null:
		return

	if bool(upgrade.call("is_maxed")):
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/TitleLabel.text = "MAX LEVEL"
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/CreditsLabel.text = ""
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/SecondaryLabel.text = ""
	else:
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/TitleLabel.text = String(upgrade.call(
			"get_next_level_gain_text",
			_get_upgrade_stat_name(upgrade)
		))
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/CreditsLabel.text = "Upgrade Cost"
		$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/SecondaryLabel.text = String(upgrade.call("get_next_level_cost_text"))
	var button_rect := button.get_global_rect()
	var page_rect := _player_page.get_global_rect()
	_upgrade_cost_popup.position = (button_rect.position - page_rect.position) + Vector2(72.0, -120.0)
	_upgrade_cost_popup.visible = true


func _hide_upgrade_cost_popup() -> void:
	_upgrade_cost_popup.visible = false


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

	var target_position := Vector2(-size.x * _current_page_index, 0.0)
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
	_research_points_label.add_theme_color_override("font_color", SalvageItemData.ARTIFACT_COLOR)
	_research_points_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_research_points_label.add_theme_constant_override("outline_size", 4)
	_research_points_label.add_theme_font_size_override("font_size", 34)
	_research_points_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_research_points_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_research_points_label)
	_refresh_research_points_display()


func _refresh_research_points_display() -> void:
	if _research_points_label == null:
		return
	var points := 0
	var save_data := _save_data as AppSaveData
	if save_data:
		points = save_data.research_points
	_research_points_label.text = "RESEARCH: %d" % points


func _toggle_weapon_popup() -> void:
	var should_show := not _weapon_popup.visible
	_weapon_popup.visible = should_show
	_weapon_popup_stats_panel.visible = false
	if should_show:
		_hide_upgrade_cost_popup()
		_hide_storage_detail()
		_position_weapon_popup()
		_populate_weapon_list()
		_refresh_current_weapon_stats()


func _close_weapon_popup() -> void:
	_weapon_popup.visible = false
	_weapon_popup_stats_panel.visible = false


func _position_weapon_popup() -> void:
	if _weapon_popup == null or _weapon_button == null or _player_page == null:
		return

	var button_rect := _weapon_button.get_global_rect()
	var page_rect := _player_page.get_global_rect()
	_weapon_popup.position = button_rect.position - page_rect.position


func _show_weapon_stats(entry: Resource) -> void:
	var entry_equipment := _catalog_entry_equipment(entry)
	if entry == null or entry_equipment == null:
		return

	var weapon := _get_weapon_preview(entry_equipment as WeaponData)
	_weapon_popup_stats_name.text = _catalog_entry_display_name(entry)
	_weapon_popup_stats_body.text = _format_weapon_stats(weapon)
	if _catalog_entry_locked(entry):
		_weapon_popup_stats_body.text += "\n\nLOCKED\nUNLOCK: %s" % _catalog_entry_unlock_cost_text(entry)
	_weapon_popup_stats_panel.visible = true


func _equip_weapon_from_popup(entry: Resource) -> void:
	if entry == null or _catalog_entry_locked(entry) or _run_loadout == null:
		return

	var weapon_data := _catalog_entry_equipment(entry) as WeaponData
	if weapon_data == null:
		return

	_run_loadout.equip_weapon(weapon_data)
	_save_current_game()
	_refresh_loadout_ui()
	_close_weapon_popup()


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
	_update_upgrade_rows()
	_populate_weapon_list()
	_populate_storage_slots(_get_storage_entries())
	_refresh_current_weapon_stats()
	_refresh_stats_panel()
	_refresh_storage_scrap_counter()
	_refresh_research_points_display()


func _update_equipment_buttons() -> void:
	if _run_loadout == null:
		return

	var weapon := _run_loadout.equipped_weapon
	if weapon:
		_weapon_button.icon = _get_equipment_icon(weapon)
		_weapon_button.text = ""

	var magnet_tool := _run_loadout.equipped_magnet_tool
	if magnet_tool:
		_magnet_button.icon = _get_equipment_icon(magnet_tool)


func _update_upgrade_rows() -> void:
	_set_upgrade_row_level(_weapon_row, _get_upgrade(&"weapon_damage"))
	_set_upgrade_row_level(_magnet_row, _get_upgrade(&"magnet_tool_pull"))
	_set_upgrade_row_level(_health_row, _get_upgrade(&"player_health"))
	_set_upgrade_row_level(_shield_row, _get_upgrade(&"player_shield"))


func _set_upgrade_row_level(row: HBoxContainer, upgrade: Resource) -> void:
	if row == null or upgrade == null:
		return

	var tick_index := 0
	for child in row.get_children():
		if child is ColorRect and String(child.name).begins_with("Tick"):
			tick_index += 1
			var tick := child as ColorRect
			tick.visible = tick_index <= int(upgrade.get("max_level"))
			tick.color = ACTIVE_TICK_COLOR if tick_index <= int(upgrade.get("current_level")) else INACTIVE_TICK_COLOR


func _on_upgrade_pressed(upgrade_id: StringName) -> void:
	if _run_loadout == null:
		return
	var upgrade := _get_upgrade(upgrade_id)
	if upgrade == null:
		return
	if bool(upgrade.call("is_maxed")):
		return
	if _save_data != null and not bool(_save_data.call("spend_upgrade_cost", upgrade)):
		return
	_run_loadout.increase_upgrade(upgrade_id)
	_save_current_game()
	_refresh_loadout_ui()
	if _upgrade_cost_popup.visible:
		var button := _get_upgrade_button(upgrade_id)
		if button:
			_show_upgrade_cost_popup(button, upgrade_id)


func _populate_weapon_list() -> void:
	if _weapon_list == null:
		return

	for child in _weapon_list.get_children():
		child.queue_free()

	var entries := _get_weapon_catalog_entries()
	for entry in entries:
		if entry == null or _catalog_entry_equipment(entry) == null:
			continue

		var button := Button.new()
		button.custom_minimum_size = Vector2(340.0, 72.0)
		button.text = _get_weapon_entry_text(entry)
		button.icon = _catalog_entry_icon(entry)
		button.expand_icon = false
		var is_locked := _catalog_entry_locked(entry)
		button.modulate = LOCKED_ENTRY_MODULATE if is_locked else UNLOCKED_ENTRY_MODULATE
		button.disabled = is_locked and not _can_unlock_catalog_entry(entry)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		Magnetide.apply_label_font(button)
		_weapon_list.add_child(button)
		button.mouse_entered.connect(_show_weapon_stats.bind(entry))
		button.focus_entered.connect(_show_weapon_stats.bind(entry))
		if is_locked:
			if _can_unlock_catalog_entry(entry):
				button.pressed.connect(_unlock_weapon_entry.bind(entry))
		else:
			button.pressed.connect(_equip_weapon_from_popup.bind(entry))


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


func _get_weapon_entry_text(entry: Resource) -> String:
	var parts := PackedStringArray([_catalog_entry_display_name(entry)])
	if _run_loadout != null and _same_equipment_data(_catalog_entry_equipment(entry), _run_loadout.equipped_weapon):
		parts.append("Equipped")
	if _catalog_entry_locked(entry):
		parts.append("Unlock %s" % _catalog_entry_unlock_cost_text(entry))
	return "  ".join(parts)


func _catalog_entry_equipment(entry: Resource) -> EquipmentData:
	if entry == null:
		return null
	return entry.get("equipment_data") as EquipmentData


func _catalog_entry_locked(entry: Resource) -> bool:
	if entry == null or not bool(entry.get("locked")):
		return false
	var save_data := _save_data as AppSaveData
	if save_data == null:
		return true
	var unlock_id := _catalog_entry_unlock_id(entry)
	return not save_data.is_research_unlocked(unlock_id)


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


func _unlock_weapon_entry(entry: Resource) -> void:
	var save_data := _save_data as AppSaveData
	if save_data == null or not _can_unlock_catalog_entry(entry):
		return

	var cost := _catalog_entry_research_cost(entry)
	if not save_data.spend_research_points(cost):
		return

	save_data.unlock_research_id(_catalog_entry_unlock_id(entry))
	_save_current_game()
	_refresh_loadout_ui()
	_show_weapon_stats(entry)


func _is_next_locked_catalog_entry(entry: Resource) -> bool:
	var group := _catalog_entry_unlock_group(entry)
	for candidate in _get_weapon_catalog_entries():
		if _catalog_entry_unlock_group(candidate) != group:
			continue
		if _catalog_entry_locked(candidate):
			return candidate == entry
	return false


func _catalog_entry_unlock_id(entry: Resource) -> StringName:
	if entry != null and entry.has_method("get_research_unlock_id"):
		return entry.call("get_research_unlock_id")
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
	var equipment_data := _catalog_entry_equipment(entry)
	return _get_equipment_name(equipment_data)


func _catalog_entry_icon(entry: Resource) -> Texture2D:
	if entry != null and entry.has_method("get_icon"):
		return entry.call("get_icon") as Texture2D
	return _get_equipment_icon(_catalog_entry_equipment(entry))


func _catalog_entry_unlock_cost_text(entry: Resource) -> String:
	if entry != null and entry.has_method("get_unlock_cost_text"):
		return String(entry.call("get_unlock_cost_text"))
	return "No unlock cost"


func _same_equipment_data(left: EquipmentData, right: EquipmentData) -> bool:
	if left == null or right == null:
		return false
	if left == right:
		return true
	return not left.resource_path.is_empty() and left.resource_path == right.resource_path


func _refresh_current_weapon_stats() -> void:
	if _weapon_popup_current_stats == null:
		return
	if _run_loadout == null or _run_loadout.equipped_weapon == null:
		_weapon_popup_current_stats.text = "No weapon equipped"
		return

	var weapon := _run_loadout.get_upgraded_weapon_preview()
	_weapon_popup_current_stats.text = "%s\n%s" % [
		_get_equipment_name(_run_loadout.equipped_weapon),
		_format_weapon_stats(weapon),
	]


func _get_upgrade(upgrade_id: StringName) -> Resource:
	if _run_loadout == null:
		return null
	return _run_loadout.get_upgrade(upgrade_id)


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


func _get_upgrade_stat_name(upgrade: Resource) -> String:
	if upgrade == null:
		return ""
	var target_property := String(upgrade.get("target_property"))
	match target_property:
		"player_max_health":
			return "Health"
		"player_max_shield":
			return "Shield"
		"damage":
			return "Damage"
		"fire_rate":
			return "Fire Rate"
		"pull_max_speed":
			return "Pull Speed"
		"ship_max_health":
			return "Hull"
		"ship_storage_max_weight":
			return "Storage"
		"magnet_hold_capacity":
			return "Magnet Capacity"
		"magnet_max_health":
			return "Magnet Health"
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


func _build_player_stats_text() -> String:
	if _run_loadout == null:
		return "No run loadout assigned"

	var lines := PackedStringArray([
		"HEALTH: %s" % _stringify_stat_value(_run_loadout.player_max_health),
		"SHIELD: %s" % _stringify_stat_value(_run_loadout.player_max_shield),
		"EQUIPPED WEAPON: %s" % _get_equipment_name(_run_loadout.equipped_weapon),
		"EQUIPPED TOOL: %s" % _get_equipment_name(_run_loadout.equipped_magnet_tool),
	])
	return "\n".join(lines)


func _build_ship_stats_text() -> String:
	if _run_loadout == null:
		return "No run loadout assigned"

	var lines := PackedStringArray([
		"HULL: %s" % _stringify_stat_value(_run_loadout.ship_max_health),
		"STORAGE: %s" % _stringify_stat_value(_run_loadout.ship_storage_max_weight),
		"MAGNET CAPACITY: %s" % _stringify_stat_value(_run_loadout.magnet_hold_capacity),
		"MAGNET HEALTH: %s" % _stringify_stat_value(_run_loadout.magnet_max_health),
	])
	return "\n".join(lines)


func _format_weapon_stats(weapon: WeaponData) -> String:
	var lines := PackedStringArray([_format_resource_stats(weapon, WEAPON_STAT_PROPERTIES)])
	var upgrade := _get_upgrade(&"weapon_damage")
	if upgrade != null:
		if bool(upgrade.call("is_maxed")):
			lines.append("UPGRADE: MAX LEVEL")
		else:
			lines.append("UPGRADE COST:\n%s" % String(upgrade.call("get_next_level_cost_text")))
	return "\n".join(lines)


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


func _configure_mouse_filters(node: Node) -> void:
	if node is Button:
		(node as Button).mouse_filter = Control.MOUSE_FILTER_STOP
	elif node is ScrollContainer:
		(node as ScrollContainer).mouse_filter = Control.MOUSE_FILTER_STOP
	elif node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child in node.get_children():
		_configure_mouse_filters(child)
