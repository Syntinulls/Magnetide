# Research Minigame UI And First Minigame Spec

## Overview

Artifact research should move from the current debug timer into an interactive research station UI. The research station UI is a centered overlay anchored conceptually to the ship's research station. It contains shared research information around the outside and a replaceable minigame viewport inside.

The long-term research flow requires three minigames completed in sequence to successfully research one artifact. Eventually, the three stages will be selected from a larger random pool. The first implementation only requires one minigame, but the UI and controller should be shaped so additional ordered stages can be added without rewriting the station shell.

This spec extends:

- `specs/research_system_spec.md`
- `specs/artifact_piles_and_research_points_spec.md`

## Goals

- Replace debug research completion with a research station UI flow.
- Create a reusable outer research station UI shell that can host different minigames.
- Show overall research progress outside the active minigame.
- Show total fail count outside the active minigame.
- End research and destroy the artifact when the combined fail count reaches `3`.
- Support the first pass with only one required minigame.
- Keep the first minigame implementation decoupled from future minigames through a small shared contract.

## Non-Goals

- No final art pass for the station UI.
- No random minigame selection in the first pass.
- No full set of three implemented minigames yet.
- No permanent researched-artifact codex/reveal screen unless already required by another spec.
- No balancing-final difficulty, timing, SFX, or VFX.

## Terminology

| Term | Meaning |
| --- | --- |
| Research session | One attempt to research one placed artifact. |
| Research stage | One required minigame inside a research session. |
| Minigame | A self-contained interaction that emits success, fail, and progress events. |
| Station shell | The outer research UI that contains overall progress, fail markers, and the minigame host area. |
| Stage progress | Progress inside the currently active minigame. |
| Total research progress | Overall progress across all required stages. |
| Total fail count | Combined fail count across all stages in the current research session. |

## High-Level Flow

1. Player places an artifact on the research station.
2. Research station starts a `ResearchSession`.
3. Research station UI opens over the normal HUD.
4. The first stage/minigame is loaded into the shell's inner minigame host.
5. Player completes the active minigame.
6. If all required stages are complete, research succeeds.
7. On success, the artifact is consumed and awards its research points.
8. If the player reaches `3` total fails before completion, research fails.
9. On terminal failure, the artifact is destroyed and no research points are awarded.

First pass:

- Required stage count: `1`
- Stage list: first minigame only
- Overall progress reaches `100%` when the first minigame succeeds

Future pass:

- Required stage count: `3`
- Stage list is selected from a minigame pool
- Stages run sequentially
- Total progress is split into equal stage segments
- Each active stage fills its own segment continuously using that minigame's internal progress

## Research Station UI Layout

The attached sketches define the first-pass blockout. The UI should feel like a physical research terminal layered over the ship view, not a station menu page.

### Outer Shell

The outer shell is a large centered panel.

Required regions:

- Top overall research progress bar.
- Large inner minigame host area.
- Bottom fail markers showing `0 / 3`, `1 / 3`, `2 / 3`, or terminal failure at `3 / 3`.

Sketch mapping:

- The top segmented bar is total research progress.
- The large gray center region is the active minigame viewport.
- The three `X` marks below the viewport are total fail markers.
- The panel floats over the in-game HUD and ship, with the ship research station visible underneath in the wider-context sketch.

### Size And Position

First-pass target:

- Center the shell horizontally.
- Place it in the middle-upper portion of the screen, leaving some of the ship/research station visible below.
- Keep the normal game HUD visible behind or around it.
- Use a modal interaction layer so gameplay controls do not accidentally fire while the minigame is active.

Responsive behavior:

- Maintain a stable aspect ratio for the shell.
- Keep the minigame host area large enough for directional input prompts and interactive elements.
- Clamp the panel to the viewport with margins on smaller resolutions.
- Do not allow fail markers or progress text to overlap the minigame host.

### Top Progress Bar

The top progress bar represents total research progress, not only current minigame progress.

First pass:

- Empty at session start.
- Fills during the first minigame if that minigame exposes continuous progress.
- Snaps/fills to complete on minigame success.
- Shows failed attempts without resetting unless the whole session fails.

Future three-stage pass:

- Split the bar visually into three stage regions.
- Completed stages stay filled.
- Active stage may show partial fill inside its segment.
- Locked/pending stages remain empty.
- All stage segments have equal weight because each minigame represents an equal portion of the full research process.

### Fail Markers

The shell must always show the total fail count.

Rules:

- Maximum total fails per research session: `3`.
- A failed minigame attempt increments the shared fail count.
- The fail count does not reset between minigames.
- A failed minigame attempt resets only the current minigame's internal progress.
- Previous completed stages remain complete.
- Future unstarted stages are unaffected.
- At `3` fails, the session ends immediately.
- The artifact is destroyed on terminal failure.
- No research point reward is granted on terminal failure.

Visual states:

- Empty marker: unused fail slot.
- Filled/bold/broken marker: consumed fail.
- Terminal failure: all three markers filled, then transition to research-failed state.

## Research Session State

Recommended state enum:

```gdscript
enum ResearchSessionState {
	IDLE,
	STARTING,
	ACTIVE,
	STAGE_COMPLETE,
	SUCCESS,
	FAILED,
}
```

Recommended session fields:

```gdscript
var artifact_item: SalvageItem = null
var artifact_data: SalvageItemData = null
var required_stage_count: int = 1
var current_stage_index: int = 0
var completed_stage_count: int = 0
var total_fail_count: int = 0
var max_fail_count: int = 3
var total_progress: float = 0.0
var current_stage_state: Dictionary = {}
```

Rules:

- A session owns exactly one artifact.
- Research can only complete while the session is active and the artifact is still valid.
- Player cancellation is not allowed.
- Closing the research UI pauses the active minigame and saves its state instead of cancelling the session.
- Opening the research UI resumes the active minigame after a short delay.
- Terminal failure should consume/destroy the artifact to match the design rule.
- If the current game run ends while an artifact is locked in the research station, the artifact is destroyed and the research session ends without reward.

## Minigame Host Contract

Each research minigame should be a `Control` scene that the station shell can instantiate into the inner host area.

Recommended signals:

```gdscript
signal progress_changed(progress: float)
signal attempt_failed(reason: StringName)
signal completed()
signal state_changed(state: Dictionary)
```

Recommended methods:

```gdscript
func start_minigame(context: ResearchMinigameContext) -> void
func stop_minigame() -> void
func pause_minigame(paused: bool) -> void
func get_progress() -> float
func save_state() -> Dictionary
func load_state(state: Dictionary) -> void
```

`progress` should be normalized from `0.0` to `1.0`.

The outer shell owns:

- total fail count
- total research progress
- stage sequencing
- loading and saving the active minigame state
- artifact success/failure consequences

The minigame owns:

- its internal input
- its internal visuals
- its own success condition
- when one failed attempt has occurred
- a serializable state dictionary for pause/resume

Minigames should not directly award research points, destroy artifacts, or advance the global research session.

### Pause And Resume

The world continues while research is active. Research minigames must therefore be pausable and resumable.

Rules:

- Closing the research UI immediately calls `save_state()` on the active minigame.
- The saved state is stored on the active research session.
- The artifact remains locked in the research station while the UI is closed.
- Reopening the research UI reloads the saved minigame state.
- The minigame resumes after a short delay so the player has time to reorient before drift, timers, heat, or other pressure continues.
- No progress is earned while the minigame is paused/closed.
- No heat, drift, timers, or failure conditions advance while the minigame is paused/closed.

This allows research to happen during a normal run while still letting the player leave the research UI to respond to attacks.

## Research Minigame Context

Add a small data object or dictionary passed into each stage.

Suggested fields:

```gdscript
var artifact_data: SalvageItemData
var stage_index: int
var stage_count: int
var total_fail_count: int
var max_fail_count: int
var difficulty: float = 1.0
var threat_level: int = 0
var rng_seed: int = 0
```

The first pass may use a dictionary if creating a resource class is unnecessary, but future minigame pooling will benefit from a typed context.

## First Minigame: Resonance Alignment

The first minigame is a balancing/calibration task represented by the sketch with a central artifact, left/right laser controls, vertical heat meters, directional arrows, and WASD prompts.

Working name: `Resonance Alignment`.

Design intent:

- The player keeps two manually controlled lasers focused on the center artifact.
- The artifact sits in the center of a horizontal signal/wave line.
- The lasers slowly drift away from the artifact over time.
- The player swaps between controlling the left laser and right laser, then nudges the selected laser up or down to keep it aligned.
- The minigame should read as a physical calibration task inside the research station.

The minigame is successful when its internal progress reaches `1.0`.

### First Minigame Layout

Required visual regions inside the minigame host:

- Center artifact/signal display.
- Left laser calibration cluster.
- Right laser calibration cluster.
- Bottom-left instruction or condition hint area.
- Bottom-center input prompt area.

Sketch mapping:

- Center artifact shape: artifact resonance target.
- Horizontal wavy line: research signal line running through the artifact.
- Left and right emitters/lines: lasers aimed toward the artifact.
- Left and right vertical meters: laser temperature bars.
- Exclamation icons: warning state for a heating or dangerously misaligned laser.
- Check icons: laser is currently impacting the artifact.
- Curved arrows: available adjustment direction or field rotation.
- Bottom-left text: current rule/hint for the active calibration condition.
- Bottom-center WASD: first-pass keyboard control prompt.

### Input

First-pass keyboard controls from the sketch:

| Input | Intended use |
| --- | --- |
| `W` | Move the selected laser upward. |
| `S` | Move the selected laser downward. |
| `A` | Select/control the left laser. |
| `D` | Select/control the right laser. |

The minigame should use existing input actions if appropriate, but it should not steal global gameplay input after the research UI closes.

Mouse/controller support can be added later. The first pass can be keyboard-only if the prompt and focus behavior are reliable.

### Laser Alignment

Each laser has a vertical offset from the artifact center.

Rules:

- A laser is aligned when its impact point is within a configured tolerance around the artifact center.
- The left and right lasers are evaluated independently.
- The player can actively control only one laser at a time.
- Pressing `A` selects the left laser.
- Pressing `D` selects the right laser.
- Holding or pressing `W` moves the selected laser upward.
- Holding or pressing `S` moves the selected laser downward.
- If a laser is not being actively moved by the player, it drifts at a constant linear speed.
- Drift movement is linear, not eased or accelerated.
- Drift direction changes over time according to difficulty settings.
- Drift speed and drift-direction-change frequency scale with current threat level.
- Each laser has a maximum allowed drift distance away from the artifact center.
- Laser offset is clamped to that maximum distance.

Recommended fields:

```gdscript
var left_laser_offset: float = 0.0
var right_laser_offset: float = 0.0
var selected_laser: StringName = &"left"
var left_drift_direction: float = 1.0
var right_drift_direction: float = -1.0
```

### Progress

Progress builds continuously while one or both lasers impact the artifact.

Rules:

- If neither laser is aligned, progress does not increase.
- If one laser is aligned, progress increases at the base progress rate.
- If both lasers are aligned, progress increases at twice the base progress rate.
- Progress is normalized from `0.0` to `1.0`.
- Completing the progress bar emits `completed()`.
- Progress is reset to `0.0` when this minigame awards a failure.
- Progress from previous completed research stages is not reset.

Recommended formula:

```gdscript
var aligned_count := int(left_is_aligned) + int(right_is_aligned)
progress += base_progress_rate * float(aligned_count) * delta
```

### Heat And Failure

Each laser has its own heat/temperature bar.

Rules:

- If a laser is not impacting the artifact, that laser builds heat.
- If a laser is impacting the artifact, its heat can cool or hold steady according to tuning.
- Heat is evaluated independently for left and right lasers.
- When a laser reaches the red temperature range, a danger timer starts for that laser.
- If any one laser remains in red temperature for the configured danger duration, that laser is destroyed.
- A destroyed laser emits `attempt_failed(reason)`.
- The outer shell increments the total fail count by `1`.
- If attempts remain, the minigame resets and starts over.
- If the total fail count reaches `3`, the outer shell ends research and destroys the artifact.

Recommended fields:

```gdscript
var left_heat: float = 0.0
var right_heat: float = 0.0
var left_red_heat_time: float = 0.0
var right_red_heat_time: float = 0.0
```

Heat values should be normalized from `0.0` to `1.0`.

Suggested first-pass red danger duration:

```gdscript
@export_range(0.1, 10.0, 0.1) var red_heat_failure_duration: float = 2.5
```

The target range is `2.0` to `3.0` seconds.

### Success And Failure Contract

The first minigame must emit `completed()` when its success condition is met.

The first minigame must emit `attempt_failed(reason)` when either laser is destroyed by sustained red heat.

- One minigame failure increments the session fail count by `1`.
- A non-terminal failure restarts/resets only the active minigame.
- Overall research progress remains at the last valid total session progress.
- At `3` total failures, the outer shell stops the minigame and fails the session.

### Difficulty Settings

Difficulty is determined by the current threat level.

Recommended tunables:

```gdscript
@export var alignment_tolerance: float = 0.08
@export var base_progress_rate: float = 0.12
@export var base_drift_speed: float = 0.08
@export var threat_drift_speed_scale: float = 0.015
@export var base_drift_direction_change_interval: float = 3.0
@export var threat_direction_change_scale: float = 0.15
@export var input_step: float = 0.05
@export var max_laser_offset: float = 1.0
@export var heat_build_rate: float = 0.2
@export var heat_cool_rate: float = 0.12
@export var red_heat_threshold: float = 0.8
@export var red_heat_failure_duration: float = 2.5
```

Notes:

- `alignment_tolerance` controls how close a laser must be to count as impacting the artifact.
- `base_progress_rate` is the progress rate for one aligned laser.
- Two aligned lasers use `base_progress_rate * 2.0`.
- `base_drift_speed` is the linear drift speed before threat scaling.
- `threat_drift_speed_scale` increases drift speed as threat rises.
- `base_drift_direction_change_interval` controls how often drift direction changes at low threat.
- `threat_direction_change_scale` reduces the direction-change interval as threat rises.
- `input_step` can be interpreted as per-press movement or converted into input speed if held input feels better.
- `max_laser_offset` clamps how far each laser can drift away from the artifact.

### Saved State

The first minigame must be able to save and restore enough state to resume cleanly.

Minimum saved fields:

```gdscript
{
	"progress": progress,
	"selected_laser": selected_laser,
	"left_laser_offset": left_laser_offset,
	"right_laser_offset": right_laser_offset,
	"left_drift_direction": left_drift_direction,
	"right_drift_direction": right_drift_direction,
	"left_heat": left_heat,
	"right_heat": right_heat,
	"left_red_heat_time": left_red_heat_time,
	"right_red_heat_time": right_red_heat_time,
	"rng_state": rng_state,
}
```

On resume:

- Restore all saved values.
- Show the UI immediately.
- Wait for the shell's resume delay.
- Resume drift, heat, input, and progress updates after the delay.

## Research Success Behavior

When all required stages are complete:

1. Set session state to `SUCCESS`.
2. Fill total progress to `1.0`.
3. Emit research completion with the artifact data.
4. Award the artifact's `research_point_reward`.
5. Consume the artifact.
6. Close or transition the station UI after a short completion beat.
7. Return normal gameplay/station controls.

This should replace the current debug timer completion path.

## Research Failure Behavior

When total fail count reaches `3`:

1. Set session state to `FAILED`.
2. Stop the active minigame.
3. Mark all fail indicators used.
4. Destroy/consume the artifact.
5. Emit a research failed signal with the artifact data.
6. Do not award research points.
7. Close or transition the station UI after a short failure beat.
8. Return normal gameplay/station controls.

Suggested signal:

```gdscript
signal research_failed(item_data: SalvageItemData, reason: StringName)
```

## Scene And File Structure

Suggested first-pass files:

| File | Purpose |
| --- | --- |
| `_project/ship/research_station.gd` | Start/finish research sessions and replace debug timer behavior. |
| `_project/ui/research/research_station_ui.tscn` | Outer station shell scene. |
| `_project/ui/research/research_station_ui.gd` | Shell controller: progress, fail markers, stage host. |
| `_project/ui/research/research_minigame_context.gd` | Optional typed context for minigames. |
| `_project/ui/research/minigames/resonance_alignment_minigame.tscn` | First minigame scene. |
| `_project/ui/research/minigames/resonance_alignment_minigame.gd` | First minigame logic. |

The exact UI path can change if the project already has a stronger convention, but research UI should remain separate from the ship station world node.

## Integration Notes

Research station:

- Should no longer auto-complete from `debug_research_duration` once this UI flow is enabled.
- Should still lock the placed artifact at the station anchor.
- Should open the station UI after `artifact_placed`.
- Should listen for UI success/failure.
- Should keep the artifact locked when the research UI is closed.
- Should destroy the locked artifact if the current run ends before research succeeds.

Game UI:

- Research UI should live under the main UI canvas, like existing HUD/minigame UI.
- It should appear above the ship/HUD but not require a scene transition.
- It should capture relevant input while active.
- Closing the research UI should save and pause the current minigame state, not cancel research.
- Reopening the research UI should reload the current minigame state and resume after a short delay.
- The world should continue while the research UI is open or closed.

Save/reward:

- Research points are awarded only on research success.
- Research points are not awarded on failure.
- Artifact destruction on failure should remove the item from the station and runtime world.

## Suggested Implementation Order

1. Add the research station UI shell scene with static progress/fail placeholders.
2. Add the shell script with session state, fail marker updates, and minigame host loading.
3. Add the minigame contract and first minigame placeholder scene.
4. Wire `ResearchStation` to open the shell instead of starting the debug timer.
5. Implement success path for one required minigame.
6. Implement fail count and terminal artifact destruction.
7. Implement research UI close/reopen pause and saved-state restore.
8. Implement Resonance Alignment laser drift, progress, heat, and reset behavior.
9. Smoke test artifact placement through success, single failure retry, pause/resume, and three-failure destruction.

## Acceptance Criteria

1. Placing an artifact on the research station opens a centered research UI shell.
2. The shell displays total research progress at the top.
3. The shell displays three total fail markers at the bottom.
4. The shell contains an inner host area for the active minigame.
5. The first pass requires exactly one minigame to complete research.
6. A minigame success completes research and awards the artifact's research points.
7. A minigame failure increments the total fail count by one.
8. Non-terminal failures allow the player to retry or continue the active stage according to the minigame's rules.
9. Reaching three total failures ends research immediately.
10. On terminal failure, the artifact is destroyed and awards no research points.
11. The first minigame scene matches the sketch blockout: center artifact/signal, left/right calibration clusters, bottom hint, and WASD prompt.
12. `A` selects the left laser and `D` selects the right laser.
13. `W` and `S` move the selected laser vertically.
14. Uncontrolled lasers drift linearly away from alignment, with threat-scaled speed and direction changes.
15. One aligned laser increases progress at the base rate and two aligned lasers increase progress at twice the base rate.
16. Misaligned lasers build heat independently.
17. A laser that stays in red heat for the configured danger duration awards one failure and resets the current minigame.
18. Closing the research UI saves and pauses the active minigame state.
19. Reopening the research UI resumes the saved minigame state after a short delay.
20. Closing the research UI restores normal gameplay/station input.
21. The locked artifact remains in the research station until success, terminal failure, or current run end.
22. Current run end destroys any artifact locked in the research station.

## Open Questions

1. Should aligned lasers cool immediately, cool after a delay, or simply stop building heat?
2. Should laser movement use discrete `input_step` taps or continuous held-key movement?
3. What is the exact resume delay after reopening the research UI?
4. Should heat and laser offset reset fully after a non-terminal failure, or should difficulty-specific penalties carry forward inside the same stage?
5. Should the selected laser be visually highlighted with a stronger outline, brighter emitter, or control cursor?
