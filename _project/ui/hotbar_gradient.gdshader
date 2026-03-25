shader_type canvas_item;

// Horizontal gradient that fades edges to transparent
// Applied to the entire hotbar viewport texture
// 0% -> 25%: fade in, 25% -> 75%: fully opaque, 75% -> 100%: fade out

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	float alpha_mult = 1.0;
	
	if (UV.x < 0.25) {
		// Left edge: fade from transparent (0%) to opaque (25%)
		alpha_mult = smoothstep(0.0, 0.25, UV.x);
	} else if (UV.x > 0.75) {
		// Right edge: fade from opaque (75%) to transparent (100%)
		alpha_mult = smoothstep(1.0, 0.75, UV.x);
	}
	// else: 25% to 75% stays fully opaque (alpha_mult = 1.0)
	
	COLOR = vec4(tex_color.rgb, tex_color.a * alpha_mult);
}
