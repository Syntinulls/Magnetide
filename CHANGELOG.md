# Magnetide — Changelog

## Version 0.3.0

### New Content

**The Repair Gun.** A new station-unlockable tool that turns collected scrap into hull
integrity mid-run. Unlock it with Research Points in the Equipment column and it appears
in **hotbar slot 3**. Hold **left-click** on the ship's hull to fire a repair beam: a
progress bar fills, and each completed cycle spends **1 scrap** from your run's haul to
restore **10 integrity**. Let go and the progress resets — repairs only count when the
cycle completes. Five upgrade levels raise the repair to **30 integrity** per cycle and
speed the beam up ~2.4x, though top-end levels push the cost to **3 scrap** per cycle.
Every point of scrap you spend is scrap you don't bank at the end of the run — patch the
hull, or pad the wallet.

**New ship augment: Auto-Repair.** Bolt it into a Ship Augment slot and the hull patches
itself: every **6 seconds** it spends **1 scrap** from your run's haul to restore
**10 integrity**, no aiming and no hold — the repair lands instantly. It only fires when
the hull is actually damaged and you can afford it, and it banks its charge otherwise, so
a hit taken with the timer up is patched on the spot. Five upgrade levels take it to
**30 integrity** every **3.5 seconds**, at **3 scrap** a tick. Unlocks in the Ship page's
Augment column for **1 common + 1 rare** Research Point. Like the Repair Gun, every point
it spends is a point you don't bank at the end of the run — but this one spends it whether
you're looking or not.

**Six weapons, one arsenal.** The Rifle and Shotgun are joined by four new guns, each
with a distinct role:

| Weapon | Damage | Fire Rate | Magazine | Reload | Notes |
|---|---|---|---|---|---|
| Pistol | 7 | 3.0/s | 12 | 1.0s | Your starting weapon. Accurate, reliable. |
| SMG | 6 | 8.0/s | 40 | 1.4s | Shreds up close; very wide spray at range. |
| Shotgun | 15 | 1.0/s | 6 | 2.0s | Pierces 2 enemies per pellet. |
| Rifle | 10 | — | 30 | 1.5s | Solid all-rounder. |
| Sniper | 45 | 1.0/s | 5 | 2.0s | Pierces 4 enemies. Pinpoint accurate. |
| Grenade Launcher | 25 | 1.3/s | 5 | 2.5s | Lobs an arcing grenade that explodes on impact, dealing its damage to every enemy caught in the blast. |

**The Grenade Launcher.** Unlike every other gun, its rounds fall under gravity — you
*arc* them onto targets rather than aiming a straight line. A grenade detonates the
moment it strikes an enemy, and the explosion hits everything nearby for the weapon's full
damage. It's the last weapon in the unlock chain and your answer to a crowd.

**New weapon: the Flamethrower.** Hoses out a wide cone of flame at **30 particles per
second** — by far the fastest-firing weapon in the game — from a **200-fuel** tank
(~6.7s of continuous fire, 1.8s reload). Each flame bursts from the muzzle, balloons to
over twice its size as it flies, and passes *through* the first enemy it touches for
**2 damage**, so a sustained stream washes over the whole front of a crowd. Flames also
inherit your momentum — firing on the move throws them with you. Anything a flame
touches is **set on fire**: burning enemies take **2 damage every second for 6–8
seconds**, and re-igniting them restarts the burn. Short reach, big sustained damage —
get close and paint the pack. Unlocks after the Grenade Launcher for **2 rare + 2 epic**
Research Points.

**Hit protection on every target.** All hitboxes now carry brief I-frames (**0.1s**):
damage instances arriving faster than that are ignored, capping rapid streams like the
Flamethrower at **10 hits per second** on a single target. Normal fire rates are
unaffected, though a point-blank shotgun blast now lands one pellet on the same enemy
instead of all of them at once.

**New enemy: the Mosquito.** A flying ranged attacker that hunts *you*, not the ship. It
closes to hovering distance, holds position, then fires needles at you with a slow windup
and a 3-second cooldown between shots. It starts appearing at Threat Level 2 and can
approach from any direction.

**New enemy: the Charger.** A flying bruiser that circles you at range, freezes into its
charge pose, then rockets straight through you — ending up on your far side before it
turns and lines up the next pass. Getting clipped costs a hit of damage *and* knocks you
back, so watch the telegraph and sidestep the line. It starts appearing at Threat Level 3.

**Two new augments:**
- **Adrenaline** — the lower your health, the more damage you deal. Scales up to +50% at
  10% HP or below (at max level).
- **Increased Recycling** — a chance for double scrap when recycling trash, up to 50%.

### New Systems

**The lever minigame was rebuilt from scratch.** Braking for salvage now plays out on a
proper calibration panel above your head instead of the old cog-and-markers bar. After a
quick **3-2-1 countdown** (during which the board deals out its green, yellow, and red
zones), a crosshair sweeps left-to-right at a steady speed and you press **E** as it
crosses each green zone. Every green zone gets a result light: a perfect press lights it
**green ("PERFECT")**, clipping the narrow yellow fringe lights it **yellow ("CLOSE")**
and permanently speeds the crosshair up for the rest of the sweep, and pressing on red —
or letting a zone slip past untouched — turns the whole board red (**"MISS"**) and fails
the brake on the spot. The old "yellow allowance" is gone: yellows never fail you, they
just make the rest of the sweep harder. Once the attempt is settled — every light lit,
or a miss taken — the panel stops taking input while the crosshair finishes its run,
so a stray press on the red stretch past the last zone cannot take a win back. Zone count still scales with Threat Level
(**2 zones** at low threat up to **5** at max). The camera dive is gentler too — a
**1.5×** zoom (was 2.5×) that eases in over 0.6s and centers on *you* instead of a point
in the sky, and the panel itself stays pixel-crisp at native size instead of scaling up
with the zoom.

**Weapons now have magazines and reloading.** Guns run dry and must be reloaded — press
**R** to reload manually, or fire the last round and it reloads automatically. Ammo and
reload progress are tracked *per weapon slot*, so switching guns mid-reload doesn't lose
your progress; the reload picks up where it left off. A magazine counter sits in the HUD,
and a progress bar appears above your head while reloading.

**Bullet spread.** Guns are no longer perfectly accurate. Each shot rolls a random spread
cone, and each weapon has its own accuracy profile — the Sniper and Shotgun are dead-on,
the Pistol drifts slightly, and the SMG sprays hard. Shoot accordingly.

**Weapons now unlock in a chain.** You start with the Pistol and unlock forward:
**Pistol → SMG → Shotgun → Rifle → Sniper → Grenade Launcher.** You can only see and buy the *next* weapon in
the chain; anything further ahead shows as a blacked-out silhouette marked "???" until you
earn your way to it.

**Research Points now come in three rarities.** Instead of one pooled currency, artifacts
now pay out **Common**, **Rare**, or **Epic** research points depending on their rarity
(Legendary artifacts pay Epic). Unlocks cost specific combinations — the Sniper, for
instance, costs 2 Rare + 1 Epic. Existing saves have their old research points converted
into Common. The station shows all three balances, color-coded by rarity.

**Item stacking.** Identical processed parts now stack in storage instead of taking up
separate space. Stacked items show a "x3"-style count and layered sprites, and a new item
visibly flies into the stack it's joining. Stacks cost no additional storage room.

**Ship storage is now physical, not a weight budget.** The old "maximum storage weight"
number is gone. Your hold is full when it's *actually* full — when items pile up against
all three sensor bands at the top of the storage zone. The storage outline glows blue when
your held item will fit and red when it won't.

**Items now have weight classes** (Light / Medium / Heavy / Very Heavy) that change how they
behave: heavier salvage pulls slower, falls faster, and settles harder. An Engine Block or a
Portable Reactor is a real commitment; wires and circuitry are trivial to haul.

**Pause menu.** Press **ESC** to pause. Continue, or abandon the run (with a confirmation —
abandoning throws the run away and sends you back to the station).

**Every station slot can now be upgraded.** Weapon, magnet tool, player health and shield,
ship integrity, storage size, magnet integrity, magnet capacity, and all four augment slots
have working upgrade buttons. Augment upgrade levels cost 20 / 35 / 55 / 80 / 110 scrap.
Dragging an augment onto a slot where it's already equipped elsewhere now swaps the two
slots instead of wiping one.

### Balance

**Enemies now scale with Threat Level.** At Threat Level 10, enemies have **4× the health**
and deal **3× the damage** they do at Level 1. Scaling is locked in when an enemy spawns, so
enemies that survive into a higher threat tier don't retroactively get stronger.

**The spawner was rebuilt.** Waves now roll a mix of enemy types instead of a single type,
enemies in a wave fan out laterally instead of stacking on one spot, and the number of
concurrent enemies scales far more aggressively with threat — from 4 at Level 1 up to **44**
at Level 10 (previously capped at 22).

**Pressure spikes now punish greed.** Enemies spawn **2× as often while the magnet minigame
is running**, and **3× as often once the threat cap is reached and a storm is imminent**
(the old behavior was a much milder ~1.7× bump). Looting is no longer free.

**Acid storms give a 60-second countdown** before they hit.

**Worm buffed:** health 30 → 50, damage 5 → 8, movement speed 300 → 350. Worms also arrive in
packs of up to 6 (previously 2).

**Rifle and SMG accuracy nerfed.** The Rifle's spread went from 0.5°–2° to **4°–8°**, and the
SMG's from 4°–9° to **8°–15°**. Both are now meaningfully less accurate at range.

**Shotgun magazine reduced** from 18 shells to **6** — but it now costs only 1 shell per shot
instead of 3, so it's the same number of shots with far more honest ammo readouts.

**Augment unlock prices set:** Regeneration 1 Common; Adrenaline 2 Common; Increased Recycling
1 Common + 1 Rare.

### Feel, Audio & Visuals

**Things that should glow now glow.** Ship thrusters throw a blue-white haze off their
plumes, flamethrower flames carry a warm glow that fades as they die, enemies you set
alight burn with glowing flames, and the repair beam burns green down its whole length
instead of reading as a plain white line. Indicator
lights light up properly too — the station's upgrade level ticks and the lever minigame's
result lights now shine rather than just changing color. Emissive things also bleed light
into the scene around them: thruster wash spills across the hull, and a jet of flame lights
up the sky behind it.

**New setting: Bloom.** Options → Video. On by default; unchecking it turns off the glow
and the light bleed together, for a small performance gain or if the effect isn't to your
taste.

**The lever minigame hits back.** Zones now rest a few shades darker and light up to
full strength the instant they fire, so a hit reads at a glance. Landing the reticle on
a green or yellow zone also punches that zone up in scale. Hitting a red one kicks the
reticle sideways and blinks **every** red zone in unison, like a warning light, for
**1.6 seconds** (up from a **0.6s** dead pause) before the panel closes — a failed
activation now reads as a failure instead of just stopping.

**Augment slots can be emptied again.** An equipped augment now carries a small red **X**
in the top-right corner of its icon — click it to pull that augment back out and leave the
slot open.
Empty slots also read as empty: they no longer show a generic player/ship placeholder icon,
so you can tell at a glance which of your slots are still free. Both are augment-only —
the weapon slot keeps its icon and has no X, because you always have a weapon equipped.

**Crisper UI panel borders.** Every bordered panel — the station screens, popups, progress
bars, and augment frames — now uses a clean square-cornered 4px border with tighter 3px
content insets, replacing the old rounded-corner frame.

**The game has music.** Every part of the game now has its own soundtrack — the main menu,
the station (carried seamlessly across the map and salvage screens), and runs each draw from
their own playlist of tracks. Songs play in a shuffled rotation (no repeats until you've
heard them all), with a few seconds of quiet between tracks. When an acid storm hits, the
run music gives way to storm music, and advancing to the next threat level brings the run
playlist back.

**The main menu is now a starry sky.** The flat backdrop is replaced with the drifting,
twinkling star field from the departure cutscene over a deep-space black, and the Magnetide
title stands larger and higher above the menu buttons.

**Combat feels sharper.** Enemies no longer shake for half a second and pause before dying —
they now pop instantly on death. Instead, they flinch and shake *when hit*, so damage reads
immediately and kills are clean. Hit flashes now cover the whole enemy (a Mosquito's wings
flash and shake with its body, not just its torso).

**Enemy hitboxes now match their sprites.** Every enemy's hitbox is sized to its actual
body — no more shots passing through a Mosquito's wings-to-body gap or clipping empty air
around a Worm. If it looks like a hit, it's a hit.

**Ship thrusters now have a voice.** A continuous engine loop tracks the ship's speed and
state — a deep hum when idle, a steady tone in transit, and a rising whine while boosting
during departure or a threat advance.

**New sound effects throughout:**
- Every weapon has its own fire and reload sounds, with a distinct sound for firing the
  final round in the magazine (the Shotgun's dry last-shell click is unmistakable).
- Salvage slamming onto the magnet now clangs, with randomized impact sounds and pitch.
- The scrap-proximity warning now has three escalating alarms for the yellow, orange, and
  red danger phases.
- Jump, landing, and footstep sounds are noticeably louder.

**Magnet capacity moved into the world.** The held/capacity readout now floats above the
magnet itself rather than sitting in the HUD, and only appears while the magnet is actively
pulling — enemies and salvage now draw over it, so it never obscures the fight.

**Highlights now wrap whole objects.** Outlines on the magnet lever, recycler, research
station, and salvage items trace the object's full silhouette instead of outlining each
sprite piece separately.

**Research results are now safe.** Research points are awarded and the artifact consumed the
instant the final stage clears — the result screens are purely cosmetic and can be skipped
with **E** or left-click. Closing the station mid-celebration can no longer cost you a reward.

**"New Game" now asks before overwriting** an existing save.

**The Alignment research minigame** now shows green arrows next to each laser emitter
indicating which way the beam is drifting.

**Departure is now a clean cutscene.** Once you commit to leaving, the storm countdown stops,
no new storm can trigger, and neither you nor the enemies can deal or take damage.

Assorted art: new shotgun, pistol, and magnet-gun sprites; new bullet sprites; new augment
icons; the hotbar now shows each weapon's actual in-world art. The departure prompt now reads
**END RUN** instead of **DEPART**.
