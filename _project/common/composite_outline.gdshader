// Outline-only shader for CompositeOutline. TEXTURE is a SubViewport capture of
// an object's combined sprites (its silhouette). This draws ONLY the outline
// ring around that silhouette; the interior is left fully transparent so the
// real sprites underneath show through unchanged. Because a single combined
// silhouette is sampled, overlapping child sprites produce one clean outline
// instead of per-sprite double edges.
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 16.0) = 3.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 size = TEXTURE_PIXEL_SIZE * outline_width;

	float a = 0.0;
	a += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
	a += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
	a += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
	a += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
	a += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
	a += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
	a += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
	a += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
	a = min(a, 1.0);

	// Ring = dilated silhouette minus the original silhouette.
	float ring = clamp(a - tex.a, 0.0, 1.0);
	COLOR = vec4(outline_color.rgb, outline_color.a * ring);
}
