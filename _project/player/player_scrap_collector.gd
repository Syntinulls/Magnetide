extends Node
class_name PlayerScrapCollector

## Scrap metal award presentation and bookkeeping: the fly-to-HUD pickup sprite,
## the stacking "+1 Scrap Metal" labels, and the collected signal the run
## controller records. Also owns the Increased Recycling double-scrap roll.

signal scrap_metal_collected(amount: int)

const ScrapMetalTexture: Texture2D = preload("res://_project/common/sprites/scrap_metal.png")

const LABEL_OFFSET_Y: float = -86.0
const LABEL_SPACING: float = 24.0
const LABEL_POP_DURATION: float = 0.14
const LABEL_LIFETIME_SECONDS: float = 0.75
const LABEL_FADE_SECONDS: float = 0.35
const LABEL_DRIFT_DISTANCE: float = 18.0

## Chance (0-100) that recycling a trash item yields double scrap. Set by the
## Increased Recycling augment for the duration of a run.
var double_scrap_chance_percent: float = 0.0

var _active_labels: Array[Label] = []

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
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(pickup, "global_position", collect_target, 0.42)
	tween.parallel().tween_property(pickup, "scale", start_scale * 0.55, 0.42)
	tween.parallel().tween_property(pickup, "modulate:a", 0.0, 0.16).set_delay(0.26)
	tween.tween_callback(_on_pickup_arrived.bind(pickup))


func _on_pickup_arrived(pickup: Sprite2D) -> void:
	if pickup and is_instance_valid(pickup):
		pickup.queue_free()
	_show_loot_label()
	scrap_metal_collected.emit(1)


func _get_collection_target_position() -> Vector2:
	var game_ui := Magnetide.game_ui
	if game_ui and game_ui.has_method("get_scrap_icon_screen_center"):
		var screen_position := game_ui.call("get_scrap_icon_screen_center") as Vector2
		return _player.get_viewport().get_canvas_transform().affine_inverse() * screen_position
	return _player.global_position + Vector2(0.0, -18.0)


func _show_loot_label() -> void:
	var game_ui := Magnetide.game_ui
	if not game_ui:
		return

	var label := Label.new()
	label.text = "+1 Scrap Metal"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Magnetide.apply_label_font(label)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("d8d8d8"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	game_ui.add_child(label)
	label.size = label.get_combined_minimum_size()
	label.position = _get_label_target_position(label, 0)
	label.scale = Vector2(0.82, 0.82)
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_active_labels.append(label)
	_reposition_labels()

	var pop_tween := label.create_tween()
	pop_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(label, "scale", Vector2.ONE, LABEL_POP_DURATION)
	pop_tween.parallel().tween_property(label, "modulate:a", 1.0, LABEL_POP_DURATION * 0.8)

	var fade_tween := label.create_tween()
	fade_tween.tween_interval(LABEL_LIFETIME_SECONDS)
	fade_tween.tween_property(label, "position", label.position + Vector2(0.0, -LABEL_DRIFT_DISTANCE), LABEL_FADE_SECONDS)
	fade_tween.parallel().tween_property(label, "modulate:a", 0.0, LABEL_FADE_SECONDS)
	fade_tween.finished.connect(_on_label_expired.bind(label))


func _reposition_labels() -> void:
	for index in range(_active_labels.size()):
		var label := _active_labels[index]
		if label == null or not is_instance_valid(label):
			continue

		label.size = label.get_combined_minimum_size()
		var reverse_index := (_active_labels.size() - 1) - index
		var target_position := _get_label_target_position(label, reverse_index)
		var tween := label.create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "position", target_position, 0.12)


func _on_label_expired(label: Label) -> void:
	_active_labels.erase(label)
	if label and is_instance_valid(label):
		label.queue_free()
	_reposition_labels()


func _get_label_target_position(label: Label, stack_index_from_bottom: int) -> Vector2:
	var base_position := _player.get_viewport().get_canvas_transform() * (_player.global_position + Vector2(0.0, LABEL_OFFSET_Y))
	return Vector2(
		base_position.x - (label.size.x * 0.5),
		base_position.y - (stack_index_from_bottom * LABEL_SPACING) - label.size.y
	)
