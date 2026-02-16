extends Node2D
class_name TrashStream

@export_group("Stream Area")
## The horizontal position where trash objects spawn (right side of screen).
@export var spawn_x: float = 1200.0
## The horizontal position where trash objects are despawned (left side of screen).
@export var despawn_x: float = -100.0
## The Y position of the trash ocean surface where objects float.
@export var surface_y: float = 540.0
## Maximum random Y offset from stream_y to give slight surface variation.
@export var y_jitter: float = 10.0

@export_group("Spawning")
## Minimum time between spawn attempts in seconds.
@export var spawn_interval_min: float = 2.0
## Maximum time between spawn attempts in seconds.
@export var spawn_interval_max: float = 4.0

@export_group("Spacing")
## Minimum horizontal distance (in pixels) between trash objects.
@export var min_spacing: float = 300.0

@export_group("Rarity Weights")
## Spawn weight for Common rarity (green).
@export var weight_common: float = 70.0
## Spawn weight for Rare rarity (blue).
@export var weight_rare: float = 20.0
## Spawn weight for Epic rarity (purple).
@export var weight_epic: float = 8.0
## Spawn weight for Legendary rarity (yellow).
@export var weight_legendary: float = 2.0

@export_group("Trash Properties")
## Speed of all trash objects in pixels per second (uniform so they never converge).
@export var trash_speed: float = 100.0
## Minimum uniform scale applied to trash objects.
@export var trash_scale_min: float = 0.7
## Maximum uniform scale applied to trash objects.
@export var trash_scale_max: float = 1.1
## Minimum rotation speed in radians per second applied to trash objects.
@export var trash_rotation_speed_min: float = -1.5
## Maximum rotation speed in radians per second applied to trash objects.
@export var trash_rotation_speed_max: float = 1.5

@export_group("Object Pool")
## Number of trash objects to pre-instantiate in the pool.
@export var pool_size: int = 10

var _trash_object_scene: PackedScene
var _spawn_timer: Timer
var _object_pool: Array[TrashObject] = []


func _ready() -> void:
	_trash_object_scene = preload("res://_project/level/trash_stream/trash_object.tscn")

	_init_object_pool()

	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)

	_start_next_spawn()


func _init_object_pool() -> void:
	for _i in range(pool_size):
		var instance: TrashObject = _trash_object_scene.instantiate()
		add_child(instance)
		_object_pool.append(instance)


func _get_pooled_object() -> TrashObject:
	for obj in _object_pool:
		if not obj.is_active:
			return obj
	return null


func _process(_delta: float) -> void:
	for obj in _object_pool:
		if obj.is_active and obj.global_position.x < despawn_x:
			obj.deactivate()


func _start_next_spawn() -> void:
	var interval := randf_range(spawn_interval_min, spawn_interval_max)
	_spawn_timer.start(interval)


func _on_spawn_timer_timeout() -> void:
	_spawn_trash()
	_start_next_spawn()


func _get_rightmost_trash_x() -> float:
	var rightmost := -INF
	for obj in _object_pool:
		if obj.is_active and obj.position.x > rightmost:
			rightmost = obj.position.x
	return rightmost


func _pick_rarity() -> TrashObject.Rarity:
	var total := weight_common + weight_rare + weight_epic + weight_legendary
	var roll := randf() * total

	if roll < weight_common:
		return TrashObject.Rarity.COMMON
	roll -= weight_common

	if roll < weight_rare:
		return TrashObject.Rarity.RARE
	roll -= weight_rare

	if roll < weight_epic:
		return TrashObject.Rarity.EPIC

	return TrashObject.Rarity.LEGENDARY


func _spawn_trash() -> void:
	var rightmost_x := _get_rightmost_trash_x()
	if rightmost_x != -INF and (spawn_x - rightmost_x) < min_spacing:
		return

	var instance := _get_pooled_object()
	if instance == null:
		return

	var spawn_y := surface_y + randf_range(-y_jitter, y_jitter)
	var s := randf_range(trash_scale_min, trash_scale_max)
	var rot := randf_range(0.0, TAU)

	instance.activate(_pick_rarity(), Vector2(spawn_x, spawn_y), trash_speed, s, rot)
