# Salvage Pile System

## Overview

Salvage piles contain two types of pullable items, each with their own loot table. The type of item pulled is determined by a probability system with pseudo-pity mechanics.

---

## Item Types

### 1. Salvageable Items
- **Result**: Broken down into **parts** and **scrap metal**
- Has its own dedicated loot table

### 2. Non-Salvageable Items
- **Result**: Redeemed directly into **inventory** as-is
- Has its own dedicated loot table

---

## Pull Type Selection (Salvageable vs Non-Salvageable)

Three values determine the probability of pulling a **Salvageable** item. These values vary by **pile rarity**.

| Parameter | Description |
|-----------|-------------|
| **Base %** | Starting probability for salvageable on first pull |
| **Increment %** | Added to probability after each non-salvageable pulled (pseudo-pity) |
| **Max %** | Ceiling for salvageable probability |

### Pity Counter
- **Stored on the Magnet** (not per-pile)
- **Persists across piles** — counter carries over between looting sessions
- **Resets when a Salvageable is pulled** — regardless of which pile it came from

### Formula
`
salvageable_chance = min(base_percent + (pull_count * increment_percent), max_percent)
`

### Roll Process
1. Get current pull_count from Magnet
2. Get pity parameters (base, increment, max) from current pile's rarity
3. Calculate salvageable_chance
4. Roll random float [0, 100)
5. If roll < salvageable_chance:
   - Pull from **Salvageable** loot table
   - **Reset** Magnet's pull_count to 0
6. Else:
   - Pull from **Non-Salvageable** loot table
   - **Increment** Magnet's pull_count

---

## Loot Tables

Each **salvage pile rarity** (e.g., Common, Rare, Epic, Legendary) has:
- One **Salvageable** loot table
- One **Non-Salvageable** loot table
- Its own pity parameters (base %, increment %, max %)

### Shared Items
Items **can appear in both** salvageable and non-salvageable tables.

### Item Selection
After item type is chosen, a random item is selected from the corresponding loot table using **weighted chance**.

Each item entry has:
- item_data: Reference to the item resource
- chance: Weight for selection (e.g., 20 = 20% relative weight)

### Example Loot Table (Salvageable - Common Pile)
| Item | Chance |
|------|--------|
| Scrap Hull Plate | 40 |
| Damaged Wiring | 30 |
| Engine Block | 20 |
| Reactor Core | 2 |
| ... | ... |

### Weighted Selection Formula
`
total_weight = sum of all item chances
roll = random float [0, total_weight)
iterate items, accumulating weight until roll < accumulated → select that item
`

---

## Threat Level

Threat level **still influences drops**. (Implementation TBD — may filter available items or skew weights.)

---

## Data Structures (Proposed)

### SalvagePileData (Resource)
`gdscript
- rarity: Rarity enum
- salvageable_loot_table: LootTable
- non_salvageable_loot_table: LootTable
- salvageable_base_percent: float
- salvageable_increment_percent: float
- salvageable_max_percent: float
`

### LootTable (Resource)
`gdscript
- entries: Array[LootEntry]
+ roll_item(threat_level: int) -> SalvageItemData
`

### LootEntry (Resource)
`gdscript
- item_data: SalvageItemData
- chance: float
`

### Magnet (existing class — additions)
`gdscript
- salvageable_pull_count: int  # pity counter
+ reset_pity_counter()
+ increment_pity_counter()
`

---

## Next Steps

1. ~~Review and finalize this spec~~
2. Identify code to remove from current implementation
3. Create/update resource classes (stubs)
4. Implement roll logic in Magnet