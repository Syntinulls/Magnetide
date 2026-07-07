extends Enemy
class_name Mosquito

## Flying, ranged enemy that hovers at a distance and fires needle projectiles at
## the player. Adds three things on top of the base Enemy:
##   1. Two wing sprites (a back layer behind the body and a fore layer in front)
##      that always play their flapping animation while the body holds a static
##      per-state frame; on death they swap to their torn "dead" frame. The body
##      art shifts within its canvas between states, so the wings are re-anchored
##      each frame by wing_frame_offsets to stay pinned to the body's wing joint.
##   2. Horizontal flipping instead of the base rotate-to-face: the art faces right,
##      so the whole creature mirrors to face a target on its left.
##   3. The hover/approach hysteresis (is_holding_position()) both the move and
##      attack behaviors read: it approaches until it reaches hover_distance, then
##      holds and fires, and only resumes approaching once the target pulls beyond
##      hover_distance + resume_margin.

const ANIM_WINDUP: StringName = &"windup"
const ANIM_SHOOT: StringName = &"attack"
const ANIM_WING_FLY: StringName = &"fly"
const ANIM_WING_DEAD: StringName = &"dead"

@export_group("Hover")
## Distance at which the mosquito stops approaching and holds position to fire.
@export var hover_distance: float = 260.0
## Extra distance the target must gain beyond hover_distance before the mosquito
## resumes approaching. Provides the "move marginally away to make it chase again"
## hysteresis so it doesn't jitter on the boundary.
@export var resume_margin: float = 90.0

@export_group("Wings")
## Per-body-animation wing offsets, indexed by the body sprite's current frame.
## Keys are body animation names (StringName), values are PackedVector2Array of
## offsets (one per frame). Both wing layers are shifted by this offset so they
## stay anchored to the body's wing joint even as the body art moves within its
## canvas between states. Frames past the array reuse the last entry; animations
## with no entry use Vector2.ZERO. The x component is mirrored when facing right.
## One entry per frame of each body animation (all single-frame today).
@export var wing_frame_offsets: Dictionary = {
	&"idle": PackedVector2Array([Vector2.ZERO]),
	&"move": PackedVector2Array([Vector2.ZERO]),
	&"windup": PackedVector2Array([Vector2.ZERO]),
	&"attack": PackedVector2Array([Vector2.ZERO]),
	&"death": PackedVector2Array([Vector2.ZERO]),
}

var _holding_position: bool = false
var _wings_dead: bool = false
var _muzzle_base_position: Vector2 = Vector2.ZERO

@onready var wing_back: AnimatedSprite2D = $Visual/WingBack
@onready var wing_fore: AnimatedSprite2D = $Visual/WingFore
@onready var muzzle: Marker2D = $Muzzle


func _ready() -> void:
	super._ready()
	if muzzle:
		_muzzle_base_position = muzzle.position
	_play_wing_animation(ANIM_WING_FLY)


func _physics_process(delta: float) -> void:
	if data and state != State.DEATH:
		_update_hover_state()
	super._physics_process(delta)
	if state == State.DEATH and not _wings_dead:
		_wings_dead = true
		_play_wing_animation(ANIM_WING_DEAD)


func _process(_delta: float) -> void:
	_update_wing_anchor()


## True while the mosquito is holding position at firing range. Read by both the
## move behavior (to stop approaching) and the attack behavior (to gate firing).
func is_holding_position() -> bool:
	return _holding_position


## World position the needle is fired from, tracking the flipped muzzle marker.
func get_muzzle_global_position() -> Vector2:
	return muzzle.global_position if muzzle else global_position


## Mirrors the body, both wing layers, and the muzzle to face the current target.
## The art faces right by default, so flip_h is set when the target is to the left.
func face_current_target() -> void:
	if not current_target_point or not is_instance_valid(current_target_point):
		return
	var facing_left := current_target_point.global_position.x < global_position.x
	sprite.flip_h = facing_left
	if wing_back:
		wing_back.flip_h = facing_left
	if wing_fore:
		wing_fore.flip_h = facing_left
	if muzzle:
		var mirror := -1.0 if facing_left else 1.0
		muzzle.position = Vector2(_muzzle_base_position.x * mirror, _muzzle_base_position.y)


func _update_hover_state() -> void:
	if not has_valid_target():
		_holding_position = false
		return

	var distance := get_distance_to_target()
	if _holding_position:
		if distance > hover_distance + resume_margin:
			_holding_position = false
	elif distance <= hover_distance:
		_holding_position = true


func _update_wing_anchor() -> void:
	var offset := _wing_offset_for(sprite.animation, sprite.frame)
	if sprite.flip_h:
		offset.x = -offset.x
	if wing_back:
		wing_back.position = offset
	if wing_fore:
		wing_fore.position = offset


func _wing_offset_for(animation_name: StringName, frame: int) -> Vector2:
	var offsets: Variant = wing_frame_offsets.get(animation_name, null)
	if offsets is PackedVector2Array and not (offsets as PackedVector2Array).is_empty():
		var packed := offsets as PackedVector2Array
		return packed[clampi(frame, 0, packed.size() - 1)]
	return Vector2.ZERO


func _play_wing_animation(animation_name: StringName) -> void:
	for wing in [wing_back, wing_fore]:
		if wing and wing.sprite_frames and wing.sprite_frames.has_animation(animation_name):
			wing.play(animation_name)
