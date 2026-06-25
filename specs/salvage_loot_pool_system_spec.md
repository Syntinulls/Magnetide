# Salvage Loot & Artifact System Specification

## Status

This document **supersedes** [salvage_pile_system.md](salvage_pile_system.md). It removes the
concept of **salvage pile rarities** and replaces the per-pile loot tables + salvageable/pity
system with a shared, rarity-pooled loot model whose rarity odds scale with threat via a tunable
curve. It also **folds in the artifact-system refactor**, because artifact acquisition now happens
inside the same pile-pull flow.

It builds on the 10-level threat model from
[threat_system_revised_spec.md](threat_system_revised_spec.md): the **current threat level**
(zero-based stage index `0`–`9`, player-facing `1`–`10`) is the only run-state input the loot model
reads (alongside a per-run artifact tracker).

The work is organized as five steps:

- **Step 1** — Generic piles + shared salvage pools (4 item rarities).
- **Step 2** — Threat-scaled salvage rarity weights (the inverse-tangent curve).
- **Step 3** — Artifact refactor (3 artifact rarities, separate fixed-chance roll, per-run caps,
  min-threat rarity).
- **Step 4** — The combined pull algorithm tying the three together.
- **Step 5** — Rarity-colored outline shader on every pulled item/artifact.
- **Step 6** — Activation minigame difficulty scales by **threat**, not rarity (untinted cog).

---

## Summary of Changes

| Old model | New model |
|---|---|
| Piles have a rarity (`COMMON`…`ARTIFACT`) with a colored tint | Piles are **generic and uncolored**; only their **size** is random |
| Each pile rarity owns its own salvageable / non-salvageable loot tables | All piles **share one set of loot pools** |
| Threat level selects which *pile rarity* spawns | Threat level skews the **salvage item-rarity** odds inside every pile |
| Item chosen by a single salvageable-vs-non-salvageable pity roll | Item chosen by: trash roll → artifact roll → salvage-rarity roll → **pity** (salvageable/non-salvageable) → uniform pick |
| Per-item weighted selection inside a table | **Uniform** pick within a rarity sub-pool; rarity is the only weighted step (pity then picks the sub-pool) |
| Per-pile-rarity pity params; pity counter on the magnet | **Retained** — one shared set of pity params; the counter stays on the magnet and persists across piles |
| Artifacts rolled as a "rarity" / via dedicated artifact piles | Artifacts are a **separate fixed-chance roll**, not a salvage rarity (4 salvage pools, not 5) |
| Artifacts conceptually single-tier | Artifacts have **3 rarities** (common/rare/epic) → matching research-point rewards |
| Artifacts authored as individual items | Artifacts are **generic, trash-style**: a per-rarity **sprite pool**; rolling a rarity **mints** a generic "Unknown Artifact" with a random sprite (no authored artifact items) |

> Salvage item rarities remain **`COMMON, RARE, EPIC, LEGENDARY`** (`SalvageItemData.ItemRarity`,
> unchanged). **Artifact is NOT added as a rarity.** Artifacts stay `ItemKind.ARTIFACT` and gain
> their own 3-tier rarity, handled by a separate roll.

---

## Step 1 — Generic Piles & Shared Salvage Pools

### Generic Salvage Pile

- A salvage pile is now a **single generic, uncolored** object — no rarity field, no rarity tint.
- Piles still come in **random sizes** (the spawner already randomizes height via
  `pile_height_ratio_min/max` in [salvage_spawner.gd](../_project/level/salvage/salvage_spawner.gd)).
- The pile no longer decides *what tier of loot* it holds; every pile draws from the same shared
  pools and the same threat-driven rarity weights.

### Shared Salvage Pools (4 rarities × 2 sub-pools)

Each of the four **salvage rarities** keeps the salvageable / non-salvageable split, so every rarity
owns **two pools** — eight arrays of `SalvageItemData` total, shared by all piles:

| Rarity | Salvageable pool | Non-salvageable pool |
|---|---|---|
| COMMON | `common_salvageable` | `common_non_salvageable` |
| RARE | `rare_salvageable` | `rare_non_salvageable` |
| EPIC | `epic_salvageable` | `epic_non_salvageable` |
| LEGENDARY | `legendary_salvageable` | `legendary_non_salvageable` |

- **Salvageable** items are broken down into **parts/scrap**; **non-salvageable** items are redeemed
  **whole** into inventory. An item may appear in **both** sub-pools — the sub-pool it is pulled
  from determines how it is processed (this is the same semantics as the old two-table model).
- Once a rarity **and** a sub-pool are chosen, the item is picked **uniformly** from that sub-pool —
  rarity is still the only weighted dimension; the pity roll (Step 4) just selects which sub-pool.

Optional `min_threat_level` filtering of pool contents is preserved: an item only enters its
sub-pool's candidate list once the current threat level meets its `min_threat_level`. A rarity is
**available** (eligible for the Step 2 rarity roll) only if **either** of its sub-pools has at least
one item passing the filter; an unavailable rarity gets weight `0`. If the pity-selected sub-pool is
empty but the other is not, the pull falls back to the non-empty sub-pool.

---

## Step 2 — Threat-Scaled Salvage Rarity Weights (The Curve)

Salvage rarity odds are computed from two pieces, **not** authored as 10 hand-made tables:

1. A **base weight table** — the low-rarity-favored odds at threat level 1.
2. A **per-rarity delta** — how much that rarity's weight grows per threat level, shaped by an
   inverse-tangent curve.

### Notation

- Salvage rarities, indexed `i = 0..3`: `COMMON=0, RARE=1, EPIC=2, LEGENDARY=3`.
- `TIER_COUNT = 4`.
- `L` = current threat level, **zero-based** stage index (`0`–`9`); player level is `L + 1`.
- `base[i]` = base weight of tier `i` at the stage it unlocks.
- `delta[i]` = additive weight increase applied to tier `i` **per threat level after unlock**.
- `min_stage[i]` = the stage index at which tier `i` unlocks (`0` = always available).

### Per-Rarity Unlock + Weight Accumulation

Each rarity has a **minimum threat** (`min_stage`) before which it cannot appear at all. Defaults:

| Rarity | `min_stage` | Unlocks at threat |
|---|---|---|
| COMMON | 0 | 1 (always) |
| RARE | 0 | 1 (always) |
| EPIC | 3 | 4 |
| LEGENDARY | 6 | 7 |

A locked rarity has weight `0` (excluded from the roll). Once unlocked, its weight **ramps from
`base[i]` at its unlock stage** and accumulates linearly:

```text
weight(i, L) = 0                                       if L < min_stage[i]
weight(i, L) = base[i] + delta[i] * (L - min_stage[i]) if L >= min_stage[i]
```

The rarity probability (within the salvage step) is the standard weighted share over the unlocked
rarities:

```text
P(i, L) = weight(i, L) / Σ_j weight(j, L)         (over unlocked rarities only)
```

Because each rarity starts at `base[i]` when it unlocks (rather than entering already-accumulated),
EPIC and LEGENDARY appear at a modest share and grow from there. Early levels (before EPIC unlocks)
are therefore **COMMON + RARE only**. A larger `delta` still makes higher tiers gain share faster,
bounded by the **ordering invariant** below so a higher tier approaches, but **never overtakes**, the
tier beneath it.

### Ordering Invariant (no tier overtakes the one below it)

At **every** threat level the probabilities must stay strictly ordered:

```text
P(COMMON, L) > P(RARE, L) > P(EPIC, L) > P(LEGENDARY, L)   for all L in 0..9
```

Since every tier shares the same denominator, this is purely a **weight** ordering. For an adjacent
pair `a` (more common) and `b` (rarer), `weight_a(L) > weight_b(L)` means
`(base[a] - base[b]) + (delta[a] - delta[b])·L > 0`. As `b` is the faster-growing tier
(`delta[b] > delta[a]`), the gap is tightest at the **last** level (`L = 9`), giving the invariant
the tuning must satisfy:

```text
base[a] - base[b]  >  (delta[b] - delta[a]) · 9          # for each adjacent pair
```

In words: **each tier's base-weight lead over the next-rarer tier must exceed that tier's extra
per-level delta, multiplied by the max stage index (9).** Satisfy this and no curve, however steep,
can let a higher tier cross a lower one within the run.

### The Delta Curve (Inverse Tangent)

`delta[i]` rises with rarity from `DELTA_MIN` (COMMON) to `DELTA_MAX` (LEGENDARY) along a **concave
arctangent ease**. The concavity matters: it **bunches the rarer tiers' deltas near `DELTA_MAX`**
(so RARE, EPIC, LEGENDARY grow at *similar* rates and fan out in proportion without crossing) while
keeping COMMON's delta far below — the big per-level jump lands on the COMMON→RARE step, exactly
where there is the most base headroom to absorb it.

Normalize the rarity index measured **from COMMON**:

```text
u(i) = i / (TIER_COUNT - 1)     # COMMON->0.0, RARE->0.333, EPIC->0.667, LEGENDARY->1.0
```

The normalized, monotonically **increasing**, concave arctangent ease `S(u) ∈ [0, 1]`:

```text
S(u) = atan(k * u) / atan(k)
```

- `S(0) = 0` (COMMON) — the **minimum** (curve floor).
- `S(1) = 1` (LEGENDARY) — the **maximum** (top y-intercept).
- `k` (`curve_sharpness`) sets the concavity: larger `k` pulls the rarer tiers' deltas *up* toward
  `DELTA_MAX` (tighter bunching at the top), which **helps** the ordering invariant on the
  rare/epic/legendary pairs.

Map the ease onto the predefined min/max delta band:

```text
delta[i] = DELTA_MIN + (DELTA_MAX - DELTA_MIN) * S(u(i))
```

- `DELTA_MAX` — per-level increase for the **rarest** tier, LEGENDARY (top y-intercept).
- `DELTA_MIN` — per-level increase for the **common** tier (floor).

LEGENDARY grows fastest (`DELTA_MAX`/level) and COMMON slowest (`DELTA_MIN`/level), with EPIC and
RARE bunched just under LEGENDARY — so the higher tiers climb quickly *in relative terms* from their
tiny bases while staying strictly under the tier below them.

### Worked Numbers

Example tunables (all `@export`, tune to taste):

```text
base         = [ COMMON 100, RARE 30, EPIC 18, LEGENDARY 12 ]
min_stage    = [ COMMON 0,  RARE 0,  EPIC 3,  LEGENDARY 6 ]
DELTA_MIN    = 1.0
DELTA_MAX    = 6.0
k            = 3.0   (atan(3) = 1.2490)
```

Evaluate the curve (`u` is the normalized index from COMMON):

| Tier (i) | `u(i)` | `S(u)` | `delta[i] = 1 + 5·S(u)` |
|---|---|---|---|
| COMMON (0)    | 0.000 | 0.0000 | **1.00** |
| RARE (1)      | 0.333 | 0.6288 | **4.14** |
| EPIC (2)      | 0.667 | 0.8864 | **5.43** |
| LEGENDARY (3) | 1.000 | 1.0000 | **6.00** |

Resulting **salvage rarity probabilities** (conditional on the pull reaching the salvage step — i.e.
not trash and not artifact), with weights ramping from each tier's unlock stage:

| Player Lvl (`L`) | COMMON | RARE | EPIC | LEGENDARY |
|---|---|---|---|---|
| 1  (`L=0`) | 76.9% | 23.1% | —     | —     |
| 3  (`L=2`) | 72.7% | 27.3% | —     | —     |
| 4  (`L=3`) | 63.0% | 26.0% | 11.0% | —     |
| 6  (`L=5`) | 56.9% | 27.5% | 15.6% | —     |
| 7  (`L=6`) | 51.2% | 26.5% | 16.6% | 5.8%  |
| 10 (`L=9`) | 42.4% | 26.2% | 19.7% | 11.7% |

Reading the trend: early levels (1–3) are **COMMON + RARE only**, COMMON-dominant (`77%`/`23%` at
threat 1). EPIC unlocks at threat 4 at `~11%`, LEGENDARY at threat 7 at `~6%`, each ramping up from
there. COMMON stays dominant throughout (`77% → 42%`), and the ordering
`COMMON > RARE > EPIC > LEGENDARY` holds at **every** level among the unlocked tiers.

---

## Step 3 — Artifact Refactor

Artifacts are decoupled from salvage rarities and resolved by their **own fixed-chance roll**.

### Artifact Rarities

- Artifacts have **three rarities: common, rare, epic** (reusing `SalvageItemData.ItemRarity`
  values `COMMON / RARE / EPIC` on items whose `item_kind == ItemKind.ARTIFACT`; `LEGENDARY` is
  unused for artifacts).
- Each rarity awards a matching **research point** (common / rare / epic). Combinations of research
  points unlock items. *(Full research/unlock rules belong to the upcoming research spec; this spec
  only governs how artifacts are acquired.)*

### Fixed Chance, Minimum-Threat Rarity

- The **artifact chance is a fixed constant** that **does not change with threat** (e.g. `0.05`).
- Each artifact rarity has a **minimum threat requirement** to appear. There is **no upper bound**,
  so lower rarities remain obtainable at higher threats:

| Artifact rarity | Min threat (player) | Min stage index (`L`) |
|---|---|---|
| COMMON | ≥ 1 | 0 |
| RARE   | ≥ 4 | 3 |
| EPIC   | ≥ 7 | 6 |

This creates **implicit bands on average** — early pulls can only yield common, mid-run unlocks
rare, late-run unlocks epic — while still **allowing lower-rarity artifacts to drop at later
threats** (e.g. catching up on a missed common at threat 8).

### Selecting the Artifact Rarity

When the artifact roll succeeds, the rarity is chosen **uniformly at random among the available
rarities** — those whose min-threat requirement is met **and** that are not yet capped this run
(below). Combined with the per-run caps, this is what produces the implicit banding: as threat
rises you tend to collect common → rare → epic in order (each removed from the pool once banked),
but any rarity you have not yet collected stays available at higher threats.

### Per-Run Caps

- A run may collect at most **1 common, 1 rare, and 1 epic** artifact (one of each rarity).
- This is tracked at the **run level** (persists across piles for the whole run), not per pile.
- A rarity counts as **collected when its artifact is placed into the ship's storage** — not when
  it is rolled, pulled, or held on the gun. An artifact lost before reaching storage does not
  consume the cap and can roll again.
- A collected rarity is removed from the available set. If **no** artifact rarity is currently
  available (all met-threshold rarities already collected, or none unlocked yet), the artifact step
  is **skipped** and the pull proceeds to the salvage step.

### Artifacts Are Generic (Trash-Style)

Artifacts are **not authored as individual items**. Like trash, each artifact rarity is a **generic
item with sprite variations**:

- Each rarity (common / rare / epic) owns a **shared pool of sprites** (`Array[Texture2D]`).
- When the artifact roll picks a rarity, a **generic "Unknown Artifact" of that rarity is minted**
  with a **random sprite** from that rarity's pool — there is no list of distinct artifact items to
  pick from.
- The minted item is a real `SalvageItemData` (`ItemKind.ARTIFACT`, `rarity` = the rolled tier,
  `item_name = "Unknown Artifact"`, a per-rarity `research_point_reward`, shared physics/visual
  props), so it flows through storage / research / outline like any other pulled item.

This mirrors how trash works (`trash_sprites` + a random sprite), but artifacts are real collectible
items rather than poppable junk.

### In-World Cue

Artifacts intentionally share the common/rare/epic **outline color** with salvage items (Step 5).
They are distinguished from same-rarity salvage **not by outline color** but by the **item sprite
itself** (drawn from the artifact sprite pools) and the **item name `"Unknown Artifact"`** (set on
the minted item, returned by `get_display_name()`). No separate teal/icon/pulse treatment is needed.

### Pile Artifact Section

Per the request, salvage piles expose a **separate artifact section** of variables/conditions:
`artifact_chance`, the per-rarity minimum-threat thresholds, and a reference to the shared artifact
sprite pools (`ArtifactPools`). Run-level state (the per-run caps) is supplied by the artifact
tracker, not stored on the pile.

---

## Step 4 — Combined Pull Algorithm

Every magnet pull resolves in this fixed order (replacing `SalvagePileData.roll_item`):

```text
1. Trash  (chance scales down with threat: trash_chance_start at level 1 -> trash_chance_end at 10).
   - if randf() < trash_chance_for(threat_level)        -> return TRASH

2. Artifact  (fixed chance; rarity by min-threshold + per-run cap).
   - available = artifact rarities whose min threat is met AND tracker.can_pull(rarity)
   - if not available.is_empty() and randf() < artifact_chance:
         rarity = pick one of `available` uniformly at random
         item   = artifact_pools.make_artifact(rarity)   # mint a generic artifact, random sprite
         if item != null                                -> return ARTIFACT (rarity, item)
     # if no rarity is available, or that rarity has no sprites, fall through to salvage.

3. Salvage item  (the remaining probability mass).
   a. Rarity  (curve-weighted).
      - available = salvage rarities with a non-empty sub-pool (after min_threat filtering)
      - rarity    = rarity_weights.roll_rarity(threat_level, available)
      - if rarity < 0                                    -> return TRASH (no rarities available)
   b. Salvageable vs non-salvageable  (pity, using the magnet's pull_count).
      - chance        = min(base% + pull_count·increment%, max%)
      - is_salvageable = randf()·100 < chance
      - on salvageable -> magnet resets pull_count to 0;  else -> magnet increments pull_count
   c. Item  (uniform within the chosen sub-pool; fall back to the other sub-pool if empty).
      - item = loot_pools.pick_uniform(rarity, is_salvageable, threat_level)
      - return SALVAGE (rarity, item, is_salvageable)
```

Notes:

- The **pity counter lives on the magnet** and **persists across piles**; it is only touched by the
  salvage step (3b) — trash and artifact pulls leave it unchanged. It resets whenever a salvageable
  item is pulled, exactly as before.
- The per-run **artifact** cap is committed when an artifact is **placed into the ship's storage**
  (i.e. successfully stored — not merely rolled, pulled, or held on the gun). That placement path
  calls `tracker.mark_collected(rarity)`, so the gate in step 2 reflects what the run has actually
  banked. An artifact lost before reaching storage does **not** consume the run's allotment.

### Salvageable Pity — In Detail

Step 3b decides, for the already-chosen rarity, whether to draw from that rarity's **salvageable**
sub-pool or its **non-salvageable** sub-pool. It is a pseudo-pity that nudges the player toward a
salvageable result the longer they go without one.

**State.** A single integer `pull_count` (the pity counter) lives on the magnet and persists across
piles for the whole run. It counts the number of **consecutive non-salvageable** salvage pulls since
the last salvageable. It is **only** advanced by the salvage step — trash and artifact pulls never
touch it.

**Chance formula.** The salvageable chance starts at a **constant base** and gains a fixed **delta**
for every consecutive non-salvageable, clamped to a **maximum**:

```text
salvageable_chance(n) = min(BASE + n * INCREMENT, MAX)

  BASE      = 10%   (constant; the chance at n = 0, never changes)
  INCREMENT = 2%    (added once per consecutive non-salvageable)
  MAX       = 20%   (ceiling)
  n         = pull_count (consecutive non-salvageables so far)
```

**Per-pull resolution.**

```text
roll r in [0, 100)
if r < salvageable_chance(pull_count):
    -> SALVAGEABLE       ; draw from the rarity's salvageable sub-pool ; pull_count = 0   (reset)
else:
    -> NON-SALVAGEABLE   ; draw from the non-salvageable sub-pool      ; pull_count += 1  (build pity)
```

**Progression with the default 10% / 2% / 20%.** The chance climbs by 2% per miss and caps after
five consecutive non-salvageables; any salvageable pull snaps it back to 10%:

| `pull_count` (consecutive non-salvageables) | Salvageable chance |
|---|---|
| 0 | 10% |
| 1 | 12% |
| 2 | 14% |
| 3 | 16% |
| 4 | 18% |
| 5 | 20% (capped) |
| 6+ | 20% (held at cap) |

Notes:

- The base is **constant** — only the accumulated pity delta moves the chance, and only upward until
  a salvageable resets it.
- Because the counter is shared across rarities (one magnet-wide counter), a non-salvageable common
  also raises the salvageable odds of the next legendary. (If per-rarity pity is ever wanted, that's
  a deliberate change — see Open Questions.)

### Resulting Probability Shape

```text
trash       = trash_chance_for(threat_level)            (lerp start->end across levels 1-10)
P(trash)    = trash
P(artifact) = (1 - trash) * artifact_chance             (only while some artifact rarity is available)
P(salvage)  = 1 - P(trash) - P(artifact)                (distributed across the UNLOCKED rarities by
                                                         the curve, then split salvageable/non by pity)
```

---

## Step 5 — Rarity Outline Shader

Every salvage item **and** artifact pulled from a pile carries a **persistent outline colored by
its rarity**, so the player can read an item's tier at a glance the moment it leaves the pile. The
existing white **interact** outline (hover/proximity highlight) **supersedes** the rarity outline
while active.

### Reuse the Existing Outline

The infrastructure already exists — no new shader is needed:

- [outline.gdshader](../_project/shaders/outline.gdshader) exposes `outline_color` (a `source_color`
  uniform), `outline_width`, and `outline_enabled`.
- [salvage_item.gd](../_project/items/salvage/salvage_item.gd) already creates an `_outline_material`
  (default white, width `3.0`), and `get_rarity_color()` maps rarity → color
  (`SalvageItemData.get_color_for_rarity`). **Artifacts now use their own rarity color too** (their
  common/rare/epic color) — the legacy teal `ARTIFACT_COLOR` is **removed** (see migration), so the
  artifact special-case in both `get_rarity_color()` implementations is deleted.
- The white interact highlight is already driven by `set_outlined()` (e.g. from
  [player.gd](../_project/player/player.gd) on hover).

### Two Layered States, One `outline_color`

Because the shader has a single `outline_color`, the two states are expressed as a **color swap**
on an always-enabled outline (rather than toggling `outline_enabled` on hover, which would hide the
rarity outline):

| State | `outline_enabled` | `outline_color` |
|---|---|---|
| Default (pulled item, not hovered) | `true` | the item's **rarity color** |
| Interact highlight (hovered / interactable) | `true` | **white** (`INTERACT_OUTLINE_COLOR`) — supersedes |
| Trash / suppressed (e.g. locked for research) | `false` | — |

When the interact highlight clears, the outline **reverts to the rarity color** (it does not turn
off). Trash has no rarity, so it gets no rarity outline.

### Proposed `SalvageItem` Changes

```gdscript
const INTERACT_OUTLINE_COLOR: Color = Color.WHITE

var _rarity_outline_color: Color = Color.WHITE
var _interact_highlight: bool = false


## Whether this item should show a persistent rarity outline (rarity items + artifacts, not trash).
func _has_rarity_outline() -> bool:
    return not _is_trash and not _is_locked_for_research


## Cache the rarity color and apply the resting outline. Call from setup() / setup_trash().
func _apply_rarity_outline() -> void:
    _rarity_outline_color = get_rarity_color()
    _refresh_outline()


## Interact (white) highlight. Supersedes the rarity color while enabled; reverts on disable.
## (Same signature as today, so existing hover callers are unchanged.)
func set_outlined(enabled: bool) -> void:
    _interact_highlight = enabled
    _refresh_outline()


func _refresh_outline() -> void:
    if not _outline_material:
        return
    if _interact_highlight:
        _outline_material.set_shader_parameter("outline_enabled", true)
        _outline_material.set_shader_parameter("outline_color", INTERACT_OUTLINE_COLOR)
    elif _has_rarity_outline():
        _outline_material.set_shader_parameter("outline_enabled", true)
        _outline_material.set_shader_parameter("outline_color", _rarity_outline_color)
    else:
        _outline_material.set_shader_parameter("outline_enabled", false)
```

- `setup()` and `setup_trash()` call `_apply_rarity_outline()` after the sprite/rarity are assigned.
- `set_outlined()` keeps its current signature, so the white hover highlight in `player.gd` and the
  recycler/research flows need no changes — white simply wins while active and the rarity color
  returns when it clears.
- `lock_for_research()` already calls `set_outlined(false)`; with `_has_rarity_outline()` returning
  `false` for locked items, the outline fully clears in that state (matching today's behavior).

---

## Step 6 — Activation Minigame: Threat-Scaled Difficulty

The magnet **activation minigame** ([activation_minigame.gd](../_project/ship/magnet/minigame/activation_minigame.gd))
currently scales its difficulty by **pile rarity**:

- `start_minigame(rarity: SalvagePile.Rarity)`
- `markers_per_rarity = [2, 3, 4, 5, 3]` and `allowed_yellows = [2, 1, 1, 0, 1]`, indexed by rarity.
- The cog and chevron are **tinted by rarity color** (`SalvagePile.RARITY_COLORS`).

Since piles are now generic (no rarity), the minigame scales by **current threat level** instead,
and the cog is **untinted**.

### Difficulty Scaling

Two values scale linearly across the 10 threat levels and are rounded to integers:

- **Markers:** `2` at threat 1 → `5` at threat 10 (harder = more markers to hit).
- **Allowed yellows:** `2` at threat 1 → `1` at threat 10 (harder = less margin).

Using the zero-based stage index `L` (`0`–`9`, as elsewhere in this spec):

```text
markers(L) = roundi(lerp(MARKERS_MIN, MARKERS_MAX, L / (LEVEL_COUNT - 1)))   # 2 -> 5
yellows(L) = roundi(lerp(YELLOWS_MIN, YELLOWS_MAX, L / (LEVEL_COUNT - 1)))   # 2 -> 1
```

| Threat (player) | `L` | Markers | Allowed yellows |
|---|---|---|---|
| 1  | 0 | 2 | 2 |
| 2  | 1 | 2 | 2 |
| 3  | 2 | 3 | 2 |
| 4  | 3 | 3 | 2 |
| 5  | 4 | 3 | 2 |
| 6  | 5 | 4 | 1 |
| 7  | 6 | 4 | 1 |
| 8  | 7 | 4 | 1 |
| 9  | 8 | 5 | 1 |
| 10 | 9 | 5 | 1 |

### Changes

- `start_minigame(rarity)` → `start_minigame(threat_level: int)` (zero-based stage index). Store
  `_current_threat_level` instead of `_current_rarity`.
- Replace the per-rarity `markers_per_rarity` / `allowed_yellows` arrays with tunable endpoints
  (`markers_min/max`, `yellows_min/max`) plus `_markers_for_threat(L)` / `_yellows_for_threat(L)`
  helpers using the formulas above. `_generate_marker_positions`, `_setup_yellow_allowance_icons`,
  and `_finish_game` read those helpers instead of indexing by rarity.
- **Untint the cog and chevron** — drop the `SalvagePile.RARITY_COLORS` lookup; leave their
  `modulate` at white. This is the last consumer of `RARITY_COLORS`, so the constant (and the
  `Rarity` enum) can be deleted from [salvage_pile.gd](../_project/level/salvage/pile/salvage_pile.gd)
  once this step lands.
- The caller [magnet_minigame.gd](../_project/ship/magnet/minigame/magnet_minigame.gd) `_start_activation_minigame()`
  stops picking a rarity for the minigame and passes the current `ThreatManager.threat_level`
  instead of `_pending_rarity`.

---

Per the project's [coding preferences](coding_preferences.md): the math/helper functions below are
fully implemented (formulaic); higher-level orchestration is left as stubs.

### `SalvageLootPools` (new Resource) — 4 rarities × 2 sub-pools

```gdscript
extends Resource
class_name SalvageLootPools

## Two arrays per salvage rarity: salvageable (broken into parts) + non-salvageable (redeemed
## whole). Shared by every salvage pile.
@export_group("Common")
@export var common_salvageable: Array[SalvageItemData] = []
@export var common_non_salvageable: Array[SalvageItemData] = []
@export_group("Rare")
@export var rare_salvageable: Array[SalvageItemData] = []
@export var rare_non_salvageable: Array[SalvageItemData] = []
@export_group("Epic")
@export var epic_salvageable: Array[SalvageItemData] = []
@export var epic_non_salvageable: Array[SalvageItemData] = []
@export_group("Legendary")
@export var legendary_salvageable: Array[SalvageItemData] = []
@export var legendary_non_salvageable: Array[SalvageItemData] = []


func get_pool(rarity: int, is_salvageable: bool) -> Array:
    match rarity:
        SalvageItemData.ItemRarity.COMMON:
            return common_salvageable if is_salvageable else common_non_salvageable
        SalvageItemData.ItemRarity.RARE:
            return rare_salvageable if is_salvageable else rare_non_salvageable
        SalvageItemData.ItemRarity.EPIC:
            return epic_salvageable if is_salvageable else epic_non_salvageable
        SalvageItemData.ItemRarity.LEGENDARY:
            return legendary_salvageable if is_salvageable else legendary_non_salvageable
    return common_salvageable if is_salvageable else common_non_salvageable


## Items in one sub-pool unlocked at the given threat level.
func get_available_items(rarity: int, is_salvageable: bool, threat_level: int) -> Array[SalvageItemData]:
    var out: Array[SalvageItemData] = []
    for item in get_pool(rarity, is_salvageable):
        if item and item.min_threat_level <= threat_level:
            out.append(item)
    return out


## True if either sub-pool of this rarity has an unlocked item (i.e. the rarity is rollable).
func has_available_items(rarity: int, threat_level: int) -> bool:
    return not get_available_items(rarity, true, threat_level).is_empty() \
        or not get_available_items(rarity, false, threat_level).is_empty()


## Uniform pick within the chosen sub-pool. Falls back to the other sub-pool if the chosen one is
## empty; returns null only if both are empty.
func pick_uniform(rarity: int, is_salvageable: bool, threat_level: int) -> SalvageItemData:
    var items := get_available_items(rarity, is_salvageable, threat_level)
    if items.is_empty():
        items = get_available_items(rarity, not is_salvageable, threat_level)
    if items.is_empty():
        return null
    return items[randi() % items.size()]
```

### `SalvageRarityWeights` (new Resource) — the curve config + computation

```gdscript
extends Resource
class_name SalvageRarityWeights

const TIER_COUNT: int = 4   # COMMON, RARE, EPIC, LEGENDARY (indices 0..3)

## Base weight per rarity at the stage it unlocks. Order: [COMMON, RARE, EPIC, LEGENDARY].
@export var base_weights: PackedFloat32Array = PackedFloat32Array([100.0, 30.0, 18.0, 12.0])
## Minimum threat stage index (0-9) each rarity unlocks at; below it the rarity is excluded.
@export var min_stage: PackedInt32Array = PackedInt32Array([0, 0, 3, 6])

@export_group("Delta Curve")
## Per-level weight increase for the COMMON tier (curve floor / minimum).
@export var delta_min: float = 1.0
## Per-level weight increase for the LEGENDARY tier (curve top y-intercept / maximum).
@export var delta_max: float = 6.0
## Arctangent concavity. Larger = the rarer tiers' deltas bunch nearer delta_max (helps ordering).
@export var curve_sharpness: float = 3.0


## Per-level additive delta for a rarity, sampled from the concave inverse-tangent ease.
## Rises from delta_min (COMMON) to delta_max (LEGENDARY); the rarer tiers bunch near delta_max.
func get_rarity_delta(rarity_index: int) -> float:
    var u := float(rarity_index) / float(TIER_COUNT - 1)   # COMMON->0.0 ... LEGENDARY->1.0
    var k := maxf(curve_sharpness, 0.0001)
    var shape := atan(k * u) / atan(k)                     # S(u): 0.0 at u=0 (common), 1.0 at u=1
    return delta_min + (delta_max - delta_min) * shape


## Weight for a rarity: 0 while locked (below min_stage), else ramps from base at its unlock stage.
func get_rarity_weight(rarity_index: int, threat_level: int) -> float:
    var unlock := get_min_stage(rarity_index)
    if threat_level < unlock:
        return 0.0
    var base := base_weights[rarity_index] if rarity_index < base_weights.size() else 0.0
    return base + get_rarity_delta(rarity_index) * float(threat_level - unlock)


func get_min_stage(rarity_index: int) -> int:
    return min_stage[rarity_index] if rarity_index < min_stage.size() else 0


## Weighted roll over the available rarities. Returns a rarity index, or -1 if none available.
func roll_rarity(threat_level: int, available_rarities: Array[int]) -> int:
    if available_rarities.is_empty():
        return -1
    var selected: Variant = WeightedRandom.roll_weighted(
        available_rarities, Callable(self, "_roll_weight").bind(threat_level)
    )
    return int(selected) if selected != null else -1


func _roll_weight(rarity_index: int, threat_level: int) -> float:
    return maxf(get_rarity_weight(rarity_index, threat_level), 0.0)
```

### `ArtifactPools` (new Resource) — per-rarity artifact sprite pools + minter

Artifacts are generic (trash-style): each rarity owns a **sprite pool**, and `make_artifact` mints a
generic "Unknown Artifact" `SalvageItemData` with a random sprite. There are **no authored artifact
items**.

```gdscript
extends Resource
class_name ArtifactPools

const ARTIFACT_NAME: String = "Unknown Artifact"

## Sprite variations + research reward per artifact rarity (COMMON / RARE / EPIC).
@export_group("Common")
@export var common_sprites: Array[Texture2D] = []
@export var common_research_reward: int = 1
@export_group("Rare")
@export var rare_sprites: Array[Texture2D] = []
@export var rare_research_reward: int = 1
@export_group("Epic")
@export var epic_sprites: Array[Texture2D] = []
@export var epic_research_reward: int = 1

@export_group("Shared Physics / Visuals")
@export var area: Vector2 = Vector2(80, 80)
@export var use_hitbox_override: bool = false
@export var hitbox_size_override: Vector2 = Vector2(40, 40)
@export var weight: float = 1.0


func get_sprites(rarity: int) -> Array[Texture2D]:
    match rarity:
        SalvageItemData.ItemRarity.COMMON: return common_sprites
        SalvageItemData.ItemRarity.RARE:   return rare_sprites
        SalvageItemData.ItemRarity.EPIC:   return epic_sprites
    return common_sprites


func get_research_reward(rarity: int) -> int:
    match rarity:
        SalvageItemData.ItemRarity.COMMON: return common_research_reward
        SalvageItemData.ItemRarity.RARE:   return rare_research_reward
        SalvageItemData.ItemRarity.EPIC:   return epic_research_reward
    return common_research_reward


func has_sprites(rarity: int) -> bool:
    return not get_sprites(rarity).is_empty()


## Mint a generic artifact item of the given rarity with a random sprite. Returns a built
## SalvageItemData (ItemKind.ARTIFACT), or null if that rarity has no sprites.
func make_artifact(rarity: int) -> SalvageItemData:
    var sprites := get_sprites(rarity)
    if sprites.is_empty():
        return null
    var data := SalvageItemData.new()
    data.item_kind = SalvageItemData.ItemKind.ARTIFACT
    data.rarity = rarity
    data.item_name = ARTIFACT_NAME
    data.sprite = sprites[randi() % sprites.size()]
    data.area = area
    data.weight = weight
    data.use_hitbox_override = use_hitbox_override
    data.hitbox_size_override = hitbox_size_override
    data.research_point_reward = get_research_reward(rarity)
    return data
```

### `RunArtifactTracker` (new, run-scoped) — the per-run caps

```gdscript
extends RefCounted
class_name RunArtifactTracker

## Artifact rarities already collected this run (one of each allowed).
var _collected: Dictionary = {}   # rarity_index -> true


func can_pull(rarity: int) -> bool:
    return not _collected.has(rarity)


func mark_collected(rarity: int) -> void:
    _collected[rarity] = true


func reset() -> void:
    _collected.clear()
```

### `SalvagePileData` (simplified) — orchestration + artifact section

```gdscript
extends Resource
class_name SalvagePileData

## Shared across all piles (assign the same resource instances everywhere).
@export var loot_pools: SalvageLootPools = null
@export var rarity_weights: SalvageRarityWeights = null

@export_group("Trash")
## Trash probability [0,1] at threat 1 (start) and threat 10 (end); lerps between by threat level.
@export_range(0.0, 1.0, 0.01) var trash_chance_start: float = 0.60
@export_range(0.0, 1.0, 0.01) var trash_chance_end: float = 0.15
@export var trash_sprites: Array[Texture2D] = []
@export var trash_area: Vector2 = Vector2(64, 64)
@export var trash_hitbox_size: Vector2 = Vector2(36, 36)
@export var trash_weight: float = 0.75

@export_group("Artifacts")
@export var artifact_pools: ArtifactPools = null
## Fixed artifact chance [0,1]. Constant — does NOT scale with threat.
@export_range(0.0, 1.0, 0.01) var artifact_chance: float = 0.05
## Minimum stage index (0-9) per artifact rarity. No upper bound, so lower rarities stay
## obtainable at higher threats. Defaults: COMMON 0, RARE 3, EPIC 6 (player levels 1, 4, 7).
@export var artifact_min_stage: Dictionary = {
    SalvageItemData.ItemRarity.COMMON: 0,
    SalvageItemData.ItemRarity.RARE: 3,
    SalvageItemData.ItemRarity.EPIC: 6,
}

@export_group("Pity (Salvageable vs Non-Salvageable)")
## Constant base probability (0-100) of a salvageable item at pity 0.
@export var salvageable_base_percent: float = 10.0
## Probability added per consecutive non-salvageable pull (pseudo-pity delta).
@export var salvageable_increment_percent: float = 2.0
## Ceiling on the salvageable probability.
@export var salvageable_max_percent: float = 20.0


## Artifact rarities currently rollable: min-threat met AND not yet capped this run.
func available_artifact_rarities(threat_level: int, tracker: RunArtifactTracker) -> Array[int]:
    var out: Array[int] = []
    for rarity in artifact_min_stage:
        if threat_level >= int(artifact_min_stage[rarity]) and tracker.can_pull(rarity):
            out.append(rarity)
    return out


## Pity-adjusted salvageable probability for the magnet's current pull_count.
func get_salvageable_chance(pull_count: int) -> float:
    return minf(salvageable_base_percent + pull_count * salvageable_increment_percent, salvageable_max_percent)


## Roll salvageable (true) vs non-salvageable (false) using the pity chance.
func roll_is_salvageable(pull_count: int) -> bool:
    return randf() * 100.0 < get_salvageable_chance(pull_count)


## STUB — full per-pull resolution (see Step 4 — Combined Pull Algorithm):
##   1. trash  2. artifact (fixed chance, min-threshold, per-run cap)  3. salvage rarity → pity → item.
## `pull_count` is the magnet's pity counter; the result reports `is_salvageable` so the magnet can
## reset (salvageable) or increment (non-salvageable) it. Returns a dict consumed by magnet.gd.
func roll_pull(threat_level: int, artifact_tracker: RunArtifactTracker, pull_count: int) -> Dictionary:
    # 1. Trash.
    if randf() < trash_chance:
        return _trash_result()

    # 2. Artifact (min-threshold + per-run cap; uniform among available rarities).
    #    var available := available_artifact_rarities(threat_level, artifact_tracker)
    #    if not available.is_empty() and randf() < artifact_chance:
    #        var art_rarity: int = available[randi() % available.size()]
    #        var artifact := artifact_pools.make_artifact(art_rarity) if artifact_pools else null
    #        if artifact != null:
    #            return { "item": artifact, "rarity": art_rarity, "is_artifact": true, "is_trash": false }

    # 3. Salvage item: rarity (curve) -> pity sub-pool -> uniform item.
    #    var available := _available_salvage_rarities(threat_level)
    #    var rarity := rarity_weights.roll_rarity(threat_level, available)
    #    if rarity < 0: return _trash_result()
    #    var is_salvageable := roll_is_salvageable(pull_count)
    #    var item := loot_pools.pick_uniform(rarity, is_salvageable, threat_level)
    #    return { "item": item, "rarity": rarity, "is_salvageable": is_salvageable, "is_artifact": false, "is_trash": false }
    return {}


## Helper — which salvage rarities currently have at least one unlocked item (either sub-pool).
func _available_salvage_rarities(threat_level: int) -> Array[int]:
    var out: Array[int] = []
    for i in range(SalvageRarityWeights.TIER_COUNT):
        if loot_pools.has_available_items(i, threat_level):
            out.append(i)
    return out


func _trash_result() -> Dictionary:
    return {
        "item": null,
        "rarity": -1,
        "is_artifact": false,
        "is_salvageable": false,
        "is_trash": true,
        "trash_texture": _roll_trash_sprite(),
        "trash_area": trash_area,
        "trash_hitbox_size": trash_hitbox_size,
        "trash_weight": trash_weight,
    }


func _roll_trash_sprite() -> Texture2D:
    if trash_sprites.is_empty():
        return null
    return trash_sprites[randi() % trash_sprites.size()]
```

---

## Migration / What Is Removed

| Removed / changed | Detail |
|---|---|
| `SalvagePile.Rarity` enum + `RARITY_COLORS` tint | Pile is generic/uncolored. The shader `tint_color` set in `activate()` is dropped (or fixed to neutral). |
| Per-rarity pile data (`common_data`, `rare_data`, … in the spawner) | Spawner instantiates one generic pile type; no rarity selection. |
| Spawner rarity roll (`_pick_rarity`, `_apply_rarity_pity_result`, rarity pity weights) | Deleted — there is no pile rarity to roll. |
| `ThreatLevelData` pile-rarity weights (`common_weight`…`artifact_weight`, `get_pile_rarity_weights`) | Superseded by the Step 2 curve; no longer used for loot. |
| `SalvagePileData`: `rarity`, the two pile-rarity loot tables, legacy artifact-roll fields, `is_artifact_pile` | Replaced by shared pools + `SalvageRarityWeights` + `trash_chance` + the new Artifacts section. The **Pity group is kept** (now one shared set, no longer per pile rarity). |
| Magnet pity counter (`salvageable_pull_count`) | **Kept.** Still magnet-owned, still persists across piles; reset on a salvageable pull, incremented on a non-salvageable one. |
| `LootTable` per-item `ITEM_RARITY_WEIGHTS` weighted selection | Replaced by uniform pick within a rarity **sub-pool**. Retire `LootTable` unless still used elsewhere. |
| Artifact-as-rarity / `ARTIFACT` added to `ItemRarity` | **Not done.** Salvage rarities stay 4; artifacts stay `ItemKind.ARTIFACT` with a 3-tier rarity, rolled separately. |
| `SalvageItemData.ARTIFACT_COLOR` (teal) | **Removed.** Artifacts now use their common/rare/epic rarity color. Both `get_rarity_color()` implementations drop the artifact special-case; the research-points label in [station_screen.gd](../_project/app/screens/station_screen.gd) that borrowed this teal must pick its own color constant. |
| Authored artifact item resources (`unknown_artifact.tres`) | **Deleted.** Artifacts are minted at runtime from `ArtifactPools` sprite pools; no per-artifact `SalvageItemData` `.tres` is authored. Author the sprite arrays + per-rarity research reward on the shared `artifact_pools.tres` instead. The ship's debug research-artifact spawn now mints a generic **common** artifact via `ArtifactPools.make_artifact(COMMON)`. |
| Dedicated artifact piles + "trash until last item" flow | **Retired.** The `is_artifact_pile` path and its pre-artifact trash sequence (`pre_artifact_trash_pulls`, `roll_artifact_pile_item`, `roll_artifact_pile_final_item`, `roll_artifact_item`, `allow_legacy_artifact_rolls`, `artifact_loot_table`, `can_roll_artifact`) are deleted — superseded by the generic pile's fixed-chance artifact roll + per-run caps. This replaces the dedicated-artifact-pile design in [artifact_piles_and_research_points_spec.md](artifact_piles_and_research_points_spec.md). |

---

## File Impact

### New Files

| File | Purpose |
|---|---|
| `_project/level/salvage/loot/salvage_loot_pools.gd` | `SalvageLootPools` (4 rarities × salvageable/non-salvageable = 8 shared arrays). |
| `_project/level/salvage/loot/salvage_rarity_weights.gd` | `SalvageRarityWeights` (base table + delta curve + roll). |
| `_project/level/salvage/loot/artifact_pools.gd` | `ArtifactPools` (per-rarity artifact **sprite** pools + `make_artifact` minter). |
| `_project/level/salvage/loot/run_artifact_tracker.gd` | `RunArtifactTracker` (per-run 1-each caps). |
| `_project/level/salvage/loot/*.tres` | Authored shared pool + curve instances assigned to all piles. |

### Existing Files To Update

| File | Change |
|---|---|
| [salvage_item_data.gd](../_project/items/salvage/salvage_item_data.gd) | `ItemRarity` unchanged (4 tiers). Artifacts use `ItemKind.ARTIFACT` + rarity COMMON/RARE/EPIC; per-item drop weight no longer used for selection. Remove `ARTIFACT_COLOR`; `get_rarity_color()` returns `get_color_for_rarity(rarity)` for all items including artifacts. |
| [salvage_pile_data.gd](../_project/level/salvage/pile/salvage_pile_data.gd) | Strip rarity + the two pile-rarity loot tables; **keep** the Pity group (`salvageable_base/increment/max_percent`, `get_salvageable_chance`, `roll_is_salvageable`); add `loot_pools`, `rarity_weights`, `trash_chance`, Artifacts section; implement `roll_pull(threat_level, tracker, pull_count)`. |
| [salvage_pile.gd](../_project/level/salvage/pile/salvage_pile.gd) | Pile renders generic/uncolored (tint forced white — done in Step 1). Remove the `Rarity` enum + `RARITY_COLORS` once their last consumers (spawner/pile data/threat weights and the activation minigame, Step 6) are migrated; pile then keeps only size + surface line. |
| [activation_minigame.gd](../_project/ship/magnet/minigame/activation_minigame.gd) | Step 6: `start_minigame(rarity)` → `start_minigame(threat_level)`; replace `markers_per_rarity`/`allowed_yellows` rarity arrays with threat-scaled `_markers_for_threat` / `_yellows_for_threat` (2→5 markers, 2→1 yellows over threat 1–10); untint cog + chevron (drop `RARITY_COLORS`). |
| [magnet_minigame.gd](../_project/ship/magnet/minigame/magnet_minigame.gd) | `_start_activation_minigame()` passes `ThreatManager.threat_level` to `start_minigame()` instead of `_pending_rarity`; stop picking a rarity for minigame difficulty. |
| [salvage_spawner.gd](../_project/level/salvage/salvage_spawner.gd) | Remove per-rarity data, `_pick_rarity`, rarity pity; spawn one generic pile with random size. |
| [magnet.gd](../_project/ship/magnet/magnet.gd) | Call `roll_pull(threat_level, tracker, pull_count)`; **keep** the `salvageable_pull_count` pity counter — reset it when `is_salvageable`, increment otherwise; consume `{item, rarity, is_salvageable, is_artifact, is_trash}`. Drop the artifact-pile branches (`roll_artifact_pile_item` / `roll_artifact_pile_final_item`). |
| Ship storage placement path (e.g. [salvage_item.gd](../_project/items/salvage/salvage_item.gd) `place_in_storage` / the storage controller) | When an `is_artifact` item is placed into ship storage, call `tracker.mark_collected(rarity)` — this is the moment the per-run artifact cap is committed. |
| [run_controller.gd](../_project/run/run_controller.gd) | Own the `RunArtifactTracker`; reset it on run start; expose it to the magnet/storage path. |
| [salvage_item.gd](../_project/items/salvage/salvage_item.gd) | Add the persistent rarity outline (Step 5): cache `get_rarity_color()` into the outline material on `setup`/`setup_trash`; make `set_outlined()` a white interact layer that supersedes and reverts to the rarity color. Drop the `is_artifact → ARTIFACT_COLOR` branch in `get_rarity_color()`. |
| [station_screen.gd](../_project/app/screens/station_screen.gd) | Research-points label no longer borrows `SalvageItemData.ARTIFACT_COLOR`; give it its own color constant. |
| [outline.gdshader](../_project/shaders/outline.gdshader) | No change — already supports `outline_color`. |
| [loot_table.gd](../_project/ship/magnet/loot_table.gd) | **Keep** — still used by `enemy_data.gd`. The salvage path stops referencing it (loot now comes from `SalvageLootPools` + `SalvageRarityWeights`), but the class stays. |
| [threat_level_data.gd](../_project/level/threat/threat_level_data.gd) / [threat_manager.gd](../_project/level/threat/threat_manager.gd) | Pile-rarity weight fields / `get_pile_rarity_weights()` no longer drive loot. |

---

## Resolved Decisions

1. Salvage piles have **no rarity** and no color — only random **size**; all piles share pools.
2. There are **4 salvage item rarities**: COMMON, RARE, EPIC, LEGENDARY. Each keeps the
   **salvageable / non-salvageable** split, so every rarity has **two sub-pools** (8 arrays total).
   Selection within the chosen sub-pool is **uniform**; rarity is the only weighted step.
3. Salvage rarity weights are **uncapped, numeric**, start from a low-rarity-favored base table, and
   grow **additively per threat level** by a per-rarity delta.
4. The delta is sampled from a **concave inverse-tangent ease** rising from `DELTA_MIN` (COMMON) to
   `DELTA_MAX` (LEGENDARY); the rarer tiers' deltas **bunch near `DELTA_MAX`** so higher rarities
   **scale faster** (in relative terms) without their deltas diverging enough to cross a lower tier.
4a. **Per-rarity unlock (`min_stage`):** each salvage rarity has a minimum threat before which it is
    excluded (weight 0). Defaults: **COMMON/RARE always, EPIC ≥ threat 4, LEGENDARY ≥ threat 7.** A
    rarity's weight **ramps from `base[i]` at its unlock stage** (`base + delta·(L - min_stage)`), so
    it enters modestly and grows. Early levels (1–3) are therefore **COMMON + RARE only**, COMMON-
    dominant. Base weights are common-heavy (`100/30/18/12`).
4b. **Ordering invariant:** `P(COMMON) > P(RARE) > P(EPIC) > P(LEGENDARY)` holds at **every** threat
    level among the unlocked tiers — a higher tier never overtakes the tier below it (verified for
    the default tuning).
5. **Artifacts are not a salvage rarity.** They stay `ItemKind.ARTIFACT` and are resolved by a
   **separate roll** with their own **3 rarities** (common/rare/epic). Artifacts are **generic,
   trash-style**: each rarity owns a **sprite pool**, and rolling a rarity **mints** a generic
   "Unknown Artifact" item with a random sprite — there are no authored artifact items.
6. The pull order is **trash → artifact → salvage rarity → pity (salvageable/non-salvageable) →
   uniform item**.
6a. The **salvageable/non-salvageable pity system is retained**: one shared set of pity params
    (`base/increment/max %`), the counter lives on the **magnet** and **persists across piles**,
    resets on a salvageable pull, and increments on a non-salvageable one. The pity roll runs only
    in the salvage step (after a rarity is chosen) and picks which of that rarity's two sub-pools to
    draw from.
7. **Artifact chance is a fixed constant** (threat-independent). Each artifact rarity has a
   **minimum threat** to appear with **no upper bound**: **common ≥ 1, rare ≥ 4, epic ≥ 7**. When
   the roll hits, the rarity is chosen **uniformly among available** (met-threshold, uncapped)
   rarities — creating implicit bands on average while still allowing lower rarities at higher
   threats.
8. **Per-run caps: 1 common + 1 rare + 1 epic** artifact, tracked at the run level. A collected
   rarity leaves the available set; if none are available the artifact step is skipped.
9. Each artifact rarity awards a matching **research point** (common/rare/epic); combinations unlock
   items (detailed in the upcoming research spec).
10. Empty salvage pools (incl. after `min_threat_level` filtering) get **weight 0** and are excluded
    from the salvage roll; if none are available the pull falls back to trash.
11. Every pulled salvage item and artifact shows a **persistent rarity-colored outline** (reusing
    the existing `outline.gdshader` + `get_rarity_color()`). The **white interact outline supersedes**
    it while the item is hovered/interactable and reverts to the rarity color afterward. Trash has
    no rarity outline.
12. **Artifacts use their own rarity color** (common/rare/epic) for the outline and everywhere else.
    The legacy teal `ARTIFACT_COLOR` is **removed**, and `get_rarity_color()` returns the per-rarity
    color for artifacts like any other item.
13. **Dedicated artifact piles are retired**, along with their "trash until last item" sequence.
    Artifacts come **only** from the generic pile's fixed-chance artifact roll. This supersedes the
    dedicated-artifact-pile design in
    [artifact_piles_and_research_points_spec.md](artifact_piles_and_research_points_spec.md).
14. **The artifact cap is committed on storage placement** — a rarity is "collected" when its
    artifact is placed into the ship's storage, not when rolled/pulled/held. A lost artifact does
    not consume the cap.
15. **`LootTable` is retained** — it is still used by `enemy_data.gd` (enemy loot). The salvage loot
    path no longer references it, but the class is not deleted.
16. **Artifacts are distinguished in-world by the item sprite and the name `"Unknown Artifact"`**
    (both set on the minted generic artifact), not by outline color (which now matches their
    common/rare/epic rarity like any salvage item).
17. **The activation minigame scales by threat, not rarity.** Markers go **2 → 5** and allowed
    yellows go **2 → 1** across threat levels 1–10 (linear, rounded). The cog/chevron are **untinted**
    (no rarity color). This removes the last consumer of `SalvagePile.RARITY_COLORS`.
18. **Trash chance scales by threat** (no longer constant): `trash_chance_start` at threat 1 (default
    `0.60`) ramps linearly down to `trash_chance_end` at threat 10 (default `0.15`). Lower threat
    yields mostly trash + common/rare; higher threat yields far less trash.

---

## Deferred / Future Tuning (Not Blocking)

These are settled for the first pass but kept as explicit levers to revisit later:

- **Artifact rarity selection:** stays a **uniform** pick among available rarities for now; could be
  weighted toward higher (or the highest available) rarity later if late game feels common-flooded.
- **Pity scope:** the salvageable pity counter stays **one magnet-wide counter shared across all
  rarities** (a non-salvageable common builds pity toward the next legendary); splitting it per
  rarity is a deliberate future change, not planned now.