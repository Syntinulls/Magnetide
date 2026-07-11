# Project Organization & Coding Conventions

This document defines how the Magnetide project is structured and the conventions all
future work (human or LLM) must follow. When adding, moving, or reviewing files, this
is the reference. If a change genuinely doesn't fit these rules, update this document
in the same commit that breaks the pattern.

## 1. Organizing principle: concepts, not file types

Files are grouped by **game concept** (player, ship, salvage, enemies, ...), never by
file type (scenes/, scripts/, sprites/). Everything a concept needs — scripts, scenes,
resources, shaders, textures — lives together under that concept's folder. Raw asset
files sit in a `sprites/` subfolder of their concept only to keep listings readable;
they still belong to the concept, not to a global asset pool.

Rules of thumb:

- A file lives with the concept that **owns** it, not the concept that happens to
  instantiate it at runtime (e.g. enemy spawning config lives in `enemies/spawning/`
  even though the level instantiates the spawner).
- A world object and the UI it exclusively owns live together
  (e.g. the research station and its minigame UI are both `ship/research/`).
- Code used by two or more concepts moves to `combat/` (gameplay primitives) or
  `common/` (generic helpers). A helper with a single consumer stays with its consumer.

## 2. Folder map

```
_project/                    All game content. (Root level is reserved for engine/tooling files.)
├── app/                     Application shell: entry scene, save data, global autoload.
│   ├── app_root.*           Top-level state machine (menu ↔ station ↔ map ↔ run ↔ salvage).
│   ├── app_save_data.gd     Persistent save resource + legacy path migration.
│   ├── magnetide.gd         The `Magnetide` autoload: run-context service locator, fonts, sfx.
│   └── screens/             One folder per out-of-run screen.
│       ├── main_menu/
│       ├── map/             Level-select screen + its roster data + its sprites.
│       ├── station/         Station hub screen + slot widgets + popups.
│       ├── salvage/         Salvage-processing minigame screen + run summary popup.
│       └── preview/         Render-only player/ship preview stages (shared by screens).
├── audio/                   Audio playback services + assets: sfx_player.gd + sfx/,
│                            bgm_player.gd + bgm/ (looping background music, own bus).
├── combat/                  Combat primitives shared across concepts:
│                            projectile, hitbox, enemy_target_point, muzzle_effect.
├── common/                  Generic, game-agnostic building blocks:
│                            utils.gd (static helpers), weighted_random, interaction_hitbox,
│                            shared outline shaders (border_outline, composite_outline).
├── enemies/                 Enemy entity, data, AI, and spawning.
│   ├── enemy.*              The enemy body + state machine.
│   ├── enemy_data.gd        Stats/config resource.
│   ├── behaviors/           Behavior resources (EnemyBehavior base + move/attack).
│   ├── spawning/            EnemySpawner + EnemySpawnProfile (threat-scaled spawn rules).
│   └── worm/                Per-enemy content: data .tres, spawn profile, sprites.
├── items/                   Meta-progression item data model (definitions, not world objects).
│   ├── upgradeable_item_data.gd, stat_upgradeable_item_data.gd,
│   │   upgrade_slot_definition.gd, slottable_catalog_entry.gd
│   ├── equipment/           EquipmentData/WeaponData/MagnetToolData + fire behaviors
│   │                        + per-weapon folders (rifle/, shotgun/) with their .tres + sprites.
│   └── augments/            AugmentData + behavior scripts + augment .tres + sprites.
├── level/                   The world during a run (presentation + simulation, not spawnable content).
│   ├── level.*              Root run scene; level_definition.gd (playable-level data).
│   ├── viewport_anchor.gd   Viewport-relative positioning helper.
│   ├── decoration/          Parallax layers, skyline, bands, decoration shaders + sprites.
│   └── threat/              Threat simulation: ThreatManager, StormController.
├── player/                  The player character: player.* + sprites.
├── run/                     One run's lifecycle & mutable state: RunController, RunLoadout,
│                            RunResult, upgrade definitions/costs, item/slot states,
│                            RunArtifactTracker.
├── salvage/                 The salvage domain, end to end:
│   ├── salvage_item.gd      In-world salvage RigidBody2D (pull/freeze/storage behavior).
│   ├── salvage_item_data.gd + salvage_part_entry.gd + salvage_item_cost.gd (data model).
│   ├── catalog/             All salvage item definition .tres files.
│   ├── sprites/             Salvage + part textures.
│   ├── pile/                World salvage piles (scene, shader, pile data).
│   ├── loot/                Loot generation config: pools, rarity weights, artifact pools.
│   └── salvage_spawner.*    Timed pile spawning.
├── ship/                    The salvage platform and everything mounted on it.
│   ├── ship.*               Hull, storage zone, thruster driver, combat surface.
│   ├── thruster.*, departure_pylon.*, recycler.*
│   ├── magnet/              Ship magnet + lever + minigame/ (looting cycle) + nine-patch shader.
│   └── research/            Research station + its UI + research minigames.
└── ui/                      In-run HUD and shared UI: game_ui, hotbar, threat_ui,
                             magnet_capacity, event_text_display, control prompts,
                             player_progress_bar, theme, fonts/, sprites/.
```

Top-level support folders outside `_project/`:

- `specs/` — design/spec documents (this file included).
- `releases/` — packaged builds.
- Root: `project.godot`, `icon.svg`, `readme.md`, editor/tooling config.

### Where does a new file go?

1. Is it a new screen? → `app/screens/<screen_name>/`.
2. Is it content for an existing concept? → that concept's folder (new enemy → `enemies/<name>/`,
   new weapon → `items/equipment/<name>/`, new salvage item → `salvage/catalog/` + `salvage/sprites/`).
3. Is it a world object mounted on the ship? → `ship/<name>/` (with its UI if it owns one).
4. Is it used by 2+ concepts? → `combat/` if it's a gameplay primitive, `common/` otherwise.
5. None of the above → new top-level concept folder, added to the map above in the same commit.

## 3. Naming conventions

| Thing | Convention | Example |
|---|---|---|
| Folders | `snake_case`, singular for a system, plural for collections | `salvage/`, `enemies/`, `screens/` |
| Files (.gd/.tscn/.tres/.gdshader/assets) | `snake_case` | `salvage_item_data.gd` |
| Script ↔ class | `class_name` is the PascalCase of the file name | `run_loadout.gd` → `RunLoadout` |
| Scene ↔ script | A scene and its root script share the same stem | `enemy.tscn` / `enemy.gd` |
| Classes | `PascalCase`; prefix only to avoid engine-class clashes | `LevelParallaxBackground` (engine has `ParallaxBackground`) |
| Functions / variables | `snake_case`; private members prefixed `_` | `_apply_pull_force()` |
| Constants / enums | `CONSTANT_CASE`; enum type names PascalCase | `MAX_THREAT`, `enum Phase` |
| Signals | past tense for events, noun phrases for state changes | `died`, `threat_changed` |
| Data resources | end in `_data` (config) or `_state` (mutable runtime state) | `enemy_data.gd`, `upgrade_slot_state.gd` |
| Behavior/strategy resources | end in `_behavior` | `default_move_behavior.gd` |
| UI scripts | suffix says what it is: `_screen`, `_popup`, `_bar`, `_display`, `_ui` (composite shells only) | `map_screen.gd`, `run_summary_popup.gd`, `game_ui.gd` |
| Autoload | registered name = PascalCase of script | `Magnetide` ← `magnetide.gd` |

File/class naming is 1:1: every `.gd` intended for reuse declares a `class_name`
matching its file name. Scene-only glue scripts may omit `class_name` only if nothing
references them by type.

## 4. Script layout

Order within a `.gd` file:

1. `extends` (line 1), `class_name` (line 2), `@tool`/`@icon` above `extends` if present
2. `##` doc comment describing the class's single responsibility
3. signals
4. enums, constants
5. `@export` variables
6. public variables, then private (`_`) variables
7. `@onready` variables
8. properties (getters/setters)
9. Godot lifecycle callbacks (`_init`, `_ready`, `_process`, ...)
10. public methods
11. private methods
12. static methods

Indentation is tabs. Typed declarations everywhere (`var x: int`, `-> void`), and
`:=` where the type is obvious from the right-hand side.

## 5. Comment policy

Comments state **constraints and non-obvious rationale** — things the code cannot say.
Everything else is noise and must not be committed:

- No change-narration: "now uses X", "no longer does Y", "formerly Z", "as per spec".
  Git history records what changed; the file describes only what **is**.
- No restating the obvious: `# play from beginning` above `play()`.
- No section banners for planned/stub systems ("NEW X SYSTEM (Stubs)"). If scaffolding
  isn't wired into a live code path in the same PR, it doesn't get committed.
- No TODO left behind after debugging (e.g. temporarily shortened timers). Debug
  tweaks are reverted before commit; real future work goes into `specs/`, not TODOs.
- `##` doc comments on classes and non-obvious public methods are encouraged — they
  should describe behavior and contracts, not history.

## 6. Code reuse rules

- A helper duplicated in a second file moves to a shared home in the same change:
  static/generic → `common/utils.gd`; gameplay primitive → `combat/`;
  domain-specific → a static method on the owning class (e.g.
  `UpgradeableItemData.is_same_item`).
- Dead code is deleted, not commented out and not kept "just in case". Unused signals,
  exports, and public functions count as dead code. If a system is worth keeping as an
  idea, describe it in `specs/` and delete the code.
- Accepted duplication (kept deliberately; consolidate only with a structural reason):
  ship/magnet combat-surface boilerplate (same shape, different node types and groups);
  parallax scroll/recycle logic (visually tuned per layer);
  `is_point_in_placement_area` in recycler/research_station (no shared script ancestor
  without rebasing Recycler onto InteractionHitbox).

## 7. Resource & reference hygiene

- Scenes/resources reference each other by `res://` path + UID. When moving files,
  move the `.uid`/`.import` companions with them and update all textual `res://`
  references (`*.gd`, `*.tscn`, `*.tres`, `*.import`, `project.godot`).
- Saved games store `res://` paths. Any move that affects `salvage/catalog/`,
  `salvage/sprites/`, item scripts, or equipment `.tres` files must add a
  corresponding rewrite rule to `AppSaveData._migrate_legacy_resource_paths()`.
- `project.godot` `folder_colors` should track the top-level concept folders.

## 8. Scenes over code for node structure

When a feature needs a node/scene structure — several nodes wired together, a
reusable UI component, a widget with children — author it as a `.tscn` scene
file, not by constructing and configuring nodes in code (`Node.new()`,
`add_child`, setting anchors/offsets/theme overrides imperatively). Scene files
are the developer-facing source of truth: they can be opened, previewed, and
tuned directly in the Godot editor without running the game.

Rules of thumb:

- **Large, clearly-defined concepts/scenes** (a HUD panel, a station widget, a
  popup, an item display, a minigame) get their own `.tscn` under the owning
  concept's folder, with a script sharing the scene's stem (see §3). Instance
  the scene — either authored directly into its parent scene, or `preload` +
  instantiate at the single point it's added.
- The script's job is behavior and data binding (populate labels, tint by
  rarity, react to signals), not building the layout. Structure lives in the
  scene; per-instance data the scene can't know is applied in `_ready`/refresh.
- **Superficial or purely-dynamic bits stay in code**: a lone label, a
  throwaway separator, or a list whose items are generated at runtime from data
  (N rows for N entries) don't need a scene. When a runtime list's row is itself
  non-trivial, make the *row* a `.tscn` and instance it per item.

If a change adds imperative node-tree construction for something that is really
a defined component, that's a smell — move it to a scene in the same change.

**But keep the file count down, too.** Prioritizing scenes over code does *not*
mean every component earns its own `.tscn`. A small UI component — the station's
research-points readout, say — isn't large enough to justify a standalone scene
file. Author it as a node structure **inside its parent scene** (the readout
lives directly under `station_screen.tscn`'s TopBar) rather than as a separate
`.tscn` that gets instanced in. It's still fully editor-tunable, just without
adding a file to the tree, and any behavior it needs lives on the parent scene's
script referencing the authored nodes by path. Reserve standalone `.tscn` files
for structures that are genuinely large, reused in more than one place, or
instanced many times at runtime; otherwise nest the nodes in the owning scene.

## 9. Specs

Each nontrivial feature gets a spec in `specs/` before/while it is built. Specs are
design history — they are not updated retroactively when code moves; this document is
the single source of truth for structure.
