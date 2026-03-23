shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.01;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Discard pixels below alpha threshold to prevent edge artifacts
	if (tex_color.a < alpha_cutoff) {
		discard;
	}
	
	// Apply tint color (for premultiplied alpha, multiply RGB by tint and keep alpha)
	COLOR = vec4(tex_color.rgb * tint_color.rgb, tex_color.a * tint_color.a);
}
