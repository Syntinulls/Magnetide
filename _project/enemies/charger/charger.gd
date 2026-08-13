extends Enemy
class_name Charger

## Slow flying enemy that orbits the player at range, then dashes straight
## through them. Adds three things on top of the base Enemy:
##   1. Head-tip aiming: the art faces right with the head tip at the sprite's
##      right center, so facing rotates the body so the head points at the
##      target, and the aim ray originates from the head tip rather than the
##      body center. The rotation freezes for the duration of a dash.
##   2. The is_charging() flag the move behavior raises while the dash is in
##      flight.
##   3. The head DamageBox: enabled only while charging, it deals the dash's
##      single contact hit, and the charger answers each hit by knocking the
##      struck target back along the dash direction.

## Local position of the head tip (the right center of the 260x130 sprite).
## Facing and the dash direction are aimed from this point at the target.
@export var head_tip_offset: Vector2 = Vector2(130, 0)

## Exponential smoothing rate (per second) applied while turning toward the
## target; higher values track tighter. The body eases onto the aim instead of
## snapping or locking on, including the 180° pivot after each dash.
@export var turn_damping: float = 5.0

@export_group("Knockback")
## Horizontal knockback speed (px/s) applied to a target struck by the dash.
@export var knockback_speed: float = 420.0
## Upward knockback speed (px/s) applied to a struck target, so a downward
## dash doesn't pin it to the floor.
@export var knockback_lift: float = 160.0

var _charging: bool = false

@onready var damage_box: DamageBox = $DamageBox


func _ready() -> void:
	super._ready()
	damage_box.dealt_damage.connect(_on_damage_box_dealt_damage)


## True while the dash is in flight. Raised by the move behavior's charge state.
func is_charging() -> bool:
	return _charging


func begin_charge() -> void:
	_charging = true
	damage_box.enabled = true


func end_charge() -> void:
	_charging = false
	damage_box.enabled = false


## World position of the head tip under the current rotation.
func get_head_tip_global_position() -> Vector2:
	return to_global(head_tip_offset)


## Direction from the head tip to the current target; Vector2.ZERO without one.
func get_aim_direction() -> Vector2:
	if not current_target_point or not is_instance_valid(current_target_point):
		return Vector2.ZERO
	return (current_target_point.global_position - get_head_tip_global_position()).normalized()


## Unit vector the head currently points along.
func get_facing_direction() -> Vector2:
	return Vector2.RIGHT.rotated(rotation)


## Eases the body's rotation toward the current target so the head tip comes
## to point at it. The art faces right, so the aim direction's angle is the
## rotation target; turn_damping sets how tightly the turn follows it.
func face_current_target() -> void:
	var aim := get_aim_direction()
	if aim == Vector2.ZERO:
		return
	var weight := 1.0 - exp(-turn_damping * get_physics_process_delta_time())
	rotation = lerp_angle(rotation, aim.angle(), weight)


## Rotates the body to a travel direction; used during the dash, when the
## charger no longer tracks the target and its rotation stays locked to the
## dash line.
func face_move_direction(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		rotation = direction.angle()


func _on_damage_box_dealt_damage(target_owner: Node) -> void:
	if target_owner == null or not target_owner.has_method("apply_knockback"):
		return
	var direction := velocity.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(rotation)
	target_owner.apply_knockback(Vector2(direction.x * knockback_speed, -knockback_lift))
