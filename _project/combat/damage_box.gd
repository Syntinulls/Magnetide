extends Area2D
class_name DamageBox

## Deals damage to any permissible Hitbox that enters it while enabled — the
## dealing-side counterpart to Hitbox, which only ever receives damage. An
## attacker places one over the body part that hurts on contact (e.g. the
## charger's head, a boss part's claw) and toggles enabled from its behaviors.
## Each hit deals the owner's get_contact_damage() and names the owner as the
## damage source. Which targets are permissible is decided by this area's
## collision_mask (e.g. the player Hitbox layer). Enabling the box treats
## targets already inside it as having just entered.

signal dealt_damage(target_owner: Node)

## Owning attacker; must implement get_contact_damage() -> float. Each hit's
## damage amount and damage source resolve from it.
@export var owner_path: NodePath
## While false the box deals no damage. Overlaps are still tracked, so enabling
## mid-overlap hits immediately.
@export var enabled: bool = false: set = set_enabled
## When true the box deals at most one hit per enable; later entries are
## ignored until it is disabled and enabled again.
@export var single_hit_per_activation: bool = false

var _hit_spent: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func set_enabled(value: bool) -> void:
	var was_enabled := enabled
	enabled = value
	_hit_spent = false
	if enabled and not was_enabled and is_inside_tree():
		for area in get_overlapping_areas():
			_try_damage(area)


func _on_area_entered(area: Area2D) -> void:
	_try_damage(area)


func _try_damage(area: Area2D) -> void:
	if not enabled:
		return
	if single_hit_per_activation and _hit_spent:
		return
	var hitbox := area as Hitbox
	if hitbox == null or not hitbox.is_valid_target():
		return
	var source := get_node_or_null(owner_path)
	if source == null or not source.has_method("get_contact_damage"):
		return
	_hit_spent = true
	hitbox.take_damage(source.get_contact_damage(), source)
	dealt_damage.emit(hitbox.get_target_owner())
