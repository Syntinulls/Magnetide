extends Resource
class_name LevelDefinition

## One playable level: its identity, scene, and the content that makes it distinct.
##
## The enemy roster and storms live here rather than on the runtime nodes, so a
## level is defined by its definition and the same scene can host different content.
## RunController injects both into EnemySpawner / ThreatManager / StormController
## when the run binds.

@export var level_id: StringName = &"default_level"
@export var display_name: String = "Default Level"
@export var level_scene: PackedScene

@export_group("Content")
## Every enemy this level can spawn, listed once. Each profile declares its own
## threat eligibility and spawn conditions.
@export var enemy_profiles: Array[EnemySpawnProfile] = []
## Storms gating this level's threat progression. Each declares the threat level it
## gates, which is what makes that boundary a storm gate instead of a plain one.
@export var storms: Array[StormData] = []
