# Magnetide — Changelog

## Version 0.3.0

### New Features

#### Weapons

- Added four new weapons — the Pistol, SMG, Sniper, and Grenade Launcher — joining the
  Rifle and Shotgun, each with its own role and feel.
- The Grenade Launcher lobs arcing grenades that explode on impact, damaging every enemy
  caught in the blast.
- Added the Flamethrower, which sprays a wide cone of flame at close range and sets
  enemies on fire, burning them over time. It roars continuously while you hold the
  trigger, with an ignition whoosh as it lights and a sputter as it dies down.
- Weapons now have magazines and reloading. Press **R** to reload manually, or fire the
  last round and the weapon reloads automatically; each weapon slot remembers its own
  ammo and reload progress.
- Guns now have bullet spread, and each weapon has its own accuracy profile — from the
  pinpoint Sniper to the spraying SMG.
- Weapons now unlock in a chain. Only the next weapon in the chain is visible and
  purchasable; everything past it stays hidden until you earn your way there.

#### Player

- Added the Repair Gun, an unlockable tool that repairs the ship's hull mid-run. Hold
  **left-click** on the hull to fire a repair beam that spends scrap from your haul to
  restore integrity.
- Added two new augments: **Adrenaline** (deal more damage the lower your health) and
  **Increased Recycling** (a chance for extra scrap when recycling trash).
- Added a pause menu. Press **ESC** to pause, then continue or abandon the run.

#### Ship

- Added the **Auto-Repair** ship augment, which automatically spends scrap from your
  haul to patch the hull whenever it takes damage.
- You can now set carried items down anywhere on the ship's floor, not just in storage.
  Anything still on the floor when you depart is left behind.
- Identical processed parts now stack in storage, showing a count, and stacks take no
  extra room.

#### Salvaging

- Items now have weight classes that change how they handle — heavier salvage pulls
  slower, falls faster, and settles harder.
- The lever minigame can now roll random modifiers. Good ones and bad ones exist, and
  the bad ones show up more often the higher the threat climbs.
- **Bonus!** adds an optional blue zone to the bar — hit it and finish the pull to be
  rewarded with extra scrap.
- **Mines!** arms some of the yellow zones — hit a mined one and the pull blows up in
  your face.
- A failed pull now flashes what actually caused it rather than the whole red bar: the
  mine you set off, the key you got wrong, or the group you let slip past. Every result
  light still goes red, as before.
- **Recover!** shortens the bar and scatters optional blue supply zones across it. Hit
  them and finish the pull to patch yourself up or repair the hull; the higher the
  threat, the more they restore.
- **Invert!** turns every zone group inside out, so the perfect windows sit at the edges
  of each group with the forgiving middle where the green used to be.
- **Ambush!** marks the red zones with a warning. Fail the pull and a pack of enemies
  drops in on you the moment the panel closes.
- **Gate!** locks the pull behind a colour match. A row of keys and a padlocked gate
  flicker through colours right up to the last moment, then settle — hit the one key
  whose colour matches the gate to unlock it, then hit the gate itself. Pick the wrong
  key and the pull fails. The gate pulses once as you claim the right key, so you can
  see the way open without mistaking it for a zone you have already answered, and its
  padlock only turns over when you hit the gate itself. The keys now hold a colour
  each while the board is still appearing and only start flickering once the countdown
  begins, so the shuffle reads as the puzzle starting.
- Lever minigame zones that carry an icon — mines, keys, supply drops — now hold a
  minimum width, so those icons stay readable at every threat level instead of shrinking
  to nothing. Boards with nothing to read, the ordinary pull included, keep their zones
  tapering as before, so a green stays visibly tighter than the yellows flanking it.
  Threat no longer buys difficulty by thinning zones: it adds zones (up to four groups
  rather than five) and winds the crosshair up a little faster with each level.
- **Mines!** and **Ambush!** now have proper icons on their marked zones.

#### Enemies

- Added the **Mosquito**, a flying ranged enemy that hunts you instead of the ship,
  hovering at a distance and firing needles after a windup.
- Added the **Charger**, a flying enemy that circles you, telegraphs its charge, then
  rockets straight through you — dealing damage and knocking you back.

#### Station

- Research Points now come in three rarities — Common, Rare, and Epic — earned based on
  the rarity of the artifact you research. Unlocks now cost specific combinations, and
  existing saves have their old points converted to Common.
- Every station slot can now be upgraded, including all four augment slots.

#### Audio

- The game now has music. The main menu, the station, and runs each play their own
  shuffled soundtrack, and acid storms bring in their own storm music.
- Added sound effects throughout: unique fire and reload sounds for every weapon (with a
  distinct last-round sound), salvage impact clangs, escalating scrap-proximity alarms,
  and an engine hum that follows the ship's speed.

#### Visuals

- Things that should glow now glow — ship thrusters, flames, beams, muzzle flashes, and
  indicator lights — and bright objects bleed light into the scene around them.
- Added a **Bloom** setting (Options → Video, on by default) that toggles the glow
  effects on and off.

### Changes

#### Weapons

- Reduced the Rifle's and SMG's accuracy at range.
- The Shotgun now spends one shell per shot from a smaller magazine — the same number of
  shots, with an honest ammo readout.
- Targets now have a brief moment of hit protection after each hit, capping how quickly
  very rapid weapons can damage a single enemy.

#### Enemies

- Enemies now grow tougher and deadlier as the Threat Level rises. An enemy's strength
  is locked in when it spawns.
- Rebuilt wave spawning: waves now mix enemy types, enemies fan out instead of stacking
  on one spot, and far more enemies can be active at high threat.
- Enemies spawn more often while the magnet minigame is running, and even more once a
  storm is imminent — looting is no longer free.
- Worms are tougher, hit harder, move faster, and now arrive in packs.

#### Salvaging

- Rebuilt the lever minigame as a calibration panel. After a countdown, a crosshair
  sweeps across the board and you press **E** as it crosses each green zone — clipping
  yellow speeds the sweep up for the rest of the attempt, and pressing on red or letting
  a zone slip past fails the brake.
- The minigame gives clearer feedback: zones light up the instant they're hit and stay
  lit for the rest of the attempt, so the board reads as a record of what you hit, and a
  failed attempt reads unmistakably as a failure before the panel closes.
- The camera dive during the minigame is gentler and centers on you.
- Acid storms now give a countdown warning before they hit.
- The magnet's capacity readout now floats above the magnet itself and only appears
  while it's pulling, so it never covers the action.

#### Ship

- Ship storage is now physical space instead of a weight limit — the hold is full when
  items actually fill it, and the storage outline shows whether your held item will fit.
- Departure is now a clean cutscene: once you commit to leaving, storms stop and nothing
  can deal or take damage.

#### Station

- Equipped augments can be removed from their slot with a new **X** button, and empty
  slots no longer show a placeholder icon.
- Dragging an augment onto a slot where it's already equipped elsewhere now swaps the
  two slots instead of wiping one.
- The Alignment research minigame now shows arrows indicating which way each laser beam
  is drifting.

#### UI

- Every bordered panel now uses a crisper, square-cornered frame.
- The main menu backdrop is now a drifting, twinkling star field.
- **New Game** now asks for confirmation before overwriting an existing save.
- The departure prompt now reads **END RUN** instead of **DEPART**.
- Scrap pickups now share one climbing counter above your head ("+6 Scrap Metal")
  instead of stacking a separate line for every scrap.
- Scrap pickups now hang in the air for a beat after appearing before flying to the
  counter, so they're easier to notice.

#### Visuals

- Combat reads sharper: enemies flinch and shake when hit, die instantly, and hit
  flashes cover the whole enemy.
- Enemy hitboxes now match their sprites — if it looks like a hit, it's a hit.
- Highlights on interactables and salvage now trace the object's full silhouette.
- New art for the shotgun, pistol, magnet gun, bullets, and augment icons; the hotbar
  now shows each weapon's actual in-world art.

### Fixes

#### Ship

- Items placed at the very bottom edge of ship storage no longer fall out of the
  ship. The box accepted clicks on its marker plate, but the plate *is* the floor
  holding stored items in — anything placed there landed below it and dropped
  straight through the hull, gone for good. The box now ends on top of the plate:
  its dashed outline reads fully on all four sides, and a click on the plate sets
  the item down on the deck instead.

#### Station

- Closing the research station mid-celebration no longer costs you your reward —
  research points are granted the instant the final stage completes, and the result
  screens are purely cosmetic and skippable.
