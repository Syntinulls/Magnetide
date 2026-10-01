shader_type canvas_item;
render_mode blend_premul_alpha;

uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec3 white = vec3(tex_color.a);
	tex_color.rgb = mix(tex_color.rgb, white, flash_intensity);
	COLOR = tex_color;
}
