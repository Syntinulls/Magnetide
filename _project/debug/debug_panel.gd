extends CanvasLayer
class_name DebugPanel

## Centralized debug overlay: grouped debug actions toggled with the
## debug_toggle_panel action (backtick). Exists only in debug builds or when the
## game is launched with --debug-panel (see specs/debug_panel.md).

## Emitted after any action that mutated save data (currency, storage, unlocks,
## upgrades) so open screens can re-sync their UI.
signal save_data_changed

const DEBUG_LAUNCH_FLAG := "--debug-panel"
const CONTEXT_REFRESH_INTERVAL := 0.25
const WIPE_CONFIRM_SECONDS := 3.0
const WIPE_BUTTON_TEXT := "Wipe Save"
const WIPE_CONFIRM_TEXT := "Confirm Wipe?"
const SCROLL_VIEWPORT_MARGIN := 24.0

## Dropdown/action catalogs. Content additions register here (spec §9); the
## enemy dropdown instead enumerates the live EnemySpawner's profiles.
@export var weapons: Array[WeaponData] = []
@export var upgrade_items: Array[ItemData] = []
@export var unlock_items: Array[ItemData] = []
@export var unlock_slot_ids: Array[StringName] = []
@export var salvage_items: Array[SalvageItemData] = []

var _context_refresh_remaining: float = 0.0
var _wipe_confirm_remaining: float = 0.0

@onready var _panel: PanelContainer = $Panel
@onready var _scroll: ScrollContainer = $Panel/Scroll
@onready var _groups: VBoxContainer = $Panel/Scroll/Groups

@onready var _spawn_random_enemy_button: Button = %SpawnRandomEnemyButton
@onready var _spawn_enemy_button: Button = %SpawnEnemyButton
@onready var _enemy_dropdown: OptionButton = %EnemyDropdown
@onready var _kill_all_enemies_button: Button = %KillAllEnemiesButton
@onready var _add_threat_button: Button = %AddThreatButton
@onready var _threat_amount_edit: LineEdit = %ThreatAmountEdit
@onready var _advance_threat_button: Button = %AdvanceThreatLevelButton
@onready var _fill_threat_button: Button = %FillThreatButton
@onready var _spawn_pile_button: Button = %SpawnSalvagePileButton
@onready var _extract_button: Button = %ExtractButton
@onready var _fail_run_button: Button = %FailRunButton

@onready var _heal_button: Button = %HealButton
@onready var _heal_amount_edit: LineEdit = %HealAmountEdit
@onready var _kill_player_button: Button = %KillPlayerButton
@onready var _god_mode_button: Button = %GodModeButton
@onready var _refill_ammo_button: Button = %RefillAmmoButton
@onready var _damage_mult_button: Button = %DamageMultButton
@onready var _damage_mult_edit: LineEdit = %DamageMultEdit
@onready var _equip_weapon_button: Button = %EquipWeaponButton
@onready var _weapon_dropdown: OptionButton = %WeaponDropdown

@onready var _add_scrap_button: Button = %AddScrapButton
@onready var _scrap_amount_edit: LineEdit = %ScrapAmountEdit
@onready var _add_research_button: Button = %AddResearchButton
@onready var _research_common_edit: LineEdit = %ResearchCommonEdit
@onready var _research_rare_edit: LineEdit = %ResearchRareEdit
@onready var _research_epic_edit: LineEdit = %ResearchEpicEdit
@onready var _add_item_button: Button = %AddItemButton
@onready var _item_dropdown: OptionButton = %ItemDropdown
@onready var _item_qty_edit: LineEdit = %ItemQtyEdit
@onready var _spawn_artifact_button: Button = %SpawnArtifactButton
@onready var _unlock_research_button: Button = %UnlockResearchButton
@onready var _grant_upgrade_button: Button = %GrantUpgradeButton
@onready var _upgrade_dropdown: OptionButton = %UpgradeDropdown
@onready var _upgrade_levels_edit: LineEdit = %UpgradeLevelsEdit
@onready var _max_upgrades_button: Button = %MaxUpgradesButton

@onready var _force_save_button: Button = %ForceSaveButton
@onready var _wipe_save_button: Button = %WipeSaveButton
@onready var _open_save_folder_button: Button = %OpenSaveFolderButton
@onready var _start_run_button: Button = %StartRunButton
@onready var _abandon_run_button: Button = %AbandonRunButton
@onready var _go_station_button: Button = %GoStationButton
@onready var _go_map_button: Button = %GoMapButton
@onready var _go_menu_button: Button = %GoMenuButton

@onready var _time_quarter_button: Button = %TimeQuarterButton
@onready var _time_one_button: Button = %TimeOneButton
@onready var _time_two_button: Button = %TimeTwoButton
@onready var _time_four_button: Button = %TimeFourButton
@onready var _pause_button: Button = %PauseButton
@onready var _cycle_music_button: Button = %CycleMusicButton

@onready var _fps_label: Label = %FpsLabel
@onready var _threat_label: Label = %ThreatLabel
@onready var _enemies_label: Label = %EnemiesLabel
@onready var _player_label: Label = %PlayerLabel
@onready var _scrap_label: Label = %ScrapLabel


func _ready() -> void:
	if not _is_debug_allowed():
		queue_free()
		return
	visible = false
	Magnetide.register_debug_panel(self)
	_populate_static_dropdowns()
	_connect_actions()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("debug_toggle_panel"):
		return
	if event is InputEventKey and event.echo:
		return
	_set_panel_open(not visible)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_update_input_capture()
	_update_readout()
	_tick_wipe_confirm(delta)
	_context_refresh_remaining -= delta
	if _context_refresh_remaining <= 0.0:
		_context_refresh_remaining = CONTEXT_REFRESH_INTERVAL
		_refresh_context()


func _set_panel_open(open: bool) -> void:
	visible = open
	if open:
		_refresh_context()
		return
	var focus := _panel.get_viewport().gui_get_focus_owner()
	if focus != null and _panel.is_ancestor_of(focus):
		focus.release_focus()
	Magnetide.debug_ui_input_captured = false


## The panel is available in debug builds always, and in release builds only
## behind the --debug-panel launch flag.
static func _is_debug_allowed() -> bool:
	if OS.is_debug_build():
		return true
	return DEBUG_LAUNCH_FLAG in OS.get_cmdline_args() \
		or DEBUG_LAUNCH_FLAG in OS.get_cmdline_user_args()


func _connect_actions() -> void:
	_spawn_random_enemy_button.pressed.connect(_on_spawn_random_enemy_pressed)
	_spawn_enemy_button.pressed.connect(_on_spawn_enemy_pressed)
	_kill_all_enemies_button.pressed.connect(_on_kill_all_enemies_pressed)
	_add_threat_button.pressed.connect(_on_add_threat_pressed)
	_advance_threat_button.pressed.connect(_on_advance_threat_level_pressed)
	_fill_threat_button.pressed.connect(_on_fill_threat_pressed)
	_spawn_pile_button.pressed.connect(_on_spawn_salvage_pile_pressed)
	_extract_button.pressed.connect(_on_extract_pressed)
	_fail_run_button.pressed.connect(_on_fail_run_pressed)

	_heal_button.pressed.connect(_on_heal_pressed)
	_kill_player_button.pressed.connect(_on_kill_player_pressed)
	_god_mode_button.toggled.connect(_on_god_mode_toggled)
	_refill_ammo_button.pressed.connect(_on_refill_ammo_pressed)
	_damage_mult_button.pressed.connect(_on_damage_mult_pressed)
	_equip_weapon_button.pressed.connect(_on_equip_weapon_pressed)

	_add_scrap_button.pressed.connect(_on_add_scrap_pressed)
	_add_research_button.pressed.connect(_on_add_research_pressed)
	_add_item_button.pressed.connect(_on_add_item_pressed)
	_spawn_artifact_button.pressed.connect(_on_spawn_artifact_pressed)
	_unlock_research_button.pressed.connect(_on_unlock_research_pressed)
	_grant_upgrade_button.pressed.connect(_on_grant_upgrade_pressed)
	_max_upgrades_button.pressed.connect(_on_max_upgrades_pressed)

	_force_save_button.pressed.connect(_on_force_save_pressed)
	_wipe_save_button.pressed.connect(_on_wipe_save_pressed)
	_open_save_folder_button.pressed.connect(_on_open_save_folder_pressed)
	_start_run_button.pressed.connect(_on_start_run_pressed)
	_abandon_run_button.pressed.connect(_on_abandon_run_pressed)
	_go_station_button.pressed.connect(_on_go_station_pressed)
	_go_map_button.pressed.connect(_on_go_map_pressed)
	_go_menu_button.pressed.connect(_on_go_menu_pressed)

	_time_quarter_button.pressed.connect(_on_time_scale_pressed.bind(0.25))
	_time_one_button.pressed.connect(_on_time_scale_pressed.bind(1.0))
	_time_two_button.pressed.connect(_on_time_scale_pressed.bind(2.0))
	_time_four_button.pressed.connect(_on_time_scale_pressed.bind(4.0))
	_pause_button.toggled.connect(_on_pause_toggled)
	_cycle_music_button.pressed.connect(_on_cycle_music_pressed)


# =============================================================================
# Level actions
# =============================================================================

func _on_spawn_random_enemy_pressed() -> void:
	var spawner := _get_enemy_spawner()
	if spawner:
		spawner.force_spawn_random_enemy()


func _on_spawn_enemy_pressed() -> void:
	var spawner := _get_enemy_spawner()
	if spawner == null or _enemy_dropdown.selected < 0:
		return
	var id: Variant = _enemy_dropdown.get_selected_metadata()
	if id is StringName:
		spawner.force_spawn_enemy_by_id(id)


func _on_kill_all_enemies_pressed() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			(enemy as Enemy).take_damage(1e9)


func _on_add_threat_pressed() -> void:
	var threat := _get_threat_manager()
	if threat:
		threat.add_threat(_parse_float(_threat_amount_edit, 20.0))


func _on_advance_threat_level_pressed() -> void:
	var threat := _get_threat_manager()
	if threat and threat.can_advance():
		threat.advance()


## Fill the current threat level so its interlevel window opens right away. Also
## the only route into a storm, since storms run when a gate's window is continued.
func _on_fill_threat_pressed() -> void:
	var threat := _get_threat_manager()
	if threat:
		threat.add_threat(ThreatManager.MAX_THREAT)


func _on_spawn_salvage_pile_pressed() -> void:
	var spawner := _get_salvage_spawner()
	if spawner:
		spawner.spawn_on_demand()


func _on_extract_pressed() -> void:
	var run := _get_run()
	if run:
		run.request_end_run(RunResult.EndReason.VOLUNTARY_DEPARTURE)


func _on_fail_run_pressed() -> void:
	var run := _get_run()
	if run:
		run.request_end_run(RunResult.EndReason.PLAYER_DESTROYED)


# =============================================================================
# Player actions
# =============================================================================

func _on_heal_pressed() -> void:
	var player := _get_player()
	if player:
		player.heal(_parse_float(_heal_amount_edit, player.max_health))


func _on_kill_player_pressed() -> void:
	var player := _get_player()
	if player == null:
		return
	if player.invulnerable:
		player.invulnerable = false
		_god_mode_button.set_pressed_no_signal(false)
	player.apply_storm_damage(player.current_health)


func _on_god_mode_toggled(pressed: bool) -> void:
	var player := _get_player()
	if player:
		player.invulnerable = pressed


func _on_refill_ammo_pressed() -> void:
	var player := _get_player()
	if player:
		player.refill_ammo()


func _on_damage_mult_pressed() -> void:
	var player := _get_player()
	if player:
		player.outgoing_damage_multiplier = maxf(_parse_float(_damage_mult_edit, 1.0), 0.0)


func _on_equip_weapon_pressed() -> void:
	var loadout := _get_loadout()
	if loadout == null or _weapon_dropdown.selected < 0:
		return
	var weapon := _weapon_dropdown.get_selected_metadata() as WeaponData
	if weapon == null:
		return
	loadout.set_item_unlocked(weapon, true)
	loadout.equip_weapon(weapon)
	_apply_loadout_to_player(loadout)
	_persist_save_data()


# =============================================================================
# Station / economy actions
# =============================================================================

func _on_add_scrap_pressed() -> void:
	var save_data := _get_save_data()
	if save_data == null:
		return
	save_data.add_scrap_metal(_parse_int(_scrap_amount_edit, 1000))
	_persist_save_data()


func _on_add_research_pressed() -> void:
	var save_data := _get_save_data()
	if save_data == null:
		return
	save_data.add_research_points(SalvageItemData.ItemRarity.COMMON, _parse_int(_research_common_edit, 10))
	save_data.add_research_points(SalvageItemData.ItemRarity.RARE, _parse_int(_research_rare_edit, 10))
	save_data.add_research_points(SalvageItemData.ItemRarity.EPIC, _parse_int(_research_epic_edit, 10))
	_persist_save_data()


func _on_add_item_pressed() -> void:
	var save_data := _get_save_data()
	if save_data == null or _item_dropdown.selected < 0:
		return
	var item := _item_dropdown.get_selected_metadata() as SalvageItemData
	if item == null:
		return
	save_data.add_storage_item(item, maxi(_parse_int(_item_qty_edit, 1), 1))
	_persist_save_data()


func _on_spawn_artifact_pressed() -> void:
	var ship := Magnetide.ship as Ship
	if ship:
		ship.spawn_debug_research_artifact()


func _on_unlock_research_pressed() -> void:
	var save_data := _get_save_data()
	var loadout := _get_loadout()
	if save_data == null or loadout == null:
		return
	for item in unlock_items:
		if item == null:
			continue
		loadout.set_item_unlocked(item, true)
		save_data.unlock_research_id(item.item_id)
	for slot_id in unlock_slot_ids:
		loadout.set_slot_unlocked(slot_id, true)
		save_data.unlock_research_id(slot_id)
	loadout.prepare_for_run()
	_apply_loadout_to_player(loadout)
	_persist_save_data()


func _on_grant_upgrade_pressed() -> void:
	var loadout := _get_loadout()
	if loadout == null or _upgrade_dropdown.selected < 0:
		return
	var item := _upgrade_dropdown.get_selected_metadata() as ItemData
	if item == null:
		return
	if loadout.increase_upgrade(item.item_id, _parse_int(_upgrade_levels_edit, 1)):
		_apply_loadout_to_player(loadout)
		_persist_save_data()


func _on_max_upgrades_pressed() -> void:
	var loadout := _get_loadout()
	if loadout == null:
		return
	var changed := false
	for item in upgrade_items:
		if item == null:
			continue
		var max_level := loadout.get_upgrade_max_level(item.item_id)
		if max_level <= 0:
			continue
		changed = loadout.increase_upgrade(item.item_id, max_level) or changed
	if changed:
		_apply_loadout_to_player(loadout)
	_persist_save_data()


# =============================================================================
# Save & flow actions
# =============================================================================

func _on_force_save_pressed() -> void:
	var save_data := _get_save_data()
	if save_data:
		save_data.save_to_disk()


func _on_wipe_save_pressed() -> void:
	if _wipe_confirm_remaining <= 0.0:
		_wipe_confirm_remaining = WIPE_CONFIRM_SECONDS
		_wipe_save_button.text = WIPE_CONFIRM_TEXT
		return
	_wipe_confirm_remaining = 0.0
	_wipe_save_button.text = WIPE_BUTTON_TEXT
	var app_root := _get_app_root()
	var save_data := _get_save_data()
	if app_root == null or save_data == null:
		return
	save_data.reset_to_default(app_root.default_run_loadout)
	save_data_changed.emit()
	app_root.show_main_menu()


func _on_open_save_folder_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path("user://"))


func _on_start_run_pressed() -> void:
	var app_root := _get_app_root()
	if app_root:
		app_root.start_run()


func _on_abandon_run_pressed() -> void:
	var app_root := _get_app_root()
	if app_root and _get_run() != null:
		app_root.abandon_run_to_station()


func _on_go_station_pressed() -> void:
	var app_root := _get_app_root()
	if app_root:
		app_root.show_station_screen()


func _on_go_map_pressed() -> void:
	var app_root := _get_app_root()
	if app_root:
		app_root.show_map_screen()


func _on_go_menu_pressed() -> void:
	var app_root := _get_app_root()
	if app_root:
		app_root.show_main_menu()


# =============================================================================
# World actions
# =============================================================================

func _on_time_scale_pressed(time_scale: float) -> void:
	Engine.time_scale = time_scale


func _on_pause_toggled(pressed: bool) -> void:
	get_tree().paused = pressed


func _on_cycle_music_pressed() -> void:
	if Magnetide.bgm:
		Magnetide.bgm.cycle_debug_volume()


# =============================================================================
# Context / display refresh
# =============================================================================

## Enable/disable rows from the live context. Rows stay visible when
## inapplicable so the layout is stable (spec: disabled, not hidden).
func _refresh_context() -> void:
	var run := _get_run()
	var player := _get_player()
	var threat := _get_threat_manager()
	var save_data := _get_save_data()
	var app_root := _get_app_root()
	var in_run := run != null

	_spawn_random_enemy_button.disabled = _get_enemy_spawner() == null
	_spawn_enemy_button.disabled = _get_enemy_spawner() == null
	_kill_all_enemies_button.disabled = not in_run
	_add_threat_button.disabled = threat == null
	_advance_threat_button.disabled = threat == null or not threat.can_advance()
	_fill_threat_button.disabled = threat == null
	_spawn_pile_button.disabled = _get_salvage_spawner() == null
	_extract_button.disabled = not in_run
	_fail_run_button.disabled = not in_run

	var has_player := player != null
	_heal_button.disabled = not has_player
	_kill_player_button.disabled = not has_player
	_god_mode_button.disabled = not has_player
	_refill_ammo_button.disabled = not has_player
	_damage_mult_button.disabled = not has_player
	if has_player:
		_god_mode_button.set_pressed_no_signal(player.invulnerable)

	var has_save := save_data != null
	_equip_weapon_button.disabled = not has_save
	_grant_upgrade_button.disabled = not has_save
	_add_scrap_button.disabled = not has_save
	_add_research_button.disabled = not has_save
	_add_item_button.disabled = not has_save
	_spawn_artifact_button.disabled = Magnetide.ship == null
	_unlock_research_button.disabled = not has_save
	_max_upgrades_button.disabled = not has_save
	_force_save_button.disabled = not has_save
	_wipe_save_button.disabled = not has_save

	_start_run_button.disabled = app_root == null
	_abandon_run_button.disabled = app_root == null or not in_run
	_go_station_button.disabled = app_root == null
	_go_map_button.disabled = app_root == null
	_go_menu_button.disabled = app_root == null

	_pause_button.set_pressed_no_signal(get_tree().paused)
	_cycle_music_button.disabled = Magnetide.bgm == null

	_refresh_enemy_dropdown()
	_update_scroll_size()


func _update_readout() -> void:
	_fps_label.text = "FPS: %d" % roundi(Engine.get_frames_per_second())

	var threat := _get_threat_manager()
	if threat:
		_threat_label.text = "Threat: %.1f/100  Lv %d/%d (cap %d)" % [
			threat.current_threat,
			threat.get_player_threat_level(),
			ThreatManager.LEVEL_COUNT,
			threat.threat_level_cap + 1,
		]
	else:
		_threat_label.text = "Threat: -"

	_enemies_label.text = "Enemies: %d" % get_tree().get_nodes_in_group("enemies").size()

	var player := _get_player()
	if player:
		_player_label.text = "Player: HP %d/%d  Shield %d  Ammo %d/%d" % [
			roundi(player.current_health),
			roundi(player.max_health),
			player.current_shield,
			player.get_current_ammo(),
			player.get_current_magazine_size(),
		]
	else:
		_player_label.text = "Player: -"

	var run := _get_run()
	if run:
		_scrap_label.text = "Scrap (run): %d" % run.scrap_metal_collected
	else:
		var save_data := _get_save_data()
		_scrap_label.text = "Scrap (bank): %d" % (save_data.total_scrap_metal if save_data else 0)


## Gameplay must ignore input aimed at the panel: capture while the pointer is
## over it or one of its controls has keyboard focus.
func _update_input_capture() -> void:
	var over_panel := _panel.get_global_rect().has_point(_panel.get_global_mouse_position())
	var focus := _panel.get_viewport().gui_get_focus_owner()
	var focus_in_panel := focus != null and _panel.is_ancestor_of(focus)
	Magnetide.debug_ui_input_captured = over_panel or focus_in_panel


func _tick_wipe_confirm(delta: float) -> void:
	if _wipe_confirm_remaining <= 0.0:
		return
	_wipe_confirm_remaining -= delta
	if _wipe_confirm_remaining <= 0.0:
		_wipe_save_button.text = WIPE_BUTTON_TEXT


## Width follows content; height is capped to the viewport so long panels
## scroll instead of running off screen.
func _update_scroll_size() -> void:
	var content := _groups.get_combined_minimum_size()
	var max_height := get_viewport().get_visible_rect().size.y - SCROLL_VIEWPORT_MARGIN * 2.0
	var needs_scroll := content.y > max_height
	var scrollbar_width := _scroll.get_v_scroll_bar().get_combined_minimum_size().x if needs_scroll else 0.0
	_scroll.custom_minimum_size = Vector2(content.x + scrollbar_width, minf(content.y, max_height))
	_panel.reset_size()


# =============================================================================
# Dropdowns
# =============================================================================

func _populate_static_dropdowns() -> void:
	for weapon in weapons:
		if weapon == null:
			continue
		_weapon_dropdown.add_item(_item_label(weapon))
		_weapon_dropdown.set_item_metadata(_weapon_dropdown.item_count - 1, weapon)
	for item in upgrade_items:
		if item == null:
			continue
		_upgrade_dropdown.add_item(_item_label(item))
		_upgrade_dropdown.set_item_metadata(_upgrade_dropdown.item_count - 1, item)
	for item in salvage_items:
		if item == null:
			continue
		_item_dropdown.add_item(item.item_name if not item.item_name.is_empty() else item.resource_path.get_file())
		_item_dropdown.set_item_metadata(_item_dropdown.item_count - 1, item)


func _refresh_enemy_dropdown() -> void:
	var spawner := _get_enemy_spawner()
	if spawner == null:
		if _enemy_dropdown.item_count > 0:
			_enemy_dropdown.clear()
		return
	var profiles := spawner.get_enemy_profiles()
	if _enemy_dropdown.item_count == profiles.size():
		return
	_enemy_dropdown.clear()
	for profile in profiles:
		if profile == null:
			continue
		_enemy_dropdown.add_item(String(profile.id))
		_enemy_dropdown.set_item_metadata(_enemy_dropdown.item_count - 1, profile.id)


static func _item_label(item: ItemData) -> String:
	if not item.display_name.is_empty():
		return item.display_name
	return String(item.item_id)


# =============================================================================
# Context accessors & helpers
# =============================================================================

func _get_app_root() -> AppRoot:
	return Magnetide.app_root as AppRoot


func _get_run() -> RunController:
	var run := Magnetide.run as RunController
	if run != null and is_instance_valid(run) and not run.is_run_ending():
		return run
	return null


func _get_player() -> Player:
	var player := Magnetide.player as Player
	if player != null and is_instance_valid(player):
		return player
	return null


func _get_save_data() -> AppSaveData:
	var app_root := _get_app_root()
	if app_root == null:
		return null
	return app_root.get_save_data() as AppSaveData


func _get_loadout() -> RunLoadout:
	var save_data := _get_save_data()
	if save_data == null:
		return null
	return save_data.current_run_loadout


func _get_level_child(child_name: String) -> Node:
	var level := Magnetide.level
	if level == null:
		return null
	return level.get_node_or_null(child_name)


func _get_enemy_spawner() -> EnemySpawner:
	return _get_level_child("EnemySpawner") as EnemySpawner


func _get_threat_manager() -> ThreatManager:
	return _get_level_child("ThreatManager") as ThreatManager


func _get_salvage_spawner() -> SalvageSpawner:
	return _get_level_child("SalvageSpawner") as SalvageSpawner


## Push loadout changes onto the live player (no-op outside a run: screens read
## the loadout directly).
func _apply_loadout_to_player(loadout: RunLoadout) -> void:
	var player := _get_player()
	if player:
		player.apply_run_loadout(loadout)


func _persist_save_data() -> void:
	var save_data := _get_save_data()
	if save_data:
		save_data.save_to_disk()
	save_data_changed.emit()


static func _parse_float(edit: LineEdit, default_value: float) -> float:
	var text := edit.text.strip_edges()
	if text.is_empty() or not text.is_valid_float():
		return default_value
	return text.to_float()


static func _parse_int(edit: LineEdit, default_value: int) -> int:
	var text := edit.text.strip_edges()
	if text.is_empty() or not text.is_valid_int():
		return default_value
	return text.to_int()
