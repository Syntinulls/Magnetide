extends Area2D

@export var speed: float = 600.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	rotation = direction.angle() + PI / 2.0


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
