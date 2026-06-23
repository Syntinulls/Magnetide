extends Node2D
class_name ThreatDividers

## Draws the threat bar overlay in local space. This node sits at the very
## top-left corner of the threat bar, which is also the gradient texture's
## top-left corner, so all coordinates are measured from the gradient's edge.
##
## It draws:
##   1. The divider lines between the segments.
##   2. A darkened shade over the locked region beyond the cap. Both span the
##      full gradient texture bounds; the frame, drawn on top, masks the rounded
##      corners.

var segment_count: int = 10
## Full gradient texture size (px) in local space.
var bar_width: float = 0.0
var bar_height: float = 0.0
## Number of reachable segments (cap stage + 1); segments beyond are shaded.
var reachable_segments: int = 1

var line_color: Color = Color(0, 0, 0, 0.45)
var line_width: float = 2.0
var locked_shade_color: Color = Color(0, 0, 0, 0.55)


func configure(p_segment_count: int, p_bar_width: float, p_bar_height: float) -> void:
	segment_count = maxi(p_segment_count, 1)
	bar_width = maxf(p_bar_width, 0.0)
	bar_height = maxf(p_bar_height, 0.0)
	queue_redraw()


func set_reachable_segments(value: int) -> void:
	reachable_segments = clampi(value, 0, segment_count)
	queue_redraw()


func _draw() -> void:
	if bar_width <= 0.0 or segment_count <= 0:
		return

	var segment_width := bar_width / float(segment_count)

	# Shade the locked region beyond the cap, out to the gradient's right edge.
	if reachable_segments < segment_count:
		var shade_left := segment_width * float(reachable_segments)
		draw_rect(
			Rect2(shade_left, 0.0, bar_width - shade_left, bar_height),
			locked_shade_color
		)

	# Divider lines between segments, spanning the full gradient height.
	for i in range(1, segment_count):
		var x := segment_width * float(i)
		draw_line(Vector2(x, 0.0), Vector2(x, bar_height), line_color, line_width)
