extends Node2D
class_name DamageNumber

## Floating damage readout spawned at the point of damage: bounces in while
## rising fast, decelerates to a halt, then shrinks away. Spawn via the static
## DamageNumber.spawn(); the color tells whose health was hit. spawn_text() reuses
## the same popup for short refusal messages ("No Scrap").

const ENEMY_COLOR := Color.WHITE
const PLAYER_COLOR := Color("ff5a5a")
const SHIP_COLOR := Color("ffd24a")
const HEAL_COLOR := Color("9bff63")
## Refusal messages: an action the player asked for that could not run.
const DENIED_COLOR := Color("ff5a5a")

const SCENE := "res://_project/combat/damage_number.tscn"
const SPAWN_JITTER_X := 12.0
const POP_SECONDS := 0.18
## Duration of the upward drift, from spawn until it halts (includes the pop).
const RISE_SECONDS := 0.53
## Time spent sitting at the landing spot before shrinking away.
const REST_SECONDS := 0.15
const SHRINK_SECONDS := 0.3
const DRIFT_DISTANCE := 128.0
## Each number's landing spot is offset by up to this much on both axes so
## rapid hits don't all stack on the exact same pixel.
const LANDING_JITTER := 24.0
## Words are several times wider than a damage number, so they read at a smaller
## size than the scene's authored one (which numbers keep).
const TEXT_FONT_SIZE := 26

var _text: String = ""
var _color: Color = Color.WHITE
## > 0 overrides the label's authored font size.
var _font_size: int = 0

@onready var _label: Label = $AmountLabel


func _ready() -> void:
	Magnetide.apply_label_font(_label)
	_label.text = _text
	_label.add_theme_color_override("font_color", _color)
	if _font_size > 0:
		_label.add_theme_font_size_override("font_size", _font_size)
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
	_spawn_popup(world_position, str(maxi(1, roundi(amount))), color, 0)


## Same popup with arbitrary text, for readouts that aren't a number.
static func spawn_text(world_position: Vector2, text: String, color: Color) -> void:
	_spawn_popup(world_position, text, color, TEXT_FONT_SIZE)


static func _spawn_popup(world_position: Vector2, text: String, color: Color, font_size: int) -> void:
	var world_root := Magnetide.world_root
	if world_root == null or text.is_empty():
		return
	var number := (load(SCENE) as PackedScene).instantiate() as DamageNumber
	number._text = text
	number._color = color
	number._font_size = font_size
	world_root.add_child(number)
	number.global_position = world_position + Vector2(randf_range(-SPAWN_JITTER_X, SPAWN_JITTER_X), 0.0)
