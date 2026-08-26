extends Area2D
class_name InteractionHitbox

## Standard player-proximity hitbox. Interactables extend this so they all detect
## the player walking into them the same way — via an Area2D + CollisionShape2D
## sized to the interactable's sprite, rather than ad-hoc distance checks.
##
## Reports `is_player_in_range` and emits `player_entered` / `player_exited`.
## Only the player counts — enemies (also CharacterBody2D) are ignored.
##
## Subclasses that override `_ready()` MUST call `super._ready()` so the body
## signals get connected.

signal player_entered()
signal player_exited()

## Layer 7. Every interactable identifies itself here rather than sitting on whatever
## a scene happened to default to, so "is an interactable" is a thing the physics
## world can answer. See project.godot [layer_names].
const COLLISION_LAYER: int = 1 << PhysicsLayers.INTERACTABLES
## Layer 5, the player body — the only thing these hitboxes look for. Set here rather
## than per scene so a new interactable cannot forget it and silently never fire.
const PLAYER_BODY_MASK: int = 1 << PhysicsLayers.PLAYER_BODY

var is_player_in_range: bool = false


func _ready() -> void:
	collision_layer = COLLISION_LAYER
	collision_mask = PLAYER_BODY_MASK
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not is_player_in_range:
		is_player_in_range = true
		player_entered.emit()


func _on_body_exited(body: Node2D) -> void:
	if body is Player and is_player_in_range:
		is_player_in_range = false
		player_exited.emit()
