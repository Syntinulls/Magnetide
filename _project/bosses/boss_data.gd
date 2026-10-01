extends Resource
class_name BossData

## Authored definition of one boss: identity, its phases, the reward for beating it,
## the cutscenes around the fight, and where it appears. The boss scene's root (a
## Boss) holds this resource; the scene itself holds the parts and states.

@export var boss_id: StringName = &""
## Shown on the boss health bar and announcements.
@export var display_name: String = ""
## In order, highest start_health_ratio first. At least one phase is required.
@export var phases: Array[BossPhaseData] = []
@export var reward: BossRewardData

@export_group("Cutscenes")
## Plays after the boss spawns (dormant) and before it activates.
@export var intro_cutscene: CutsceneBehavior
## Plays after the reward is collected, before the run departs.
@export var outro_cutscene: CutsceneBehavior

@export_group("Placement")
## Where the boss root is placed, as a ratio of the viewport (0,0 top-left, 1,1
## bottom-right). An intro cutscene can move it in from there.
@export var spawn_viewport_ratio: Vector2 = Vector2(0.5, 0.25)


func get_phase(index: int) -> BossPhaseData:
	if index < 0 or index >= phases.size():
		return null
	return phases[index]


func get_phase_count() -> int:
	return phases.size()
