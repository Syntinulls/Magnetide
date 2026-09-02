extends LeverModifierBehavior
class_name AmbushModifierBehavior

## "Ambush!" (negative): the standard board, but every red zone carries a threat
## icon -- the pull is being watched. The board plays exactly as normal; the
## consequence is entirely off-panel. Fail the attempt, for any reason, and a
## single batch of enemies drops in once the panel has closed. Both the size of
## the batch and which enemies can be in it scale with threat, the latter for
## free: the spawner's own profiles gate themselves by threat level.
##
## Authored down to the no-icon floor (min_zone_width_ratio) so the board stays
## the standard one to the pixel: Ambush's icons ride the red, which is whatever
## the clusters left over and which no floor sizes anyway. What keeps those reds
## wide enough to read an icon in is the minigame's edge margin and spacing.

@export var threat_icon: Texture2D = preload("res://_project/level/lever_minigame/modifiers/ambush/sprites/enemy.png")
## Enemies in the batch at threat stage 0 and stage 9.
@export var batch_min: int = 2
@export var batch_max: int = 8
## Pause after the minigame closes before the batch drops, so the activation
## presentation (camera, vignette) finishes restoring first.
@export var spawn_delay: float = 0.6

var _attempt_threat_level: int = 0


func on_minigame_started(_minigame: LeverMinigame, threat_level: int) -> void:
	_attempt_threat_level = threat_level


func modify_zones(minigame: LeverMinigame, _threat_level: int) -> void:
	for zone in minigame.get_zones():
		if zone.type == LeverMinigame.ZoneType.RED:
			zone.icon = threat_icon


func on_minigame_closed(minigame: LeverMinigame, success: bool) -> void:
	if success:
		return
	await minigame.get_tree().create_timer(spawn_delay).timeout
	var level := Magnetide.level
	if level == null or not is_instance_valid(level):
		return
	var spawner := level.get_node_or_null("EnemySpawner") as EnemySpawner
	if spawner == null:
		return
	# Spawn profiles gate themselves by the player-facing 1-10 threat level, while
	# the minigame hooks speak the zero-based 0-9 stage.
	var spawn_level := _attempt_threat_level + 1
	var eligible: Array[EnemySpawnProfile] = []
	for profile in spawner.get_enemy_profiles():
		if profile and profile.is_eligible_at_level(spawn_level):
			eligible.append(profile)
	if eligible.is_empty():
		return
	var profile := WeightedRandom.roll_weighted(
		eligible, func(entry: EnemySpawnProfile) -> float: return maxf(entry.spawn_weight, 0.0)
	) as EnemySpawnProfile
	if profile == null:
		return
	var count := minigame.scale_for_threat(_attempt_threat_level, batch_min, batch_max)
	spawner.spawn_batch_for_storm(profile, count, profile.allowed_spawn_zones, spawn_level)
