---
name: verify
description: How to build, launch, and drive Magnetide headlessly to verify changes at runtime.
---

# Verifying Magnetide changes

Godot 4.6 project; no test framework. Verification = drive the real game.

## Binary

Use the console build so output reaches the terminal:

```bash
"/c/Workspaces/Godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . <args>
```

## Recipes

- **Validate scripts/scenes parse + import:** `--headless --import` (errors print; progress bars are noise).
- **Boot smoke:** `--headless --path . --quit-after 120` — boots `app_root.tscn` to the main menu for 120 frames; script errors print.
- **Drive gameplay headlessly:** write a throwaway scene at repo root (`smoke_test.tscn` + `.gd`, root `Node`) that instantiates `res://_project/app/app_root.tscn`, awaits a few `process_frame`s, then drives systems via the `Magnetide` autoload (`Magnetide.app_root.start_run()`, `Magnetide.player`, `Magnetide.level.get_node_or_null("ThreatManager")`, ...). Run it with `--headless --path . res://smoke_test.tscn` and `get_tree().quit(failures)` at the end. **Delete the temp files (including the generated `.uid`) afterwards.**
- Real key input works headless: `Input.parse_input_event(InputEventKey.new() ...)` with `physical_keycode` set exercises `_input` paths (used for the debug panel toggle).

## Gotchas

- **The game reads/writes the real save** at `%APPDATA%/Godot/app_userdata/Magnetide/magnetide_save.tres`. Back it up before any run that mutates currency/storage/loadout and restore it after.
- `AppRoot.start_run()` needs ~15 frames before `Magnetide.run` / `Magnetide.player` resolve.
- Pre-existing at-exit noise: "ObjectDB instances leaked" / "resources still in use" after `quit()` mid-scene, and an "invalid UID uid://jfxvrkd1ncx3" warning for `held_item_data.gd` — both unrelated to most changes.
- The debug panel (backtick) can drive most systems manually when verifying interactively; in release exports it needs `--debug-panel`.
