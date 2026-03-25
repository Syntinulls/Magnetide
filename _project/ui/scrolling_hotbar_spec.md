# Scrolling Hotbar Specification

## Overview
A looping, horizontally scrolling weapon hotbar that displays 3 visible slots with the center slot highlighted and enlarged. Scrolling is smooth and tweened, with items looping seamlessly.

## Visual Layout

```
   [Mask Area - 3 visible slots]
┌─────────────────────────────────┐
│  [Slot1]   [SLOT2]   [Slot3]    │
│   small    LARGE     small      │
│   faded   HIGHLIGHT  faded      │
└─────────────────────────────────┘
```

- **Center slot (Slot 2)**: Larger, fully opaque, highlighted (selected item)
- **Side slots (Slot 1 & 3)**: Smaller, faded/dimmed (adjacent items)

## Node Structure

```
ItemSlotContainer (HBoxContainer) - existing node
└── Hotbar (Control) - root container, fixed size
    └── HotbarMask (Control) - clips content to 3-slot width
        └── HotbarStrip (HBoxContainer) - scrollable strip containing 5 slots
            ├── Slot0 (Control) - buffer slot (left, outside mask)
            ├── Slot1 (Control) - visible left
            ├── Slot2 (Control) - visible center (highlighted)
            ├── Slot3 (Control) - visible right
            └── Slot4 (Control) - buffer slot (right, outside mask)
```

### Slot Structure (each slot)
```
SlotN (Control)
├── SlotBackground (TextureRect) - slot frame/border
├── ItemIcon (TextureRect) - weapon icon
└── SlotNumber (Label) - slot number indicator (1, 2, 3)
```

## Slot Sizing

| Slot Position | Scale | Opacity | Notes |
|---------------|-------|---------|-------|
| Buffer (0, 4) | 0.7x  | 0.0     | Outside mask, invisible |
| Side (1, 3)   | 0.7x  | gradient | Visible, gradient fade (see below) |
| Center (2)    | 1.0x  | 1.0     | Full size, highlighted |

## Gradient Fade Effect

Side slots use a **horizontal gradient fade** that fades outward from the center slot:

```
        ← fade direction    fade direction →
        
Slot1 (left):              Slot2 (center):       Slot3 (right):
┌──────────────┐           ┌──────────────┐      ┌──────────────┐
│ 0%  ───►  100%│           │     100%     │      │100%  ◄───  0%│
│ faded    full │           │  full opaque │      │full    faded │
└──────────────┘           └──────────────┘      └──────────────┘
```

- **Slot1 (left visible)**: Gradient from 0% opacity (left edge) to 100% opacity (right edge, toward center)
- **Slot2 (center)**: Uniform 100% opacity
- **Slot3 (right visible)**: Gradient from 100% opacity (left edge, toward center) to 0% opacity (right edge)

### Implementation Options
1. **Shader-based**: Apply a horizontal gradient shader to side slot contents
2. **Gradient texture overlay**: Use a `TextureRect` with a gradient texture and blend mode
3. **CanvasItemMaterial**: Use a custom material with modulate gradient

Recommended: Use a simple shader on the `ItemIcon` TextureRect that samples a gradient based on UV.x

## Scrolling Behavior

### Concept
The `HotbarStrip` moves horizontally within `HotbarMask`. Only the center 3 slots are visible at any time.

### Scroll Direction
- **Select item to the RIGHT**: Strip scrolls LEFT (items move left)
- **Select item to the LEFT**: Strip scrolls RIGHT (items move right)

### Looping Logic (Example)
Given 3 inventory items: `[Sniper, Rifle, MagnetGun]`

**Initial state** (Rifle selected, index 1):
```
Slot0: MagnetGun (buffer, clone of right neighbor)
Slot1: Sniper
Slot2: Rifle ← SELECTED
Slot3: MagnetGun
Slot4: Sniper (buffer, clone of left neighbor)
```

**Selecting MagnetGun (index 2, to the right)**:
1. Before tween: Populate Slot4 with Sniper (wraps around)
2. Tween: Scroll strip LEFT by 1 slot width
3. After tween: Reset strip position, reassign all slots for new selection

**Post-scroll state** (MagnetGun selected):
```
Slot0: Rifle (buffer)
Slot1: Sniper
Slot2: MagnetGun ← SELECTED
Slot3: Rifle
Slot4: MagnetGun (buffer)
```

## Buffer Slot Population Rules

Before scrolling, populate the destination buffer slot:
- **Scrolling LEFT** (selecting right item): Slot4 = item that will enter from right (wraps from inventory start)
- **Scrolling RIGHT** (selecting left item): Slot0 = item that will enter from left (wraps from inventory end)

## Tween Animation

- **Duration**: ~0.2s (configurable)
- **Easing**: Ease out (smooth deceleration)
- **Property**: `HotbarStrip.position.x`
- **Distance**: One slot width (including spacing)

## Implementation Notes

### Masking
Use `clip_contents = true` on `HotbarMask` to hide buffer slots.

### Slot Alignment
All slots should be vertically centered within the strip. The center slot's larger size should expand equally above and below the baseline.

### Responsiveness
Slot sizes should be defined relative to a base size constant for easy adjustment.

## Constants (Suggested)

```gdscript
const SLOT_BASE_SIZE := Vector2(64, 64)
const SLOT_CENTER_SCALE := 1.0
const SLOT_SIDE_SCALE := 0.7
const SLOT_SIDE_OPACITY := 0.5
const SLOT_SPACING := 8
const SCROLL_DURATION := 0.2
```

## Scene File Changes

Target: `res://_project/ui/game_ui.tscn`

Add nodes under existing `ItemSlotContainer` (line 259-261):
1. `Hotbar` (Control) - fixed size container
2. `HotbarMask` (Control) - clip_contents enabled
3. `HotbarStrip` (HBoxContainer) - holds all 5 slots
4. 5x `SlotN` nodes with children

## API Functions

### Public Methods

```gdscript
## Sets the content of a specific slot (0-indexed inventory position, not visual slot)
## icon: Texture2D for the item
## item_data: Optional metadata (WeaponData, etc.)
func set_slot(index: int, icon: Texture2D, item_data: Variant = null) -> void

## Clears a slot
func clear_slot(index: int) -> void

## Sets all slots at once
## items: Array of { icon: Texture2D, data: Variant }
func set_all_slots(items: Array) -> void

## Selects a slot by index, triggering scroll animation
func select_slot(index: int) -> void

## Returns the currently selected slot index
func get_selected_index() -> int
```

### Signals

```gdscript
## Emitted when a slot is selected (after scroll animation completes)
signal slot_selected(index: int)

## Emitted when scroll animation starts
signal scroll_started(from_index: int, to_index: int)

## Emitted when scroll animation finishes
signal scroll_finished(index: int)
```

## Input Handling

The hotbar should respond to the following inputs:

| Input | Action |
|-------|--------|
| `1` key | Select slot 0 |
| `2` key | Select slot 1 |
| `3` key | Select slot 2 |
| Scroll wheel up | Select previous slot (wraps) |
| Scroll wheel down | Select next slot (wraps) |

### Input Actions (project.godot)
```
hotbar_slot_1: Key 1
hotbar_slot_2: Key 2
hotbar_slot_3: Key 3
hotbar_scroll_up: Mouse wheel up
hotbar_scroll_down: Mouse wheel down
```

### Input Processing
```gdscript
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("hotbar_slot_1"):
        select_slot(0)
    elif event.is_action_pressed("hotbar_slot_2"):
        select_slot(1)
    elif event.is_action_pressed("hotbar_slot_3"):
        select_slot(2)
    elif event.is_action_pressed("hotbar_scroll_up"):
        select_slot((selected_index - 1 + slot_count) % slot_count)
    elif event.is_action_pressed("hotbar_scroll_down"):
        select_slot((selected_index + 1) % slot_count)
```

## Player Integration

### Current System
The player currently uses a simple toggle between two weapons:
- `Player.gd` line 111-112: `Input.is_action_just_pressed("swap_weapon")` calls `swap_weapon()`
- `swap_weapon()` toggles between `Weapon.GUN` and `Weapon.MAGNET_GUN`
- Enum: `enum Weapon { GUN, MAGNET_GUN }`

### Integration Plan

1. **Hotbar owns weapon selection UI** - The hotbar emits `slot_selected(index)` when user changes slots
2. **Player subscribes to hotbar** - Player connects to `slot_selected` signal
3. **Replace `swap_weapon` input** - Remove `swap_weapon` action, use hotbar inputs instead
4. **Extend weapon system** - Map slot indices to `Weapon` enum values

### Connection Example
```gdscript
# In Player._ready() or level setup:
var hotbar := Magnetide.game_ui.get_hotbar()
hotbar.slot_selected.connect(_on_hotbar_slot_selected)

func _on_hotbar_slot_selected(index: int) -> void:
    match index:
        0: _switch_to_weapon(Weapon.GUN)
        1: _switch_to_weapon(Weapon.MAGNET_GUN)
        # Future: 2: _switch_to_weapon(Weapon.SNIPER)
```

### Refactored Player Methods
```gdscript
## Replace swap_weapon() with:
func _switch_to_weapon(new_weapon: Weapon) -> void:
    if current_weapon == new_weapon:
        return
    
    # Clean up current weapon state
    if current_weapon == Weapon.MAGNET_GUN:
        stop_magnetize()
        _clear_magnet_gun_state()
    
    current_weapon = new_weapon
    _update_weapon_sprite()

func _update_weapon_sprite() -> void:
    match current_weapon:
        Weapon.GUN:
            if weapon and weapon.weapon_sprite:
                weapon_sprite.texture = weapon.weapon_sprite
        Weapon.MAGNET_GUN:
            weapon_sprite.texture = MagnetGunTexture
```

## Default Slot Configuration

| Slot Index | Item | Notes |
|------------|------|-------|
| 0 | Gun/Rifle | Default selected on game start |
| 1 | Magnet Gun | |
| 2 | (Empty) | Reserved for future weapon |

On initialization, slot 0 (Gun/Rifle) should be selected by default.

## Future Script Responsibilities

- `hotbar.gd`: Manages slot content, handles input, triggers scroll animations
- Integrates with `Player` via signals for weapon switching
- Exposes API for external systems to populate slots
