extends Node2D
class_name RepairBeam

## Repair gun beam VFX: a tiling Line2D from the muzzle to the hull contact point,
## with looping start ("shine") and end ("contact") sprites. On stop_dissipate() the
## line hides immediately while each sprite finishes its current animation pass; the
## shine keeps tracking the muzzle, the contact stays frozen at the last hit point.

## The muzzle marker the beam originates from (assigned by the owning scene).
@export var muzzle_path: NodePath

@export_group("Beam Animation")
## Standalone per-frame textures for the animated beam. They must be individual
## textures, not AtlasTexture regions — Line2D ignores atlas regions and would
## draw the whole sheet. Cycled at beam_anim_fps and tiled along the beam.
@export var beam_frames: Array[Texture2D] = [
	preload("res://_project/items/repair_gun/effect_beam_1_frame_0.png"),
	preload("res://_project/items/repair_gun/effect_beam_1_frame_1.png"),
	preload("res://_project/items/repair_gun/effect_beam_1_frame_2.png"),
	preload("res://_project/items/repair_gun/effect_beam_1_frame_3.png"),
	preload("res://_project/items/repair_gun/effect_beam_1_frame_4.png"),
	preload("res://_project/items/repair_gun/effect_beam_1_frame_5.png"),
	preload("res://_project/items/repair_gun/effect_beam_1_frame_6.png"),
	preload("res://_project/items/repair_gun/effect_beam_1_frame_7.png"),
]
## Playback rate of the beam frames, matching the shine and contact sprites.
@export var beam_anim_fps: float = 15.0

var _active: bool = false
var _dissipating: bool = false
var _beam_anim_time: float = 0.0

@onready var _beam: Line2D = $Beam
@onready var _shine: AnimatedSprite2D = $Shine
@onready var _contact: AnimatedSprite2D = $Contact
@onready var _muzzle: Node2D = get_node_or_null(muzzle_path) as Node2D


func _ready() -> void:
	_shine.animation_looped.connect(_on_sprite_animation_looped.bind(_shine))
	_contact.animation_looped.connect(_on_sprite_animation_looped.bind(_contact))


func _process(delta: float) -> void:
	_advance_beam_animation(delta)
	if not (_active or _dissipating) or _muzzle == null:
		return
	_shine.global_position = _muzzle.global_position
	if _active:
		_beam.points = PackedVector2Array([_muzzle.global_position, _contact.global_position])


## Cycle the beam's frame texture while the line shows; the line tiles whichever
## frame is current along its length.
func _advance_beam_animation(delta: float) -> void:
	if not _beam.visible or beam_frames.is_empty() or beam_anim_fps <= 0.0:
		return
	_beam_anim_time = fmod(_beam_anim_time + delta, float(beam_frames.size()) / beam_anim_fps)
	var frame_texture: Texture2D = beam_frames[int(_beam_anim_time * beam_anim_fps) % beam_frames.size()]
	if frame_texture != null and _beam.texture != frame_texture:
		_beam.texture = frame_texture


func is_active() -> bool:
	return _active


func update_beam(contact_global: Vector2) -> void:
	if not _beam.visible:
		_beam_anim_time = 0.0
	_active = true
	_dissipating = false
	_contact.global_position = contact_global
	if _muzzle != null:
		_shine.global_position = _muzzle.global_position
		_beam.points = PackedVector2Array([_muzzle.global_position, contact_global])
	_beam.visible = true
	for sprite: AnimatedSprite2D in [_shine, _contact]:
		if not sprite.visible or not sprite.is_playing():
			sprite.visible = true
			sprite.play()


## One pass of the shine and contact sprites with no connecting line, for a beam that
## refused to run: the player sees what they were aiming at and that the tool
## responded, without the line or progress that mean a repair is under way.
func flash_once(contact_global: Vector2) -> void:
	if _active or _dissipating:
		return
	_dissipating = true
	_beam.visible = false
	_contact.global_position = contact_global
	if _muzzle != null:
		_shine.global_position = _muzzle.global_position
	for sprite: AnimatedSprite2D in [_shine, _contact]:
		sprite.visible = true
		sprite.frame = 0
		sprite.play()


## Hide the line immediately; each sprite finishes its current animation pass and
## hides itself via _on_sprite_animation_looped.
func stop_dissipate() -> void:
	if not _active:
		return
	_active = false
	_dissipating = true
	_beam.visible = false


func stop_immediate() -> void:
	_active = false
	_dissipating = false
	_beam.visible = false
	for sprite: AnimatedSprite2D in [_shine, _contact]:
		sprite.stop()
		sprite.visible = false


func _on_sprite_animation_looped(sprite: AnimatedSprite2D) -> void:
	if not _dissipating:
		return
	sprite.stop()
	sprite.visible = false
	if not _shine.visible and not _contact.visible:
		_dissipating = false
