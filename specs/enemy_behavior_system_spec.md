# Enemy Behavior System Spec

## Overview

This spec defines the next version of Magnetide's enemy behavior architecture.

The current enemy system is functional, but most enemy behavior still lives in one shared `Enemy` script. That is enough for the first worm-style enemy, but it will not scale cleanly once enemies need to become highly specialized: different silhouettes, different child nodes, different movement rules, different attack models, and sometimes entirely unique internal states.

The new system should split enemy behavior into four authored parts:

1. `EnemyData`: the enemy resource that owns shared stats, visuals, targeting properties, and behavior references.
2. `EnemyBase`: the common runtime class for all enemy instances.
3. `MoveBehavior`: a base behavior resource for enemy movement logic.
4. `AttackBehavior`: a base behavior resource for enemy attack logic.

The main design goal is specialization without base-class bloat. New enemies should usually be created by authoring an `EnemyData` resource, assigning enemy-specific movement and attack behavior scripts, and optionally adding supporting visual nodes for unique state presentation. `EnemyBase` should stay a thin shared shell for universal combat contracts.

---

## Design Goals

1. Keep enemy archetypes data-driven and inspector-authorable.
2. Let each enemy define bespoke movement and attack behavior scripts.
3. Keep common combat contracts centralized in `EnemyBase`.
4. Support highly distinct enemies without adding enemy-specific branches to the base class.
5. Make valid targets, target priority, target switching, and target-point selection first-class `EnemyData` settings.
6. Preserve compatibility with existing spawner, hitbox, target-point, and damage contracts where practical.
7. Use a small base behavior-tree selector with two delegated sub-state-machines: one for movement and one for attacking.
8. Keep the first implementation small enough to migrate the existing worm enemy before adding new archetypes.

---

## Shared Versus Enemy-Specific

Only universal enemy infrastructure should be shared.

Shared through `EnemyBase`:

- hitbox setup and access
- taking damage
- current health
- shared high-level states: `IDLE`, `MOVE`, `ATTACK`, and `DEATH`
- death signal
- shared death animation/presentation hooks
- target group resolution
- structure target-point resolution
- target acquisition and target switching
- base behavior-tree selection and update orchestration
- run-end shutdown

Enemy-specific through behavior scripts and enemy scenes:

- movement rules
- attack rules
- internal movement state machine
- internal attack state machine
- enemy-specific phases inside those behavior state machines
- visuals beyond common death handling
- projectile, beam, possession, summon, charge, burrow, orbit, or support logic
- special timing, wind-ups, recoveries, tells, and reactions
- optional extra visual elements for specialized states

If a behavior would make an enemy feel unique, it should live in that enemy's concrete behavior script instead of `EnemyBase`.

---

## Current Project Context

The project already has several pieces that should be reused:

- `_project/enemies/enemy.gd` is the current runtime enemy class.
- `_project/enemies/enemy_data.gd` is the current enemy stat and targeting resource.
- `_project/enemies/hitbox.gd` provides the shared `take_damage(amount, source)` forwarding contract.
- `_project/enemies/enemy_target_point.gd` provides ship/magnet attack anchors.
- `_project/level/enemies/enemy_spawn_definition.gd` lets the spawner select enemy scenes and data.
- `_project/player/equipment/weapon_fire_behavior.gd` already demonstrates the local pattern of behavior resources.

The current enemy script already handles:

- health and death
- enemy hitbox setup
- target resolution by group
- basic chase movement
- attack range and attack interval
- direct damage delivery
- sprite animation and death animation

The new system should keep only the truly shared responsibilities in the base class. Enemy-specific movement, attack timing, visual state, and special state machines should live in the enemy's assigned behavior scripts.

---

## Core Architecture

### Runtime Ownership

At runtime, one enemy instance should be structured like this:

```text
EnemyBase
  uses EnemyData
    owns enemy-specific MoveBehavior template
    owns enemy-specific AttackBehavior template
```

`EnemyData` is authored once and may be shared by many spawned enemies.

`EnemyBase` is instanced per enemy.

`MoveBehavior` and `AttackBehavior` are authored as resources on `EnemyData`. In most cases, each enemy archetype should have its own concrete movement and attack behavior scripts. Because Godot resources are shared by default, `EnemyBase` should create runtime duplicates of assigned behaviors if those behaviors need mutable state.

### Responsibility Split

| Part | Owns | Does Not Own |
|---|---|---|
| `EnemyData` | Stats, visuals, hitbox config, valid targets, target priority mode, target switching modes, target-point rules, loot table, enemy-specific behavior references | Runtime health, current target, timers, physics state |
| `EnemyBase` | Health, hitbox, damage intake, shared `IDLE` / `MOVE` / `ATTACK` / `DEATH` states, death flow, target acquisition, target switching, target-point resolution, behavior orchestration | Enemy-specific movement or attack state machines |
| `MoveBehavior` | Enemy-specific movement rules and internal movement state machine | Shared health, death, spawn selection |
| `AttackBehavior` | Enemy-specific attack rules, internal attack state machine, and attack presentation | Shared health, death, spawn selection |

---

## Part 1: EnemyData

`EnemyData` is the base resource for an enemy archetype. This spec should evolve the current `_project/enemies/enemy_data.gd` class rather than replacing it with a renamed resource class.

### Recommended File

```text
_project/enemies/enemy_data.gd
```

### Responsibilities

`EnemyData` should own:

- stable enemy id and display name
- max health
- base contact/attack damage
- base movement speed
- attack range or engagement distance
- target range
- target acquire interval
- hitbox size and collision setup data
- `SpriteFrames` resource for the enemy's single `AnimatedSprite2D`
- valid target groups
- target priority mode
- target switching mode
- target-point selection mode
- death presentation tuning
- assigned enemy-specific `MoveBehavior`
- assigned enemy-specific `AttackBehavior`
- optional `LootTable`, empty by default
- optional tags for future systems, such as `flying`, `armored`, `swarm`, `elite`, or `boss`

### Suggested Shape

```gdscript
@tool
extends Resource
class_name EnemyData

@export var id: StringName = &""
@export var enemy_name: String = ""

@export_group("Stats")
@export var max_health: float = 50.0
@export var damage: float = 5.0
@export var movement_speed: float = 100.0
@export var attack_range: float = 50.0
@export var target_range: float = 500.0
@export var target_acquire_interval: float = 1.0

@export_group("Combat Shape")
@export var hitbox_size: Vector2 = Vector2(40.0, 40.0)

@export_group("Visuals")
@export var sprite_frames: SpriteFrames

var valid_targets: Array[String] = []
var target_range: float = 500.0
var target_acquire_interval: float = 1.0
var target_priority_mode: TargetSelectionMode = TargetSelectionMode.ORDER
var target_priority_order: Array[String] = []
var target_priority_random_excludes: Array[String] = []
var target_switching_mode: TargetSwitchingMode = TargetSwitchingMode.DEFAULT
var proximity_switch_interval: float = 1.0
var target_point_selection_mode: TargetSelectionMode = TargetSelectionMode.CLOSEST

func _get_property_list() -> Array[Dictionary]:
	# Expose target settings in mode-specific inspector sections.
	return []

@export_group("Behaviors")
@export var move_behavior: MoveBehavior
@export var attack_behavior: AttackBehavior

@export_group("Rewards")
@export var loot_table: LootTable = null
```

This sketch is not final code. It shows the ownership boundary. `EnemyData` should be a `@tool` resource and use `_get_property_list()` for target authoring so mode-specific settings only appear when their mode is selected.

Enemy data stats should be treated as common defaults, not mandatory behavior rules. For example, `movement_speed`, `damage`, and `attack_range` are available to behavior scripts, but a specialized behavior may ignore them or interpret them differently if that enemy's design requires it.

### Spawn Integration

`EnemySpawnDefinition` should continue to reference `EnemyData`.

```gdscript
@export var enemy_data: EnemyData
```

Spawn-specific data should stay in `EnemySpawnDefinition`:

- allowed spawn zones
- max batch sizes by threat
- spawn weights through `WeightedEnemySpawnEntry`

Enemy-specific combat, targeting, visual, reward, and behavior data should live in `EnemyData`. Spawn-time data such as allowed zones and batch sizes should stay in `EnemySpawnDefinition`.

---

## Part 2: EnemyBase

`EnemyBase` is the common runtime class for all enemies. It can be implemented by evolving the current `_project/enemies/enemy.gd`.

### Recommended File

```text
_project/enemies/enemy_base.gd
```

The class name may be `EnemyBase` while keeping `Enemy` as a compatibility alias if existing systems rely on `Enemy`.

### Responsibilities

`EnemyBase` should own:

- current health
- shared high-level state: `IDLE`, `MOVE`, `ATTACK`, or `DEATH`
- damage intake through `take_damage(amount, source)`
- death flow and `died` signal
- hitbox setup and `get_hitbox()`
- primary `AnimatedSprite2D` setup from `EnemyData.sprite_frames`
- current target group, target point, and damage target
- target acquisition timer
- target acquisition from `EnemyData.valid_targets`
- target range filtering
- target priority selection
- target switching rules
- target-point resolution
- current target validity checks
- runtime behavior instances
- behavior lifecycle calls
- base state transition requests from behavior scripts
- shared death animation/presentation hooks
- run-end shutdown through `stop_for_run_end()`

### Non-Responsibilities

`EnemyBase` should not contain enemy-specific branches like:

- "if this is a charger, wind up first"
- "if this is a worm, chase directly"
- "if this is a spitter, keep distance"
- "if this is a shield enemy, rotate around the magnet"

Those rules belong in movement or attack behavior resources.

### Runtime Lifecycle

Recommended lifecycle:

1. `_ready()`
2. validate assigned `EnemyData`
3. initialize current health from `EnemyData`
4. configure hitbox and visuals from `EnemyData`
5. create runtime behavior instances
6. call behavior setup hooks
7. acquire initial target
8. enter the shared `IDLE` state
9. each physics tick:
   - validate the current target
   - run periodic target acquisition when the acquire timer elapses
   - apply target switching rules when a current target exists
   - evaluate the base behavior selector
   - if there is no valid target, enter or remain in `IDLE`
   - if there is a valid target and the attack behavior's attack conditions are true, enter or remain in `ATTACK`
   - if there is a valid target and attack conditions are false, enter or remain in `MOVE`
   - if the base state is `MOVE`, tick only the move behavior's internal state machine
   - if the base state is `ATTACK`, tick only the attack behavior's internal state machine
   - move via `CharacterBody2D`
   - update animation
10. on damage:
   - reduce health
   - notify behaviors
   - apply `RECEIVED_DAMAGE` target switching to the damage source if enabled
   - enter `DEATH` if health reaches zero
11. on death:
   - disable hitbox
   - notify behaviors
   - emit `died`
   - run shared death presentation

### Behavior Context

Movement and attack behaviors need access to common runtime data without duplicating base logic. The simplest first version can pass the enemy instance into behavior methods:

```gdscript
func physics_tick(enemy: EnemyBase, delta: float) -> void:
	pass
```

If behavior methods start reaching too deeply into the enemy later, introduce a small context object or a documented set of public getters.

### Public API For Behaviors

`EnemyBase` should expose stable helper methods and properties for behavior resources.

Recommended helpers:

- `get_data() -> EnemyData`
- `get_base_state() -> EnemyBase.State`
- `request_base_state(state: EnemyBase.State) -> void`
- `is_idle() -> bool`
- `is_moving() -> bool`
- `is_attacking() -> bool`
- `is_dead() -> bool`
- `get_current_target_root() -> Node2D`
- `get_current_focus_point() -> Node2D`
- `get_current_target_point() -> Node2D`
- `get_current_damage_target() -> Node2D`
- `has_valid_target() -> bool`
- `distance_to_target() -> float`
- `direction_to_target() -> Vector2`
- `face_target() -> void`
- `request_target_acquisition() -> void`
- `evaluate_target_acquisition() -> bool`
- `get_current_target_group() -> StringName`
- `deal_damage_to_current_target(amount: float) -> void`
- `get_projectile_parent() -> Node`
- `set_desired_velocity(velocity: Vector2) -> void`
- `is_aggroed() -> bool`
- `request_death() -> void`

The exact method names can change during implementation. The important point is that behaviors should call a stable enemy API rather than poking many internal variables directly.

---

## Part 3: MoveBehavior

`MoveBehavior` defines the shared interface for enemy movement scripts. Each `EnemyData` resource should assign its own concrete movement behavior resource.

### Recommended File

```text
_project/enemies/behaviors/move_behavior.gd
```

### Responsibilities

`MoveBehavior` should own:

- target approach logic
- desired velocity calculation
- movement-specific timers and state machines
- optional movement animation hints
- decisions like chase, orbit, flee, strafe, charge, idle, or reposition
- all enemy-specific movement states that run while the base state is `MOVE`
- overridable state registration, transition, enter, exit, and update hooks for its internal movement state machine
- stopping or yielding when the base state changes to `ATTACK` or `DEATH`

### Base Contract

The base class should provide no-op or simple helper behavior so concrete enemy movement scripts can override the methods they need.

Suggested methods:

```gdscript
extends Resource
class_name MoveBehavior

func setup(enemy: EnemyBase, data: EnemyData) -> void:
	pass

func get_initial_state(enemy: EnemyBase) -> StringName:
	return &""

func register_states(enemy: EnemyBase) -> void:
	pass

func can_transition(enemy: EnemyBase, from_state: StringName, to_state: StringName) -> bool:
	return true

func request_state(enemy: EnemyBase, state: StringName) -> void:
	pass

func get_current_state() -> StringName:
	return &""

func on_enter_state(enemy: EnemyBase, state: StringName, previous_state: StringName) -> void:
	pass

func on_exit_state(enemy: EnemyBase, state: StringName, next_state: StringName) -> void:
	pass

func update_state(enemy: EnemyBase, state: StringName, delta: float) -> void:
	pass

func on_enter_move(enemy: EnemyBase) -> void:
	pass

func on_exit_move(enemy: EnemyBase) -> void:
	pass

func physics_tick(enemy: EnemyBase, delta: float) -> void:
	pass

func on_target_changed(enemy: EnemyBase) -> void:
	pass

func on_damaged(enemy: EnemyBase, amount: float) -> void:
	pass

func on_death(enemy: EnemyBase) -> void:
	pass
```

These methods are intentionally generic. A simple enemy can ignore most of them, while a specialized enemy can override them to add states such as `CHASE`, `ORBIT`, `WINDUP`, `DASH`, `BURROW`, or `RECOVER` without changing `EnemyBase`.

### First Concrete Movement Behavior

The first implementation should include only the movement behavior needed to migrate the existing worm.

Recommended first behavior:

```text
_project/enemies/worm/worm_move_behavior.gd
```

`WormMoveBehavior` should reproduce current worm movement:

- move toward the current target point
- run only while the base state is `MOVE`
- move until the worm attack behavior reports that attack conditions are true
- stop or yield when the base state enters `ATTACK`
- rotate toward target
- use `EnemyData` movement speed

Future enemy-specific movement scripts may implement:

- orbiting around a target before lunging
- charging after a wind-up
- keeping distance while firing
- waypoint or patrol movement
- swarm drift and separation
- stationary turret behavior
- burrowing, phasing, or teleporting
- unique state machines owned entirely by that enemy's movement script

### Movement And Attack Boundary

The movement behavior can decide positioning, but it should not apply damage.

For example:

- A charger's movement behavior can perform the wind-up and dash motion.
- Its attack behavior should decide whether the dash hit deals damage, how often it can happen, and what target receives the damage.

If an enemy has movement and attack that are tightly coupled, that coupling should live in that enemy's paired behavior scripts. Prefer explicit behavior-to-behavior coordination through `EnemyBase` helper methods over moving the logic into `EnemyBase`.

---

## Part 4: AttackBehavior

`AttackBehavior` defines the shared interface for enemy attack scripts. Each `EnemyData` resource should assign its own concrete attack behavior resource.

### Recommended File

```text
_project/enemies/behaviors/attack_behavior.gd
```

### Responsibilities

`AttackBehavior` should own:

- attack cooldowns
- attack range checks or engagement checks
- attack condition validation through `can_attack(enemy)`
- hit timing
- melee, projectile, beam, aura, burst, or summon attack rules
- attack-specific state machines such as wind-up, recovery, burst count, channeling, possession, or projectile spread
- calling back into `EnemyBase` to apply direct damage
- spawning projectiles through the shared `Projectile` class
- all enemy-specific attack states that run while the base state is `ATTACK`
- overridable state registration, transition, enter, exit, and update hooks for its internal attack state machine
- stopping or yielding when the base state changes to `MOVE`, `IDLE`, or `DEATH`

### Base Contract

Suggested methods:

```gdscript
extends Resource
class_name AttackBehavior

func setup(enemy: EnemyBase, data: EnemyData) -> void:
	pass

func get_initial_state(enemy: EnemyBase) -> StringName:
	return &""

func register_states(enemy: EnemyBase) -> void:
	pass

func can_transition(enemy: EnemyBase, from_state: StringName, to_state: StringName) -> bool:
	return true

func request_state(enemy: EnemyBase, state: StringName) -> void:
	pass

func get_current_state() -> StringName:
	return &""

func on_enter_state(enemy: EnemyBase, state: StringName, previous_state: StringName) -> void:
	pass

func on_exit_state(enemy: EnemyBase, state: StringName, next_state: StringName) -> void:
	pass

func update_state(enemy: EnemyBase, state: StringName, delta: float) -> void:
	pass

func on_aggro(enemy: EnemyBase) -> void:
	pass

func on_aggro_cleared(enemy: EnemyBase) -> void:
	pass

func can_attack(enemy: EnemyBase) -> bool:
	return false

func on_enter_attack(enemy: EnemyBase) -> void:
	pass

func on_exit_attack(enemy: EnemyBase) -> void:
	pass

func physics_tick(enemy: EnemyBase, delta: float) -> void:
	pass

func on_target_changed(enemy: EnemyBase) -> void:
	pass

func on_damaged(enemy: EnemyBase, amount: float) -> void:
	pass

func on_death(enemy: EnemyBase) -> void:
	pass
```

These methods are intentionally generic. A simple attack can ignore most of them, while a specialized enemy can override them to add states such as `AIM`, `WINDUP`, `BITE`, `CHANNEL`, `RECOVER`, `POSSESS`, or `SUMMON` without changing `EnemyBase`.

### First Concrete Attack Behavior

The first implementation should include only the attack behavior needed to migrate the existing worm.

Recommended file:

```text
_project/enemies/worm/worm_attack_behavior.gd
```

`WormAttackBehavior` should support:

- attack range from `EnemyData`
- attack interval or cooldown
- attack condition validation, such as in range and cooldown ready
- damage from `EnemyData`
- an internal attacking cooldown state
- direct damage against the current damage target
- leaving attack state if the target becomes invalid or too far away

Future enemy-specific attack scripts may implement:

- projectile volleys
- charge impacts
- beams or channels
- area pulses
- summons
- shield support
- self-destruction
- possession or disabling effects
- unique state machines owned entirely by that enemy's attack script

---

## Projectile System

Attack behaviors are responsible for projectiles.

The project should add one shared projectile class that can be used by player weapons, enemy attacks, and future projectile-producing systems. This should replace the current player-specific `_project/player/bullet.gd` path over time.

### Recommended File

```text
_project/utils/projectile.gd
```

This should be a script-only projectile implementation. It does not need a projectile scene. Attack behaviors and player weapon behaviors should statically reference helper functions on this script to create projectile instances on the fly.

### Responsibilities

`Projectile` should own:

- movement direction
- projectile speed
- damage
- pierce count
- lifetime
- collision and damage application
- damaged-target tracking so pierce does not hit the same target repeatedly
- sprite setup
- source tracking for filtering ownership or friendly fire rules

### Helper Construction

`Projectile` should expose static helper functions for easy runtime spawning from dictionaries.

Suggested shape:

```gdscript
extends Area2D
class_name Projectile

static func spawn(parent: Node, values: Dictionary) -> Projectile:
	return null

static func create(values: Dictionary) -> Projectile:
	return null

func configure(values: Dictionary) -> void:
	pass
```

The `parent` argument to `spawn(...)` is required. The values dictionary should require the following fields:

- `global_position`
- `direction`
- `sprite`
- `damage`
- `speed`
- `lifetime`
- `collision_mask`
- `source`

`pierce` is optional and should default to `1`.

All other projectile fields should be required for now. The goal is that attack behaviors can spawn projectiles without building a custom scene for every simple shot, while still failing clearly if a required projectile value is missing.

Example behavior-side usage:

```gdscript
Projectile.spawn(enemy.get_projectile_parent(), {
	"global_position": enemy.global_position,
	"direction": enemy.direction_to_target(),
	"sprite": projectile_texture,
	"damage": data.damage,
	"speed": 420.0,
	"lifetime": 3.0,
	"collision_mask": enemy_projectile_mask,
	"source": enemy,
	"pierce": 1,
})
```

### Player Bullet Migration

The current `_project/player/bullet.gd` should eventually be migrated into this shared projectile class.

Player weapons should use the same projectile helper path as enemy attack behaviors, while still being able to pass player-specific values such as weapon damage, pierce, speed, spread, and source.

---

## Targeting Model

Targeting is a first-class part of this system. It should be configured on `EnemyData` and executed by shared functionality in `EnemyBase`.

Targeting should be split into separate concerns that work together:

1. Valid target groups
2. Target acquisition timing and range
3. Target priority selection
4. Target switching rules
5. Target-point selection

Keeping these concerns separate makes enemy targeting easier to author and easier to change without rewriting movement or attack behavior scripts.

### Target Groups

All enemies should expose an array of possible target groups on `EnemyData`. Each entry is the name of a Godot group that can contain one or more targetable nodes.

Default target groups:

- `"player"`
- `"ship"`
- `"magnet"`

Player, ship, and magnet root nodes should add themselves to their matching groups. Future targetable objects, such as ship turrets, can be supported by adding those nodes to a new group and authoring that group name into `EnemyData`.

This array defines which groups the enemy is allowed to search. If a group name is not present in the array, the enemy should never acquire nodes from that group.

Suggested field:

```gdscript
var valid_targets: Array[String] = []
```

### Acquisition Timing And Range

Enemies should attempt to acquire a target:

- when they spawn
- every configured interval after spawn, defaulting to about `1.0` second

Targets are only valid acquisition candidates if they are inside the enemy's target range.

Suggested fields:

```gdscript
@export var target_range: float = 500.0
@export var target_acquire_interval: float = 1.0
```

This means target acquisition is no longer global awareness. An enemy must find a valid target node in one of its configured groups inside range.

### Target Priority Mode

When multiple valid target nodes are in range, `EnemyBase` should choose one using the enemy's target priority mode.

The target priority mode should use a shared enum:

```gdscript
enum TargetSelectionMode {
	ORDER,
	RANDOM,
	CLOSEST,
}
```

Modes:

- `ORDER`: use `target_priority_order` to define highest-to-lowest group priority, filtered by `valid_targets`; candidate nodes from the first matching group win, with closest used as the tie-breaker inside that group
- `RANDOM`: choose randomly among valid in-range target nodes, excluding candidates whose group appears in `target_priority_random_excludes`
- `CLOSEST`: choose the closest valid in-range target

Suggested fields:

```gdscript
var target_priority_mode: TargetSelectionMode = TargetSelectionMode.ORDER
var target_priority_order: Array[String] = []
var target_priority_random_excludes: Array[String] = []
```

`target_priority_order` should only be exposed in the Priority Settings inspector section when `target_priority_mode == ORDER`.

`target_priority_random_excludes` should only be exposed in the Priority Settings inspector section when `target_priority_mode == RANDOM`. Any group present in this list should be removed from the normal acquisition priority group list before candidates are gathered. If all groups are excluded, no target should be acquired from that random roll.

`CLOSEST` does not currently need extra priority tuning variables.

### Target Switching Modes

Target switching should be separate from initial target acquisition.

Switching modes only matter when the enemy already has a current target.

Suggested enum:

```gdscript
enum TargetSwitchingMode {
	DEFAULT,
	RECEIVED_DAMAGE,
	PROXIMITY,
}
```

Modes:

- `DEFAULT`: switch only when the current target is lost, destroyed, disabled, or otherwise invalid
- `RECEIVED_DAMAGE`: when the enemy receives damage, it should switch directly to the damage source if that source belongs to one of the valid priority groups. This validation should ignore `target_priority_random_excludes`, so a group can be excluded from normal random acquisition while still being targetable when it is the damage source.
- `PROXIMITY`: when a higher-priority target enters range, the enemy may switch to that target

Suggested fields:

```gdscript
var target_switching_mode: TargetSwitchingMode = TargetSwitchingMode.DEFAULT
var proximity_switch_interval: float = 1.0
```

Switching should respect the same valid target list, target range, and priority mode as acquisition.

`proximity_switch_interval` should only be exposed in the Switching Settings inspector section when `target_switching_mode == PROXIMITY`.

`PROXIMITY` should compare candidate nodes using the active `target_priority_mode`. With `ORDER`, this means a node from a group earlier in `target_priority_order` entered range. With `CLOSEST`, this means a closer valid target node entered range. With `RANDOM`, proximity switching can re-roll among valid in-range target nodes when the proximity switch interval runs.

### Target Points

Once a target root is acquired, `EnemyBase` should resolve a concrete focus point for movement and attack behavior.

Each target root may expose an array of target points as an exported variable or through a shared accessor. If that array exists, `EnemyBase` should choose one target point using the same `TargetSelectionMode` enum:

- `ORDER`
- `RANDOM`
- `CLOSEST`

If no target-point array exists on the target root, the target root or parent node's own `global_position` should be used as the focus point.

Suggested field:

```gdscript
var target_point_selection_mode: TargetSelectionMode = TargetSelectionMode.CLOSEST
```

Target point selection should have a dedicated Target Point Settings inspector section. `ORDER`, `RANDOM`, and `CLOSEST` currently need no extra tuning variables beyond the selected mode.

This means target-point selection is separate from target group priority. An enemy can choose a node from the `"ship"` group by `ORDER`, then choose the closest ship target point by `CLOSEST`, or choose both target node and target point randomly.

### EnemyBase Targeting Functionality

`EnemyBase` should implement the shared runtime targeting behavior:

- keep a target acquisition timer
- acquire a target on spawn
- re-run acquisition every `target_acquire_interval` seconds
- gather candidate nodes with `get_tree().get_nodes_in_group()` for each configured group in `valid_targets`
- filter candidates by `target_range`
- choose a target root from the candidate node list using `target_priority_mode`
- apply the configured target switching mode only when a current target exists
- resolve target points from the target root
- choose a target point using `target_point_selection_mode`
- fall back to the target root position if no target-point array exists
- store current target group, target root, focus point, and damage target
- validate target roots, focus points, and damage receivers
- notify movement and attack behaviors when the target changes
- derive aggro from target validity

### Aggro

Aggro should be derived from target validity.

If an enemy has a valid resolved target in any configured target group, it is aggroed:

- `PLAYER`
- `SHIP`
- `MAGNET`

If the enemy has no valid target, it is not aggroed.

Aggro should therefore not require line of sight, a separate aggro request, or enemy-specific activation logic. Enemy-specific behavior scripts can still decide what to do while aggroed, but they should not own the core meaning of aggro.

---

## Runtime Behavior Model

The enemy runtime should be modeled as one small behavior-tree selector with two delegated sub-state-machines.

At a high level:

```text
EnemyBase selector
  DEATH   if dead or death requested
  IDLE    if no valid target
  ATTACK  if AttackBehavior.can_attack(enemy)
  MOVE    otherwise

MOVE leaf
  ticks MoveBehavior's internal state machine

ATTACK leaf
  ticks AttackBehavior's internal state machine
```

### 1. Base Behavior Selector

`EnemyBase` owns the shared high-level behavior selector that every enemy exhibits:

```text
IDLE
MOVE
ATTACK
DEATH
```

These selector results should be exposed as the enemy's shared base state and should be accessible to movement and attack behavior scripts through `EnemyBase` helper methods.

`IDLE` means the enemy has no valid target. If an enemy has no valid player, ship, or magnet target, it should be idle.

`MOVE` means the base enemy has handed movement control to the assigned `MoveBehavior`. While in this state, the move behavior's internal state machine decides what "moving" means for that enemy.

`ATTACK` means the base enemy has handed attack control to the assigned `AttackBehavior`. While in this state, the attack behavior's internal state machine decides what "attacking" means for that enemy.

`DEATH` means the enemy has entered the shared death flow:

- stop taking combat actions
- disable its hitbox
- emit `died`
- play or trigger death presentation
- eventually free or clean up the instance

The base selector should not contain enemy-specific branches. It decides only the high-level mode and delegates the actual behavior.

Recommended selector priority:

1. If health is zero or death was requested, enter `DEATH`.
2. If there is no valid target, enter `IDLE`.
3. If there is a valid target and `AttackBehavior.can_attack(enemy)` returns true, enter `ATTACK`.
4. If there is a valid target and attack conditions are not currently true, enter `MOVE`.

This keeps `MOVE` and `ATTACK` mutually exclusive. An enemy should never run its movement and attack behavior state machines as active control modes at the same time.

### 2. Movement Behavior State Machine

`MoveBehavior` owns the enemy-specific movement state machine.

Whenever the base state is `MOVE`, `EnemyBase` should tick the current move behavior and should not tick the attack behavior as the active control mode. The movement behavior may then run whatever states that enemy requires:

- `WormMoveBehavior` may only need simple chasing state.
- A charger movement behavior may own `WINDUP`, `DASHING`, and `RECOVERING`.
- A burrower movement behavior may own `SUBMERGED`, `EMERGING`, and `EXPOSED`.

The movement behavior may request base state changes when appropriate. For example, it can request `IDLE` when it has no valid movement to perform, request `MOVE` after a pause, or request `DEATH` through the base if movement logic causes self-destruction.

### 3. Attack Behavior State Machine

`AttackBehavior` owns the enemy-specific attack state machine.

Aggro is derived from valid target state. When `EnemyBase` has a valid resolved target, it should treat the enemy as aggroed and notify the assigned attack behavior.

`ATTACK` is entered only when aggro is true and the attack behavior's conditions pass. Those conditions are enemy-specific, but common examples include:

- target is in attack range
- cooldown is ready
- line-up or wind-up requirements are satisfied
- the attack behavior is not recovering

When the base state is `ATTACK`, `EnemyBase` should tick the current attack behavior and should not tick the move behavior as the active control mode. From there, the attack behavior decides what attacking means:

- A worm attack behavior may own `COOLDOWN` and `BITE`.
- A beam attack behavior may own `AIMING`, `CHANNELING`, and `COOLDOWN`.
- A possession attack behavior may own `SEEK_HOST`, `POSSESSING`, `CONTROLLED`, and `EJECTED`.
- A summoner attack behavior may own `CASTING`, `SPAWNING`, and `RECOVERING`.

The attack behavior may request base state changes while it runs. For example, it can request `MOVE` when it needs repositioning or request `DEATH` after a self-destruct attack.

### Behavior Tree Coordination

The base behavior selector is authoritative for shared state, but specialized behaviors are allowed to request transitions or invalidate their current branch.

Recommended coordination rules:

- `EnemyBase` owns the current base selector result and validates base state transitions.
- `MoveBehavior` owns movement phases and only ticks while the base state is `MOVE`.
- `AttackBehavior` owns attack phases and only ticks as the active control mode while the base state is `ATTACK`.
- Aggro should not become a shared base state; it is derived from whether the enemy currently has a valid target.
- Losing the current valid target should clear aggro and notify the attack behavior.
- Having a valid target should make the enemy not-idle.
- Having no valid target should make the enemy idle.
- Attack conditions decide whether a targeted enemy is in `ATTACK` or `MOVE`.
- `MOVE` and `ATTACK` are mutually exclusive base states.
- `DEATH` overrides movement and attack behavior state machines.
- Behavior scripts should affect shared systems only through explicit `EnemyBase` methods such as setting velocity, requesting a base state change, requesting target acquisition, dealing damage, disabling hitboxes through the base, or requesting death.

### Internal State Machine Extension Hooks

Both `MoveBehavior` and `AttackBehavior` should provide easy overridable functions for building their own internal state machines.

The goal is that creating a new enemy should feel like:

1. Create a new concrete move or attack behavior script.
2. Define the internal states that behavior needs.
3. Override state enter, exit, update, and transition methods.
4. Let `EnemyBase` plug that behavior into the shared selector automatically.

Behavior scripts should not need to reimplement shared enemy wiring just to add a new movement or attack state. The base behavior classes should provide common internal state-machine helpers for:

- setting the initial internal state
- registering or declaring known states
- requesting an internal state transition
- validating transitions
- handling state enter callbacks
- handling state exit callbacks
- updating the current state
- querying the current internal state

Concrete enemy behaviors can then focus on enemy-specific logic. For example:

- a charger move behavior can add `APPROACH`, `WINDUP`, `DASH`, and `RECOVER`
- a burrower move behavior can add `SUBMERGED`, `EMERGE`, and `CHASE`
- a worm attack behavior can add `COOLDOWN` and `BITE`
- a beam attack behavior can add `AIM`, `CHANNEL`, and `RECOVER`
- a possession attack behavior can add `SEEK_HOST`, `POSSESS`, and `EJECT`

These internal state names and transitions are owned by the concrete behavior script, but the way they plug into the enemy runtime should be consistent across all enemies.

---

## Visual And Animation Ownership

Every enemy should have one primary `AnimatedSprite2D` owned by the enemy scene.

`EnemyData` should expose a `SpriteFrames` resource, and `EnemyBase` should assign that resource to the enemy's primary `AnimatedSprite2D` during setup.

The `SpriteFrames` resource is the shared visual component for the enemy. It should house the animations that the base selector and behavior states need to access.

Expected default animation names:

- `idle`
- `move`
- `death`

Attack animations may be more complex than one simple animation. Attack behavior scripts should be allowed to choose animation names from the same `SpriteFrames` resource, sequence multiple animations, play tells/wind-ups/recoveries, or drive additional optional visual nodes for specialized attacks.

This keeps all enemies visually consistent at the base level while still allowing complex state-specific presentation:

- `EnemyBase` can rely on the primary `AnimatedSprite2D` and default animations.
- `MoveBehavior` can play movement-state animations from `EnemyData.sprite_frames`.
- `AttackBehavior` can play one or more attack-state animations from `EnemyData.sprite_frames`.
- Custom enemy scenes may include extra child nodes for special effects, projectiles, beams, shields, or possession visuals.

---

## Data Authoring Example

An authored worm-style enemy could be represented as:

```text
worm_data.tres
  id: worm
  enemy_name: Worm
  max_health: 30
  damage: 5
  movement_speed: 300
  attack_range: 50
  target_range: 500
  target_acquire_interval: 1
  valid_targets: ["magnet", "ship"]
  target_priority_mode: RANDOM
  target_switching_mode: DEFAULT
  target_point_selection_mode: RANDOM
  move_behavior: WormMoveBehavior
  attack_behavior: WormAttackBehavior
```

A future charger could use the same base class with its own bespoke behaviors:

```text
charger_data.tres
  move_behavior: ChargeMoveBehavior
  attack_behavior: ChargeImpactAttackBehavior
```

A future spitter could use the same base class with a different bespoke pair:

```text
spitter_data.tres
  move_behavior: KeepDistanceMoveBehavior
  attack_behavior: ProjectileAttackBehavior
```

---

## Proposed File Impact

### New Files Expected

| File | Purpose |
|---|---|
| `_project/enemies/enemy_base.gd` | Shared runtime enemy class |
| `_project/enemies/behaviors/move_behavior.gd` | Base movement behavior resource |
| `_project/enemies/behaviors/attack_behavior.gd` | Base attack behavior resource |
| `_project/enemies/worm/worm_move_behavior.gd` | Worm-specific movement behavior matching current chase logic |
| `_project/enemies/worm/worm_attack_behavior.gd` | Worm-specific attack behavior matching current interval damage logic |
| `_project/utils/projectile.gd` | Script-only shared projectile helper/class for player and enemy projectiles |

### Existing Files To Update

| File | Change |
|---|---|
| `_project/enemies/enemy.gd` | Evolve into `EnemyBase` or become a thin compatibility class |
| `_project/enemies/enemy_data.gd` | Add behavior references, `SpriteFrames`, optional `LootTable`, and any missing shared fields |
| `_project/enemies/enemy.tscn` | Point to the new base class and use one primary `AnimatedSprite2D` |
| `_project/enemies/worm/worm_data.tres` | Assign sprite frames and worm-specific behavior resources |
| `_project/level/enemies/enemy_spawn_definition.gd` | Continue referencing `EnemyData` |
| `_project/level/enemies/worm_spawn_definition.tres` | Keep referencing `worm_data.tres` |
| `_project/level/enemies/enemy_spawner.gd` | Assign spawned enemy data using the existing `enemy_data` field |
| `_project/player/bullet.gd` | Migrate or replace with the shared `Projectile` class |
| player weapon fire behavior files | Spawn projectiles through the shared `Projectile` helper |

### Existing Files To Preserve

| File | Reason |
|---|---|
| `_project/enemies/hitbox.gd` | Already provides a useful shared damage receiver contract |
| `_project/enemies/enemy_target_point.gd` | Already supports structure attack points |
| `_project/level/enemies/enemy_spawner.gd` | Spawning behavior is separate from combat behavior |

---

## Migration Plan

### Phase 1: Add New Types Without Changing Behavior

- Extend `EnemyData`.
- Add `MoveBehavior` and `AttackBehavior` base resources.
- Add `WormMoveBehavior`.
- Add `WormAttackBehavior`.
- Add the shared `Projectile` class.
- Keep the current worm behavior visually and mechanically identical.

### Phase 2: Move Logic Out Of EnemyBase

- Move direct chase movement out of the base enemy script.
- Move interval melee damage out of the base enemy script.
- Keep targeting, health, death, hitbox, and animation support in the base class.

### Phase 3: Convert Existing Resources

- Extend existing `EnemyData` resources with behavior, `SpriteFrames`, and optional loot fields.
- Keep `EnemySpawnDefinition` pointed at `EnemyData`.
- Update existing worm resources and spawner profile.

### Phase 4: Add A Second Enemy Archetype

Create one new enemy that proves the architecture:

- same `EnemyBase`
- different `EnemyData`
- enemy-specific movement and attack behaviors

This is the real validation step. If the second enemy needs base-class branches, the behavior boundary is too weak.

---

## Implementation Rules

1. Do not add enemy archetype checks to `EnemyBase`.
2. Behavior resources should use base enemy helper methods instead of directly mutating unrelated internals.
3. Runtime-mutable behavior state must not leak across enemies spawned from the same `EnemyData`.
4. Spawn rules stay in level enemy spawn resources.
5. Targeting, target acquisition, target switching, and target-point resolution stay in `EnemyBase`.
6. Hitbox and damage contracts remain compatible with the shared `Projectile` class and target points.
7. `EnemyBase` owns the shared base behavior selector that resolves to `IDLE`, `MOVE`, `ATTACK`, or `DEATH`.
8. Enemies are `IDLE` when they have no valid target and not-idle when they do.
9. Move behaviors own their internal movement state machines and tick when the base state is `MOVE`.
10. Attack behaviors own their internal attack state machines and tick when the base state is `ATTACK`.
11. Attack behavior conditions decide whether a targeted enemy is in `ATTACK`; otherwise it is in `MOVE`.
12. `MOVE` and `ATTACK` must be mutually exclusive.
13. Move and attack base behavior classes must expose overridable internal state-machine hooks.
14. Concrete enemy behaviors should add and connect new internal states through those hooks instead of duplicating state-machine plumbing.
15. Every enemy scene should have one primary `AnimatedSprite2D`.
16. `EnemyData.sprite_frames` should be assigned to that primary `AnimatedSprite2D`.
17. `EnemyData.sprite_frames` should include default `idle`, `move`, and `death` animations.
18. Attack behaviors own projectile spawning through the shared `Projectile` class.
19. `EnemyData.loot_table` should default to empty.
20. Targeting must keep valid target groups, priority mode, switching mode, and target-point mode separate.
21. Target acquisition runs on spawn and every `target_acquire_interval` seconds.
22. Targets can only be acquired if they are inside `target_range`.
23. Existing worm gameplay should be preserved during the first migration.

---

## Testing And Validation

The first implementation should be considered correct when:

1. The worm enemy still spawns through the current enemy spawner.
2. The worm still picks valid player, magnet, or ship targets according to its `EnemyData`.
3. The worm only acquires targets inside its `target_range`.
4. The worm re-runs acquisition on its configured target interval.
5. The worm respects its `target_priority_mode`.
6. The worm resolves a target point from the acquired target root.
7. The worm still moves toward its target using direct chase movement.
8. The worm still deals interval damage in attack range.
9. The worm still takes projectile damage through its hitbox.
10. The worm still dies and emits `died` for the spawner.
11. The worm transitions through shared `IDLE`, `MOVE`, `ATTACK`, and `DEATH` base states.
12. The worm is `IDLE` only when it has no valid target.
13. The worm's move behavior owns its movement decisions while the base state is `MOVE`.
14. The worm's attack behavior owns its attack cooldown/attack phases while the base state is `ATTACK`.
15. The worm never moves and attacks as active control modes at the same time.
16. A concrete behavior can add a new internal move state through the move behavior state hooks.
17. A concrete behavior can add a new internal attack state through the attack behavior state hooks.
18. The enemy uses one primary `AnimatedSprite2D` with frames assigned from `EnemyData.sprite_frames`.
19. Default `idle`, `move`, and `death` animations can be played from the assigned `SpriteFrames`.
20. Attack behaviors can spawn shared `Projectile` instances.
21. `EnemyData.loot_table` can remain empty without causing runtime errors.
22. Two spawned enemies using the same `EnemyData` do not share runtime cooldown or movement state.
23. A second test enemy can use bespoke movement, attack, and internal behavior states without editing `EnemyBase`.

---

## Risks And Decisions

### Risk: Shared Resource State

Godot resources are shared by default. If behavior resources store timers or phase state, two enemies using the same `EnemyData` could accidentally share that state.

Decision:

- Treat assigned behaviors as templates.
- `EnemyBase` creates per-instance duplicates during setup.
- Alternatively, keep all mutable behavior state on `EnemyBase`, but this may become cluttered as behavior variety grows.

### Risk: EnemyBase Becomes A Dumping Ground

As new enemies are added, it will be tempting to add special cases to the base class.

Decision:

- Base class owns contracts and orchestration only.
- Enemy-specific rules go into behavior resources.

### Risk: Movement And Attack Coupling

Some enemies, especially chargers or self-destruct enemies, blur the line between movement and attack.

Decision:

- Let behaviors communicate through explicit base-class requests and hooks.
- If a pair of behaviors must be used together, document that pairing on `EnemyData`.
- Avoid hiding that coupling inside base-class branches.

### Risk: False Reusability

The goal is highly specialized enemies, not a generic AI toolkit. Over-generalizing early could make every enemy harder to author.

Decision:

- Prefer enemy-specific behavior scripts when the enemy's identity, state machine, or timing differs meaningfully.
- Reuse a behavior script only when two enemies are intentionally meant to share the same behavior.
- Do not force unrelated enemies into one configurable behavior script just to avoid creating a new file.

---

## Resolved Decisions

1. The new enemy system has four primary parts: enemy data, base class, movement behavior, and attack behavior.
2. `EnemyData` owns shared stats, `SpriteFrames`, valid targets, target priority mode, target switching modes, target-point selection mode, optional loot table, and behavior references.
3. `EnemyBase` owns health, damage, hitbox, target state, target acquisition, target switching, target-point resolution, the shared `IDLE` / `MOVE` / `ATTACK` / `DEATH` base behavior selector, and behavior orchestration.
4. Movement logic moves into `MoveBehavior` resources.
5. Attack logic moves into `AttackBehavior` resources.
6. Behavior resources assigned on `EnemyData` should be treated as templates and duplicated per spawned enemy if they hold mutable state.
7. Valid targets, target priority, target switching, and target-point selection should stay separate and work together in `EnemyBase`.
8. Target acquisition runs on spawn and every configured acquire interval, and only in-range targets are valid candidates.
9. Aggro is not a shared base state; it is derived from having a valid player, ship, or magnet target.
10. When the base state is `MOVE`, `EnemyBase` defers movement to the move behavior's internal state machine.
11. When the base state is `ATTACK`, `EnemyBase` defers attack execution to the attack behavior's internal state machine.
12. A targeted enemy should be in `ATTACK` only when its attack behavior conditions validate; otherwise it should be in `MOVE`.
13. `MOVE` and `ATTACK` must be mutually exclusive.
14. `MoveBehavior` and `AttackBehavior` should expose overridable helpers for internal state registration, transition validation, enter callbacks, exit callbacks, updates, and current-state queries.
15. Concrete enemy behaviors should be able to add new internal states without changing `EnemyBase`.
16. Enemies use one primary `AnimatedSprite2D` whose `SpriteFrames` resource is stored on `EnemyData`.
17. Attack behaviors are responsible for spawning projectiles.
18. The shared `Projectile` class replaces the current player-specific bullet path over time.
19. `EnemyData.loot_table` uses the existing `LootTable` resource type and defaults to empty.
20. The shared projectile script lives at `_project/utils/projectile.gd`.
21. Projectiles do not require a dedicated projectile scene.
22. `Projectile.spawn(...)` requires all configured dictionary fields except `pierce`, which defaults to `1`.
23. The first concrete worm behaviors should reproduce the current direct chase and interval melee enemy behavior.

---

## Open Questions

No open questions currently block the first implementation plan.

---

## Recommended First Build Order

1. Extend `EnemyData` with sprite frames, behavior references, optional loot table, and any missing shared fields.
2. Create base `MoveBehavior` and `AttackBehavior` resources.
3. Create `WormMoveBehavior` and `WormAttackBehavior`.
4. Create the shared `Projectile` class.
5. Refactor current `Enemy` into `EnemyBase` while preserving the public `Enemy` class if needed by the spawner.
6. Update the worm data resource to assign sprite frames plus its movement and attack behaviors.
7. Keep the spawner path on `enemy_data`.
8. Migrate player bullet usage to the shared projectile path.
9. Run the current level and verify worm spawning, movement, attack, damage, and death.
10. Add one second prototype enemy to prove bespoke behavior scripts can own unique movement, attack, and state.
