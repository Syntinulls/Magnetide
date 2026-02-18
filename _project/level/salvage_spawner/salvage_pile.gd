extends Node2D
class_name SalvagePile

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

const RARITY_COLORS: Dictionary = {
	Rarity.COMMON: Color(0.0, 0.8, 0.0),      # Green
	Rarity.RARE: Color(0.2, 0.4, 1.0),        # Blue
	Rarity.EPIC: Color(0.6, 0.2, 0.8),        # Purple
	Rarity.LEGENDARY: Color(1.0, 0.85, 0.0),  # Yellow/Gold
}

var _pile_textures: Array[Texture2D] = []
var direction: Vector2 = Vector2.LEFT
var rarity: Rarity = Rarity.COMMON
var is_active: bool = false
var _level: Node = null


func _ready() -> void:
	_pile_textures = [
		preload("res://_project/level/salvage_spawner/sprites/trash_pile_1.png"),
		preload("res://_project/level/salvage_spawner/sprites/trash_pile_2.png"),
		preload("res://_project/level/salvage_spawner/sprites/trash_pile_3.png"),
	]
	deactivate()


func activate(new_rarity: Rarity, spawn_position: Vector2, level: Node, new_scale: float, _new_rotation: float) -> void:
	rarity = new_rarity
	position = spawn_position
	_level = level
	scale = Vector2(new_scale, new_scale)
	rotation = deg_to_rad(randf_range(-10.0, 10.0))  # Shallow random rotation

	var sprite := $Sprite2D as Sprite2D
	if sprite:
		sprite.texture = _pile_textures[randi() % _pile_textures.size()]
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

	var level_speed := _get_level_speed()
	if level_speed <= 0.0:
		return

	position += direction * level_speed * delta


func _get_level_speed() -> float:
	if _level and "level_speed" in _level:
		return _level.level_speed
	return 0.0
