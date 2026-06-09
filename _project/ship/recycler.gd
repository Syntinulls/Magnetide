extends Area2D
class_name Recycler

signal trash_recycled(scrap_origin: Vector2)

@export var recycle_drop_distance: float = 48.0
@export var recycle_entry_duration: float = 0.18
@export var recycle_blade_contact_distance: float = 14.0
@export var recycle_blade_contact_duration: float = 0.1
@export var recycle_blade_pass_duration: float = 0.85
@export var blade_spin_speed: float = 6.0

const OUTLINE_SHADER: Shader = preload("res://_project/items/salvage_item_outline.gdshader")
const RENDER_Z_MAX: int = 0
const RENDER_Z_BACK: int = -3
const RENDER_Z_TRASH: int = -4
const RENDER_Z_PARTICLES: int = -2
const RENDER_Z_BLADES: int = -1

var _is_recycling: bool = false
var _outline_material: ShaderMaterial = null

@onready var _sprite_back: Sprite2D = $SpriteBack as Sprite2D
@onready var _sprite_front: AnimatedSprite2D = $SpriteFront as AnimatedSprite2D
@onready var _placement_shape: CollisionShape2D = $CollisionShape2D as CollisionShape2D
@onready var _grinder_left: Node2D = $GrinderLeft as Node2D
@onready var _grinder_right: Node2D = $GrinderRight as Node2D
@onready var _trash_start: Marker2D = $TrashStart as Marker2D
@onready var _trash_particles: GPUParticles2D = $TrashParticles as GPUParticles2D


func _ready() -> void:
	_apply_render_order()
	_setup_outline_material()
	_setup_particles()
	set_highlighted(false)


func _process(delta: float) -> void:
	if not _is_recycling:
		return
	if _grinder_left:
		_grinder_left.rotation += blade_spin_speed * delta
	if _grinder_right:
		_grinder_right.rotation -= blade_spin_speed * delta


func is_point_in_placement_area(global_point: Vector2) -> bool:
	if _placement_shape == null or _placement_shape.shape == null:
		return false
	if _placement_shape.shape is RectangleShape2D:
		var rect_shape := _placement_shape.shape as RectangleShape2D
		var local_point := _placement_shape.to_local(global_point)
		var rect := Rect2(-rect_shape.size * 0.5, rect_shape.size)
		return rect.has_point(local_point)
	return false


func can_accept_item(item: SalvageItem) -> bool:
	return item != null and is_instance_valid(item) and item.is_trash and not _is_recycling


func set_highlighted(enabled: bool) -> void:
	if _outline_material:
		_outline_material.set_shader_parameter("outline_enabled", enabled)


func recycle_trash(item: SalvageItem) -> bool:
	if not can_accept_item(item):
		return false

	_is_recycling = true
	set_highlighted(false)
	item.set_outlined(false)
	item.z_as_relative = false
	item.z_index = RENDER_Z_TRASH
	if _trash_particles:
		_configure_particles_for_item(item)
		_trash_particles.emitting = false
		_trash_particles.restart()
		_trash_particles.emitting = true

	var entry_position := _trash_start.global_position if _trash_start else global_position + Vector2(0.0, -45.0)
	var blade_contact_distance := clampf(recycle_blade_contact_distance, 0.0, recycle_drop_distance)
	var blade_contact_position := entry_position + Vector2(0.0, blade_contact_distance)
	var sink_position := entry_position + Vector2(0.0, recycle_drop_distance)
	var tween := item.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "global_position", entry_position, recycle_entry_duration)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "global_position", blade_contact_position, recycle_blade_contact_duration)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "global_position", sink_position, recycle_blade_pass_duration)
	tween.parallel().tween_property(item, "modulate:a", 0.0, recycle_blade_pass_duration * 0.7).set_delay(recycle_blade_pass_duration * 0.3)
	tween.tween_callback(_finish_recycling.bind(item, entry_position))
	return true


func _finish_recycling(item: SalvageItem, scrap_origin: Vector2) -> void:
	if item and is_instance_valid(item):
		item.queue_free()
	_is_recycling = false
	if _trash_particles:
		_trash_particles.emitting = false
	trash_recycled.emit(scrap_origin)


func _setup_outline_material() -> void:
	if _sprite_front == null:
		return
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	_outline_material.set_shader_parameter("outline_enabled", false)
	_outline_material.set_shader_parameter("outline_width", 3.0)
	_outline_material.set_shader_parameter("outline_color", Color.WHITE)
	_sprite_front.material = _outline_material


func _apply_render_order() -> void:
	z_as_relative = false
	z_index = RENDER_Z_MAX
	if _sprite_back:
		_sprite_back.z_as_relative = false
		_sprite_back.z_index = RENDER_Z_BACK
	if _trash_particles:
		_trash_particles.z_as_relative = false
		_trash_particles.z_index = RENDER_Z_PARTICLES
	if _grinder_left:
		_grinder_left.z_as_relative = false
		_grinder_left.z_index = RENDER_Z_BLADES
	if _grinder_right:
		_grinder_right.z_as_relative = false
		_grinder_right.z_index = RENDER_Z_BLADES
	if _sprite_front:
		_sprite_front.z_as_relative = false
		_sprite_front.z_index = RENDER_Z_MAX


func _setup_particles() -> void:
	if _trash_particles == null:
		return

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 56.0
	material.initial_velocity_min = 40.0
	material.initial_velocity_max = 84.0
	material.radial_accel_min = 82.0
	material.radial_accel_max = 135.0
	material.damping_min = 18.0
	material.damping_max = 32.0
	material.gravity = Vector3(0.0, 55.0, 0.0)
	material.scale_min = 0.16
	material.scale_max = 0.28
	material.color_ramp = _create_particle_alpha_ramp()
	material.scale_curve = _create_particle_scale_curve()

	_trash_particles.process_material = material
	_trash_particles.amount = 22
	_trash_particles.lifetime = 0.85
	_trash_particles.one_shot = true
	_trash_particles.explosiveness = 0.6
	_trash_particles.randomness = 0.35
	_trash_particles.emitting = false


func _configure_particles_for_item(item: SalvageItem) -> void:
	if _trash_particles == null or item == null or not is_instance_valid(item):
		return

	var sprite := _get_item_sprite(item)
	if sprite == null or sprite.texture == null:
		return

	_trash_particles.texture = sprite.texture
	var material := _trash_particles.process_material as ParticleProcessMaterial
	if material == null:
		return

	var item_visual_scale := maxf(sprite.scale.x, sprite.scale.y)
	material.scale_min = maxf(0.08, item_visual_scale * 0.32)
	material.scale_max = maxf(material.scale_min + 0.04, item_visual_scale * 0.52)


func _get_item_sprite(item: SalvageItem) -> Sprite2D:
	for child in item.get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null


func _create_particle_alpha_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.7),
		Color(1.0, 1.0, 1.0, 0.52),
		Color(1.0, 1.0, 1.0, 0.0)
	])

	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _create_particle_scale_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.7, 0.58))
	curve.add_point(Vector2(1.0, 0.12))

	var texture := CurveTexture.new()
	texture.curve = curve
	return texture
