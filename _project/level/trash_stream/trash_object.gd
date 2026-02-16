extends Node2D
class_name TrashObject

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

const RARITY_COLORS: Dictionary = {
	Rarity.COMMON: Color(0.0, 0.8, 0.0),      # Green
	Rarity.RARE: Color(0.2, 0.4, 1.0),        # Blue
	Rarity.EPIC: Color(0.6, 0.2, 0.8),        # Purple
	Rarity.LEGENDARY: Color(1.0, 0.85, 0.0),  # Yellow/Gold
}

var speed: float = 100.0
var direction: Vector2 = Vector2.LEFT
var rarity: Rarity = Rarity.COMMON
var is_active: bool = false


func _ready() -> void:
	deactivate()


func activate(new_rarity: Rarity, spawn_position: Vector2, new_speed: float, new_scale: float, new_rotation: float) -> void:
	rarity = new_rarity
	position = spawn_position
	speed = new_speed
	scale = Vector2(new_scale, new_scale)
	rotation = new_rotation

	var sprite := $Sprite2D as Sprite2D
	if sprite:
		sprite.modulate = RARITY_COLORS.get(rarity, Color.WHITE)

	is_active = true
	visible = true
	set_process(true)


func deactivate() -> void:
	is_active = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not is_active:
		return

	position += direction * speed * delta
