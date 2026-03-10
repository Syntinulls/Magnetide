shader_type canvas_item;

uniform sampler2D pattern_texture : repeat_enable, filter_nearest;
uniform float fade_ratio : hint_range(0.0, 1.0) = 0.3;
uniform vec2 rect_size = vec2(200.0, 16.0);

void fragment() {
	// Calculate tiled UV based on rect size and pattern texture size
	vec2 tex_size = vec2(textureSize(pattern_texture, 0));
	vec2 tex_uv = (UV * rect_size) / tex_size;
	vec4 col = texture(pattern_texture, tex_uv);

	// Fade to transparent at top edge (UV.y = 0 is top)
	float fade = smoothstep(0.0, fade_ratio, UV.y);
	col.a *= fade;

	COLOR = col;
}
