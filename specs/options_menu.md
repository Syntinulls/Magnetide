# Options Menu (MVP)

A modal options panel reachable from both the main menu and the in-run pause menu via an
"Options" button. It overlays whatever the player was on — it is not a screen swap — so
closing it always returns to the caller (main menu, or the still-paused run).

## Layout

A centered `PanelContainer` over a dimmed backdrop (does not cover the full screen), with:

- Three tabs — **General**, **Video**, **Audio** — in a `TabContainer`, with room to add
  more. General and Video are empty placeholders for now.
- **Audio** tab: two sliders, **Music** and **SFX**, each 0–100%.
- Bottom button row: **OK** (apply + save + close) and **Cancel** (close; if there are
  unsaved changes, an in-panel confirm asks to Apply or Discard them first).
- ESC behaves like Cancel (and closes the unsaved-changes confirm first if open).

## Volume model

Each slider drives its audio bus (`Music` / `SFX`) through the existing player services
(`BgmPlayer.set_music_volume`, `SfxPlayer.set_sfx_volume`). The percent maps **linearly
in dB** across a 40 dB span below full volume (`AppOptions.VOLUME_RANGE_DB`), so slider
travel tracks perceived loudness evenly; 0% hard-mutes the bus rather than being the
bottom of the span. A 100% SFX slider is 0 dB (full scale). A 100% Music slider is
**-6 dB** (`AppOptions.MUSIC_FULL_VOLUME_DB`): the placeholder tracks are mastered hot
and music should sit under gameplay SFX; raise the constant toward 0 dB if future masters
are quieter. Slider changes apply to the buses immediately as a live preview; only OK
persists them, and Cancel/Discard reverts the buses to the on-disk values.

## Persistence

`AppOptions` (`_project/app/app_options.gd`) persists to `user://options.ini` via
`ConfigFile` — deliberately separate from the game save (`magnetide_save.tres`). Ini
sections match the tab names (`[audio]` → `music_volume`, `sfx_volume`; future tabs add
their own sections). The `Magnetide` autoload loads and applies the file at startup.
The panel compares its widgets against the on-disk values to know when it is dirty.
