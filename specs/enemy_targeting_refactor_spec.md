# Enemy Targeting Refactor Spec

## Overview

This spec defines the refactor needed to support authored enemy targeting behavior in Magnetide.

The design goal is to move enemies away from the current generic "pick the highest-priority node every frame using distance-gated rules" behavior and toward a system where:

- Enemies can prioritize the `Player`, `Magnet`, or `Ship`
- `Magnet` and `Ship` expose multiple attack locations
- Each enemy type can have its own targeting rules
- Some enemies can change behavior after taking damage
- Some enemies can permanently ignore the player

This document is intentionally scoped as a prototype/refactor plan, not a final combat design pass.

---

## Authored Requirements

The following requirements come directly from the design notes and should be treated as the target behavior for the refactor.

### Core Target Types

Enemies may target one or more of:

- The `Player`
- The `Magnet`
- The `Ship`

### Multi-Point Targets

- The `Magnet` must expose multiple attackable target locations
- The `Ship` must expose multiple attackable target locations
- When an enemy chooses the `Magnet` or `Ship`, it should resolve the attack point using one of two modes:
  - `Random`: choose a random valid point
  - `Closest`: choose the closest valid point

### Target Evaluation Timing

Target selection should **not** run every frame.

Targets are evaluated only at specific authored moments, including:

- When the enemy first spawns
- When the enemy first takes damage, if that enemy supports damage-triggered retargeting
- When the enemy drops below a configured health threshold, if that enemy supports health-threshold retargeting
- Any other explicit retarget event defined by the enemy's behavior profile

Between those events, the enemy should stay committed to its current resolved target unless that target becomes invalid.

### No Range-Based Targeting

Target acquisition should not be limited by detection radius or proximity checks.

- Enemies should be able to acquire a valid target immediately when they spawn
- This should remain true even if the target is far away from the enemy's spawn position
- Spawn zones will be implemented later, but the targeting model should assume enemies can resolve their target as soon as they appear within those spawn zones

Targeting range should therefore not be a factor in deciding whether an enemy is allowed to pick a target.

### Enemy-Specific Priority Rules

Different enemy types can use different target priorities. Examples:

- Some enemies always start by targeting the `Player`
- Some enemies prefer the `Magnet` or `Ship`, but switch to the `Player` after taking damage
- Some enemies only ever attack the `Ship` and/or `Magnet`
- Some enemies always ignore the `Player`

### Important Behavioral Implication

Target selection is no longer just a single static priority list. It becomes a per-enemy behavior rule with conditional overrides.

---

## Current Implementation

The current enemy system exists, but it is much simpler than the desired design.

### Current Enemy Behavior

`_project/enemies/enemy.gd` currently:

- Uses one shared script for all enemies
- Finds a target every frame from three abstract groups:
  - `target_high`
  - `target_medium`
  - `target_low`
- Chooses the highest-priority target that is also within `detection_range`
- Breaks ties by nearest distance
- Chases the chosen target directly by its `global_position`
- Enters an attack state when within `attack_range`
- Deals damage by calling `current_target.take_damage(data.damage)` if that method exists

### Current Enemy Data

`_project/enemies/enemy_data.gd` currently contains:

- Basic combat stats
- Detection range and attack range
- Health-based retarget threshold
- Animation data

It does **not** currently contain:

- Target priority data
- Allowed target types
- Damage-response targeting rules
- Target-point selection rules
- Enemy-specific behavior profiles

### Current Target Availability

The world does not currently expose the required combat targets cleanly:

- The `Player` scene is in group `target_high`
- The `Ship` is not in an enemy target group
- The `Magnet` is not in an enemy target group
- The `Ship` does not expose combat target markers
- The `Magnet` does not expose combat target markers

### Current Damageability

Although enemies attempt to call `take_damage`, the main intended targets do not currently implement that contract:

- `Player` has no `take_damage` method
- `Ship` has no `take_damage` method
- `Magnet` has no `take_damage` method

As a result, the current enemy can path toward targets, but it cannot actually damage the authored target set yet.

### Current Behavioral Flexibility

All enemies currently share the same targeting model:

- Static priority buckets
- Distance tiebreak
- Optional low-health retarget to a higher-priority target

This is not enough to support:

- "Attack ship first, aggro player on hit"
- "Ignore player forever"
- "Only attack infrastructure"
- "Randomly choose one ship weak point"

---

## Gap Analysis

The main differences between the current implementation and the target design are below.

| Area | Current | Required |
|---|---|---|
| Target model | Single `Node2D` selected from global groups | Explicit target domains: `Player`, `Magnet`, `Ship` |
| Range gating | Target search is constrained by `detection_range` | No range-based target acquisition |
| Ship/magnet targeting | No dedicated attack points | Multiple authored attack points per structure |
| Structure point selection | No authored point-selection strategy | Per-enemy structure point mode: `Random` or `Closest` |
| Priority authoring | Shared global priority table in code | Per-enemy targeting configuration |
| Target evaluation timing | Target is re-evaluated every frame | Target is evaluated only on spawn and explicit retarget events |
| Conditional behavior | Only low-health retargeting | Damage-triggered aggro, health-threshold retargets, and type-specific rules |
| Damage contract | Intended targets do not implement `take_damage` | Player, ship, magnet, and/or target points must be attackable |
| Behavior variation | One generic script behavior | Distinct targeting policies per enemy archetype |
| Structure target choice | Direct node position only | `Random` or `Closest` point selection on ship/magnet |
| Data ownership | Stats only in `EnemyData` | Targeting behavior must be data-driven too |

---

## Proposed Refactor

The prototype should introduce a more explicit targeting model without forcing a full enemy AI rewrite.

### 1. Separate "Target Category" from "Target Point"

Enemies should first decide **what they want to attack**, then decide **where on that thing they will attack**.

Recommended two-step model:

1. Choose a target category:
   - `PLAYER`
   - `MAGNET`
   - `SHIP`
2. Resolve that category into a concrete target point:
   - `Player` resolves to the player node itself
   - `Magnet` resolves to a magnet attack point using the enemy's point-selection mode
   - `Ship` resolves to a ship attack point using the enemy's point-selection mode

This is the key structural change that the current system is missing.

### 2. Introduce Attackable Target Points

Add a lightweight node type for structure weak points / attack anchors.

Suggested responsibilities:

- Belongs to either `SHIP` or `MAGNET`
- Has a `global_position` enemies can chase
- Forwards damage to its owner
- Can expose metadata such as:
  - target category
  - point id/name
  - optional weight
  - optional enabled/disabled state

This avoids making enemies special-case ship and magnet internals.

### 3. Add a Real Targeting Profile to Enemy Data

Targeting behavior should move out of hardcoded group priorities and into enemy-authored data.

Suggested first-pass fields:

```gdscript
enum EnemyTargetCategory {
	PLAYER,
	MAGNET,
	SHIP,
}

enum EnemyTargetPointSelectionMode {
	RANDOM,
	CLOSEST,
}

@export var initial_target_priorities: Array[EnemyTargetCategory]
@export var damaged_target_priorities: Array[EnemyTargetCategory]
@export var retarget_on_damage: bool = false
@export var retarget_on_health_threshold: bool = false
@export var retarget_health_threshold: float = 0.3
@export var can_target_player: bool = true
@export var can_target_magnet: bool = true
@export var can_target_ship: bool = true
@export var lock_target_until_invalid: bool = true
@export var structure_point_selection_mode: EnemyTargetPointSelectionMode = EnemyTargetPointSelectionMode.RANDOM
@export var choose_new_structure_point_on_retarget: bool = true
```

The exact shape can change, but the system needs:

- Initial priorities
- Post-damage priorities
- A health-threshold retarget option
- An authored structure point-selection mode
- A way to forbid target categories entirely

### 4. Track Enemy Retarget State

Enemies need internal state for one-shot retarget events such as:

- `has_taken_damage`
- `has_triggered_health_threshold_retarget`

These flags allow the enemy to switch between:

- pre-damage targeting priorities
- post-damage targeting priorities

This directly supports the design note: "prefer ship/magnet, attack player only after taking damage."

### 5. Replace Group-Driven Target Search with Target Providers

Instead of scanning `target_high`, `target_medium`, and `target_low`, enemies should resolve candidates from explicit providers:

- `Magnetide.player`
- a ship target-point provider
- a magnet target-point provider

This keeps target selection tied to game concepts instead of editor group names.

### 6. Evaluate Targets Only on Authored Retarget Events

The enemy should not call its full target-selection routine every frame.

Recommended target evaluation triggers:

- on spawn
- on first damage taken, if enabled by profile
- on crossing a configured health threshold, if enabled by profile
- when the current target becomes invalid
- on any future explicit scripted retarget event

This keeps behavior stable and readable, and avoids enemies constantly changing their mind because of small distance changes frame to frame.

### 7. Remove Detection Range from Target Acquisition

The prototype should not use distance-based eligibility when deciding whether a target can be selected.

- `Player`, `Ship`, and `Magnet` targets are globally eligible if they are valid
- Structure attack points are eligible if they are valid and enabled
- Enemy spawn location should not delay target acquisition

Attack range can still exist for the separate question of when an enemy starts dealing damage, but range should not control who can be targeted.

### 8. Keep Movement/Attack Logic Mostly Intact

For the prototype, the enemy locomotion loop can stay simple:

- move directly toward chosen point
- enter attack state in range
- apply damage on interval

The refactor is primarily about target selection and target representation, not navigation/pathfinding.

---

## Recommended Runtime Model

### Target Resolution Flow

On spawn or a retarget event:

1. Build the active priority list for this enemy
   - if `has_taken_damage` and `retarget_on_damage`, use damaged priorities
   - otherwise use initial priorities
2. For each category in priority order:
   - resolve available candidates
   - filter invalid or disabled candidates
3. Choose one candidate:
   - `Player`: direct player node
   - `Ship`/`Magnet`: resolve one valid attack point using either `Random` or `Closest`
4. Store both:
   - current target category
   - current resolved target point/node
5. Keep that target until an authored retarget event occurs or the target becomes invalid

### Damage Flow

When an enemy takes damage:

1. Set `has_taken_damage = true`
2. Re-evaluate targeting if the enemy has a damage-response profile and this is the first qualifying damage event
3. If the new priority result differs, switch targets

### Health Threshold Flow

When an enemy's health drops below a configured threshold:

1. Check whether that threshold retarget has already fired
2. If not, mark it as triggered
3. Re-evaluate targeting if the enemy profile enables threshold retargeting

### Structure Damage Flow

When an enemy attacks a structure target point:

1. Enemy damages the target point
2. Target point forwards damage to its owning structure
3. Owning structure updates health / visuals / UI

This keeps enemy code generic.

---

## Prototype Scope

The first prototype does not need the full future combat system. It only needs enough support to prove the targeting model.

### Prototype Goals

The prototype should demonstrate all of the following:

1. One enemy that always targets the player
2. One enemy that targets ship or magnet first, then swaps to player after taking damage
3. One enemy that ignores player entirely
4. Ship and magnet each expose multiple attack points
5. Enemies support both `Random` and `Closest` structure point selection
6. Enemies can acquire targets immediately on spawn without range checks
7. Ship/magnet/player can all actually receive enemy damage

### Explicitly Out of Scope for This Prototype

- Advanced pathfinding
- Complex attack animations per target type
- Per-target-point health pools
- Repair systems
- Destructible ship parts
- Final enemy spawner tuning

---

## Proposed File Impact

### Existing Files To Update

| File | Change |
|---|---|
| `_project/enemies/enemy.gd` | Replace group-priority targeting with category/profile-based target resolution |
| `_project/enemies/enemy_data.gd` | Add targeting profile data |
| `_project/player/player.gd` | Add damage/health support or route damage into an owned health component |
| `_project/ship/ship.gd` | Add damage/health support and ship target-point registration |
| `_project/ship/magnet/magnet.gd` | Add damage/health support and magnet target-point registration |
| `_project/ship/ship.tscn` | Add ship attack point markers/nodes |
| `_project/ship/magnet/magnet.tscn` | Add magnet attack point markers/nodes |
| `_project/level/level.tscn` | Eventually remove the one-off placed test enemy and hand off to a spawner/director |

### New Files Recommended

| File | Purpose |
|---|---|
| `_project/enemies/enemy_target_point.gd` | Lightweight attackable point node for ship/magnet |
| `_project/enemies/enemy_target_profile.gd` or expanded `enemy_data.gd` | Data container for targeting behavior |
| `_project/common/health_component.gd` or equivalent | Optional shared damage/health handling if you want to avoid duplicate `take_damage` code |

The health component is optional, but some shared damage contract is strongly recommended because all three target domains need it.

---

## Suggested Data Shapes

These are not mandatory, but they fit the current codebase well.

### Enemy Target Category

```gdscript
enum EnemyTargetCategory {
	PLAYER,
	MAGNET,
	SHIP,
}
```

### Enemy Target Point

```gdscript
extends Marker2D
class_name EnemyTargetPoint

@export var category: EnemyTargetCategory
@export var owner_path: NodePath
@export var point_weight: float = 1.0
@export var enabled: bool = true

func take_damage(amount: float) -> void:
	var owner := get_node_or_null(owner_path)
	if owner and owner.has_method("take_damage"):
		owner.take_damage(amount)
```

### EnemyData Additions

```gdscript
@export_group("Targeting")
@export var initial_priority_order: Array[int] = []
@export var damaged_priority_order: Array[int] = []
@export var switch_to_damaged_profile_on_hit: bool = false
@export var retarget_on_health_threshold: bool = false
@export var retarget_health_threshold: float = 0.3
@export var structure_point_selection_mode: int = 0
```

Using `int` enum values is consistent with current Godot resource authoring if typed enum export friction becomes annoying.

`detection_range` should not be part of targeting behavior in the refactored design.

---

## Implementation Phases

### Phase 1: Make Targets Real

- Add `take_damage` support to `Player`, `Ship`, and `Magnet`
- Add visible or hidden attack point nodes to `Ship` and `Magnet`
- Provide a way to query those points from enemy code

This phase enables enemies to attack the authored target set at all.

### Phase 2: Refactor Enemy Target Selection

- Remove dependency on `target_high` / `target_medium` / `target_low`
- Remove distance-gated target acquisition from targeting logic
- Add per-enemy target category priority authoring
- Resolve structure categories to attack points using `Random` or `Closest`
- Stop re-running full target evaluation every frame

This phase enables authored target preference.

### Phase 3: Add Damage-Response Aggro

- Track `has_taken_damage`
- Track one-shot health-threshold retarget state
- Allow enemy profiles to switch priority sets after taking damage
- Retarget only at authored trigger moments when appropriate

This phase enables "infrastructure first, player after provocation."

### Phase 4: Prototype Enemy Archetypes

Create at least three prototype enemy profiles:

- `Hunter`: player-first
- `Raider`: magnet/ship-first, then player when damaged
- `Siege`: ship/magnet-only

These can all still use the same base `Enemy` scene/script.

---

## Integration Notes

### Threat System

The current threat spec already expects a future enemy spawner to own spawn cadence and enemy pool selection. This targeting refactor should stay separate from that.

- Threat/spawner chooses **which enemy archetype appears**
- Enemy targeting profile chooses **what that spawned enemy wants to attack**

That keeps responsibilities clean.

### Existing Scene Structure

The current scene hierarchy is actually a good fit for this refactor:

- `Level`
  - `Ship`
    - `Player`
    - `Magnet`

Because `Player`, `Ship`, and `Magnet` already have stable ownership paths, enemies can query them directly through `Magnetide` and through structure-owned target points.

### Existing Spawn Zones

`level.tscn` already contains directional `SpawnZones`, which should be useful once an enemy spawner is added.

The targeting implications should be explicit:

- An enemy spawned from a spawn zone should be able to resolve its target immediately
- It should not need to enter a detection radius before becoming aware of the player, ship, or magnet

This spec does not require changing the spawn zones yet, but the future spawner should work with this assumption.

---

## Risks and Design Decisions

### Risk: Attacking Structure Roots Directly

If enemies target `Ship` or `Magnet` root nodes directly, they will all stack on the same point and look bad.

Decision:

- Use multiple target points for structures

### Risk: Hardcoding Too Many Enemy Behaviors in `enemy.gd`

If every enemy exception lives in branches inside `enemy.gd`, the system will become brittle quickly.

Decision:

- Keep the shared script generic
- Push target preference rules into data/resources

### Risk: Duplicated Health Logic

If `Player`, `Ship`, and `Magnet` each invent their own incompatible damage handling, enemy attack code will become messy.

Decision:

- Standardize on a shared `take_damage(amount)` contract

---

## Resolved Decisions

1. The refactor should use explicit target categories: `Player`, `Magnet`, and `Ship`.
2. `Ship` and `Magnet` should expose multiple attack points, not just a single target position.
3. Structure attack points should support either `Random` or `Closest` selection, authored per enemy behavior.
4. Enemy target priorities should be data-driven per enemy type.
5. Damage taken can change an enemy's priority profile.
6. Target evaluation should happen on spawn and explicit retarget events, not every frame.
7. Target acquisition should not use detection range; enemies can choose targets immediately on spawn.
8. Some enemies must be allowed to ignore the player permanently.
9. The first prototype should reuse the current movement/attack loop and focus on target-selection architecture.

---

## Open Questions

These do not block the prototype spec, but they should be decided before full implementation.

1. Should `Ship` and `Magnet` share one combined hull pool, or should they have separate health pools?
2. Should structure attack points be purely positional, or can some points be disabled/destroyed independently later?
3. When an enemy targeting the `Ship` or `Magnet` takes damage, should it always retarget immediately, or only if the player is currently a valid target under that enemy's profile?
4. Should random structure target-point choice be uniform, or weighted so some points are hit more often?

---

## Recommended First Build Order

If we want to move from spec to implementation with the least churn, this is the cleanest order:

1. Add damage support to `Player`, `Ship`, and `Magnet`
2. Add ship/magnet target points in scenes
3. Add target-point query helpers on ship/magnet
4. Add authored structure point-selection mode (`Random` / `Closest`)
5. Remove range-gated target acquisition from the enemy targeting model
6. Refactor `Enemy` to resolve categories instead of abstract groups
7. Add event-driven retargeting for first-hit and health-threshold triggers
8. Author three prototype enemy profiles

That sequence gets the architecture in place before we spend time tuning enemy archetypes.
