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

var _bob_amplitude: float = 3.0
var _bob_frequency: float = 2.0
var _bob_offset: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	deactivate()


func activate(new_rarity: Rarity, spawn_position: Vector2, new_speed: float, new_scale: float, new_rotation: float) -> void:
	rarity = new_rarity
	position = spawn_position
	speed = new_speed
	scale = Vector2(new_scale, new_scale)
	rotation = new_rotation

	_bob_offset = randf() * TAU
	_bob_amplitude = randf_range(8.0, 15.0)
	_bob_frequency = randf_range(1.2, 2.0)
	_base_y = position.y

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

	position.x += direction.x * speed * delta
	_base_y += direction.y * speed * delta
	var bob_raw := sin(Time.get_ticks_msec() * 0.001 * _bob_frequency + _bob_offset)
	var bob := (bob_raw * 0.5 + 0.5) * _bob_amplitude
	position.y = _base_y + bob
