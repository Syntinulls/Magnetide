extends Node2D
class_name DamageNumber

## Floating damage readout spawned at the point of damage: bounces in while
## drifting upward, then fades out. Spawn via the static DamageNumber.spawn();
## the color tells whose health was hit.

const ENEMY_COLOR := Color.WHITE
const PLAYER_COLOR := Color("ff5a5a")
const SHIP_COLOR := Color("ffd24a")

const SCENE := "res://_project/combat/damage_number.tscn"
const SPAWN_JITTER_X := 12.0
const POP_SECONDS := 0.18
const HOLD_SECONDS := 0.35
const FADE_SECONDS := 0.3
const DRIFT_DISTANCE := 64.0

var _amount: float = 0.0
var _color: Color = Color.WHITE

@onready var _label: Label = $AmountLabel


func _ready() -> void:
	Magnetide.apply_label_font(_label)
	_label.text = str(maxi(1, roundi(_amount)))
	_label.add_theme_color_override("font_color", _color)
	scale = Vector2(0.4, 0.4)
	modulate = Color(1.0, 1.0, 1.0, 0.0)

	var pop_tween := create_tween()
	pop_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(self, "scale", Vector2.ONE, POP_SECONDS)
	pop_tween.parallel().tween_property(self, "modulate:a", 1.0, POP_SECONDS * 0.8)

	var drift_tween := create_tween()
	drift_tween.tween_property(self, "position", Vector2(0.0, -DRIFT_DISTANCE),
		POP_SECONDS + HOLD_SECONDS + FADE_SECONDS).as_relative()

	var fade_tween := create_tween()
	fade_tween.tween_interval(POP_SECONDS + HOLD_SECONDS)
	fade_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	fade_tween.finished.connect(queue_free)


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
