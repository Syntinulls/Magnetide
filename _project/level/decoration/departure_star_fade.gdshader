shader_type canvas_item;

uniform float fade_start_y = -1200.0;
uniform float fade_end_y = -5500.0;
uniform float min_alpha = 0.0;
uniform float max_alpha = 1.0;

varying float canvas_y;

void vertex() {
	canvas_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	float fade_span = max(abs(fade_start_y - fade_end_y), 1.0);
	float height_fade = clamp((fade_start_y - canvas_y) / fade_span, 0.0, 1.0);
	tex.a *= mix(min_alpha, max_alpha, height_fade);
	COLOR = tex;
}
