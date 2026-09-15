extends Area2D
class_name Recycler

signal trash_recycled

@export_group("Scrap Bundle")
## Trash items that must be fed in before the recycler pays out. Driven by the recycler intake
## upgrade through the run loadout.
@export var trash_per_bundle: int = 5
## Scrap metal awarded by one completed bundle. Driven by the recycler yield upgrade.
@export var scrap_per_bundle: int = 15
## Where the payout readout pops, relative to the recycler.
@export var scrap_popup_offset: Vector2 = Vector2(0, -90)
@export_group("")

@export var recycle_drop_distance: float = 48.0
@export var recycle_entry_duration: float = 0.18
@export var recycle_blade_contact_distance: float = 14.0
@export var recycle_blade_contact_duration: float = 0.1
@export var recycle_blade_pass_duration: float = 0.85
@export var blade_spin_speed: float = 6.0
@export_group("Audio")
@export var grind_sfx_filename: String = "ship/recycler_grind.ogg"
@export var grind_sfx_volume_db: float = -2.0

const RENDER_Z_MAX: int = 0
const RENDER_Z_BACK: int = -3
const RENDER_Z_TRASH: int = -4
const RENDER_Z_PARTICLES: int = -2
const RENDER_Z_BLADES: int = -1

## PlayerInteraction drop-target contract: outranks storage and the research
## station so trash dropped on the recycler is always recycled.
var drop_priority: int = 30

## Chance (0-100) that a completed bundle pays out twice. Set by the Increased Recycling augment
## for the duration of a run.
var double_bundle_chance_percent: float = 0.0

var _is_recycling: bool = false
var _outline: CompositeOutline = null
## Trash fed in since the last payout; at trash_per_bundle it pays a bundle and resets.
var _trash_fed: int = 0
var _pending_scrap_player: Player = null

@onready var _sprite_back: Sprite2D = $SpriteBack as Sprite2D
@onready var _sprite_front: AnimatedSprite2D = $SpriteFront as AnimatedSprite2D
@onready var _placement_shape: CollisionShape2D = $CollisionShape2D as CollisionShape2D
@onready var _grinder_left: Node2D = $GrinderLeft as Node2D
@onready var _grinder_right: Node2D = $GrinderRight as Node2D
@onready var _grinder_left_saw: Sprite2D = $GrinderLeft/Sprite2D as Sprite2D
@onready var _grinder_right_saw: Sprite2D = $GrinderRight/Sprite2D as Sprite2D
@onready var _trash_start: Marker2D = $TrashStart as Marker2D
@onready var _trash_particles: GPUParticles2D = $TrashParticles as GPUParticles2D
@onready var _bundle_counter: Label = $BundleCounter as Label


func _ready() -> void:
	add_to_group(PlayerInteraction.DROP_TARGET_GROUP)
	_apply_render_order()
	_setup_outline_material()
	_setup_particles()
	set_highlighted(false)
	_refresh_counter_label()


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
	if _outline:
		_outline.set_enabled(enabled)


# ---- PlayerInteraction drop-target contract ----

func is_drop_point(global_point: Vector2) -> bool:
	return is_point_in_placement_area(global_point)


func can_accept_dropped_item(item: SalvageItem, _point: Vector2) -> bool:
	return can_accept_item(item)


func get_drop_prompt_label(_item: SalvageItem) -> String:
	return "RECYCLE"


func update_drop_state(_item: SalvageItem, _point: Vector2, is_active: bool) -> void:
	set_highlighted(is_active)


func clear_drop_state() -> void:
	set_highlighted(false)


## Starts the recycle and remembers who fed it, so the bundle pays out to that player when the
## grind finishes.
func accept_dropped_item(player: Player, item: SalvageItem, _point: Vector2) -> Dictionary:
	if not recycle_trash(item):
		return {"accepted": false}

	_pending_scrap_player = player
	var recycled_callback := Callable(self, "_on_own_trash_recycled")
	if not trash_recycled.is_connected(recycled_callback):
		trash_recycled.connect(recycled_callback, CONNECT_ONE_SHOT)
	return {"accepted": true}


## Counts a finished trash item toward the current bundle, paying out once the counter fills.
func _on_own_trash_recycled() -> void:
	var player := _pending_scrap_player
	_pending_scrap_player = null

	var required := maxi(trash_per_bundle, 1)
	_trash_fed += 1
	if _trash_fed < required:
		_refresh_counter_label()
		return

	_trash_fed = 0
	_refresh_counter_label()
	if player == null or not is_instance_valid(player) or scrap_per_bundle <= 0:
		return
	var bundles := 2 if randf() * 100.0 < double_bundle_chance_percent else 1
	var awarded := bundles * scrap_per_bundle
	# The readout over the recycler is the payout's whole presentation: no pickup sprite
	# riding up to the HUD, and no second label over the player saying the same thing.
	player.scrap_collector.bank(awarded)
	DamageNumber.spawn_gain(
		global_position + scrap_popup_offset, awarded, DamageNumber.SCRAP_COLOR, "scrap"
	)


## Applies the run's recycler upgrades and restarts the bundle counter.
func apply_run_loadout(loadout: RunLoadout) -> void:
	if loadout == null:
		return
	trash_per_bundle = maxi(loadout.recycler_trash_per_bundle, 1)
	scrap_per_bundle = maxi(loadout.recycler_scrap_per_bundle, 0)
	_trash_fed = 0
	_refresh_counter_label()


func _refresh_counter_label() -> void:
	if _bundle_counter == null:
		return
	_bundle_counter.text = "%d/%d" % [_trash_fed, maxi(trash_per_bundle, 1)]


func recycle_trash(item: SalvageItem) -> bool:
	if not can_accept_item(item):
		return false

	_is_recycling = true
	_play_grind_sfx()
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
	tween.tween_callback(_finish_recycling.bind(item))
	return true


func _finish_recycling(item: SalvageItem) -> void:
	if item and is_instance_valid(item):
		item.queue_free()
	_is_recycling = false
	if _trash_particles:
		_trash_particles.emitting = false
	trash_recycled.emit()


func _play_grind_sfx() -> void:
	if grind_sfx_filename.is_empty() or not Magnetide.sfx:
		return
	Magnetide.sfx.play(grind_sfx_filename, grind_sfx_volume_db)


func _setup_outline_material() -> void:
	# Composite outline around the back + front sprites (the front animates, so
	# this is dynamic and re-syncs each frame while highlighted).
	var sources: Array = []
	if _sprite_back:
		sources.append(_sprite_back)
	if _grinder_left_saw:
		sources.append(_grinder_left_saw)
	if _grinder_right_saw:
		sources.append(_grinder_right_saw)
	if _sprite_front:
		sources.append(_sprite_front)
	if sources.is_empty():
		return
	_outline = CompositeOutline.new()
	add_child(_outline)
	# Mirror the front sprite's exact depth (uses absolute z in the scene).
	_outline.configure(sources, true, Color.WHITE, 3.0, _sprite_front)


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

	var process_mat := ParticleProcessMaterial.new()
	process_mat.direction = Vector3(0.0, -1.0, 0.0)
	process_mat.spread = 56.0
	process_mat.initial_velocity_min = 40.0
	process_mat.initial_velocity_max = 84.0
	process_mat.radial_accel_min = 82.0
	process_mat.radial_accel_max = 135.0
	process_mat.damping_min = 18.0
	process_mat.damping_max = 32.0
	process_mat.gravity = Vector3(0.0, 55.0, 0.0)
	process_mat.scale_min = 0.16
	process_mat.scale_max = 0.28
	process_mat.color_ramp = _create_particle_alpha_ramp()
	process_mat.scale_curve = _create_particle_scale_curve()

	_trash_particles.process_material = process_mat
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
	var process_mat := _trash_particles.process_material as ParticleProcessMaterial
	if process_mat == null:
		return

	var item_visual_scale := maxf(sprite.scale.x, sprite.scale.y)
	process_mat.scale_min = maxf(0.08, item_visual_scale * 0.32)
	process_mat.scale_max = maxf(process_mat.scale_min + 0.04, item_visual_scale * 0.52)


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
