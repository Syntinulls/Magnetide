shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.72, 0.95, 1.0, 1.0);
uniform float line_alpha : hint_range(0.0, 1.0) = 0.35;
uniform vec2 rect_top_left = vec2(-200.0, -250.0);
uniform vec2 rect_size = vec2(400.0, 250.0);
uniform float dash_length = 28.0;
uniform float gap_length = 18.0;
uniform float dash_speed = 24.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 top_left = rect_top_left;
	vec2 bottom_right = rect_top_left + rect_size;

	float dist_top = abs(local_pos.y - top_left.y);
	float dist_right = abs(local_pos.x - bottom_right.x);
	float dist_bottom = abs(local_pos.y - bottom_right.y);
	float dist_left = abs(local_pos.x - top_left.x);

	float nearest = min(min(dist_top, dist_right), min(dist_bottom, dist_left));
	float perimeter_pos = 0.0;
	if (nearest == dist_top) {
		perimeter_pos = clamp(local_pos.x - top_left.x, 0.0, rect_size.x);
	} else if (nearest == dist_right) {
		perimeter_pos = rect_size.x + clamp(local_pos.y - top_left.y, 0.0, rect_size.y);
	} else if (nearest == dist_bottom) {
		perimeter_pos = rect_size.x + rect_size.y + clamp(bottom_right.x - local_pos.x, 0.0, rect_size.x);
	} else {
		perimeter_pos = rect_size.x + rect_size.y + rect_size.x + clamp(bottom_right.y - local_pos.y, 0.0, rect_size.y);
	}

	float cycle = max(dash_length + gap_length, 1.0);
	float dash_pos = mod(perimeter_pos + TIME * dash_speed, cycle);
	float edge = fwidth(dash_pos) * 1.5;
	float dash_alpha = 1.0 - smoothstep(dash_length - edge, dash_length + edge, dash_pos);

	COLOR = vec4(outline_color.rgb, outline_color.a * line_alpha * dash_alpha);
}
