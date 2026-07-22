# Debug Panel

A single in-game panel that centralizes all debugging functionality behind one keybind,
replacing the scattered debug hotkeys that currently live in individual scene scripts.

## 1. Goals

- One toggle (`` ` `` backtick by default) shows/hides a compact overlay panel available
  from any app state (menu, station, map, run, salvage).
- Every existing debug action moves into the panel; the ad-hoc hotkeys and their
  handlers are deleted in the same change (spec §6: no parallel old/new paths).
- Buttons are grouped by concept with headers; parameterized actions get inline
  text boxes / dropdowns next to their button.
- Actions that don't apply to the current context are disabled (greyed out), not hidden,
  so the panel layout is stable and discoverable.
- The panel is a development tool: it must never ship active in a release build.

## 2. Inventory of existing debug functionality (all absorbed by the panel)

| Current trigger | Location | Behavior | Fate |
|---|---|---|---|
| `debug_spawn_enemy` action (**Y**) | `level.gd` `_unhandled_input` → `EnemySpawner.force_spawn_random_enemy()` | Spawn one random roster enemy, bypassing timer/threat gating | Panel button; action + handler deleted |
| `debug_add_research_points` action (**P**) | `station_screen.gd` `_debug_grant_research_points()` | +1 research point of each rarity, refresh UI | Panel button (with amounts); action + handler deleted |
| `debug_cycle_music` action (**M**) | `bgm_player.gd` (dormant — `BgmPlayer` autoload is commented out in `magnetide.gd`) | Cycle music bus volume 0.5 → 0 → 1 | Keybind + input handler deleted; `cycle_debug_volume()` stays and backs a World-group button that is disabled while `BgmPlayer` is dormant |
| Raw **T** key | `threat_manager.gd` `_unhandled_input` | `add_threat(DEBUG_THREAT_ADD_AMOUNT)` (+20) | Panel button with amount box; handler + constant deleted |
| Raw **U** key | `threat_manager.gd` `_unhandled_input` | `raise_cap()` (advance threat level) | Panel button; handler deleted |
| `@export spawn_debug_research_artifact_in_storage := true` | `ship.gd` | Mints a Common test artifact into ship storage on ready | Export default flips to `false`; panel gets a "spawn research artifact" button |

Not debug UI, unchanged: `research_station.gd`'s `debug_research_duration` timer fallback
(only runs when no research UI exists) and all `Engine.is_editor_hint()` editor-preview
guards.

None of today's debug hotkeys are gated on build type — they are live in release builds.
The panel fixes this (§4).

## 3. Placement & architecture

- New top-level concept folder **`_project/debug/`** containing `debug_panel.tscn`,
  `debug_panel.gd` (`class_name DebugPanel`). `project_organization.md` §2's folder map
  and `folder_colors` are updated in the same commit.
- `app_root.tscn` authors the panel as its last child (a `CanvasLayer` with a high
  `layer`, e.g. 100) so it overlays every screen and the run HUD. It is authored in the
  scene, not instanced from code (spec §8).
- The panel's structure — groups, headers, buttons, inputs — is authored in
  `debug_panel.tscn`. Only content that is genuinely runtime-derived (dropdown option
  lists) is populated from code. Handler wiring uses editor signal connections or
  `@onready` references; `debug_panel.gd` holds one small handler per action that calls
  into the owning system (it contains no gameplay logic of its own).
- The panel reaches systems exclusively through the existing service locator:
  `Magnetide.app_root / .run / .level / .player / .hotbar` plus
  `Magnetide.level.get_node_or_null("EnemySpawner" / "ThreatManager" / "SalvageSpawner")`.

## 4. Availability & toggle

- New input action **`debug_toggle_panel`**, default binding QuoteLeft (`` ` ``,
  physical keycode 96). The key is currently unbound.
- Available when **`OS.is_debug_build()`** is true **or** the launch flag
  `--debug-panel` is present (checked in both `OS.get_cmdline_user_args()` and
  `OS.get_cmdline_args()`, so `magnetide.exe --debug-panel` and
  `magnetide.exe -- --debug-panel` both work). Otherwise the panel frees itself in
  `_ready()` and the toggle does nothing. This is a deliberate behavior change — today's
  debug keys ship live in release builds; after this change a release build needs the
  flag to expose any debug functionality.
- The toggle is handled in the panel's `_input()` (not `_unhandled_input`) and marks the
  event handled, so it works even while a game control or panel text box has focus.
- Toggling **does not pause the game**; effects are observed live. Pausing is itself a
  panel action (§6, World group).

### Input capture

While the panel is visible, game input must not leak through it:

- The panel root `Control` uses `mouse_filter = STOP` so clicks on it never reach the
  world, and a new `Magnetide.debug_ui_input_captured: bool` is true whenever the
  pointer is over the panel or one of its text boxes has focus.
- The two existing `research_ui_input_captured` checks (`player.gd` weapon input,
  formerly `level.gd`'s debug handler) are widened to a single helper
  `Magnetide.is_ui_input_captured() -> bool` returning either flag, so typing an amount
  or clicking a button never fires the weapon.
- Closing the panel releases focus from any of its controls.

## 5. Panel UI

- `CanvasLayer` → `PanelContainer` anchored **top-right** with a solid, slightly
  translucent `StyleBoxFlat` background, using `magnetide_theme.tres` fonts.
- Sized to fit content only: `VBoxContainer` of groups; each group is a header `Label`
  plus rows (`HBoxContainer`) of `Button` + optional `LineEdit` / `OptionButton` /
  `SpinBox`. If total height exceeds the viewport, the group list scrolls inside a
  `ScrollContainer` capped at screen height; width stays content-sized.
- Amount boxes are `LineEdit`s with placeholder text showing the default (e.g. `20`);
  empty input uses the default. Non-numeric input is ignored.
- Context gating: on visibility and on a short refresh timer, each group enables/disables
  its rows from context (`Magnetide.run != null` for run-only actions, save data present
  for station/economy actions). Disabled rows stay visible.
- Dropdowns populate on first open: enemies from the live `EnemySpawner.enemy_profiles`
  (id + display name), equipment/items from preloaded catalog lists (§7).

## 6. Groups & actions

Amount defaults shown in parentheses; `[text]` = LineEdit, `[dropdown]` = OptionButton.

### Level *(enabled only in a run)*

| Action | Input | Implementation |
|---|---|---|
| Spawn random enemy | — | `EnemySpawner.force_spawn_random_enemy()` |
| Spawn enemy by id | `[dropdown: enemy id]` | new `EnemySpawner.force_spawn_enemy_by_id(id: StringName)` (§7) |
| Kill all enemies | — | iterate group `"enemies"`, kill each |
| Add threat | `[text amount (20)]` | `ThreatManager.add_threat(amount)` |
| Advance threat level | — | `ThreatManager.raise_cap()` (disabled when `not can_raise_cap()`) |
| Trigger storm | — | `ThreatManager.trigger_storm()` |
| Spawn salvage pile | — | `SalvageSpawner.spawn_on_demand()` |
| Extract (end run, keep loot) | — | `RunController.request_end_run(RunResult.EndReason.VOLUNTARY_DEPARTURE)` |
| Fail run | — | `request_end_run(RunResult.EndReason.PLAYER_DESTROYED)` |

### Player *(enabled only in a run)*

| Action | Input | Implementation |
|---|---|---|
| Heal player | `[text amount (full)]` | `Player.heal(amount)`; empty = `max_health` |
| Kill player | — | `Player.take_damage(current_health, null)` |
| God mode (toggle) | — | new `Player.invulnerable` flag (§7); button shows state |
| Refill ammo | — | `Player._init_weapon_ammo()` made public as `refill_ammo()` (§7) |
| Damage multiplier | `[text multiplier (1.0)]` | `Player.outgoing_damage_multiplier = value` |
| Equip weapon | `[dropdown: weapon]` | loadout `equip_weapon(w)` → `prepare_for_run()` → `Player.apply_run_loadout(loadout)` → `save_to_disk()`; hotbar repopulates automatically |
| Grant upgrade level | `[dropdown: upgradeable item]` `[text levels (1)]` | `RunLoadout.increase_upgrade(item_id, n)` → apply + persist as above |

Note on "equip item in slot": at runtime the hotbar mirrors `RunLoadout`'s derived
equipment — slot 0 is always the equipped weapon, slot 1 the magnet tool. There is no
per-slot assignment to force; **Equip weapon** already updates loadout + hotbar
consistently and persists into the save. Free-form "any item in any hotbar slot" would
require restructuring `RunLoadout` to N held-item slots — out of scope here; if wanted,
it becomes its own feature spec.

### Station / economy *(enabled whenever save data exists — works mid-run too)*

| Action | Input | Implementation |
|---|---|---|
| Add scrap metal | `[text amount (1000)]` | `AppSaveData.add_scrap_metal(amount)` |
| Add research points | `[text common (10)] [text rare (10)] [text epic (10)]` | `add_research_points(rarity, amount)` per non-zero box (only Common/Rare/Epic exist) |
| Add item to storage | `[dropdown: salvage item]` `[text qty (1)]` | `AppSaveData.add_storage_item(item, qty)` + explicit `save_to_disk()` (the merge-into-stack path skips the autosave) |
| Spawn research artifact | — | reuse `ship.gd`'s `_spawn_debug_research_artifact_in_storage()` (run-only; replaces the always-on export) |
| Unlock all research | — | iterate every `UpgradeCatalogEntry` research id across station slots → `unlock_research_id()` + `set_slot_unlocked()` (mirrors `StationScreen._sync_research_unlocks_to_loadout()`) |
| Max all upgrades | — | for each upgradeable item id: `increase_upgrade(id, max)` → apply + persist |

When the station screen is open, economy actions finish by refreshing it (the panel
emits a signal `save_data_changed`; `StationScreen` connects and re-runs its refresh).

### Save & flow

| Action | Input | Implementation |
|---|---|---|
| Force save | — | `AppSaveData.save_to_disk()` |
| Wipe save | — | two-step confirm (button turns into "Confirm wipe?" for 3 s) → `reset_to_default(app_root.default_run_loadout)` → main menu |
| Open save folder | — | `OS.shell_open(ProjectSettings.globalize_path("user://"))` |
| Start run | — | `AppRoot.start_run()` (default level + current loadout) |
| Abandon run → station | — | `AppRoot.abandon_run_to_station()` (run only) |
| Go to station / map / menu | — | new public `AppRoot.show_station_screen()` / `show_map_screen()` / `show_main_menu()` wrappers (§7) |

### World *(anywhere)*

| Action | Input | Implementation |
|---|---|---|
| Time scale | buttons `0.25× / 1× / 2× / 4×` | `Engine.time_scale` |
| Pause / resume | — | `get_tree().paused` toggle (panel's CanvasLayer runs with `PROCESS_MODE_ALWAYS`) |
| Cycle music volume | — | `BgmPlayer.cycle_debug_volume()`; **disabled** while the `BgmPlayer` autoload is commented out, enabled automatically once the node exists again |

### Readout *(bottom of panel, labels not buttons)*

Live one-line stats refreshed while visible: FPS; in-run: threat `value/100 (level x/10,
cap y)`, enemy count, player HP/shield/ammo, scrap collected this run. Cheap to build,
saves opening the remote inspector for the most common questions.

## 7. Supporting code changes

Small API additions, each in its owning system:

1. `EnemySpawner.force_spawn_enemy_by_id(id: StringName) -> void` — find the profile in
   `enemy_profiles` by id, spawn via the existing private spawn path, ignoring
   timer/threat/zone gating like `force_spawn_random_enemy()` does.
2. `Player.invulnerable: bool = false` — early-return guard at the top of
   `take_damage()` and `apply_storm_damage()`. (`combat_disabled` is not suitable: it
   also disables the player's own weapons.)
3. `Player.refill_ammo() -> void` — public wrapper for the current private
   `_init_weapon_ammo()` reseed.
4. `AppRoot.show_station_screen() / show_map_screen() / show_main_menu()` — thin public
   wrappers over the existing private `_show_*` methods.
5. `Magnetide.debug_ui_input_captured: bool` + `is_ui_input_captured() -> bool`
   (research flag OR debug flag); `player.gd` switches to the helper.
6. Deletions: the three `debug_*` input actions from `project.godot`; the handlers in
   `level.gd`, `station_screen.gd`, and `bgm_player.gd`'s `_unhandled_input`
   (`cycle_debug_volume()` itself stays — the panel calls it); the T/U block and
   `DEBUG_THREAT_ADD_AMOUNT` in `threat_manager.gd`; `ship.gd`'s debug-artifact export
   default flips to `false`.

Dropdown data sources: enemies enumerate the live spawner's `enemy_profiles`; weapons,
upgradeable items, and salvage items come from `preload`ed catalog arrays authored as
`@export` lists on `DebugPanel` in `debug_panel.tscn` (spec §9 — content in data, and no
reliance on `DirAccess` directory listing, which breaks under `.remap` in exports).
When a new weapon/salvage item is added, it is added to the panel's exported list —
same one-line authoring step as registering it anywhere else.

## 8. Non-goals

- No command console / text parser — buttons only.
- No persistence of panel state between sessions (open state and typed values reset).
- No per-slot hotbar assignment (see Player group note).
- No mobile/controller affordances; keyboard + mouse only.
- No replacement for the Godot remote inspector — the readout covers only high-traffic
  values.

## 9. Resolved decisions

1. **Release gating:** available in release builds behind the `--debug-panel` launch
   flag; debug builds always have it (§4).
2. **Wipe-save confirm:** the two-step in-place button confirm is sufficient; no
   `ConfirmationDialog`.
3. **Music volume cycling:** kept as a World-group button, disabled while `BgmPlayer`
   is dormant.
