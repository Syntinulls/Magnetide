shader_type canvas_item;

uniform float scroll_offset : hint_range(0.0, 100.0) = 0.0;
uniform float bottom_width_ratio : hint_range(1.0, 4.0) = 2.0;  // Width at bottom relative to screen (for overhang)
uniform float x_tiles : hint_range(0.1, 20.0) = 1.0;  // How many times texture tiles horizontally
uniform float y_tiles : hint_range(0.1, 20.0) = 1.0;  // How many times texture would tile vertically (used to prevent tiling)

void fragment() {
	vec2 uv = UV;
	
	// UV from STRETCH_TILE is already scaled by rect/texture ratio
	// uv.x ranges 0 to x_tiles, uv.y ranges 0 to y_tiles
	
	// Normalize Y to 0-1 range (prevent vertical tiling by clamping)
	float norm_y = clamp(uv.y / y_tiles, 0.0, 1.0);
	
	// Calculate the width ratio at this vertical position (lerp from top to bottom)
	// norm_y=0 is top (horizon), norm_y=1 is bottom
	float width_at_y = mix(bottom_width_ratio, 1.0, norm_y);
	
	// Apply perspective to X: center, scale by width ratio, uncenter
	float center_x = uv.x - (x_tiles * 0.5);
	float perspective_x = center_x * width_at_y + (x_tiles * 0.5);
	
	// Apply horizontal scroll and wrap
	uv.x = fract(perspective_x / x_tiles + scroll_offset) * x_tiles;
	
	// Clamp Y to prevent vertical tiling
	uv.y = norm_y * y_tiles;
	if (uv.y > y_tiles) {
		uv.y = y_tiles;
	}
	
	// Normalize back to 0-1 for texture sampling
	uv.x = fract(uv.x / x_tiles);
	uv.y = uv.y / y_tiles;
	
	// Sample texture
	COLOR = texture(TEXTURE, uv);
}
