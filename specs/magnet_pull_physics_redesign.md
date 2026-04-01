# Magnet Pull Physics Redesign

## Overview

Refactor the magnet pull physics for both the **ship magnet** and the **magnet gun**. Replaces hard RigidBody2D collisions with soft-body Area2D simulation, adds a surface-level acceleration curve, weight-based drag, and new freeze/unfreeze mechanics.

---

## 1. Magnet Properties

The magnet tracks three pull parameters:

| Property | Description | Default |
|---|---|---|
| `pull_frequency` | Time between pulling each item (seconds) | 2.5 |
| `pull_batch_size` | Number of items pulled simultaneously per interval. **Always 1 for now.** Mechanics for >1 TBD. | 1 |
| `hold_capacity` | Max number of items the magnet can hold at once. Stops pulling once reached. | 10 |

> **`hold_capacity` replaces `max_carry_weight`.** Capacity is purely quantity-based — weight is no longer used to fill capacity. Weight only biases acceleration (see §5). Remove all `max_carry_weight`, `_current_weight`, and `is_overweight` logic from `magnet.gd`.

---

## 2. Acceleration Curve (Magnet Pull)

Items spawn at the bottom of the screen and are pulled upward. The speed profile has **three phases**:

### Phase 1 — Underground Approach
- Item accelerates from `pull_base_speed` toward `pull_max_speed` using the existing exponential ramp.
- This is the normal pull from bottom-of-screen up to the pile surface.

### Phase 2 — Surface Resistance
- When the item crosses the **surface line** (top edge of pile sprite), speed drops sharply toward near-zero.
- Simulates the item having "give" — it's stuck in the ground and must free itself.
- Duration: ~1.0–1.5 seconds of slow movement at the surface.
- Uses a steep deceleration curve on approach, then a slow crawl while "freeing."

### Phase 3 — Breakaway Acceleration
Two sub-phases simulate the item being **yanked free** before resuming normal pull:

1. **Yank** — Once the surface dwell time expires, the item sharply accelerates from near-zero to `breakaway_base_speed`. This is a very fast, almost instant spike (like a jolt). Visually conveys the item snapping loose from the ground.
2. **Normal ramp** — After reaching `breakaway_base_speed`, the item transitions into a standard exponential ramp-up toward `pull_max_speed` (same curve shape as Phase 1, but starting from a higher base). Item reaches the magnet field and enters the settle/freeze cycle.

### Surface Line (Line2D / Curve2D)
- A `Line2D` child is added to `SalvagePile` that traces a **simplified bezier curve** along the top edge of the pile sprite.
- This is **not** a pixel-perfect silhouette trace — it's a smooth, simple curve (3–5 control points) that roughly follows the top contour of the pile.
- Generated programmatically from the pile sprite dimensions using a `Curve2D` sampled into `Line2D` points.
- This line defines the "ground level" Y position for each X coordinate.
- When a pulled item's Y position crosses this line (interpolated at the item's X), Phase 2 triggers.

### Curve Parameters (on Magnet)
```
@export var surface_slow_speed: float = 15.0       # Near-zero crawl speed at surface
@export var surface_dwell_time: float = 1.2         # Seconds spent freeing from ground
@export var breakaway_ramp_time: float = 0.3        # Time to ramp from surface to max speed
@export var breakaway_max_speed: float = 2000.0     # Max speed after breakaway
```

### Pull State Enum (on SalvageItem)
```
enum PullPhase { UNDERGROUND, SURFACE, BREAKAWAY }
```
The item tracks which phase it's in and switches based on position relative to the surface line and elapsed time.

---

## 3. Soft-Body Collision (Area2D Simulation)

### Current Problem
Items are `RigidBody2D` with hard collisions. This causes jitter and glitching when items pile on each other at the magnet.

### New Approach — Hybrid (RigidBody2D + Area2D)
- **SalvageItem stays as `RigidBody2D`** for gravity, impulses, and storage falling.
- **Disable item-to-item collision via collision masks** — items no longer physically collide with each other through the RigidBody2D physics engine.
- **Add a child `Area2D`** (with the same shape) for soft-body overlap detection.
- When two items' areas overlap, a **simulated repulsion force** is applied as a velocity offset based on overlap depth and direction.
- This creates bouncy, soft collisions where items push each other apart without hard physics jitter.
- RigidBody2D collision is still used for: storage borders, magnet body, walls.

### Simulated Collision Force
```
# Per-frame, for each overlapping pair:
var overlap_dir = (self.global_position - other.global_position).normalized()
var overlap_depth = (combined_radii - distance_between_centers)
var repulsion = overlap_dir * overlap_depth * repulsion_strength
# Apply as velocity offset
```

### Collision Parameters (constants on SalvageItem)
```
const SOFT_REPULSION_STRENGTH: float = 300.0   # Force multiplier for overlap pushback
const SOFT_DAMPING: float = 0.9                # Velocity damping per frame
const SOFT_MAX_REPULSION: float = 500.0        # Cap on repulsion velocity
```

> **Decided: Hybrid.** RigidBody2D kept for storage/falling physics. Item-to-item RigidBody2D collision disabled via masks. Child Area2D handles soft-body overlap detection between items.

---

## 4. Freeze / Unfreeze Mechanics

### Freezing (Settling)
- Same principle as current: after a duration of **low velocity** (below a threshold), the item freezes in place.
- **Lower the freeze time** compared to current values (faster settling).

```
const FREEZE_VELOCITY_THRESHOLD: float = 20.0   # Speed below which settle timer ticks
const FREEZE_TIME: float = 0.15                  # Seconds of low velocity before freezing
```

### Unfreezing (Re-magnetize)
A frozen/attached item unfreezes and re-enters the magnet pull cycle **only** under these conditions:

1. **Adjacent item grabbed by magnet gun** — When a frozen item's neighbor is grabbed, all items in the contact chain unfreeze and re-settle. *(Already partially implemented via `get_contact_chain()`.)*
2. **Collision from another item** — When a newly pulled item's soft-body area overlaps a frozen item, the frozen item unfreezes and re-settles.

> Items that unfreeze re-enter the pull cycle from their current position (no teleporting). They get a fresh `_pull_elapsed = 0.0` and pull back toward the magnet.

---

## 5. Weight System

### SalvageItemData Changes
- **Add an explicit `weight` export** to `SalvageItemData` instead of computing from area × density.
- Weight is a float value set per-item in the resource.

```
@export var weight: float = 1.0   # kg, manually tuned per item
```

### Weight as Acceleration Bias
Weight does **not** replace the base acceleration — it **biases** it. A reference weight defines "normal" acceleration; heavier items are slightly slower, lighter items slightly faster.

```
const REFERENCE_WEIGHT: float = 1.0       # Weight at which acceleration is unmodified
const WEIGHT_INFLUENCE: float = 0.3        # 0.0 = weight ignored, 1.0 = fully proportional

# Acceleration multiplier:
var weight_factor = lerp(1.0, REFERENCE_WEIGHT / item_weight, WEIGHT_INFLUENCE)
# Applied to pull speed:
effective_speed = base_speed * weight_factor
```

- **Heavier items** → `weight_factor < 1.0` → slower acceleration, slower deceleration
- **Lighter items** → `weight_factor > 1.0` → faster acceleration, faster deceleration
- At `WEIGHT_INFLUENCE = 0.3`, a 2.0 kg item moves at ~85% speed; a 0.5 kg item at ~115%.

This applies to:
- Magnet pull (all three phases)
- Magnet gun pull
- Soft-body repulsion damping (heavier items resist pushback more)
- Storage settling (heavier items have more inertia)

---

## 6. Magnet Gun Pull

The magnet gun pull works like the magnet pull **except**:
- **No surface resistance** — no Phase 2 slowdown. Straight acceleration from current position to the gun anchor.
- **Faster ramp** — rapid acceleration curve (current behavior is fine, may tighten `pull_ramp_time`).
- Weight bias still applies.

No changes needed to the tethered/hold behavior after the item reaches the anchor.

---

## 7. Storage Friction

When an item is placed in storage via `place_in_storage()`:
- Apply **higher damping/friction** so items settle quickly and don't roll or drift.
- Increase `linear_damp` and `angular_damp` on the RigidBody2D (or apply manual friction if using Area2D movement).

```
const STORAGE_LINEAR_DAMP: float = 5.0    # High damping to prevent rolling
const STORAGE_ANGULAR_DAMP: float = 5.0   # High damping to prevent spinning
```

---

## 8. Files Affected

| File | Changes |
|---|---|
| `salvage_item_data.gd` | Add explicit `@export var weight` float, remove computed weight property and `DENSITY` constant |
| `salvage_item.gd` | New pull phase state machine, child Area2D for soft-body collision, disable item-to-item RigidBody2D collision, new freeze/unfreeze logic, weight bias on acceleration, storage friction |
| `magnet.gd` | Replace `max_carry_weight` with `hold_capacity` (quantity-based). Remove weight tracking. Add `pull_batch_size` export. Surface line reference. Acceleration curve params. |
| `salvage_pile.gd` | Add `Line2D` child with bezier surface curve along top edge of sprite |
| `player.gd` | Update `_unfreeze_item_for_resettle()` to use new unfreeze API. Magnet gun pull params may change. |

### New Files
None anticipated — all changes fit within existing files.

### Removed / Deprecated Code
- `SalvageItem`: Remove `ITEM_PULL_DAMPING`, `SETTLE_TIME` constants (replaced by new freeze params)
- `SalvageItem`: Remove or refactor `_get_ramped_pull_speed()` into phase-aware version
- `SalvageItem`: Remove item-to-item collision mask bit (layer 2 vs mask 2) from RigidBody2D; soft collision handled by child Area2D
- `SalvageItemData`: Remove computed `weight` property, `DENSITY` constant (replaced by `@export var weight`)
- `Magnet`: Remove `max_carry_weight`, `_current_weight`, `is_overweight`, all weight-tracking logic
- `Magnet`: `pull_interval` renamed/replaced by `pull_frequency`

---

## 9. Resolved Decisions

1. **Hybrid approach** — RigidBody2D kept for storage/falling. Item-to-item collision disabled via masks. Child Area2D for soft-body overlap.
2. **Bezier surface line** — Simple smooth curve (3–5 control points) approximating pile top, not a pixel-perfect silhouette trace.
3. **`hold_capacity` replaces `max_carry_weight`** — Capacity is quantity-only. Weight biases acceleration, not capacity.
4. **Batch size = 1 for now** — Mechanics for batch sizes >1 to be designed later.

---

## 10. Pull Mechanics Clarification

### Ship Magnet — Area-Based Pull
- The magnet's **Area2D field** defines the pull zone (trapezoid from magnet to pile).
- **All unfrozen items inside the pull area are continually affected** by the magnetic pull force.
- Items are spawned at the bottom of the screen (from the pile) and enter the pull area immediately.
- If an item were to leave the pull area (e.g., knocked out by collision), it would stop being pulled until it re-enters.
- **Frozen items are not affected** — they remain stationary until unfrozen (see §4).

### Magnet Gun — Click-Based Pull
- Only the **specific item clicked by the player** is grabbed and pulled to the gun anchor.
- No area effect — the magnet gun does not affect nearby items.
- This behavior is already correct in the current implementation.

### Implementation Notes
- `magnet.gd`: Track all unfrozen items currently inside the Area2D field. Each frame, apply pull force to all of them.
- `salvage_item.gd`: Remove the "always pulling once spawned" behavior. Instead, respond to per-frame pull calls from the magnet while inside its field.
- Items that exit the field (`area_exited`) stop receiving pull force (but may still have residual velocity).
