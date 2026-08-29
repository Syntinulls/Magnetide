extends Node
class_name PlayerScrapCollector

## Scrap metal award presentation and bookkeeping: the fly-to-HUD pickup sprite,
## the aggregated "+N Scrap Metal" loot label, and the collected signal the run
## controller records. Also owns the Increased Recycling double-scrap roll.

signal scrap_metal_collected(amount: int)

const ScrapMetalTexture: Texture2D = preload("res://_project/common/sprites/scrap_metal.png")

## Hang time between a pickup popping into view and it flying off to the HUD
## counter, so the award registers before the sprite leaves.
const PICKUP_HOLD_SECONDS: float = 0.6

## Chance (0-100) that recycling a trash item yields double scrap. Set by the
## Increased Recycling augment for the duration of a run.
var double_scrap_chance_percent: float = 0.0

@onready var _player: Player = owner as Player


## Grants scrap for a recycled trash item, rolling the Increased Recycling
## augment's double-scrap chance to spawn a second scrap pickup.
func collect_recycled(origin: Vector2) -> void:
	collect_from(origin)
	if double_scrap_chance_percent > 0.0 and randf() * 100.0 < double_scrap_chance_percent:
		collect_from(origin)


func collect_from(start_position: Vector2) -> void:
	if not is_inside_tree():
		return
	var parent_node := Magnetide.world_root
	if not parent_node:
		parent_node = _player.get_parent()
	if not parent_node:
		return

	var pickup := Sprite2D.new()
	pickup.texture = ScrapMetalTexture
	pickup.centered = true
	pickup.global_position = start_position
	pickup.z_index = 50
	if pickup.texture:
		var tex_size := pickup.texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var uniform_scale := minf(28.0 / tex_size.x, 28.0 / tex_size.y)
			pickup.scale = Vector2(uniform_scale, uniform_scale)
	parent_node.add_child(pickup)

	var pop_direction := (start_position - _player.global_position).normalized()
	if pop_direction == Vector2.ZERO:
		pop_direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var pop_target := start_position + pop_direction * randf_range(28.0, 44.0) + Vector2(0.0, randf_range(-28.0, -12.0))
	var collect_target := _get_collection_target_position()
	var start_scale := pickup.scale
	var tween := pickup.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pickup, "global_position", pop_target, 0.16)
	tween.parallel().tween_property(pickup, "scale", start_scale * 1.2, 0.16)
	tween.tween_interval(PICKUP_HOLD_SECONDS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(pickup, "global_position", collect_target, 0.42)
	tween.parallel().tween_property(pickup, "scale", start_scale * 0.55, 0.42)
	tween.parallel().tween_property(pickup, "modulate:a", 0.0, 0.16).set_delay(0.26)
	tween.tween_callback(_on_pickup_arrived.bind(pickup))


func _on_pickup_arrived(pickup: Sprite2D) -> void:
	if pickup and is_instance_valid(pickup):
		pickup.queue_free()
	if _player.loot_labels:
		_player.loot_labels.record("Scrap Metal", 1)
	scrap_metal_collected.emit(1)


func _get_collection_target_position() -> Vector2:
	var game_ui := Magnetide.game_ui
	if game_ui and game_ui.has_method("get_scrap_icon_screen_center"):
		var screen_position := game_ui.call("get_scrap_icon_screen_center") as Vector2
		return _player.get_viewport().get_canvas_transform().affine_inverse() * screen_position
	return _player.global_position + Vector2(0.0, -18.0)
