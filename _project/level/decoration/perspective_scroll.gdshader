shader_type canvas_item;

uniform float scroll_offset : hint_range(0.0, 1.0) = 0.0;
uniform float top_width_ratio : hint_range(0.0, 2.0) = 1.0;  // Width at top relative to bottom (1.0 = no perspective)
uniform float bottom_width_ratio : hint_range(1.0, 4.0) = 2.0;  // Width at bottom relative to screen (for overhang)

void fragment() {
	vec2 uv = UV;
	
	// Calculate the width ratio at this vertical position (lerp from top to bottom)
	float width_at_y = mix(bottom_width_ratio, top_width_ratio, uv.y);
	
	// Remap X coordinate to create trapezoid effect
	// Center the texture and scale based on width ratio
	uv.x = (uv.x - 0.5) * width_at_y + 0.5;
	
	// Apply horizontal scroll with wrapping
	uv.x = fract(uv.x + scroll_offset);
	
	// Sample texture
	COLOR = texture(TEXTURE, uv);
}
