extends RefCounted
class_name Utils
## Shared static helpers. Add a helper here once it has two or more consumers;
## a single-consumer helper belongs in the file that uses it.


## Returns true if the object declares a property with the given name.
static func has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


## Formats a float as an integer when whole, otherwise with two decimals.
static func format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value


## Formats a duration in seconds as MM:SS.
static func format_elapsed_time(seconds: float) -> String:
	var total_seconds := maxi(roundi(seconds), 0)
	@warning_ignore("integer_division")
	var minutes := total_seconds / 60
	var remaining_seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, remaining_seconds]


## Creates a solid-color texture used as a stand-in when an item has no sprite.
static func create_placeholder_texture(fill_color: Color, display_size: Vector2) -> Texture2D:
	var image_size := Vector2i(maxi(int(display_size.x), 2), maxi(int(display_size.y), 2))
	var image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	image.fill(fill_color)
	return ImageTexture.create_from_image(image)


## Walks up the tree to the level node (identified by its level_speed and
## viewport_anchor members, so it works from inside a SubViewport).
static func find_level_ancestor(node: Node) -> Node:
	var current := node.get_parent()
	while current:
		if "level_speed" in current and "viewport_anchor" in current:
			return current
		current = current.get_parent()
	return null
