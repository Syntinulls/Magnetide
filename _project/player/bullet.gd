extends Area2D

@export var speed: float = 600.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var pierce: int = 1:
	set(value):
		pierce = maxi(value, 1)

var _remaining_pierce: int = 1
var _damaged_targets: Array[Node] = []

func _ready() -> void:
	_remaining_pierce = maxi(pierce, 1)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	rotation = direction.angle() + PI / 2.0


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("get_hitbox") and body.get_hitbox() != null:
		return
	_apply_damage_to(body, body)


func _on_area_entered(area: Area2D) -> void:
	var target: Node = area
	if area.has_method("get_target_owner"):
		var owner := area.call("get_target_owner") as Node
		if owner:
			target = owner
	_apply_damage_to(area, target)


func _apply_damage_to(receiver: Node, target: Node) -> void:
	if receiver == null or target == null:
		return
	if target in _damaged_targets:
		return
	if not receiver.has_method("take_damage"):
		return

	_damaged_targets.append(target)
	receiver.call("take_damage", damage)
	_remaining_pierce -= 1
	if _remaining_pierce <= 0:
		queue_free()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
