# Background Music (BGM)

Looping background music, played through its own audio bus and mixer, separate
from SFX. Owned by `_project/audio/bgm_player.gd` (`BgmPlayer`), registered as the
`Magnetide.bgm` autoload service alongside `Magnetide.sfx`.

## Bus & volume model

- A dedicated `Music` bus (sibling of `SFX`) is declared in
  `default_bus_layout.tres` and re-ensured at runtime by
  `BgmPlayer._ensure_music_bus()`.
- Two volume levels are kept independent:
  - **Per-track fade envelope** — lives on each `AudioStreamPlayer.volume_db`
    (0 dB audible ↔ `SILENT_VOLUME_DB` faded out). This is what fade-in /
    fade-out / crossfade tween.
  - **Global music level** — lives on the `Music` bus. Set via
    `set_music_volume(linear)` / `get_music_volume()` (linear 0..1). This is the
    hook for the future options menu; a debug scale is layered on top of it.

Persisting the options music level (in `AppSaveData`) is deferred until the
options menu exists; the setter/getter API is in place now so the menu only has
to call and store it.

## Bus processing (mixer chain)

The `Music` bus in `default_bus_layout.tres` carries a light, conventional
"music sub-bus" mastering chain (visible/tweakable in the editor Audio panel).
Kept gentle on the assumption tracks arrive already mastered — this only
balances the track into the game mix and guards headroom:

1. **High-pass @ 30 Hz** — removes inaudible sub-bass rumble that only wastes
   headroom and muddies against SFX.
2. **EQ6** — subtle corrective curve (all ≤1.5 dB): −1.5 dB @ 320 Hz (low-mid
   mud), −1.0 dB @ 3.2 kHz (carve a pocket so gameplay SFX stay intelligible
   over the music), +1.0 dB @ 10 kHz (air).
3. **Limiter @ −1 dB ceiling** — safety brickwall so music never clips the
   master when SFX stack on top.

Tune the EQ by ear in the mixer rather than trusting the numbers; the values
above are a safe starting point, not a measured fit to any specific track. If
the `Music` bus is ever absent from the layout, `BgmPlayer._ensure_music_bus()`
recreates a bare bus (no effects) as a fallback so audio still plays.

## Playback API

- `play_track(track, fade_in_seconds)` — fade in and loop a track (filename
  inside `audio/bgm/`, or an `AudioStream`). No-op if that track is already the
  current one and still playing, so callers can hold music continuous.
- `fade_to_random_track(fade_seconds)` — crossfade to a random *other* `.ogg` in
  `audio/bgm/`; if the current track is the only one, it keeps looping.
- `fade_out(fade_seconds)` — fade the current track out and stop.
- `stop()` / `set_enabled(enabled)` — hard stop / global gate.

Streams loop natively via their `loop` flag (`_make_looping()` duplicates the
cached resource before setting it, so shared resources are never mutated).

## Run wiring (`RunController`)

- **Level entry** (`_bind_runtime`) → `play_track(LEVEL_ENTRY_BGM)` fades in
  `bgm_zone1.ogg`.
- **Advancing out of an acid storm** into the next threat level
  (`ThreatManager.cap_raised`) → `fade_to_random_track()`.
- **End-run sequence start** (`request_end_run`, both voluntary departure and
  death) → `fade_out()`.

## Debug hotkey

`debug_cycle_music` (key **M**, in `project.godot` input map) →
`BgmPlayer.cycle_debug_volume()`. Cycles a debug scale over the options volume:
first press 50%, second 0%, third back to original, then repeats. Handled in
`BgmPlayer._unhandled_input` (autoload), so it works on any screen.

## Future: station / map screens

The API is screen-agnostic. Out-of-run screens (station, map) can call
`play_track()` on entry. Because `play_track()` is a no-op when the same track is
already playing, two screens sharing a track get **continuous** music with no
seam; passing different tracks (or calling `fade_to_random_track`) **switches**
on transition. Wire these from `AppRoot._show_station_screen` /
`_show_map_screen` when those tracks exist.
