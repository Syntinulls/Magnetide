shader_type canvas_item;

// Damage flash for the player's sprite layers: mixes the sprite toward
// flash_color by flash_intensity, scaled by the color's alpha so a
// half-opacity red never fully replaces the artwork.
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.0, 0.5);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	tex_color.rgb = mix(tex_color.rgb, flash_color.rgb, flash_intensity * flash_color.a);
	COLOR = tex_color;
}
