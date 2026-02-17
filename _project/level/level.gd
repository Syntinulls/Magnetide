extends Node2D

## The speed at which the level scrolls (used by trash stream and foreground).
@export var level_speed: float = 300.0
## The Y position of the ocean surface as ratio of viewport height.
@export var surface_y_ratio: float = 0.46

@export_group("Ship Positioning")
## Ship X position as ratio of viewport width.
@export var ship_x_ratio: float = 0.5
## Ship Y position as ratio of viewport height.
@export var ship_y_ratio: float = 0.44

var viewport_anchor: ViewportAnchor

var surface_y: float:
	get:
		if viewport_anchor:
			return viewport_anchor.get_y(surface_y_ratio)
		return 500.0

@onready var ship: Node2D = $Ship


func _enter_tree() -> void:
	viewport_anchor = ViewportAnchor.new()
	add_child(viewport_anchor)


func _ready() -> void:
	viewport_anchor.viewport_changed.connect(_on_viewport_changed)
	_update_positions()


func _on_viewport_changed(_size: Vector2) -> void:
	_update_positions()


func _update_positions() -> void:
	if not viewport_anchor:
		return
	
	if ship:
		ship.position = viewport_anchor.get_position(ship_x_ratio, ship_y_ratio)
