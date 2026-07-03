# Weapon Reloading — Design Spec

Status: **implemented**. This spec covers the third use of the new
[`PlayerProgressBar`](../_project/ui/player_progress_bar.gd), alongside the already-done
hold-to-depart / magnet-repel swaps. Kept as living documentation of the mechanic.

---

## 1. Goal

Every weapon gains a **magazine**. Firing drains it; when it empties the player
**auto-reloads**, and they may also **manually reload with `R`** at any time (even a
partial magazine). During a reload the player cannot shoot. Reloading is shown by the
shared player progress bar (caption `"Reloading..."`) above the player's head, and the
current magazine state is shown on the HUD.

> **Input:** a `reload` action was added on `R`. `R` previously bound
> `debug_spawn_enemy`, which was moved to `P` to free the key.

---

## 2. New weapon stats (`weapon_data.gd`)

Add three exported stats to `WeaponData`:

| Stat | Type | Meaning | Suggested default |
|------|------|---------|-------------------|
| `magazine_size` | `int` | Rounds available before a reload is required. | `30` |
| `ammo_consumption` | `int` | Rounds consumed **per shot** (per trigger pull, not per pellet). | `1` |
| `reload_time` | `float` | Seconds to refill the magazine. | `1.5` |

```gdscript
@export var magazine_size: int = 30:
	set(value):
		magazine_size = maxi(value, 1)
@export var ammo_consumption: int = 1:
	set(value):
		ammo_consumption = maxi(value, 1)
@export var reload_time: float = 1.5:
	set(value):
		reload_time = maxf(value, 0.0)
```

Per-weapon `.tres` overrides (suggested starting values):
- **Rifle** — `magazine_size = 30`, `ammo_consumption = 1`, `reload_time = 1.5`
- **Shotgun** — `magazine_size = 18`, `ammo_consumption = 3`, `reload_time = 2.0` (6 shots/mag)

> **Shotgun note:** `ammo_consumption` is charged **once per `shoot()` call**, so a
> 3-pellet blast costs 1 (not 3). The pellet fan-out in `shotgun_fire_behavior.gd`
> is unaffected.

---

## 3. Player state (`player.gd`)

```gdscript
## Current rounds in the magazine, keyed by equipment slot index. A weapon keeps
## its own ammo when the player switches away and back.
var _weapon_ammo: Dictionary = {}            # int index -> int current ammo
## Reload progress in seconds, keyed by equipment slot index. Only meaningful while
## that slot's weapon is mid-reload (its ammo is 0). Persisted across weapon
## switches so a reload RESUMES from where it left off, not from zero.
var _weapon_reload_elapsed: Dictionary = {}  # int index -> float seconds

const RELOAD_BAR_COLOR: Color = Color("ffd24a")   # amber
const RELOAD_BAR_TEXT: String = "Reloading..."
```

There is deliberately **no `_is_reloading` flag**. Reload state is derived from the
**presence of a `_weapon_reload_elapsed[index]` entry** — one source of truth that
survives weapon switches for free. (An entry is created both by auto-reload at empty
and by a manual `R` reload on a partial magazine.)

`PROGRESS_BAR_PRIORITY_RELOAD` (= 30) is already defined and outranks repel/depart,
so a reload bar wins if two claims ever overlap.

### Public API (for the HUD to poll — mirrors how the scrap counter already polls)

```gdscript
func has_ammo_display() -> bool:
    var wpn := current_weapon_data
    return wpn != null and wpn.magazine_size > 0

func get_current_magazine_size() -> int:
    var wpn := current_weapon_data
    return wpn.magazine_size if wpn else 0

func get_current_ammo() -> int:
    if current_weapon_data == null:
        return 0
    return int(_weapon_ammo.get(_selected_equipment_index, get_current_magazine_size()))

func is_reloading() -> bool:
    # A weapon is reloading exactly while it has a reload-progress entry for its slot.
    # (Derived from the elapsed dict, NOT from ammo == 0, because a manual reload can
    # run on a partially-full magazine.)
    return current_weapon_data != null and _weapon_reload_elapsed.has(_selected_equipment_index)
```

---

## 4. Lifecycle & rules

### Initialization
- On `apply_run_loadout()` / `_ready`, for each equipment slot that is a
  `WeaponData`, seed `_weapon_ammo[index] = weapon.magazine_size` (full mag).

### Firing (`_process_weapon_input` → `shoot`)
1. Advance reload for the current weapon first (`_process_reload(delta)`).
2. On `reload` just-pressed, call `_try_manual_reload()` (starts a reload unless the
   mag is full or one is already running).
3. **If `is_reloading()`: ignore fire input entirely** (cannot shoot).
4. Otherwise the gate applies: `shoot` pressed **and** `_fire_cooldown <= 0`
   **and** `get_current_ammo() > 0`.
5. In `shoot()`, after firing the projectile(s), `_consume_ammo_for_shot(wpn)`:
   ```gdscript
   var idx := _selected_equipment_index
   var current := int(_weapon_ammo.get(idx, wpn.magazine_size))
   current -= mini(current, wpn.ammo_consumption)   # < consumption reaches exactly 0
   if current <= 0:
       current = 0
       _weapon_reload_elapsed[idx] = 0.0            # auto-reload begins next frame
   _weapon_ammo[idx] = current
   ```
   This satisfies the rule: *if `current_ammo < ammo_consumption`, still fire, drain
   to 0, then reload.* Reaching 0 seeds a reload entry, which `_process_reload` picks up.

### Reload (per-weapon, resumable)
`_process_reload` only ever advances the **currently selected** weapon. A weapon
switched away from simply stops accumulating; its `_weapon_reload_elapsed[idx]`
stays put and resumes when reselected.

```gdscript
func _process_reload(delta: float) -> void:
    var idx := _selected_equipment_index
    if not is_reloading():
        clear_progress_bar(&"reload")      # nothing to show for this weapon
        return
    var wpn := current_weapon_data
    var reload_time: float = wpn.reload_time
    var elapsed: float = float(_weapon_reload_elapsed.get(idx, 0.0)) + delta
    if elapsed >= reload_time:              # done — refill and clear
        _weapon_ammo[idx] = wpn.magazine_size
        _weapon_reload_elapsed.erase(idx)
        clear_progress_bar(&"reload")
        return
    _weapon_reload_elapsed[idx] = elapsed   # persist progress (survives switches)
    request_progress_bar(&"reload",
        clampf(elapsed / maxf(reload_time, 0.01), 0.0, 1.0),
        RELOAD_BAR_COLOR, RELOAD_BAR_TEXT, PROGRESS_BAR_PRIORITY_RELOAD)
```

### Weapon switching (`_switch_to_equipment` / `_cleanup_current_equipment`)
- The switch is **instant** — never blocked by a reload.
- On switch, only `clear_progress_bar(&"reload")` is called. **Do not** reset
  `_weapon_reload_elapsed` — the outgoing weapon keeps its partial progress.
- The incoming weapon shows its **own** stored `_weapon_ammo[index]`. If it is
  mid-reload (ammo 0), `_process_reload` resumes it from its saved elapsed the next
  frame, re-showing the bar. If it isn't a weapon (magnet tool), the bar stays
  hidden and no reload advances.

> Example: reload rifle to 50%, switch to magnet gun → rifle reload freezes at 50%
> and the bar disappears; switch back → rifle bar reappears at 50% and continues.

### Run end (`stop_for_run_end`)
- Already clears all bar claims; also clear `_weapon_reload_elapsed`.

### Non-weapon equipment (magnet tool)
- `has_ammo_display()` returns `false`; the HUD magazine row hides. `_process_reload`
  isn't reached (the magnet-tool input branch runs instead), so no weapon's reload
  advances while a non-weapon is equipped.

---

## 5. HUD changes (`game_ui.tscn` + `game_ui.gd`)

Add a **magazine row above the scrap counter** inside
`PlayerStatus/HBoxContainer/PlayerBars`, and move `ScrapCounterMargin` **below** it
(node order in the `VBoxContainer` controls vertical order).

New row `MagazineCounter` (`HBoxContainer`), mirroring the scrap counter's styling:
- `BulletIcon` (`TextureRect`) → `res://_project/ui/sprites/icon_bullet.png`
- `MagazineLabel` (`Label`, digital font like the scrap label)

Format: **`[icon] {current} / {magazine_size}`** — e.g. `24 / 30`.

`game_ui.gd`, in `_process` (alongside `_update_scrap_counter`):
```gdscript
func _update_magazine_counter() -> void:
    var player := Magnetide.player as Player
    var show := player != null and player.has_ammo_display()
    _magazine_row.visible = show
    if not show: return
    _magazine_label.text = "%d / %d" % [player.get_current_ammo(), player.get_current_magazine_size()]
```
Optionally tint / pulse the label when `player.is_reloading()` (reuse the existing
`pulse_scrap_counter`-style tween) — nice-to-have, not required.

---

## 6. Resolved decisions

1. **No ammo reserve — confirmed.** Infinite ammo; reload is purely a *time* cost to
   refill the magazine to `magazine_size`. The bullet icon is cosmetic. No carried-ammo
   currency.
2. **Manual reload — added.** Automatic reload still triggers at 0 ammo; pressing
   `R` also starts a reload manually, including on a partially-full magazine (ignored
   when the mag is full or a reload is already running).
3. **Switching pauses & resumes — confirmed.** A switch is instant and stops the
   reload, but progress is saved per weapon slot (`_weapon_reload_elapsed[index]`) and
   resumes from that point when the weapon is reselected. (See §4 "Weapon switching".)
4. **Fire-rate vs. reload — confirmed.** `_fire_cooldown` keeps gating rate-of-fire
   independently; reload additionally blocks all shots while active.
5. **Defaults** in the §2 table are placeholders — final balance values TBD.
