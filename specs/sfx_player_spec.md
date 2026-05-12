# SFX Player Specification

## Overview

This spec defines a small global sound-effects playback module for Magnetide.

The module should make one-shot sound effects easy to trigger from anywhere in the project through the existing `Magnetide` autoload, while keeping playback rules centralized:

- all sound effects route through a dedicated `SFX` audio bus
- sound files are resolved from one global SFX folder
- different sound effects can overlap naturally
- the same sound effect file does not overlap with itself
- replaying the same sound effect interrupts and restarts the previous instance

This document is for implementation review before code is written.

---

## Design Goals

1. Provide a simple global API for one-shot SFX calls.
2. Keep audio playback ownership out of gameplay scripts.
3. Route every SFX through a dedicated `SFX` bus for future volume/mute/mix control.
4. Resolve SFX by filename from one global SFX folder instead of requiring full resource paths at call sites.
5. Allow many different SFX to play at the same time.
6. Prevent stacked duplicates of the same SFX file.
7. Keep playback non-positional and lightweight.
8. Leave room for future pitch randomization, volume variation, and named sound IDs.

---

## Current Project Context

The project already has:

- a single global `Magnetide` autoload at `_project/autoloads/magnetide.gd`
- project-wide convenience accessors like `Magnetide.player`, `Magnetide.ship`, `Magnetide.game_ui`, and `Magnetide.hotbar`
- no current audio bus layout or audio playback module found in the project files

The SFX system should follow the existing pattern: `Magnetide` remains the global access point, but it should delegate the real audio work to a dedicated module.

---

## Proposed Architecture

### 1. SFX Bus

Add a dedicated Godot audio bus named:

```text
SFX
```

Rules:

- `SFX` should route to `Master` unless a future mix design says otherwise.
- Every player created by the SFX module must set `bus = "SFX"`.
- The implementation should ensure the bus exists at runtime as a guard against missing editor/project configuration.

Recommended behavior:

- Prefer defining the bus in the project's default audio bus layout so it is visible in the editor.
- Also add a small runtime guard in `SfxPlayer` that checks `AudioServer.get_bus_index("SFX")` and creates the bus if missing.

The runtime guard is not a replacement for project configuration; it prevents silent failure when a branch, export, or new checkout is missing the bus layout.

### 2. Global SFX Folder

All one-shot SFX files should live under:

```text
res://_project/audio/sfx/
```

`SfxPlayer` should expose this as a configurable root folder:

```gdscript
const DEFAULT_SFX_FOLDER := "res://_project/audio/sfx/"
```

Rules:

- Gameplay and UI scripts should pass a sound filename, not a full resource path.
- `SfxPlayer` resolves that filename against the global SFX folder.
- The global folder should be the only search location for first-pass SFX playback.
- Filenames may include a subfolder path relative to the SFX folder if we later organize sounds by category.

Examples:

```gdscript
Magnetide.sfx.play("player_shoot.ogg")
Magnetide.sfx.play("ui/confirm.ogg")
```

These resolve to:

```text
res://_project/audio/sfx/player_shoot.ogg
res://_project/audio/sfx/ui/confirm.ogg
```

### 3. SfxPlayer Module

Add a dedicated script:

```text
_project/audio/sfx_player.gd
```

Suggested class:

```gdscript
class_name SfxPlayer
extends Node
```

Responsibilities:

- own all one-shot SFX `AudioStreamPlayer` instances
- route players to the `SFX` bus
- load or accept `AudioStream` resources
- track active playback by sound file key
- interrupt and restart an active player when the same file is requested again
- clean up completed players
- expose a minimal public API for gameplay/UI scripts

### 4. Magnetide Access

Expose the module through the existing autoload:

```gdscript
Magnetide.sfx.play("example.ogg")
```

Implementation shape:

- `Magnetide` should create or preload one `SfxPlayer` child during `_ready()`.
- `Magnetide` should expose it through a read-only `sfx` property.
- Gameplay scripts should not instantiate `SfxPlayer` directly.

Suggested `Magnetide` additions:

```gdscript
var _sfx: SfxPlayer = null

var sfx: SfxPlayer:
	get:
		return _sfx
```

The exact initialization can be decided during implementation, but the global calling convention should be stable.

---

## Public API

### Required First-Pass API

```gdscript
func play(sound: Variant, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer
```

Accepted `sound` values:

- `String` or `StringName`: filename or relative path inside the global SFX folder, such as `hit.ogg` or `ui/hit.ogg`
- `AudioStream`: already-loaded stream resource

Behavior:

1. Resolve `sound` into an `AudioStream`.
2. If `sound` is a string, resolve it against the global SFX folder.
3. Resolve a stable sound key.
4. If that key is already playing, stop the existing player and restart it from the beginning.
5. If that key is not playing, create or reuse a player.
6. Set bus, volume, pitch, stream, and playback state.
7. Return the `AudioStreamPlayer` used for playback.

### Optional Convenience API

These helpers are not required for the first implementation, but the design should not block them:

```gdscript
func stop(sound: Variant) -> void
func stop_all() -> void
func is_playing(sound: Variant) -> bool
func set_enabled(enabled: bool) -> void
```

`stop_all()` is useful for scene transitions, run end cleanup, pause menu flows, or future hard mutes.

---

## Sound Identity Rules

The "same SFX file" rule depends on stable identity.

### Filename-Based Sounds

For string filenames, the sound key is the resolved resource path:

```text
res://_project/audio/sfx/hit.ogg
```

Calling `play()` with the same filename while it is still playing interrupts the previous playback and restarts it.

Example:

```gdscript
Magnetide.sfx.play("hit.ogg")
```

The module resolves this to:

```text
res://_project/audio/sfx/hit.ogg
```

### AudioStream Resources

For `AudioStream` resources:

- If `stream.resource_path` is non-empty, use that as the key.
- If `stream.resource_path` is empty, use the stream instance id as a fallback key.

This means imported audio files obey the no-self-overlap rule, while dynamically-created streams are treated as distinct unless they are the same resource instance.

---

## Overlap Rules

### Different Files

Different sound keys may play at the same time.

Example:

```gdscript
Magnetide.sfx.play("player_shoot.ogg")
Magnetide.sfx.play("enemy_hit.ogg")
```

Both should be audible together.

### Same File

The same sound key must not stack.

Example:

```gdscript
Magnetide.sfx.play("player_shoot.ogg")
Magnetide.sfx.play("player_shoot.ogg")
```

The second call should stop/restart the first player instead of creating another overlapping instance.

This gives rapid events a crisp restart instead of an increasingly loud pileup.

---

## Player Management

The module should maintain:

```gdscript
var _active_players_by_key: Dictionary = {}
var _idle_players: Array[AudioStreamPlayer] = []
```

Expected flow:

1. A sound key is requested.
2. If `_active_players_by_key` has that key:
   - get the existing player
   - stop it
   - restart it with the requested volume and pitch
3. If no active player exists:
   - pop an idle player if available
   - otherwise create a new `AudioStreamPlayer`
   - add it as a child of `SfxPlayer`
   - register it in `_active_players_by_key`
4. Connect or handle the player's `finished` signal.
5. When finished:
   - remove the key from `_active_players_by_key`
   - clear the stream if desired
   - move the player to `_idle_players`

The idle pool keeps repeated SFX playback from constantly allocating nodes during combat or UI-heavy moments.

---

## Error Handling

The module should fail softly because SFX calls should not crash gameplay.

Recommended behavior:

- If `sound` is null, return `null`.
- If a filename cannot be resolved and loaded as an `AudioStream`, push a warning and return `null`.
- If an `AudioStream` has no valid key, use a fallback instance id key.
- If the `SFX` bus is missing and cannot be created, push a warning and let Godot fall back according to its audio behavior.

Gameplay scripts should not need to wrap every SFX call in defensive checks.

---

## Folder Layout

Recommended files:

```text
_project/audio/
  sfx_player.gd
  sfx/
    .gitkeep
specs/
  sfx_player_spec.md
```

The `sfx/` folder gives imported one-shot audio files an obvious home.

Future optional files:

```text
_project/audio/sfx_catalog.gd
_project/audio/sfx_catalog.tres
```

A catalog is not required now. Filename-based lookup from the global SFX folder is enough for the first implementation.

---

## Example Usage

Player weapon:

```gdscript
Magnetide.sfx.play("player_shoot.ogg")
```

UI confirm:

```gdscript
Magnetide.sfx.play("ui_confirm.ogg", -4.0)
```

Impact variation:

```gdscript
Magnetide.sfx.play("enemy_hit.ogg", 0.0, randf_range(0.94, 1.06))
```

Even with pitch variation, calls using the same file still interrupt/restart the prior instance because identity is based on file key, not pitch.

---

## Implementation Steps

1. Add the `SFX` audio bus to the project audio bus layout.
2. Add `_project/audio/sfx_player.gd`.
3. Add `_project/audio/sfx/` for future imported audio assets.
4. Update `_project/autoloads/magnetide.gd` to create and expose one `SfxPlayer`.
5. Add a small smoke test script under `.codex/` to verify:
   - `Magnetide.sfx` exists
   - the `SFX` bus exists
   - playing two different fake/test streams creates two active keys
   - replaying the same stream keeps one active key and restarts it
6. Run Godot headless smoke checks.

---

## Verification Plan

Headless verification:

- launch the project headless to confirm no parse/runtime errors
- run a focused smoke script that instantiates or uses `Magnetide.sfx`
- assert the `SFX` bus exists
- assert duplicate sound identity does not create duplicate active players

Manual editor verification:

- confirm the `SFX` bus appears in the Audio panel
- import one short test sound under `_project/audio/sfx/`
- trigger it from a temporary call site
- confirm different sounds overlap
- confirm repeated calls to the same sound restart instead of stacking

---

## Deferred Features

These are intentionally out of scope for the first pass:

- global settings UI for SFX volume
- music bus or music player
- ambience loops
- sound cooldowns
- priority limits or max simultaneous voice caps
- authored sound definition resources
- random clip sets under one sound ID
- editor tooling for assigning SFX names

The first implementation should stay small: a global one-shot SFX player with correct bus routing and duplicate-interrupt behavior.
