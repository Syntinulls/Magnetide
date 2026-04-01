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

---

## Equipment System Refactor

### Current Problem
- Player stores a single `@export var weapon: WeaponData` for the rifle
- Magnet gun is hardcoded as a texture constant (`MagnetGunTexture`)
- No unified system for equippable items
- Hotbar has no way to display what's actually equipped

### Equipment Types
Two equipment categories exist (more may be added):

| Type | Base Version | Description |
|------|--------------|-------------|
| **Weapon** | Rifle | Fires projectiles, uses `WeaponData` |
| **Magnet Tool** | Magnet Gun | Grabs/places items, uses `MagnetToolData` |

**Any equipment type can be equipped in any slot.** Slots are not type-restricted.

### New Architecture

#### EquipmentData Resource (Base Class)
A new base resource class for all equippable items:

```gdscript
# equipment_data.gd
extends Resource
class_name EquipmentData

## Display name shown in UI
@export var display_name: String = ""
## Icon texture for hotbar slot
@export var hotbar_icon: Texture2D
```

#### WeaponData Changes
`WeaponData` extends `EquipmentData` instead of `Resource`:

```gdscript
# weapon_data.gd
extends EquipmentData
class_name WeaponData

@export var damage: float = 10.0
@export var fire_rate: float = 5.0
@export var bullet_speed: float = 1800.0
@export var weapon_sprite: Texture2D      # Sprite shown on player arm
@export var bullet_sprite: Texture2D

@export_group("Positioning")
@export var weapon_offset: Vector2 = Vector2(-15.125, 0.0)
@export var weapon_rotation: float = -0.14660765
@export var muzzle_position: Vector2 = Vector2(-55.915, -4.695)
```

#### MagnetToolData Resource (New)
A new resource for magnet tools (magnet gun is the base version):

```gdscript
# magnet_tool_data.gd
extends EquipmentData
class_name MagnetToolData

@export var weapon_sprite: Texture2D      # Sprite shown on player arm
@export var hold_distance: float = 30.0
@export var repel_hold_time: float = 0.8
@export var repel_impulse_force: float = 600.0
@export var pull_base_speed: float = 133.0
@export var pull_max_speed: float = 1000.0
@export var pull_ramp_time: float = 0.6
```

### Player Equipment Storage

Replace the single `weapon` export with an equipment array:

```gdscript
# In player.gd

## Equipment slots - indices match hotbar slots
@export var equipment: Array[EquipmentData] = []

## Currently selected equipment index
var _selected_equipment_index: int = 0

## Convenience getters
var current_equipment: EquipmentData:
    get:
        if _selected_equipment_index < equipment.size():
            return equipment[_selected_equipment_index]
        return null
```

### Hotbar Integration

#### On Player Ready
Player populates hotbar with equipped items using their `hotbar_icon`:

```gdscript
func _populate_hotbar() -> void:
    var hotbar := Magnetide.hotbar
    if not hotbar:
        return
    var items: Array = []
    for equip in equipment:
        if equip:
            items.append({ "icon": equip.hotbar_icon, "data": equip })
        else:
            items.append({ "icon": null, "data": null })
    hotbar.set_all_slots(items)
```

#### On Hotbar Selection
```gdscript
func _on_hotbar_slot_selected(index: int) -> void:
    _switch_to_equipment(index)

func _switch_to_equipment(index: int) -> void:
    if index == _selected_equipment_index:
        return
    if index < 0 or index >= equipment.size():
        return
    
    _cleanup_current_equipment()
    _selected_equipment_index = index
    _apply_current_equipment()

func _apply_current_equipment() -> void:
    var equip := current_equipment
    if equip is WeaponData:
        # Apply weapon sprite, offset, rotation
        pass
    elif equip is MagnetToolData:
        # Apply magnet tool sprite
        pass
```

### Default Equipment Setup

| Slot | Equipment | Type |
|------|-----------|------|
| 0 | Rifle | WeaponData |
| 1 | Magnet Gun | MagnetToolData |
| 2 | (Empty) | null |

### Files Affected

| File | Changes |
|------|---------|
| `equipment_data.gd` | **NEW** - Base resource class with `hotbar_icon` |
| `magnet_tool_data.gd` | **NEW** - Magnet tool resource |
| `weapon_data.gd` | Extend `EquipmentData` instead of `Resource` |
| `player.gd` | Replace `weapon` export with `equipment` array |
| `hotbar.gd` | Use `hotbar_icon` from equipment data for slot icons |

### Resource Files to Create

```
_project/player/equipment/
├── rifle.tres          # WeaponData resource
└── magnet_gun.tres     # MagnetToolData resource
```

### Migration Notes

1. Move existing rifle `WeaponData` values into `rifle.tres`
2. Move hardcoded magnet gun constants from `player.gd` into `magnet_gun.tres`
3. Remove `MagnetGunTexture` constant - use resource's `weapon_sprite`
4. Remove `Weapon` enum - use `is` type checks instead

### Player Visual & Input Refactor

When equipment changes, the player must update both **visuals** (arm sprite) and **input handling** (fire vs grab).

#### Visual Updates

Each equipment type has a `weapon_sprite` that displays on the player's arm:

```gdscript
func _apply_current_equipment() -> void:
    var equip := current_equipment
    if equip is WeaponData:
        var wpn := equip as WeaponData
        weapon_sprite.texture = wpn.weapon_sprite
        weapon_sprite.offset = Vector2(wpn.weapon_offset.x * _facing_mult(), wpn.weapon_offset.y)
        weapon_sprite.rotation = wpn.weapon_rotation * _facing_mult()
        muzzle.position = Vector2(wpn.muzzle_position.x * _facing_mult(), wpn.muzzle_position.y)
    elif equip is MagnetToolData:
        var tool := equip as MagnetToolData
        weapon_sprite.texture = tool.weapon_sprite
        # Magnet tool may have its own offset/rotation exports, or use defaults
    else:
        # Empty slot or unknown type
        weapon_sprite.texture = null
```

#### Input Handling by Equipment Type

Replace the current `match current_weapon` pattern with type-based dispatch:

```gdscript
func _physics_process(delta: float) -> void:
    # ... movement code ...
    
    if input_enabled:
        var equip := current_equipment
        if equip is WeaponData:
            _process_weapon_input(delta)
        elif equip is MagnetToolData:
            _process_magnet_tool_input(delta)

func _process_weapon_input(delta: float) -> void:
    # Fire projectiles on shoot input
    if Input.is_action_pressed("shoot") and _fire_cooldown <= 0.0:
        shoot()

func _process_magnet_tool_input(delta: float) -> void:
    # Existing magnet gun logic: hover, grab, hold, repel, place
    if _held_item and is_instance_valid(_held_item):
        _held_item.update_gun_hold_position(_get_magnet_gun_hold_point())
        if _held_item.has_reached_anchor:
            # Repel on hold, place on click
            # ... existing logic ...
    else:
        _process_magnet_gun_hover()
        if Input.is_action_just_pressed("shoot"):
            if _hovered_item and is_instance_valid(_hovered_item):
                _grab_item_from_magnet(_hovered_item)
```

#### Cleanup on Equipment Switch

When switching away from an equipment type, clean up its state:

```gdscript
func _cleanup_current_equipment() -> void:
    var equip := current_equipment
    if equip is MagnetToolData:
        # Release held item, clear hover outline
        stop_magnetize()
        _clear_magnet_gun_state()
    elif equip is WeaponData:
        # Cancel any ongoing fire cooldown visual effects if needed
        pass
```

#### Removed Code

- Remove `enum Weapon { GUN, MAGNET_GUN }`
- Remove `var current_weapon: Weapon`
- Remove `match current_weapon:` blocks
- Remove `_switch_to_weapon()` — replaced by `_switch_to_equipment()`
- Remove `MagnetGunTexture` constant — use `MagnetToolData.weapon_sprite`
- Remove hardcoded magnet gun constants (`magnet_gun_hold_distance`, `repel_hold_time`, etc.) — read from `MagnetToolData`

#### Reading Equipment Properties

When using equipment-specific values, cast and read from the resource:

```gdscript
func _get_magnet_gun_hold_point() -> Vector2:
    var tool := current_equipment as MagnetToolData
    var hold_dist := tool.hold_distance if tool else 30.0
    var gun_dir := (muzzle.global_position - arm_sprite.global_position).normalized()
    return muzzle.global_position + gun_dir * hold_dist

func shoot() -> void:
    var wpn := current_equipment as WeaponData
    if not wpn:
        return
    _fire_cooldown = 1.0 / wpn.fire_rate
    var bullet := BulletScene.instantiate()
    bullet.global_position = muzzle.global_position
    bullet.direction = (get_global_mouse_position() - global_position).normalized()
    bullet.damage = wpn.damage
    bullet.speed = wpn.bullet_speed
    if wpn.bullet_sprite:
        bullet.get_node("Sprite2D").texture = wpn.bullet_sprite
    get_tree().current_scene.add_child(bullet)
```
