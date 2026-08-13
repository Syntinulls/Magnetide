extends Node
class_name PlayerHealth

## The player's vitality: health, the kinetic shield with its recharge timers,
## damage intake and out-of-combat healing. The Player body forwards the
## duck-typed combat contract (take_damage / apply_storm_damage) here.

signal destroyed
signal damaged(amount: float)
signal shield_changed(current: int, maximum: int, broken: bool, delta: int)

@export var max_health: float = 100.0
@export var max_shield: float = 2.0
@export var shield_recharge_delay: float = 6.0
@export var shield_recharge_duration: float = 1.0
@export var shield_break_recharge_delay: float = 10.0

var current_health: float = 0.0
var current_shield: int = 0
## Debug god mode: while true the player ignores all incoming damage.
var invulnerable: bool = false
## Time since the player last took damage of any kind, including environmental
## drain. The single source of truth for out-of-combat healing — any new damage
## source suppresses healing simply by resetting this.
var seconds_since_damage: float = 0.0

var _shield_recharge_cooldown_remaining: float = 0.0
var _shield_recharge_progress: float = 0.0
var _shield_broken: bool = false
## Healing accumulated toward the next whole-point green popup, so per-frame
## regeneration ticks batch up instead of spawning a popup every frame.
var _pending_heal_popup: float = 0.0

@onready var _player: Player = owner as Player


func _ready() -> void:
	current_health = max_health
	current_shield = get_max_shield_hits()


func _physics_process(delta: float) -> void:
	seconds_since_damage += delta
	_process_shield_recharge(delta)


func apply_loadout(loadout: RunLoadout, runtime_reconfigure: bool) -> void:
	max_health = loadout.player_max_health
	max_shield = loadout.player_max_shield
	shield_recharge_delay = loadout.player_shield_recharge_delay
	shield_recharge_duration = loadout.player_shield_recharge_duration
	shield_break_recharge_delay = loadout.player_shield_break_recharge_delay

	if not runtime_reconfigure:
		current_health = max_health
		current_shield = get_max_shield_hits()
	else:
		current_health = minf(current_health, max_health)
		current_shield = mini(current_shield, get_max_shield_hits())
	if get_max_shield_hits() <= 0:
		current_shield = 0
		_shield_recharge_cooldown_remaining = 0.0
		_shield_recharge_progress = 0.0
		_shield_broken = false


func take_damage(amount: float, _source: Node = null) -> void:
	if current_health <= 0.0 or _player.combat_disabled or invulnerable:
		return
	if amount <= 0.0:
		return

	seconds_since_damage = 0.0
	damaged.emit(amount)
	if current_shield > 0:
		current_shield -= 1
		_shield_recharge_progress = 0.0
		if current_shield <= 0:
			_shield_broken = true
			_shield_recharge_cooldown_remaining = shield_break_recharge_delay
		else:
			_shield_broken = false
			_shield_recharge_cooldown_remaining = shield_recharge_delay
		_emit_shield_changed(-1)
		return

	var previous_health := current_health
	current_health = maxf(current_health - amount, 0.0)
	DamageNumber.spawn(_player.global_position, amount, DamageNumber.PLAYER_COLOR)
	if previous_health > 0.0 and current_health <= 0.0:
		destroyed.emit()


## Environmental storm drain. Bypasses the kinetic shield, the damage number and
## the damage flash — it is a continuous DoT, not a discrete hit, and per-frame
## flashes would be unreadable. It does reset seconds_since_damage, so healing is
## suppressed for as long as the drain lasts: storm damage is meant to be recovered
## between storms, not shrugged off inside one.
func apply_storm_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0 or _player.combat_disabled or invulnerable:
		return
	seconds_since_damage = 0.0
	var previous_health := current_health
	current_health = maxf(current_health - amount, 0.0)
	if previous_health > 0.0 and current_health <= 0.0:
		destroyed.emit()


func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	var healed := minf(current_health + amount, max_health) - current_health
	current_health += healed
	if healed <= 0.0:
		return
	_pending_heal_popup += healed
	if _pending_heal_popup >= 1.0:
		DamageNumber.spawn(_player.global_position, floorf(_pending_heal_popup), DamageNumber.HEAL_COLOR)
		_pending_heal_popup -= floorf(_pending_heal_popup)


func is_shield_broken() -> bool:
	return _shield_broken


func get_max_shield_hits() -> int:
	return maxi(roundi(max_shield), 0)


func _process_shield_recharge(delta: float) -> void:
	var max_shield_hits := get_max_shield_hits()
	if max_shield_hits <= 0 or current_health <= 0.0:
		current_shield = 0
		_shield_recharge_progress = 0.0
		_shield_broken = false
		return
	if current_shield >= max_shield_hits:
		current_shield = max_shield_hits
		_shield_recharge_cooldown_remaining = 0.0
		_shield_recharge_progress = 0.0
		_shield_broken = false
		return
	if _shield_recharge_cooldown_remaining > 0.0:
		_shield_recharge_cooldown_remaining = maxf(_shield_recharge_cooldown_remaining - delta, 0.0)
		return

	var seconds_per_hit := maxf(shield_recharge_duration, 0.01)
	_shield_recharge_progress += delta
	if _shield_recharge_progress >= seconds_per_hit and current_shield < max_shield_hits:
		_shield_recharge_progress -= seconds_per_hit
		current_shield += 1
		_shield_broken = current_shield <= 0
		_emit_shield_changed(1)
	_shield_broken = current_shield <= 0


func _emit_shield_changed(delta: int) -> void:
	shield_changed.emit(current_shield, get_max_shield_hits(), _shield_broken, delta)
