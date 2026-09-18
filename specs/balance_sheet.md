# Magnetide Balance Sheet

Reference document for balancing. Every table lists the **live, authored values** as of the
v0.3.0 tiered-numbers pass (2026-09-18), with the file that owns each value so adjustments land
in the right place. Cosmetic-only tuning (animation timings, particle counts, SFX volumes) is
omitted unless it affects gameplay feel decisions.

> **Where base values actually live.** A loadout stat has two candidates: the `@export` default
> in `run_loadout.gd` and the **authored default loadout sub-resource in `_project/app/app_root.tscn`**.
> The authored one is the source of truth: a new game copies it, and a loaded save now re-reads
> its stat bases from it (`RunLoadout.sync_stat_bases_from`, called from `AppSaveData.setup`),
> so rebalancing the scene reaches existing saves too. Keep the script default in step anyway so
> it never becomes a lie.

## Balancing philosophy (guidelines, not hard rules)

1. **Tiered progression, threat 1 → 10.** Difficulty climbs linearly *within* a storm band
   (levels 1–3, 4–6, 7–9, 10) and takes a clear step *at* every storm: surviving one promotes
   all enemies a tier. Threat 1–2 should be clearable with starting gear and little effort;
   from threat 3 on, un-upgraded gear needs noticeably more hits, and the level after a storm
   should all but require the upgrades bought since the previous one. Each upgrade level is
   "on schedule" at roughly threat 2 × level (L1 by threat 2–3, L3 by 6–7, L5 for 10). At
   threat 10, assume max upgrades are required to reliably clear and defeat the boss.
2. **Research point rarity gates unlocks — no mixed-rarity costs.** Each unlock costs a single
   RP rarity, ascending 1 → 2 → 3 within that rarity band. Since higher rarities only drop at
   later threat levels, the rarity alone gates when an unlock becomes reachable.
3. **Numbers grow with the run.** Starting values are small (pistol 7, player 100 HP, worm
   50 HP); mid-run values are larger and late-run values largest. This is presentation, not
   difficulty: enemy stats scale steeply with threat and upgrades add large flat steps, so
   gear that is on schedule keeps a roughly flat shots-to-kill. Scrap and RP costs are
   **not** part of this scaling — they stay on the fixed ladders in §12.

---

## 1. Threat system (the progression clock)

Source: `_project/level/threat/threat_manager.gd` (no scene overrides).

| Value | Number |
|---|---|
| Threat levels | 10 (stage index 0–9 internally) |
| Threat pool / segment size | 100.0 total, 10.0 per level |
| Passive threat gain | 0.0833/s (100 ÷ 1200 s reference run) |
| Time per threat level (BUILDING) | **120 s** |
| Interlevel window | 30 s (auto-continues on expiry) |
| Storm gates | after levels **3, 6, 9** |
| Level 10 | terminal window — depart-only; **boss phase exists but is unimplemented** |

What threat level changes: enemy stats (+10%/level within a band, ×1.25 per storm
passed), spawn pacing/composition, storm gates,
lever minigame difficulty and modifier odds, salvage trash chance and rarity weights, artifact
rarity availability. Full details in each section.

---

## 2. Weapons

### 2.1 Base stats

Source: `_project/items/weapons/<name>/<name>.tres`; defaults from `weapon_data.gd`
(every weapon now authors its damage explicitly; the script default is 10.0).
Cooldown = 1 / fire_rate. Spread: worst off-axis deviation = max/2.

| Stat | Pistol | SMG | Rifle | Shotgun | Sniper | Grenade L. | Flamethrower |
|---|---|---|---|---|---|---|---|
| Damage | 7 | 6 | 10 | 15 ×3 pellets | 45 | 25 (explosion) | 2 |
| Fire rate (shots/s) | 3.0 | 8.0 | 5.0 | 1.0 | 1.0 | 1.3 | 30.0 |
| Magazine | 12 | 40 | 30 | 6 | 5 | 5 | 200 |
| Reload | 1.0 s | 1.4 s | 1.5 s | 2.0 s | 2.0 s | 2.5 s | 1.8 s |
| Bullet speed | 1700 | 1800 | 1800 | 1550 | 2400 | 1500 (grav 1400) | 1300 (decays to 250) |
| Pierce | 1 | 1 | 1 | 2 | 4 | 1 (AoE r=130) | 5 |
| Spread min/max (°) | 0/0 | 8/15 | 4/8 | fixed ±12 cone | 0/0 | 0/0 | 8.5/17 |
| Special | — | — | — | 3 pellets at −12/0/+12° | — | no impact dmg; blast only | applies Burning; bullets survive contact |

Derived (single target, no pierce, ignoring burn):

| | Pistol | SMG | Rifle | Shotgun | Sniper | Grenade L. | Flamethrower |
|---|---|---|---|---|---|---|---|
| Burst DPS | 21 | 48 | 50 | 45 | 45 | 32.5 | 60 |
| Damage per mag | 84 | 240 | 300 | 270 | 225 | 125 | 400 |
| Time to empty mag | 4.0 s | 5.0 s | 6.0 s | 6.0 s | 5.0 s | 3.85 s | 6.67 s |

**Burning DoT** (`_project/effects/burning/burning_effect.gd`): 2 dmg/tick, 1.0 s tick,
duration 6–8 s → **12–16 total** per application. Refreshes, doesn't stack. **Fixed —
does not scale with weapon damage or upgrades** (see flag #4).

### 2.2 Weapon unlock costs (research points)

Source: `_project/app/screens/station/station_screen.tscn` (UpgradeCatalogEntry
sub-resources). Weapons share one empty unlock group → **strictly sequence-gated by
order** (only the next locked weapon is purchasable). Single rarity each, ascending.

| Weapon | Order | Cost | Naturally reachable from |
|---|---|---|---|
| Pistol | — | free (starter) | — |
| SMG | 10 | 1 Common | threat 1 |
| Shotgun | 20 | 2 Common | threat 1 |
| Rifle | 30 | 3 Common | threat 1 |
| Sniper | 40 | 1 Rare | threat 4 |
| Grenade Launcher | 50 | 2 Rare | threat 4 |
| Flamethrower | 60 | 3 Rare | threat 4 |

Epic RP is unspent by design — reserved for future weapons (e.g. the planned laser gun) at
1 / 2 / 3 Epic, naturally gated to threat 7+.

### 2.3 Per-weapon upgrade tracks

Each weapon owns its track in `_project/upgrades/weapon/<name>.tres`, so level counts and
per-level damage differ. Every level adds a **flat** damage amount (`level_amounts`), sized so
a maxed weapon lands at roughly **3× base** — the same growth enemies see between threat 1
and threat 9 (§3.2). Every weapon costs **400 scrap total** to max; only the granularity changes.

| Weapon | Levels | Damage/level | Base → Max | Max ÷ base | Scrap ladder |
|---|---|---|---|---|---|
| Pistol | 5 | +3 | 7 → **22** | 3.1× | 25/50/75/100/150 |
| SMG | 5 | +3/+2/+3/+2/+3 | 6 → **19** | 3.2× | 25/50/75/100/150 |
| Rifle | 5 | +4 | 10 → **30** | 3.0× | 25/50/75/100/150 |
| Shotgun | 4 | +8 | 15 → **47**/pellet | 3.1× | 25/75/125/175 |
| Sniper | 3 | +30 | 45 → **135** | 3.0× | 50/125/225 |
| Grenade Launcher | 4 | +13 | 25 → **77** | 3.1× | 25/75/125/175 |
| Flamethrower | 5 | +1 | 2 → **7** | 3.5× | 25/50/75/100/150 |

Parts per level (Gear = Common, Circuitry = Epic):

| Levels | Part ladder |
|---|---|
| 5 | G1 · G2+C1 · G3+C2 · G4+C3 · G5+C4 |
| 4 | G1 · G3+C1 · G4+C2 · G5+C3 |
| 3 | G2 · G4+C2 · G6+C3 |

Damage is still the only weapon stat with an authored upgrade; nothing upgrades fire rate,
magazine, reload, spread, pierce, or projectile speed.

### 2.4 Shots-to-kill reference (progression check)

ceil(enemy HP ÷ damage). "Base" = level 0 weapon vs threat 1 enemy; "Max" = max-level
weapon vs threat 10 enemy (×3.71). Shotgun counts **pellets** (up to 3 hit per shot);
flamethrower counts flames, excluding the 12–16 burn.

| Weapon | Worm base→max | Mosquito base→max | Charger base→max |
|---|---|---|---|
| Pistol | 8 → 9 | 5 → 6 | 10 → 12 |
| SMG | 9 → 10 | 6 → 7 | 12 → 14 |
| Rifle | 5 → 7 | 4 → 5 | 7 → 9 |
| Shotgun | 4 → 4 | 3 → 3 | 5 → 6 |
| Sniper | 2 → 2 | 1 → 1 | 2 → 2 |
| Grenade L. | 2 → 3 | 2 → 2 | 3 → 4 |
| Flamethrower | 25 → 27 | 18 → 19 | 35 → 38 |

On-schedule gear holds a near-flat curve: a **level 2 pistol (13) vs a threat-4 worm (81 HP)
is 7 shots**, a **level 3 pistol (16) vs a threat-7 worm (125 HP) is 8**. Falling behind is what
creates difficulty — the storm steps make it bite: an **un-upgraded pistol needs 8 shots on a
threat-3 worm, 12 on a threat-4 worm, and 27 on a threat-10 worm**. Level 10 sits alone after
the third storm, so even maxed gear takes about one extra shot there (the finale).

---

## 3. Enemies

### 3.1 Base stats

Sources: `_project/enemies/<name>/<name>_data.tres` + behavior scripts. Every enemy authors its
own health and damage (`enemy_data.gd` defaults are 50 / 5).

| Stat | Worm | Mosquito | Charger |
|---|---|---|---|
| Max health | 50 | 35 | 70 |
| Damage | 8 (bite/s while latched) | 6 (needle projectile) | **30** (dash contact, 1 hit/dash) |
| Movement | 1040 burst propel (windup 0.4 s, pause 0.35 s) | 220 fly, hovers at 1000 px | 130 approach; dash 1170 px/s (windup 0.6 s) |
| Attack cycle | 1.0 s per bite | 4.0 s per shot (0.8 windup + 0.2 recover + 3.0 cd); needle 800 px/s | orbit → windup → dash (2× target distance, 2 s timeout) |
| Targets | magnet, ship, player (random magnet/ship) | player only | player only |
| Min threat to spawn | 1 | 2 | 3 |
| Spawns magnet idle? | no | yes | yes |
| Max batch size | 6 | 2 | 1 |
| Spawn cooldown | 0 | 10 s | 14 s |
| Spawn weight | 1.0 | 1.0 | 1.0 |
| Spawn zones | 3 south zones | 10 side zones | 10 side zones |

The charger is the big-hit enemy by design: one dash takes **30% of an un-upgraded player's
health** (was 12% before this pass). A shield hit absorbs it whole regardless of size.

**Enemies drop nothing on death** — no scrap, no loot (kill count is a run-summary stat
only). All income is salvage-side.

### 3.2 Threat scaling

Source: `_project/enemies/spawning/enemy_spawner.gd` —
`scale = (1 + (level−1) × 10%) × 1.25 ^ (storm gates below level)`, applied to **health and
damage only** (speed/timings never scale), locked in at spawn time. The storm gates come from
the level's authored storms (after 3, 6, 9), so the curve is linear inside each band and jumps
**×1.25** when a storm is crossed. `storm_tier_stat_multiplier = 1.0` restores a pure line.

| Threat | Band | Mult | Worm HP/dmg | Mosquito HP/dmg | Charger HP/dmg |
|---|---|---|---|---|---|
| 1 | 1 | 1.00 | 50 / 8 | 35 / 6 | 70 / 30 |
| 2 | 1 | 1.10 | 55 / 8.8 | 38.5 / 6.6 | 77 / 33 |
| 3 | 1 | 1.20 | 60 / 9.6 | 42 / 7.2 | 84 / 36 |
| 4 | 2 | **1.63** | 81 / 13 | 57 / 9.8 | 114 / 49 |
| 5 | 2 | 1.75 | 87.5 / 14 | 61 / 10.5 | 122.5 / 52.5 |
| 6 | 2 | 1.88 | 94 / 15 | 66 / 11.3 | 131 / 56 |
| 7 | 3 | **2.50** | 125 / 20 | 87.5 / 15 | 175 / 75 |
| 8 | 3 | 2.66 | 133 / 21 | 93 / 16 | 186 / 80 |
| 9 | 3 | 2.81 | 141 / 22.5 | 98 / 17 | 197 / 84 |
| 10 | 4 | **3.71** | 186 / 30 | 130 / 22 | 260 / 111 |

Player durability: 100 HP base ÷ worm bite = **12.5 bites** at threat 1; at threat 10 against
a maxed 250 HP pool = **8.4 bites**. Charger dashes: 3.3 → 2.3 (30% → 45% of max health per
hit), which is why the shield track matters most against chargers.

### 3.3 Spawn pacing per threat level

Interval from `level.tscn` override (the live values); other columns are
`enemy_spawner.gd` defaults. Interval **halves while the magnet minigame is active**
(magnet_active_spawn_rate_multiplier = 2.0).

| Threat | Spawn interval (idle / magnet) | Max concurrent | Batches per pass | Batch size cap |
|---|---|---|---|---|
| 1 | 30 / 15 s | 4 | 1 | 1 |
| 2 | 28 / 14 s | 6 | 2 | 2 |
| 3 | 26 / 13 s | 9 | 2 | 2 |
| 4 | 24 / 12 s | 12 | 3 | 3 |
| 5 | 22 / 11 s | 16 | 3 | 3 |
| 6 | 20 / 10 s | 20 | 4 | 4 |
| 7 | 18 / 9 s | 25 | 4 | 4 |
| 8 | 16 / 8 s | 31 | 5 | 5 |
| 9 | 14 / 7 s | 37 | 5 | 5 |
| 10 | 12 / 6 s | 44 | 6 | 6 |

At threat 1, only worms are eligible and worms can't spawn magnet-idle → **idle
traversal at threat 1 spawns nothing**.

### 3.4 Storms

Sources: `_project/level/threat/storms/storm_*.tres`. All storms: 2.0 s intro / 2.5 s outro,
3.0 s between batches, 5.0 s between waves; enemy stats use current run threat; ambient
spawning suspended; ship halts. Storm spawns bypass the concurrency cap. **No charger
appears in any storm.**

| Storm | Gate after level | Waves | Total enemies | Player acid drain |
|---|---|---|---|---|
| storm_1 | 3 | 3 | 23 (18 worm, 5 mosquito) | 0.75 HP/s |
| storm_2 | 6 | 4 | 35 (22 worm, 13 mosquito) | 1.25 HP/s |
| storm_3 | 9 | 5 | 58 (37 worm, 21 mosquito) | 2.0 HP/s |

Drain is tuned to the health the player should have at each gate: storm_1 kills an unhealed
100 HP player in ~133 s, storm_2 a ~160 HP player in ~130 s, storm_3 a maxed 250 HP player
in ~125 s.

---

## 4. Player

Base values authored in `_project/app/app_root.tscn`; mechanics in
`_project/player/player_health.gd`.

| Stat | Value |
|---|---|
| Max health | 100 |
| Health regen | none intrinsic (Regeneration augment only) |
| I-frames | **none** |
| Move speed | 400 px/s |
| Jump | 112.5 px max / 40 px min height, 0.375 s to apex |
| Shield (locked) | 0 hits |
| Shield (slot unlocked) | base **2 hits**; absorbs 1 hit per damage instance regardless of size |
| Shield recharge | 6 s delay (10 s if broken), then 1 hit per 1 s |

### Player upgrade tracks

Sources: `_project/upgrades/player/*.tres`. Both 5 levels, scrap ladder
**25/50/75/100/150** (400 total).

**Player Health** — +30 flat per level → 130 / 160 / 190 / 220 / **250** at L5 (2.5× base,
against enemy damage that grows 3.7× by threat 10 — the player is meant to end slightly
squishier than they started, with the shield covering the gap).
Parts: Spring ×1..5 (Rare) + Processor ×0,1..4 (Legendary).

**Player Shield** — +1 hit per level → 3 / 4 / 5 / 6 / **7 hits** at L5 (on the unlocked
base of 2). Parts: Battery ×1..5 (Rare) + Power Core ×0,1..4 (Legendary).
Slot unlock: **2 Common RP**.

---

## 5. Ship

Base values authored in `_project/app/app_root.tscn`.

| Stat | Value |
|---|---|
| Hull max health | 250 (no regen; repair gun / auto-repair only) |
| Storage area (level 0) | 180 × 100 px |
| Magnet hold capacity | **5** |
| Magnet pull cadence | 2.5 s per pull |
| Magnet pull speed | 200 base → 1500 max, 0.6 s ramp |
| Magnet width | 264 px |

### Ship upgrade tracks

Sources: `_project/upgrades/ship/*.tres`, `_project/upgrades/magnet/ship_magnet_capacity.tres`.
All 5 levels, scrap ladder 25/50/75/100/150 (400 total).

| Track | Effect per level | L5 result | Parts (primary ×1..5 / secondary ×0,1..4) |
|---|---|---|---|
| Ship Hull | +75 flat | **625** | Gear (C) / Spring (R) |
| Ship Storage Size | table below (hardcoded in `run_loadout.gd`, `.tres` has no effects) | 480 × 300 | Gear (C) / Spring (R) |
| Ship Magnet Capacity | +1 item | **10** | Magnet (E) / Processor (L) |

Storage size by level: 180×100 → 240×140 → 300×180 → 360×220 → 420×260 → **480×300**.

---

## 6. Recycler

The recycler counts trash fed into it and pays a **scrap bundle** every N items. Each bundle
rolls a **uniform random amount in [min, max]**, so payouts vary run to run instead of
repeating one number. Source: `_project/ship/recycler/recycler.gd`, driven from the run loadout
(`recycler_scrap_bundle_min` / `_max`). An in-world counter on the recycler shows progress
toward the next bundle. A payout banks its scrap immediately and announces itself with a
`DamageNumber.spawn_gain` readout above the recycler (e.g. "+8 scrap") — no pickup sprite, so
the readout is never obscured.

| Stat | Base | At max upgrades |
|---|---|---|
| Trash per bundle | **5** | **3** (Intake L2) |
| Scrap per bundle | **5–10** (avg 7.5) | **30–40** (avg 35, Yield L5) |
| Scrap per trash (avg) | 1.5 | 11.7 (≈17.5 with the augment averaged in) |

### Recycler upgrade tracks

Sources: `_project/upgrades/recycler/*.tres`. Both total 400 scrap.

| Track | Levels | Effect per level | Base → Max | Scrap ladder | Parts |
|---|---|---|---|---|---|
| Intake | 2 | −1 trash needed | 5 → **3** | 150/250 | Gear ×3 · Gear ×5 + Piston ×2 |
| Yield | 5 | raises both ends of the range (table below) | 5–10 → **30–40** | 25/50/75/100/150 | Gear ×1..5 / Motor ×0,1..4 |

Yield range by level (two `level_amounts` effects, one per end; the level's gain text reads
"+3 Min Scrap, +4 Max Scrap"):

| Level | Range | Avg | Min step / Max step | On schedule at |
|---|---|---|---|---|
| 0 | 5–10 | 7.5 | — | threat 1–2 |
| 1 | 8–14 | 11 | +3 / +4 | threat 2–3 |
| 2 | 12–18 | 15 | +4 / +4 | threat 4–5 |
| 3 | 16–24 | 20 | +4 / +6 | threat 6–7 |
| 4 | 22–30 | 26 | +6 / +8 | threat 8–9 |
| 5 | 30–40 | 35 | +8 / +10 | threat 10 |

**Recycler augment slot** (1 slot): Increased Recycling — 25% base chance for a completed
bundle to pay out **twice** (each bundle rolls its own amount), +5%/level to 50% at L5.
Unlock 1 Rare RP.

Estimated income: ~30–50 scrap on an early (threat 1–3) run — about one first-tier upgrade
per run, deliberately half the pre-pass trickle — rising to a few hundred on a deep run.

---

## 7. Held tools

### Magnet Gun (free, starter)

Source: `_project/items/magnet_tool/magnet_gun.tres`.

| Stat | Value |
|---|---|
| Pull speed | 600 base → 2000 max, 0.4 s ramp |
| Hold distance | 50 px |
| Repel | 0.8 s hold, 2400 impulse |

**Magnet Tool Pull upgrade** (`_project/upgrades/magnet/magnet_tool.tres`): 5 levels,
+5%/level on pull_max_speed → 2100…**2500**. Scrap 25/50/75/100/150 + Magnet ×1..5 (Epic)
+ Battery ×0,1..4 (Rare).

### Repair Gun (unlock: 1 Common RP)

Source: `_project/items/repair_gun/repair_gun.tres` (stats from `repair_gun_data.gd` defaults),
upgrade `_project/upgrades/repair_gun/repair_gun.tres`. Beam range 520 px; progress resets on
any interruption. The track moves three stats: **scrap per cycle climbs a flat +5**, cycle speed
climbs a flat +0.14/s, and **hull per cycle climbs by a growing step** (+7, +9, +12, +17, +25)
so each level is a bigger jump than the last. Target: **10–15 cycles** to fill a base 250 hull
at level 0, **6–8** to fill a maxed 625 hull at level 5. While the Repair Gun is the selected
hotbar item the HUD scrap counter reads "total / cost".

| Level | Hull per cycle | Cycles/s | s per cycle | Scrap per cycle | Hull per scrap | Cycles 0 → full |
|---|---|---|---|---|---|---|
| 0 | 20 | 0.50 | 2.00 | 5 | 4.0 | 12.5 (250 hull) |
| 1 | 27 | 0.64 | 1.56 | 10 | 2.7 | 12.0 (325) |
| 2 | 36 | 0.78 | 1.28 | 15 | 2.4 | 11.1 (400) |
| 3 | 48 | 0.92 | 1.09 | 20 | 2.4 | 9.9 (475) |
| 4 | 65 | 1.06 | 0.94 | 25 | 2.6 | 8.5 (550) |
| 5 | **90** | **1.20** | 0.83 | **30** | 3.0 | **6.9** (625) |

"Cycles 0 → full" assumes the hull track is upgraded in step. A full repair costs ~63 scrap at
level 0 and ~208 at level 5: efficiency (hull per scrap) dips through the middle levels and
recovers at the top, the deliberate price of much faster, chunkier repairs.

Costs: scrap 25/50/75/100/150 + Gear ×1..5 (Common) + Copper Wires ×0,1..4 (Common).

---

## 8. Augments

Sources: `_project/items/augments/*`, `_project/upgrades/augment/*.tres`,
unlocks in `station_screen.tscn`. Upgrade levels cost **scrap only**, shared ladder
**50 / 100 / 150 / 200 / 250** (750 total to L5; Regeneration caps at L3 = 300 total).

### 8.1 Implemented

| Augment | Slot | Unlock | Levels | Base effect | Per level | Max effect |
|---|---|---|---|---|---|---|
| Regeneration | player | 1 Common | 3 | 2 HP/s after 6 s out of combat | +2 HP/s, −0.75 s delay | 8 HP/s after 3.75 s |
| Adrenaline | player | 2 Common | 5 | up to +25% damage at ≤10% HP (linear from full HP) | +5% max bonus | +50% |
| Increased Recycling | **recycler** | 1 Rare | 5 | 25% double scrap bundle | +5% | 50% |
| Auto-Repair | ship | 2 Rare | 5 | 10 hull / 6 s cd / 10 scrap | +8 hull, −0.5 s cd | 50 hull / 3.5 s / 10 scrap |

Auto-Repair's scrap cost is now flat 10 at every level (it used to rise at L3 and L5).

### 8.2 Placeholders (no behavior, no upgrade track, priced 99/99/99 as a soft lock)

Kinetic Repulsion (player), Electrified Hull (ship), Enemy Repulsion (magnet).

Augment slots: PlayerAugment ×2 (Regeneration, Adrenaline, Kinetic Repulsion),
ShipAugment ×1 (Auto-Repair, Electrified Hull), MagnetAugment ×1 (Enemy Repulsion),
RecyclerAugment ×1 (Increased Recycling). No augment is chain-gated behind another.

---

## 9. Research point economy

Sources: `_project/app/app_save_data.gd`, `_project/salvage/loot/artifact_pools.tres`,
`_project/run/run_artifact_tracker.gd`, `_project/salvage/pile/salvage_pile_data.gd`.

Three currencies: **Common / Rare / Epic RP** (Legendary folds into Epic). RP pays for
**unlocks only**; upgrade levels are scrap + parts.

### Supply — the only source is researched artifacts

| Value | Number |
|---|---|
| Artifact chance per magnet pull | **8%** flat (not threat-scaled) |
| Artifact rarity availability | Common ≥ threat 1, Rare ≥ **4**, Epic ≥ **7** (uniform among available) |
| Per-run cap | **2 artifacts of each rarity** |
| RP per researched artifact | **1** (all rarities) |
| Research failure | 3 laser losses or run end → artifact destroyed, 0 RP |

A run does not need to be completed to bank RP: encounter an artifact, clear the research
minigame, and depart at the next safe window.

### Demand (everything currently purchasable)

| Sink | Common | Rare |
|---|---|---|
| Weapons (6 locked) | 6 | 6 |
| Augments (4 implemented) | 3 | 3 |
| Slots (Shield, Repair Gun) | 3 | — |
| **Total** | **12** | **9** |

At ~1–2 Common per early run, this unlocks the SMG in run 1, the Shotgun by run 2–3, and the
Rifle by run 4–5 — roughly **a new weapon every 2–3 runs**, with spare Commons flowing to
augments and slots. Rare demand opens up once threat 4 is reachable.

### Research minigame (Alignment A) difficulty

Source: `_project/ship/research_station/minigames/alignment_a/alignment_a_minigame.gd`.
1 stage per artifact, 3-fail budget per session, no time limit. ~9.1 s of dual-laser
alignment to complete (progress 0.11/s).

| Tunable | Base | Per threat stage | At stage 9 |
|---|---|---|---|
| Drift speed | 0.20 | +0.011 | 0.299 |
| Heat build | 0.28/s | +0.011 | 0.379/s |
| Heat cool delay | 0.6 s | **+0.111** | 1.60 s (dominant difficulty lever) |
| Laser destroyed after | 2.5 s continuous red (>0.8 heat) | — | — |

---

## 10. Salvage loot

### 10.1 Pull resolution (per magnet pull, every 2.5 s)

Source: `_project/salvage/pile/salvage_pile_data.gd`. Order: **trash → artifact →
rarity → salvageable pity → uniform item in sub-pool**.

| Threat | Trash chance | Salvage rarity split (C/R/E/L, conditional on non-trash, non-artifact) |
|---|---|---|
| 1 | 60% | 77 / 23 / — / — |
| 2 | 55% | 75 / 25 / — / — |
| 3 | 50% | 73 / 27 / — / — |
| 4 | 45% | 63 / 26 / 11 / — |
| 5 | 40% | 60 / 27 / 13 / — |
| 6 | 35% | 57 / 28 / 16 / — |
| 7 | 30% | 51 / 27 / 17 / 6 |
| 8 | 25% | 48 / 26 / 18 / 8 |
| 9 | 20% | 45 / 26 / 19 / 10 |
| 10 | 15% | 42 / 26 / 20 / 12 |

Rarity curve: `weight = base + delta × (stage − min_stage)`; base [100, 30, 18, 12],
min stage [0, 0, 3, 6], delta [1.00, 4.14, 5.43, 6.00]
(`_project/salvage/loot/salvage_rarity_weights.tres`).

Salvageable-vs-part pity: 10% base, +2% per consecutive part pull, 20% cap.
Trash is fed to the recycler (§6) rather than rolled per item.

### 10.2 Loot pools (uniform pick within pool)

Source: `_project/salvage/loot/salvage_loot_pools.tres`.

| Pool | Salvageables | Terminal parts |
|---|---|---|
| Common | Mattress, Tire, Trashcan | Gear, Hose, Rubber, Copper Wires |
| Rare | Microwave, Air Conditioner, Refrigerator, Old Monitor, Radio | Battery, Cathode Ray Tube, Motor, Light Bulb, Spring |
| Epic | Camera, Engine Block, Microscope, Generator, Server Rack, Transformer, X-Ray Machine | Fan, Magnet, Circuitry, Lens, Piston |
| Legendary | Portable Reactor, Rocket Thruster | Induction Coil, Processor, Power Core |

### 10.3 Salvageable → parts yield (always exactly 1 of each part)

Source: `_project/salvage/catalog/*.tres`.

| Salvageable (rarity) | Parts |
|---|---|
| Mattress (C) | Spring |
| Tire (C) | Rubber |
| Trashcan (C) | Gear |
| Air Conditioner (R) | Hose, Fan, Motor, Copper Wires |
| Microwave (R) | Circuitry, Copper Wires, Fan, Light Bulb |
| Old Monitor (R) | Cathode Ray Tube, Copper Wires |
| Radio (R) | Copper Wires, Battery |
| Refrigerator (R) | Light Bulb, Hose |
| Camera (E) | Processor, Lens |
| Engine Block (E) | Gear, Hose, Rubber |
| Generator (E) | Magnet, Copper Wires, Battery |
| Microscope (E) | Lens, Light Bulb |
| Server Rack (E) | Circuitry, Copper Wires, Processor, Fan |
| Transformer (E) | Induction Coil |
| X-Ray Machine (E) | Cathode Ray Tube, Circuitry |
| Portable Reactor (L) | Power Core, Copper Wires, Magnet, Battery |
| Rocket Thruster (L) | Copper Wires, Hose, Circuitry, Fan, Spring |

Part rarities: **Common** — Gear, Hose, Rubber, Copper Wires. **Rare** — Battery,
Cathode Ray Tube, Motor, Light Bulb, Spring. **Epic** — Fan, Magnet, Circuitry, Lens,
Piston. **Legendary** — Induction Coil, Processor, Power Core.

Part demand at full progression (all tracks maxed): 78 Gear, 15 Spring, 25 Battery,
30 Magnet, 25 Circuitry, 10 Copper Wires, 20 Processor, 10 Power Core, 10 Motor, 2 Piston.

### 10.4 Looting cycle throughput

Sources: `_project/level/magnet_minigame/magnet_minigame.gd` (+ `level.tscn`
overrides), `_project/ship/magnet/magnet.gd`.

| Value | Number |
|---|---|
| Cooldown between cycles | 8–10 s (level.tscn override) |
| Warning phase | 8–10 s |
| Looting window | 30 s (spawn cutoff at 5 s remaining) |
| Pull cadence | 2.5 s → **~10 pulls per cycle**, capped by magnet capacity (5–10) |
| Piles | one at a time; frozen during windows/storms |

Salvage processing converts salvageables to parts with **no multipliers**; clicks per item:
Common 2 / Rare 3 / Epic 4 / Legendary 5. Terminal parts and artifacts skip processing.

---

## 11. Lever minigame

Source: `_project/level/lever_minigame/lever_minigame.gd` (script defaults are live).

| Tunable | Stage 0 (threat 1) | Stage 9 (threat 10) |
|---|---|---|
| Green clusters | 2 | 4 (3 from T4, 4 from T8) |
| Green / yellow width ratio | 0.040 / 0.060 | ×0.85 → 0.034 / 0.051 |
| Reticle speed (bar-widths/s) | 0.350 | 0.476 (+4%/stage) |
| Yellow-hit speed penalty | ×1.1 per yellow hit | same |

### Modifier roll

Source: `modifiers/lever_modifier_weights.gd`. None 70 / positive 15 / negative
5 + 3×stage; uniform within each pool of 3.

| Stage | None | Any positive | Any negative |
|---|---|---|---|
| 0 | 77.8% | 16.7% | 5.6% |
| 4 | 68.6% | 14.7% | 16.7% |
| 9 | 59.8% | 12.8% | 27.4% |

### Modifier effects

| Modifier | Type | Key numbers |
|---|---|---|
| Bonus | + | 1 optional chest zone; **10–30 scrap** on hit (flat, not threat-scaled); forfeited on fail |
| Recover | + | shorter board (2–3 clusters); 1–2 zones, each 50/50 med-kit/hull-patch; **HP 10→70, hull 20→120** by stage |
| Invert | + | green-yellow-green layout, no reward/penalty |
| Mines | − | **1→4** mined yellows by stage; pressing one = instant fail |
| Ambush | − | on fail, spawns **2→8** enemies by stage (storm-style spawn) |
| Gate | − | **2→4** color-keys + gate; wrong key = instant fail; key/gate widths fixed 0.09/0.11 |

Failure stake in all cases: the salvage cycle itself (lever must be re-attempted).

---

## 12. Standard cost ladders (summary)

| Ladder | Values | Total | Used by |
|---|---|---|---|
| Item/stat tracks (5 levels) | 25 / 50 / 75 / 100 / 150 | 400 | health, shield, hull, storage, magnet capacity, magnet pull, repair gun, recycler yield, 5-level weapons |
| Weapon track (4 levels) | 25 / 75 / 125 / 175 | 400 | shotgun, grenade launcher |
| Weapon track (3 levels) | 50 / 125 / 225 | 400 | sniper |
| Recycler intake (2 levels) | 150 / 250 | 400 | recycler intake |
| Augment tracks | 50 / 100 / 150 / 200 / 250 | 750 | all augments (Regeneration stops at 300) |

Part pairings per track: Weapons = Gear/Circuitry · Magnet Pull = Magnet/Battery ·
Repair Gun = Gear/Wires · Health = Spring/Processor · Shield = Battery/Power Core ·
Hull & Storage = Gear/Spring · Magnet Capacity = Magnet/Processor ·
Recycler Intake = Gear/Piston · Recycler Yield = Gear/Motor.

---

## 13. Open flags

Known gaps and judgement calls still outstanding after the v0.3.0 pass:

1. **No boss exists** — threat 10 is a terminal depart-only window. Philosophy rule 1 assumes a
   boss; "max upgrades beat the boss" cannot be tuned until it exists.
2. **Enemies drop no loot** — combat is pure cost. Deliberate? It determines whether
   combat-heavy lever modifiers (Ambush) are ever worth engaging rather than avoiding.
3. **Epic RP has no sink.** Epic artifacts (threat 7+) are bankable but buy nothing until
   Epic-tier content lands. Good runs currently bank a dead currency.
4. **Burning DoT is fixed** (120–160) and unaffected by the flamethrower's damage upgrade —
   the upgrade only touches the weak 20-per-flame direct hit. Scaling it would need a new
   `status_damage_multiplier`-style stat on WeaponData, since the DoT lives on the effect scene.
5. **Map screen's Wasteland LevelDefinition has an empty enemy/storm roster** — only the
   `app_root.tscn` copy is populated. Deploying via the map's own definition would start a run
   with no enemies and no storms. (Bug, not balance.)
6. **Ship Storage Size track has no authored effects** — its values are hardcoded in
   `run_loadout.gd: STORAGE_SIZE_BY_LEVEL`, unlike every other track (spec §10 smell).
7. **Dead values** that look tunable but do nothing: `SalvageItemData.value` (set on
   3 items, read nowhere), `SalvageItemData.min_threat_level` (never authored),
   `ITEM_RARITY_WEIGHTS`, `SalvagePartEntry` quantity ranges (all 1),
   alignment minigame `alignment_tolerance` and the UI-computed `difficulty`,
   `MagnetMinigame.decel_rate`, `ship.tscn` Magnet `hold_capacity = 5`.
8. **Three placeholder augments** (Kinetic Repulsion, Electrified Hull, Enemy
   Repulsion) are visible in the station at 99/99/99 RP with no behavior.
9. **Threat 1 idle traversal spawns nothing** (worms are magnet-active-only) — the
   first two minutes of a run have combat only while looting.
10. **No charger in any storm wave** — chargers only appear in ambient spawns and
    Ambush batches.
11. **Level 10 gets a third tier step.** The storm after level 9 counts like the others, so
    threat 10 enemies are 3.7× base against maxed gear at ~3×. Intended as the finale, but
    `storm_tier_stat_multiplier` on the spawner is the single knob if it plays too steep.
12. **Scrap rewards outside the recycler were not rescaled.** The lever Bonus zone still pays
    10–30 scrap flat — now worth one to three early bundles — and the repair gun / Auto-Repair
    still charge 10 scrap per cycle, so early hull repair is relatively pricier than before.
