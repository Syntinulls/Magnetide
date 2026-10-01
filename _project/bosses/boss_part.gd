extends Node2D
class_name BossPart

## One piece of a boss: its own health pool, the Hitbox that takes damage, the
## DamageBoxes that deal contact damage, and its visuals. Damage always routes through
## the owning Boss, which decides how much lands (phase clamps, invulnerability) and
## keeps the boss total in step. Subclasses add the part's attacks and animation and
## react to the boss through the _on_boss_* hooks.
##
## Scene contract: an optional `Visual` Node2D child carrying the hit-flash material
## (combat/hit_flash.gdshader), and a `Hitbox` child whose owner_path points at this
## part. DamageBoxes anywhere below the part (but not inside a nested BossPart) are
## found automatically and start disabled until set_attacks_enabled(true).

## Health reached zero. Named `died` because StatusEffect ends itself on it.
signal died

enum DestroyedMode {
	## Hidden, with its hitbox and damage boxes off.
	HIDE_AND_DISABLE,
	## Stays visible as wreckage; hitbox and damage boxes off.
	DISABLE_ONLY,
	## Keeps its visuals and damage boxes (a turret that fights on as scrap); only
	## the hitbox goes off.
	STAY_ACTIVE,
}

const HIT_FLASH_SECONDS: float = 0.15
const DESTROY_FADE_SECONDS: float = 0.4
const HIT_SFX := "enemies/enemy_hit.ogg"
const HIT_SFX_VOLUME_DB := -6.0

@export var max_health: float = 100.0
## Counted parts make up the boss's total health. An uncounted part (a respawning
## shield, a decoy) can be destroyed without moving the boss bar.
@export var counts_toward_boss_health: bool = true
## Damage one contact hit from this part's DamageBoxes deals.
@export var contact_damage: float = 10.0
@export var destroyed_mode: DestroyedMode = DestroyedMode.HIDE_AND_DISABLE
## While false the part shrugs off damage (armored, not yet exposed).
@export var damageable: bool = true

## The boss this part belongs to; assigned by the Boss when it readies.
var boss: Boss = null
var current_health: float = 0.0
var is_destroyed: bool = false
## Optional internal state for part-local behavior, separate from the boss's state.
## Changing it calls _on_part_state_changed().
var part_state: StringName = &"":
	set(value):
		if part_state == value:
			return
		var previous := part_state
		part_state = value
		_on_part_state_changed(previous, value)

var _damage_boxes: Array[DamageBox] = []
var _flash_tween: Tween = null

@onready var visual: Node2D = get_node_or_null(^"Visual") as Node2D
@onready var hitbox: Hitbox = get_node_or_null(^"Hitbox") as Hitbox


func _ready() -> void:
	add_to_group("boss_parts")
	current_health = max_health
	if visual and visual.material is ShaderMaterial:
		visual.material = visual.material.duplicate()
	_collect_damage_boxes(self)
	set_attacks_enabled(false)


## Combat contract (Hitbox → owner). The boss decides how much of `amount` lands.
func take_damage(amount: float, source: Node = null) -> void:
	if boss == null or is_destroyed or not damageable:
		return
	var applied := boss.apply_part_damage(self, amount, source)
	if applied <= 0.0:
		return
	DamageNumber.spawn(global_position, applied, DamageNumber.ENEMY_COLOR)
	_flash()
	if Magnetide.sfx:
		Magnetide.sfx.play(HIT_SFX, HIT_SFX_VOLUME_DB)
	_on_damaged(applied, source)


## DamageBox contract.
func get_contact_damage() -> float:
	return contact_damage


func get_hitbox() -> Hitbox:
	return hitbox


func set_attacks_enabled(enabled: bool) -> void:
	for box in _damage_boxes:
		box.enabled = enabled


func get_health_ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0


func stop_for_run_end() -> void:
	set_attacks_enabled(false)
	set_process(false)
	set_physics_process(false)


## Called by the Boss only: lower this part's pool by an amount it already approved.
func apply_approved_damage(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	if current_health <= 0.0:
		_destroy()


# -- Hooks for subclasses ----------------------------------------------------

## The boss switched combat state (ids are BossState node names).
func _on_boss_state_changed(_from: StringName, _to: StringName) -> void:
	pass


## The boss began its transition into phase `index`.
func _on_boss_phase_changed(_index: int) -> void:
	pass


func _on_boss_lifecycle_changed(_lifecycle: Boss.Lifecycle) -> void:
	pass


func _on_part_state_changed(_from: StringName, _to: StringName) -> void:
	pass


## Damage landed on this part (after the boss's clamps).
func _on_damaged(_amount: float, _source: Node) -> void:
	pass


## The part's death/destruction presentation; awaited before destroyed_mode applies.
## Default: a white flash, and a fade-out when the part is about to be hidden.
func _play_destruction_sequence() -> void:
	_flash()
	if destroyed_mode != DestroyedMode.HIDE_AND_DISABLE:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, DESTROY_FADE_SECONDS)
	await tween.finished


# -- Internals ---------------------------------------------------------------

func _destroy() -> void:
	is_destroyed = true
	_set_hitbox_active(false)
	died.emit()
	if boss:
		boss.notify_part_destroyed(self)
	await _play_destruction_sequence()
	_apply_destroyed_mode()


func _apply_destroyed_mode() -> void:
	match destroyed_mode:
		DestroyedMode.HIDE_AND_DISABLE:
			set_attacks_enabled(false)
			visible = false
		DestroyedMode.DISABLE_ONLY:
			set_attacks_enabled(false)
		DestroyedMode.STAY_ACTIVE:
			pass


## A spent hitbox must stop being detected at all, or projectiles would still spend
## their pierce on the wreck.
func _set_hitbox_active(active: bool) -> void:
	if hitbox == null:
		return
	hitbox.enabled = active
	hitbox.set_deferred("monitorable", active)


func _collect_damage_boxes(node: Node) -> void:
	for child in node.get_children():
		if child is BossPart:
			continue
		if child is DamageBox:
			_damage_boxes.append(child as DamageBox)
		_collect_damage_boxes(child)


func _flash() -> void:
	var mat := visual.material as ShaderMaterial if visual else null
	if mat == null:
		return
	if _flash_tween:
		_flash_tween.kill()
	mat.set_shader_parameter("flash_intensity", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(mat, "shader_parameter/flash_intensity", 0.0, HIT_FLASH_SECONDS)
