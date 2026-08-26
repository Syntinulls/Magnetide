extends Node2D
class_name ShipFloor

## Drop target for the ship's walkable deck: the fallback for setting a carried item
## down anywhere the player can stand, when no station or the storage area claims the
## point. Items put here are temporary — departure carries back the storage area and
## nothing else, so the deck is bench space, not a hold.
##
## The drop region is derived from the Boundaries body the player actually walks on
## rather than authored a second time, so the two can never drift apart.

## Lowest of the ship's drop targets, so the storage area, recycler and research
## station all win a point that falls inside both.
var drop_priority: int = 0

## Body whose shapes bound the player: its floor, walls and ceiling define the deck.
@export var boundaries_path: NodePath = NodePath("../Boundaries")
## Where dropped items are parented, so they ride with the ship rather than the world.
@export var dropped_items_path: NodePath = NodePath("../DeckSalvageItems")
## Inset from the walls and ceiling. A drop is refused nearer than this to an edge, so
## an item always lands with clearance instead of wedging against the boundary — and,
## for the ceiling, so a release never starts inside it and gets pushed back out.
@export var edge_inset: float = 48.0
## Gap kept between a released item and the deck surface, on top of the item's own
## half-height. Releasing right on the deck line would bury half the item in the floor,
## and a deep overlap resolves as a shove rather than a nudge.
@export var drop_clearance: float = 6.0

@onready var _boundaries: Node2D = get_node_or_null(boundaries_path) as Node2D
@onready var _dropped_items: Node2D = get_node_or_null(dropped_items_path) as Node2D


func _ready() -> void:
	add_to_group(PlayerInteraction.DROP_TARGET_GROUP)


# ---- PlayerInteraction drop-target contract ----

func is_drop_point(global_point: Vector2) -> bool:
	var deck := get_deck_rect()
	return deck.has_area() and deck.has_point(global_point)


## Anything the player can carry can be set down; there is no capacity to run out of.
func can_accept_dropped_item(item: SalvageItem, _point: Vector2) -> bool:
	return item != null and is_instance_valid(item)


func get_drop_prompt_label(_item: SalvageItem) -> String:
	return "DROP"


## The deck has no outline of its own — the storage area is the one region worth
## drawing, and lighting up the whole deck alongside it would only add noise.
func update_drop_state(_item: SalvageItem, _point: Vector2, _is_active: bool) -> void:
	pass


func clear_drop_state() -> void:
	pass


## Lifts a release that would start inside the floor up to rest on it instead. The
## cursor may sit on the deck line itself; the item's centre may not.
func _settle_point(item: SalvageItem, point: Vector2) -> Vector2:
	var floor_rect := _rect_of("Floor")
	if not floor_rect.has_area():
		return point
	var clearance := item.hitbox_size.y * 0.5 + drop_clearance
	return Vector2(point.x, minf(point.y, floor_rect.position.y - clearance))


## Where dropped items live: under the ship, so they travel with it.
func get_dropped_items_root() -> Node2D:
	return _dropped_items


func accept_dropped_item(_player: Player, item: SalvageItem, point: Vector2) -> Dictionary:
	if item == null or not is_instance_valid(item):
		return {"accepted": false}
	item.drop_on_deck(_settle_point(item, point), _dropped_items)
	return {"accepted": true}


## Region a carried item may be released into: the standing volume itself — floor to
## ceiling, wall to wall — inset all round. Taken from the same shapes that bound the
## player, so it is literally the space they can stand in.
func get_deck_rect() -> Rect2:
	var floor_shape := _rect_of("Floor")
	var ceiling := _rect_of("Ceiling")
	var left := _rect_of("LeftWall")
	var right := _rect_of("RightWall")
	for shape in [floor_shape, ceiling, left, right]:
		if not shape.has_area():
			return Rect2()
	var min_x := left.end.x + edge_inset
	var max_x := right.position.x - edge_inset
	var top_y := ceiling.end.y + edge_inset
	var deck_y := floor_shape.position.y
	if max_x <= min_x or deck_y <= top_y:
		return Rect2()
	return Rect2(Vector2(min_x, top_y), Vector2(max_x - min_x, deck_y - top_y))


## Global rect of one of the Boundaries collision shapes, or an empty rect when the
## shape is missing or is not a rectangle.
func _rect_of(shape_name: String) -> Rect2:
	if _boundaries == null:
		return Rect2()
	var node := _boundaries.get_node_or_null(shape_name) as CollisionShape2D
	if node == null:
		return Rect2()
	var rect := node.shape as RectangleShape2D
	if rect == null:
		return Rect2()
	return Rect2(node.global_position - rect.size * 0.5, rect.size)
