extends Node
class_name BossState

## One state in a boss's state machine. States are authored as children of the boss
## scene's States node; the node name is the state id passed to Boss.transition_to().
## A state drives the parts through their own APIs (NodePath exports on the subclass)
## and ticks only while the boss is ACTIVE. Patterns that differ by phase read
## boss.get_phase_index().

## The boss running this state; assigned before the first enter().
var boss: Boss = null


## Called when the boss switches into this state. `from` is the previous state id
## (empty when a phase begins).
func enter(_from: StringName) -> void:
	pass


## Called when the boss leaves this state. `to` is empty when the state is being
## interrupted (phase transition, defeat, run end) rather than replaced.
func exit(_to: StringName) -> void:
	pass


func physics_tick(_delta: float) -> void:
	pass
