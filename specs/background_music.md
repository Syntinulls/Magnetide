# Background Music (BGM)

Category-based playlist music, played through its own audio bus and mixer,
separate from SFX. Owned by `_project/audio/bgm_player.gd` (`BgmPlayer`),
registered as the `Magnetide.bgm` autoload service alongside `Magnetide.sfx`.

## Categories & track folders

Music is organized into five **categories**, each mapping to a subfolder of
`_project/audio/bgm/`:

| `BgmPlayer.Category` | Folder | Played when |
|---|---|---|
| `MAIN_MENU` | `main_menu/` | Main menu screen |
| `STATION` | `station/` | Station, map, salvage, and run-summary screens |
| `IN_RUN` | `run/` | During a run (outside storms) |
| `STORM` | `storm/` | While an acid storm is active |
| `BOSS` | `boss/` | Reserved — no boss exists yet; unwired |

**Adding a track is a file drop**: every `.ogg`/`.mp3`/`.wav` in a category's
folder is automatically in that category's rotation — no code or resource
edits. Folders are scanned at pick time via `DirAccess`; in exported builds the
`.import`/`.remap` stubs are stripped back to their source names. Track files
keep their source filenames (see the naming exception in
`project_organization.md` §3). Files at the `bgm/` root belong to no category
and never play.

## Playback model

- **One category active at a time.** `play_category(category, fade_seconds)` is
  a no-op when that category is already active, so screens sharing a category
  (station → map) get continuous music with no seam.
- **Playlist rotation.** Tracks do not loop. When a track ends naturally, a
  silent gap of 3–5 s (`TRACK_GAP_MIN/MAX_SECONDS`) passes, then another track
  from the category fades in.
- **Shuffle bag, per category.** A track is not repeated until every other
  track in its category has played (`_played_by_category`); the bag then resets,
  avoiding a back-to-back repeat. Bags survive category switches, so
  run → storm → run resumes the run cycle rather than restarting it.
- **Interrupts crossfade quickly.** Switching categories fades the old track
  out and the new one in over `DEFAULT_FADE_SECONDS` (1.5 s) — no gap. A
  category whose folder is empty (storm/boss today) fades to silence; music
  returns on the next category switch.
- Looping streams are defused (`_make_one_shot` duplicates before clearing the
  `loop` flag) because rotation relies on the `finished` signal.
- The player runs with `PROCESS_MODE_ALWAYS`: music, fades, and gap timers
  continue while the tree is paused (pause menu).
- In-flight gap timers and finished callbacks carry a `_playlist_epoch` stamp
  and cancel when any interrupt (switch/stop/fade-out) bumps it.

## Bus & volume model

- A dedicated `Music` bus (sibling of `SFX`) is declared in
  `default_bus_layout.tres` and re-ensured at runtime by
  `BgmPlayer._ensure_music_bus()` (bare fallback bus, no effects).
- Two volume levels are kept independent:
  - **Per-track fade envelope** — each `AudioStreamPlayer.volume_db` (0 dB
    audible ↔ `SILENT_VOLUME_DB` faded out). This is what fades tween.
  - **Global music level** — the `Music` bus, via `set_music_volume(linear)` /
    `get_music_volume()` (linear 0..1, 0 mutes the bus). This is the hook for
    the future options menu; `set_enabled(false)` / `stop()` are the hard
    gates. A debug scale is layered on top for the debug panel's mute cycle
    (`cycle_debug_volume()`: 50% → 0% → original).

The `Music` bus mastering chain (high-pass @ 30 Hz, gentle EQ6 carve, limiter
@ −1 dB) lives in `default_bus_layout.tres`; see the editor Audio panel. Tune
by ear — tracks are assumed to arrive mastered.

Persisting the options music level (in `AppSaveData`) is deferred until the
options menu exists.

## Wiring

- `AppRoot` screen flow → `_play_screen_music()`: main menu → `MAIN_MENU`;
  station, map, salvage, and both run-summary paths → `STATION`.
- `RunController._bind_runtime` → `IN_RUN` on level entry.
- `ThreatManager.storm_arrived` → `STORM`; `cap_raised` (advancing out of the
  storm) → `IN_RUN`.
- `RunController.request_end_run` (departure and death) → `fade_out()`; the
  post-run screens fade `STATION` back in.
- Debug panel's cycle-music button → `cycle_debug_volume()`.
