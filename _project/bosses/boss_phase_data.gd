extends Resource
class_name BossPhaseData

## One phase of a boss fight: the slice of the boss's total health it covers and the
## state it opens in. A phase runs from its start_health_ratio down to the next
## phase's; the last phase runs to zero.

@export var display_name: String = ""
## Fraction of the boss's total health (1.0 = full) at which this phase begins. The
## first phase is 1.0; later phases must be strictly lower than the one before.
@export_range(0.0, 1.0, 0.01) var start_health_ratio: float = 1.0
## BossState (node name under the boss's States node) entered when the phase begins.
@export var entry_state: StringName = &""
## Plays between the previous phase and this one. Null = the phase begins at once.
@export var transition_cutscene: CutsceneBehavior
## The boss ignores damage while the transition into this phase plays.
@export var invulnerable_during_transition: bool = true
## Damage that would carry the boss past the end of this phase is cut off at the
## boundary, so a single burst cannot skip the next phase.
@export var clamp_damage_at_end: bool = true
