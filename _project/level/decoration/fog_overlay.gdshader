shader_type canvas_item;

// Texture from SubViewport containing parallax content with transparent background
uniform sampler2D parallax_texture : hint_default_transparent;
// Haze parameters from level
uniform vec4 haze_color : source_color = vec4(0.85, 0.65, 0.4, 1.0);
uniform float haze_intensity : hint_range(0.0, 1.0) = 0.7;
uniform float haze_falloff : hint_range(0.1, 5.0) = 2.0;

void fragment() {
	// Sample the parallax content texture to get its alpha (mask)
	vec4 parallax_color = texture(parallax_texture, UV);
	
	// Only apply fog where there's parallax content (alpha > 0)
	float mask = parallax_color.a;
	
	// Calculate fog density based on Y position with exponential falloff
	// UV.y = 0 at top, UV.y = 1 at bottom
	// We want fog to be densest at top and fade toward bottom
	// - At top (UV.y=0): density = 1 * intensity (full fog)
	// - At bottom (UV.y=1): density = 0 (no fog)
	// - Higher falloff = fog spreads further down (denser overall)
	// - Lower falloff = fog concentrated at top (fades faster)
	float fade = pow(UV.y, haze_falloff);
	float fog_density = (1.0 - fade) * haze_intensity;
	
	// Apply fog color with calculated density, masked to parallax content
	COLOR = vec4(haze_color.rgb, fog_density * mask);
}
