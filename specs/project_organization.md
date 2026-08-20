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
  (e.g. the research station and its minigame UI are both `ship/research_station/`).
- Code used by two or more concepts moves to `combat/` (gameplay primitives) or
  `common/` (generic helpers). A helper with a single consumer stays with its consumer.

## 2. Folder map

```
_project/                    All game content. (Root level is reserved for engine/tooling files.)
├── app/                     Application shell: entry scene, save data, global autoload.
│   ├── app_root.*           Top-level state machine (menu ↔ station ↔ map ↔ run ↔ salvage).
│   ├── app_save_data.gd     Persistent save resource + legacy path migration.
│   ├── magnetide.gd         The `Magnetide` autoload: run-context service locator, fonts, sfx.
│   └── screens/             One folder per out-of-run screen. A screen keeps the sprites it
│       │                    alone uses in its own sprites/ subfolder.
│       ├── main_menu/
│       ├── map/             Level-select screen + its roster data + its sprites.
│       ├── station/         Station hub screen + slot widgets + popups + its sprites.
│       ├── salvage/         Salvage-processing minigame screen + run summary popup
│       │                    + its sprites.
│       └── preview/         Render-only player/ship preview stages (shared by screens).
├── audio/                   Audio playback services + assets: sfx_player.gd + sfx/,
│                            bgm_player.gd + bgm/ (looping background music, own bus).
├── combat/                  Combat primitives shared across concepts:
│                            projectile, hitbox, enemy_target_point, muzzle_effect.
├── common/                  Generic, game-agnostic building blocks:
│                            utils.gd (static helpers), weighted_random, interaction_hitbox,
│                            shared outline shaders (border_outline, composite_outline).
│   └── sprites/             Sprites with no single owner: reusable chrome (ui_border_*) and
│                            icons consumed by 2+ concepts (scrap_metal, icon_magnet,
│                            icon_crate, icon_research_point). A sprite used by exactly one
│                            concept belongs to that concept, not here.
├── debug/                   Development-only tooling: the debug panel overlay
│                            (debug_panel.*), active only in debug builds or behind the
│                            --debug-panel launch flag. See specs/debug_panel.md.
├── effects/                 Runtime status effects applied to combatants: the
│   │                        StatusEffect base (status_effect.gd) plus one folder per
│   │                        effect owning its scene, script, and sprites.
│   └── burning/             Burning DoT: scene, script, flame SpriteFrames + sheet.
├── enemies/                 Enemy entity, data, AI, and spawning.
│   ├── enemy.*              The enemy body + state machine.
│   ├── enemy_data.gd        Stats/config resource.
│   ├── behaviors/           Behavior resources (EnemyBehavior base + move/attack).
│   ├── spawning/            EnemySpawner + EnemySpawnProfile (threat-scaled spawn rules).
│   └── worm/                Per-enemy content: data .tres, spawn profile, sprites.
├── items/                   Meta-progression item data model (definitions, not world objects).
│   ├── item_data.gd         ItemData: base (identity + leveling) for every upgradeable item.
│   ├── held_item_data.gd    HeldItemData: hotbar/mounting base for every equippable item.
│   ├── held_item_behavior.gd  HeldItemBehavior: base for per-item equipped behavior. Each
│   │                        data class creates one live instance per hotbar slot (via
│   │                        create_use_behavior), which owns that slot's input handling and
│   │                        runtime state (ammo, held item, repair progress).
│   ├── upgrade_catalog_entry.gd  UpgradeCatalogEntry: one selectable item in a dynamic slot.
│   ├── weapons/             WeaponData + weapon_behavior (trigger/ammo/reload) +
│   │                        weapon_fire_behavior (per-weapon firing pattern) + per-weapon
│   │                        folders (pistol/, rifle/, ...) with their .tres + sprites.
│   ├── magnet_tool/         MagnetToolData + magnet_tool_behavior + magnet_gun.tres + sprites.
│   ├── repair_gun/          RepairGunData + repair_gun_behavior + repair_beam.* +
│   │                        repair_gun.tres + sprites.
│   └── augments/            AugmentData + behavior scripts + augment .tres + sprites.
├── level/                   The world during a run (presentation + simulation, not spawnable content).
│   ├── level.*              Root run scene; level_definition.gd (playable-level data).
│   ├── viewport_anchor.gd   Viewport-relative positioning helper.
│   ├── decoration/          Parallax layers, skyline, bands, decoration shaders + sprites.
│   ├── threat/              Threat simulation: ThreatManager, StormController.
│   └── magnet_minigame/     The looting-cycle minigame + its activation overlay, warning icon,
│                            vignette shader, sprites. Lives here, not under ship/magnet/:
│                            level.tscn instances it and game_ui.tscn owns its overlay — it
│                            never touches the ship, and exists only inside a run.
├── player/                  The player character. player.gd (the body: movement, facing,
│   │                        animation, combat-contract facade) manages component nodes
│   │                        authored in player.tscn: player_health, player_equipment (hosts
│   │                        the per-slot HeldItemBehavior instances), player_interaction
│   │                        (generic drop-target/proximity bridge — interactables implement
│   │                        its duck-typed contract on themselves and join its groups),
│   │                        player_scrap_collector, player_progress_bar_controller. Sprites
│   │                        in sprites/.
├── run/                     One run's lifecycle & mutable state: RunController, RunLoadout,
│                            RunResult, RunUpgrade, item/slot states, RunArtifactTracker.
├── salvage/                 The salvage domain, end to end:
│   ├── salvage_item.gd      In-world salvage RigidBody2D (pull/freeze/storage behavior).
│   ├── salvage_item_data.gd + salvage_part_entry.gd + salvage_item_cost.gd (data model).
│   ├── catalog/             All salvage item definition .tres files.
│   ├── sprites/             Salvage + part textures.
│   ├── pile/                World salvage piles (scene, shader, pile data).
│   ├── loot/                Loot generation config: pools, rarity weights, artifact pools.
│   └── salvage_spawner.*    Timed pile spawning.
├── ship/                    The salvage platform and everything mounted on it. Every mounted
│   │                        object is a folder owning its own scene, scripts and sprites;
│   │                        ship/ root holds only the hull. ship.tscn instances each one.
│   ├── ship.*               Hull, storage zone, combat surface; storage_zone_fade.gdshader.
│   ├── sprites/             Hull art only (hull_back/fore, force_field_*, pattern_hazard).
│   ├── magnet/              Ship magnet + lever + nine-patch shader + sprites.
│   ├── research_station/    Research station + its UI + minigame_docker + sprites.
│   │   └── minigames/       One folder per self-contained minigame (alignment_a/), each
│   │                        owning its scene, script and sprites/. Art used by the station
│   │                        UI shell rather than by a minigame stays in research_station/sprites/.
│   ├── recycler/            Recycler + sprites.
│   ├── thruster/            Thruster + thruster_audio + sprites.
│   └── departure_pylon/     Departure pylon.
├── upgrades/                Authored upgrade definitions (data-driven, §9): upgrade_effect.gd +
│                            upgrade_level_cost.gd + per-domain .tres grouped in player/, ship/,
│                            magnet/, weapon/.
└── hud/                     The in-run heads-up display (only the HUD — not "anything drawn
    │                        on the UI layer"; screens live in app/screens/, and a world
    │                        object's own UI lives with that object).
    ├── game_ui.*            HUD shell: player/ship status bars, augment icons, counters.
    ├── magnet_capacity.gd, event_text_display.*, control_prompt*.gd,
    │   player_progress_bar.*, pause_menu.gd
    ├── magnetide_theme.tres, fonts/
    ├── sprites/             Sprites owned by game_ui.tscn itself (player/ship HP bars,
    │                        player icon, bullet icon).
    ├── hotbar/              Hotbar script + gradient shader + its sprites/.
    └── threat/              Threat bar scene/script + its sprites/.
```

Top-level support folders outside `_project/`:

- `specs/` — design/spec documents (this file included).
- `releases/` — packaged builds.
- Root: `project.godot`, `icon.svg`, `readme.md`, editor/tooling config.

### Where does a new file go?

1. Is it a new screen? → `app/screens/<screen_name>/`.
2. Is it content for an existing concept? → that concept's folder (new enemy → `enemies/<name>/`,
   new weapon → `items/equipment/<name>/`, new salvage item → `salvage/catalog/` + `salvage/sprites/`).
3. Is it a world object mounted on the ship? → `ship/<name>/` (with its UI and sprites if it
   owns them). "Mounted" means `ship.tscn` instances it — not merely that it is *about* the
   ship. A system that only exists during a run and is instanced by `level.tscn` belongs in
   `level/`, however ship-flavored its name (the magnet minigame is `level/magnet_minigame/`).
4. Is it used by 2+ concepts? → `combat/` if it's a gameplay primitive, `common/` otherwise.
5. None of the above → new top-level concept folder, added to the map above in the same commit.

A sprite follows the same rules as code: it belongs to the concept that **displays** it, which
is rarely "the UI". A sprite drawn only by the HUD goes under `hud/`; one drawn only by a screen
goes under that screen's `sprites/`; one drawn only by a world object goes with that object
(the magnet minigame's alert icons live in `ship/magnet/minigame/sprites/`). Only a sprite with
two or more consumers across different concepts belongs in `common/sprites/`. Sprite file names
do not repeat their folder (`hud/sprites/player_hp_back.png`, not `ui_hud_player_hp_back.png`).

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
| Run state | `Run*` prefix = mutable per-run save/state; authored *definitions* never take it | `RunLoadout`, `RunUpgrade` (state) vs `UpgradeData`, `UpgradeEffect` (definitions) |

A `Run`-prefixed class is per-run save/state (`RunLoadout`, `RunUpgrade`, `RunResult`). Authored
definition resources — what a designer tunes — are never `Run`-prefixed (`UpgradeData`,
`UpgradeEffect`, `UpgradeLevelCost`, `WeaponData`, `AugmentData`). Naming a definition `Run*`, or a
state object without it, is the smell this rule prevents.

Exception: music track files under `audio/bgm/` keep their source filenames
verbatim (e.g. `1025487_Skyline.mp3`). Nothing references tracks by name — the
BGM player scans its category folders — and preserving the original name keeps
the track traceable to its source.

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
- No backwards-compatibility or legacy shims. When a system is replaced or restructured, the
  old implementation is deleted in the same change — no parallel old/new paths, compatibility
  wrappers, deprecated aliases, or "kept just in case" code. Overlapping functionality is
  consolidated onto the single new system.
- No pre-release save compatibility. Until an official release, saved-game formats are not kept
  backwards-compatible: a change that alters the save shape or resource paths lets old saves
  reset and does not add `AppSaveData._migrate_legacy_resource_paths()` rules. (Post-release,
  migration rules return.)
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

## 9. Data-driven systems

New systems default to **data-driven**: their content, tuning, and per-instance
configuration live in authored data — `@export` fields, `.tres` resources, catalogs,
and scenes — not baked into scripts. Code defines *behavior* and reads the data; it
does not hardcode the *content*.

- Prefer an authored resource/scene over a hardcoded table, a `match` on ids, or
  per-case branches. Adding or tuning content (a new upgrade, weapon, enemy, cost,
  stat curve) should be inspector/`.tres` work, not a code edit.
- Reuse an existing data type when one already models the thing (an upgrade track is a
  `RunUpgrade`, a per-level cost is a `RunUpgradeLevelCost`); introduce a new resource
  only when none fits (see §6).
- Values a designer would tune — costs, amounts, level counts, spawn weights, names,
  icons — are `@export`s or resource fields with sensible defaults, never magic numbers
  buried in logic.
- Code discovers and iterates authored data generically rather than referencing each
  item by name. A per-item `match`/if-chain that grows with content is a smell — drive
  it from the data instead.

This is the companion to §8: §8 keeps *structure* in scenes; this keeps *content and
tuning* in data. Both exist so the game grows through authoring, not code churn.

## 10. Specs

Each nontrivial feature gets a spec in `specs/` before/while it is built. Specs are
design history — they are not updated retroactively when code moves; this document is
the single source of truth for structure.

## 11. Changelog

`CHANGELOG.md` at the repo root is the **player-facing** record of what changed between
builds. It is written for someone who plays the game, not someone who works on it. Git
history already records the engineering; the changelog records the experience.

### Audience rule

Every entry must answer: *"what does this change about playing the game?"* If it can't,
it doesn't go in. Concretely:

**Include** — new content (weapons, enemies, augments, salvage, levels), new systems and
mechanics, balance changes (buffs, nerfs, spawn/scaling tuning), control and input changes,
UI/UX changes the player sees, audio and visual/feel changes, bug fixes with a visible
symptom.

**Exclude** — refactors, file/folder reorganization, renames, class extraction, dead-code
removal, resource-path migrations, build/tooling/CI changes, spec documents, comment
cleanup, and anything whose only description is "how the code is arranged." A commit whose
message is entirely technical may still contain player-facing changes bundled in — read the
diff, don't trust the subject line.

### Write net state, not commit history

The changelog is **not** a commit log. It describes the difference between the previous
build and this one, as the player will experience it:

- **Collapse churn.** A value tuned three times across five commits gets one line with the
  final number. A system added in one commit and refined in three more is one entry.
- **Omit reverted or disabled work.** If a feature was added and then turned off before the
  build ships, it does not appear — the player never sees it. It appears in the changelog
  for the build that actually enables it.
- **Omit debug values and their corrections.** A timer temporarily shortened for testing and
  then restored is not a change. But if the debug value actually shipped in the previous
  build, the correction *is* a player-facing change and gets an entry.
- **Group by theme, not by commit.** Suggested sections, in order:
  `New Content` → `New Systems` → `Balance` → `Feel, Audio & Visuals` → `Fixes`.
  Drop any section with nothing in it.

### Voice and specificity

- Address the player in second person ("You start with the Pistol"), present tense.
- **Balance entries carry real numbers**, and show the delta when a value changed:
  "Worm health 30 → 50", "enemies spawn 3× as often once a storm is imminent".
  Vague entries ("improved balance", "various tweaks") are not acceptable.
- Say what a change *means*, not just what it is. "Enemies spawn 2× as often while the
  magnet minigame runs — looting is no longer free" beats "adjusted magnet spawn multiplier".
- Lead each section with the changes a player will notice first. A new weapon outranks a
  louder footstep.
- Tables are for enumerable stat comparisons (weapon stat lines, tier costs). Everything
  else is prose and bullets.
- Bold the subject of an entry so the file is skimmable at a glance.

### Structure

One `## Version X.Y.Z` section per build, newest first, matching `application/config/version`
in `project.godot` and the binary in `releases/`. A section covers every player-facing change
since the previous version's section — not since the last commit.

### Producing a changelog

Given a starting commit or tag, walk the full commit range and read the **diffs**, not the
subject lines: `.tres` resources and exported `@export` defaults are where balance actually
lives, and a reorg commit will happily hide a new pause menu in the middle of 500 moved files.
Then apply the net-state rules above before writing a single line.
