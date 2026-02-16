shader_type canvas_item;

uniform float amplitude : hint_range(0.0, 10.0) = 3.0;
uniform float frequency : hint_range(0.0, 5.0) = 2.0;
uniform float phase_offset : hint_range(0.0, 6.28318) = 0.0;

void vertex() {
	float bob_raw = sin(TIME * frequency + phase_offset);
	float bob = (bob_raw * 0.5 - 0.5) * amplitude;
	VERTEX.y += bob;
}
