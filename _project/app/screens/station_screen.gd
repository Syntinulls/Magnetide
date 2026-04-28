extends Control
class_name StationScreen

signal start_requested
signal main_menu_requested

const StorageSlotScene := preload("res://_project/app/screens/station_storage_slot.tscn")
const PlaceholderGearData := preload("res://_project/items/resources/gear.tres")
const PlaceholderMagnetData := preload("res://_project/items/resources/magnet.tres")
const PlaceholderBatteryData := preload("res://_project/items/resources/battery.tres")

@export var page_pan_duration: float = 0.35

var _current_page_index: int = 0
var _is_panning: bool = false
var _page_tween: Tween = null

@onready var _page_viewport: Control = $PageViewport
@onready var _page_container: Control = $PageViewport/PageContainer
@onready var _player_page: Control = $PageViewport/PageContainer/PlayerPage
@onready var _ship_page: Control = $PageViewport/PageContainer/ShipPage
@onready var _map_button: Button = $TopBar/MapButton
@onready var _menu_button: Button = $TopBar/MenuButton
@onready var _pan_to_ship_button: Button = $PageViewport/PageContainer/PlayerPage/PanToShipButton
@onready var _pan_to_player_button: Button = $PageViewport/PageContainer/ShipPage/PanToPlayerButton
@onready var _weapon_button: Button = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/LeftUpgradeGroup/RowStack/WeaponRow/EquipmentButton
@onready var _magnet_button: Button = $PageViewport/PageContainer/PlayerPage/UpgradeLayer/LeftUpgradeGroup/RowStack/MagnetRow/EquipmentButton
@onready var _weapon_popup: Control = $PageViewport/PageContainer/PlayerPage/WeaponEquipmentPopup
@onready var _weapon_popup_stats_panel: Control = $PageViewport/PageContainer/PlayerPage/WeaponEquipmentPopup/HoveredWeaponStatsPanel
@onready var _weapon_popup_stats_name: Label = $PageViewport/PageContainer/PlayerPage/WeaponEquipmentPopup/HoveredWeaponStatsPanel/NameLabel
@onready var _weapon_popup_stats_body: Label = $PageViewport/PageContainer/PlayerPage/WeaponEquipmentPopup/HoveredWeaponStatsPanel/BodyLabel
@onready var _upgrade_cost_popup: Control = $PageViewport/PageContainer/PlayerPage/UpgradeCostPopup
@onready var _stats_title_label: Label = $SharedBottomArea/StatsPanel/TitleLabel
@onready var _stats_body_label: Label = $SharedBottomArea/StatsPanel/BodyLabel
@onready var _storage_grid: GridContainer = $SharedBottomArea/StoragePanel/StorageScroll/StorageGrid
@onready var _storage_detail_panel: Control = $SharedBottomArea/StorageDetailPanel
@onready var _storage_detail_icon: TextureRect = $SharedBottomArea/StorageDetailPanel/ItemIcon
@onready var _storage_detail_name: Label = $SharedBottomArea/StorageDetailPanel/NameLabel
@onready var _storage_detail_body: Label = $SharedBottomArea/StorageDetailPanel/BodyLabel


func _ready() -> void:
	_configure_mouse_filters(self)
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

	_connect_upgrade_cost_hover($PageViewport/PageContainer/PlayerPage/UpgradeLayer/LeftUpgradeGroup/RowStack/WeaponRow/UpgradeButton, "350", "0 / 5")
	_connect_upgrade_cost_hover($PageViewport/PageContainer/PlayerPage/UpgradeLayer/LeftUpgradeGroup/RowStack/MagnetRow/UpgradeButton, "250", "1 / 5")
	_connect_upgrade_cost_hover($PageViewport/PageContainer/PlayerPage/UpgradeLayer/RightUpgradeGroup/HealthRow/UpgradeButton, "200", "0 / 5")
	_connect_upgrade_cost_hover($PageViewport/PageContainer/PlayerPage/UpgradeLayer/RightUpgradeGroup/ShieldRow/UpgradeButton, "275", "0 / 5")

	_populate_storage_slots(_get_placeholder_storage_entries())

	for weapon_entry in $PageViewport/PageContainer/PlayerPage/WeaponEquipmentPopup/EquipmentPanel/WeaponList.get_children():
		if weapon_entry is Button:
			weapon_entry.mouse_entered.connect(_show_weapon_stats.bind(weapon_entry.text))
			weapon_entry.focus_entered.connect(_show_weapon_stats.bind(weapon_entry.text))
			if not weapon_entry.disabled:
				weapon_entry.pressed.connect(_equip_weapon_from_popup.bind(weapon_entry.text))

	_layout_pages()
	_update_pan_buttons()
	_refresh_stats_panel()


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


func _connect_upgrade_cost_hover(button: Button, credit_cost: String, secondary_cost: String) -> void:
	if button == null:
		return
	button.mouse_entered.connect(_show_upgrade_cost_popup.bind(button, credit_cost, secondary_cost))
	button.mouse_exited.connect(_hide_upgrade_cost_popup)
	button.focus_entered.connect(_show_upgrade_cost_popup.bind(button, credit_cost, secondary_cost))
	button.focus_exited.connect(_hide_upgrade_cost_popup)


func _show_upgrade_cost_popup(button: Button, credit_cost: String, secondary_cost: String) -> void:
	$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/CreditsLabel.text = credit_cost
	$PageViewport/PageContainer/PlayerPage/UpgradeCostPopup/SecondaryLabel.text = secondary_cost
	var button_rect := button.get_global_rect()
	var page_rect := _player_page.get_global_rect()
	_upgrade_cost_popup.position = (button_rect.position - page_rect.position) + Vector2(72.0, -120.0)
	_upgrade_cost_popup.visible = true


func _hide_upgrade_cost_popup() -> void:
	_upgrade_cost_popup.visible = false


func _on_map_pressed() -> void:
	start_requested.emit()


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
		_stats_title_label.text = "Stats"
		_stats_body_label.text = "HEALTH: 100 / 100\nSHIELD: 50 / 50\nSPEED: 400\nLOADOUT: LIGHT"
	else:
		_stats_title_label.text = "Ship Stats"
		_stats_body_label.text = "HULL: 250 / 250\nSTORAGE: 100\nMAGNET: ONLINE\nTHRUSTERS: READY"


func _clear_stats_panel() -> void:
	_stats_title_label.text = ""
	_stats_body_label.text = ""


func _toggle_weapon_popup() -> void:
	var should_show := not _weapon_popup.visible
	_weapon_popup.visible = should_show
	_weapon_popup_stats_panel.visible = false
	if should_show:
		_hide_upgrade_cost_popup()
		_hide_storage_detail()


func _close_weapon_popup() -> void:
	_weapon_popup.visible = false
	_weapon_popup_stats_panel.visible = false


func _show_weapon_stats(weapon_name: String) -> void:
	_weapon_popup_stats_name.text = weapon_name
	_weapon_popup_stats_body.text = "RARITY: COMMON\nDAMAGE: 12\nFIRE RATE: 4.0 / S\nWEIGHT: 6\n\nPreview stats for the hovered weapon."
	_weapon_popup_stats_panel.visible = true


func _equip_weapon_from_popup(_weapon_name: String) -> void:
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


func _get_placeholder_storage_entries() -> Array[Dictionary]:
	return [
		{
			"item_data": PlaceholderGearData,
			"quantity": 12,
		},
		{
			"item_data": PlaceholderMagnetData,
			"quantity": 4,
		},
		{
			"item_data": PlaceholderBatteryData,
			"quantity": 2,
		},
	]


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
	var rarity_names := {
		SalvageItemData.ItemRarity.COMMON: "COMMON",
		SalvageItemData.ItemRarity.RARE: "RARE",
		SalvageItemData.ItemRarity.EPIC: "EPIC",
		SalvageItemData.ItemRarity.LEGENDARY: "LEGENDARY",
	}
	var rarity_name: String = rarity_names.get(int(item_data.rarity), "COMMON")
	var parts_text := "NONE"
	if not item_data.parts.is_empty():
		var part_names := PackedStringArray()
		for part_entry in item_data.parts:
			if part_entry == null or part_entry.item_data == null:
				continue
			part_names.append(part_entry.item_data.item_name)
		if not part_names.is_empty():
			parts_text = ", ".join(part_names)

	return "QUANTITY: %d\nRARITY: %s\nWEIGHT: %.1f\nVALUE: %d\nPARTS: %s\n\nRecovered station material." % [
		quantity,
		rarity_name,
		item_data.weight,
		item_data.value,
		parts_text,
	]


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
