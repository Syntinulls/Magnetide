shader_type canvas_item;

// Nine-patch shader for Sprite2D - stretches center while preserving corners and edges
// Use with NinePatchSprite script to automatically handle sizing

// Margins in pixels from each edge (non-stretching regions)
uniform float margin_left : hint_range(0.0, 512.0) = 16.0;
uniform float margin_right : hint_range(0.0, 512.0) = 16.0;
uniform float margin_top : hint_range(0.0, 512.0) = 16.0;
uniform float margin_bottom : hint_range(0.0, 512.0) = 16.0;

// Target size in pixels - set by script or manually
uniform vec2 target_size = vec2(128.0, 128.0);

void fragment() {
	// Get texture size from built-in
	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	
	// Current pixel position in target space
	vec2 pixel_pos = UV * target_size;
	vec2 uv_out;
	
	// Calculate the stretchable center region sizes
	float src_center_w = texture_size.x - margin_left - margin_right;
	float src_center_h = texture_size.y - margin_top - margin_bottom;
	float dst_center_w = max(target_size.x - margin_left - margin_right, 0.001);
	float dst_center_h = max(target_size.y - margin_top - margin_bottom, 0.001);
	
	// X-axis mapping
	if (pixel_pos.x < margin_left) {
		// Left edge - no stretch
		uv_out.x = pixel_pos.x / texture_size.x;
	} else if (pixel_pos.x > target_size.x - margin_right) {
		// Right edge - no stretch
		float from_right = target_size.x - pixel_pos.x;
		uv_out.x = (texture_size.x - from_right) / texture_size.x;
	} else {
		// Center - stretch
		float center_pos = pixel_pos.x - margin_left;
		float center_ratio = center_pos / dst_center_w;
		uv_out.x = (margin_left + center_ratio * src_center_w) / texture_size.x;
	}
	
	// Y-axis mapping
	if (pixel_pos.y < margin_top) {
		// Top edge - no stretch
		uv_out.y = pixel_pos.y / texture_size.y;
	} else if (pixel_pos.y > target_size.y - margin_bottom) {
		// Bottom edge - no stretch
		float from_bottom = target_size.y - pixel_pos.y;
		uv_out.y = (texture_size.y - from_bottom) / texture_size.y;
	} else {
		// Center - stretch
		float center_pos = pixel_pos.y - margin_top;
		float center_ratio = center_pos / dst_center_h;
		uv_out.y = (margin_top + center_ratio * src_center_h) / texture_size.y;
	}
	
	COLOR = texture(TEXTURE, uv_out);
}
