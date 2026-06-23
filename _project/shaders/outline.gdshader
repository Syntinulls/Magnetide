// Generic canvas_item sprite outline. Samples the texture's alpha in 8
// directions to draw a solid outline around the opaque silhouette. Reusable on
// any Sprite2D / TextureRect material. Toggle with `outline_enabled`.
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;
uniform bool outline_enabled = false;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (outline_enabled) {
		vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
		float outline = texture(TEXTURE, UV + vec2(size.x, 0)).a;
		outline += texture(TEXTURE, UV + vec2(-size.x, 0)).a;
		outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
		outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
		outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
		outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
		outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
		outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
		outline = min(outline, 1.0);
		col = mix(col, outline_color, outline - col.a);
	}
	COLOR = col;
}
