shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_radius : hint_range(0.0, 1.0) = 0.5;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.5;
uniform float grayscale_intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Read the screen behind this overlay
	vec4 screen_color = textureLod(screen_texture, SCREEN_UV, 0.0);
	
	// Apply grayscale to screen
	float gray = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grayscale_color = mix(screen_color.rgb, vec3(gray), grayscale_intensity);
	
	// Apply vignette (darken edges only)
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(SCREEN_UV, center);
	float vignette = smoothstep(vignette_radius, vignette_radius + vignette_softness, dist);
	vec3 final_color = grayscale_color * (1.0 - vignette * vignette_intensity);
	
	COLOR = vec4(final_color, 1.0);
}
