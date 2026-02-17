extends Node2D
class_name SalvageSpawner

@export_group("Spawn Area")
## The horizontal position ratio where salvage piles spawn (right side of screen).
@export var spawn_x_ratio: float = 1.1
## The horizontal position ratio where salvage piles are despawned (left side of screen).
@export var despawn_x_ratio: float = -0.052
## Maximum random Y offset from surface_y to give slight variation.
@export var y_jitter: float = 10.0

@export_group("Spawning")
## Minimum time between spawns in seconds.
@export var spawn_interval_min: float = 20.0
## Maximum time between spawns in seconds.
@export var spawn_interval_max: float = 30.0

@export_group("Rarity Weights")
## Spawn weight for Common rarity (green).
@export var weight_common: float = 70.0
## Spawn weight for Rare rarity (blue).
@export var weight_rare: float = 20.0
## Spawn weight for Epic rarity (purple).
@export var weight_epic: float = 8.0
## Spawn weight for Legendary rarity (yellow).
@export var weight_legendary: float = 2.0

@export_group("Salvage Properties")
## Minimum uniform scale applied to salvage piles.
@export var salvage_scale_min: float = 0.7
## Maximum uniform scale applied to salvage piles.
@export var salvage_scale_max: float = 1.1
## Minimum rotation speed in radians per second applied to salvage piles.
@export var salvage_rotation_speed_min: float = -1.5
## Maximum rotation speed in radians per second applied to salvage piles.
@export var salvage_rotation_speed_max: float = 1.5

var _salvage_pile_scene: PackedScene
var _spawn_timer: Timer
var _current_pile: SalvagePile = null
var _level: Node = null
var _viewport_anchor: ViewportAnchor = null


func _ready() -> void:
	_salvage_pile_scene = preload("res://_project/level/salvage_spawner/salvage_pile.tscn")

	_level = get_parent()
	if _level and "viewport_anchor" in _level:
		_viewport_anchor = _level.viewport_anchor

	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)

	_start_spawn_timer()


func _get_level_speed() -> float:
	if _level and "level_speed" in _level:
		return _level.level_speed
	return 0.0


func _get_screen_width() -> float:
	if _viewport_anchor:
		return _viewport_anchor.size.x
	return get_viewport().get_visible_rect().size.x


func _get_spawn_x() -> float:
	return _get_screen_width() * spawn_x_ratio


func _get_despawn_x() -> float:
	return _get_screen_width() * despawn_x_ratio


func _get_surface_y() -> float:
	if _level and "surface_y" in _level:
		return _level.surface_y
	return get_viewport().get_visible_rect().size.y * 0.463


func _process(_delta: float) -> void:
	var level_speed := _get_level_speed()

	if level_speed <= 0.0:
		if not _spawn_timer.paused:
			_spawn_timer.paused = true
	else:
		if _spawn_timer.paused:
			_spawn_timer.paused = false

	if _current_pile and _current_pile.is_active:
		if _current_pile.global_position.x < _get_despawn_x():
			_on_pile_removed()


func _start_spawn_timer() -> void:
	var interval := randf_range(spawn_interval_min, spawn_interval_max)
	_spawn_timer.start(interval)


func _on_spawn_timer_timeout() -> void:
	_spawn_salvage()


func _on_pile_removed() -> void:
	if _current_pile:
		_current_pile.deactivate()
		_current_pile.queue_free()
		_current_pile = null
	_start_spawn_timer()


func on_pile_acquired() -> void:
	_on_pile_removed()


func _pick_rarity() -> SalvagePile.Rarity:
	var total := weight_common + weight_rare + weight_epic + weight_legendary
	var roll := randf() * total

	if roll < weight_common:
		return SalvagePile.Rarity.COMMON
	roll -= weight_common

	if roll < weight_rare:
		return SalvagePile.Rarity.RARE
	roll -= weight_rare

	if roll < weight_epic:
		return SalvagePile.Rarity.EPIC

	return SalvagePile.Rarity.LEGENDARY


func _spawn_salvage() -> void:
	if _current_pile and _current_pile.is_active:
		return

	_current_pile = _salvage_pile_scene.instantiate() as SalvagePile
	add_child(_current_pile)

	var spawn_y := _get_surface_y() + randf_range(-y_jitter, y_jitter)
	var s := randf_range(salvage_scale_min, salvage_scale_max)
	var rot := randf_range(0.0, TAU)

	_current_pile.activate(_pick_rarity(), Vector2(_get_spawn_x(), spawn_y), _level, s, rot)
