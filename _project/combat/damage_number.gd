extends Node2D
class_name DamageNumber

## Floating damage readout spawned at the point of damage: bounces in while
## rising fast, decelerates to a halt, then shrinks away. Spawn via the static
## DamageNumber.spawn(); the color tells whose health was hit.

const ENEMY_COLOR := Color.WHITE
const PLAYER_COLOR := Color("ff5a5a")
const SHIP_COLOR := Color("ffd24a")

const SCENE := "res://_project/combat/damage_number.tscn"
const SPAWN_JITTER_X := 12.0
const POP_SECONDS := 0.18
## Duration of the upward drift, from spawn until it halts (includes the pop).
const RISE_SECONDS := 0.53
## Time spent sitting at the landing spot before shrinking away.
const REST_SECONDS := 1.05
const SHRINK_SECONDS := 0.3
const DRIFT_DISTANCE := 128.0
## Each number's landing spot is offset by up to this much on both axes so
## rapid hits don't all stack on the exact same pixel.
const LANDING_JITTER := 24.0

var _amount: float = 0.0
var _color: Color = Color.WHITE

@onready var _label: Label = $AmountLabel


func _ready() -> void:
	Magnetide.apply_label_font(_label)
	_label.text = str(maxi(1, roundi(_amount)))
	_label.add_theme_color_override("font_color", _color)
	scale = Vector2(0.4, 0.4)

	var pop_tween := create_tween()
	pop_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(self, "scale", Vector2.ONE, POP_SECONDS)

	var landing := Vector2(
		randf_range(-LANDING_JITTER, LANDING_JITTER),
		-DRIFT_DISTANCE + randf_range(-LANDING_JITTER, LANDING_JITTER)
	)
	var drift_tween := create_tween()
	drift_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	drift_tween.tween_property(self, "position", landing, RISE_SECONDS).as_relative()

	var shrink_tween := create_tween()
	shrink_tween.tween_interval(RISE_SECONDS + REST_SECONDS)
	shrink_tween.tween_property(self, "scale", Vector2.ZERO, SHRINK_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	shrink_tween.finished.connect(queue_free)


static func spawn(world_position: Vector2, amount: float, color: Color) -> void:
	if amount <= 0.0:
		return
	var world_root := Magnetide.world_root
	if world_root == null:
		return
	var number := (load(SCENE) as PackedScene).instantiate() as DamageNumber
	number._amount = amount
	number._color = color
	world_root.add_child(number)
	number.global_position = world_position + Vector2(randf_range(-SPAWN_JITTER_X, SPAWN_JITTER_X), 0.0)
