shader_type canvas_item;

uniform float scroll_offset : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	uv.x = fract(uv.x + scroll_offset);
	COLOR = texture(TEXTURE, uv);
}
