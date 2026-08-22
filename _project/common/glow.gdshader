// Emission for any CanvasItem: drives the node's brightest channels past 1.0 so the
// viewport's bloom pass has something to pick up. The bleed itself is entirely the
// bloom's -- this shader never draws outside the node, it only decides what is bright
// enough to bleed.
//
// At glow_intensity 0, or with the Bloom option off, the node draws exactly as it would
// with no material at all.
shader_type canvas_item;

// Master switch for every glow material at once, driven by the Bloom video option
// (AppRoot.set_bloom_enabled). 0 takes every node back to drawing untouched.
global uniform float bloom_strength;
// Per-material strength. Tween this to flash, fade, or switch the glow off entirely.
uniform float glow_intensity : hint_range(0.0, 1.0) = 1.0;
// Tint on the light the node gives off, multiplied into the emission after the sprite's
// own channels have decided how much there is. White leaves the glow the colour of the
// art; pulling a channel down biases which way the bloom leans without touching how the
// sprite itself draws. It cannot add a colour the art has none of -- it only shapes what
// is already emitting.
uniform vec3 glow_color : source_color = vec3(1.0, 1.0, 1.0);
// How far past full brightness an emitting channel is driven. The display clamps it
// back, so this reads purely as how hard the pixel blooms.
uniform float emission_energy : hint_range(0.0, 4.0) = 1.0;
// Brightness a channel must already carry before it emits at all. High (~0.9) keeps the
// sprite looking exactly as drawn and only drives channels that were at full scale
// anyway; low turns emission into a deliberate blow-out flash.
uniform float emission_knee : hint_range(0.0, 1.0) = 0.9;
// Breathing rate in cycles per second. 0 = a steady glow.
uniform float pulse_speed : hint_range(0.0, 10.0) = 0.0;
// How far the pulse dips below full strength (0.5 = down to half and back).
uniform float pulse_depth : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// cos-based so pulse_speed 0 parks the pulse at full strength rather than holding it
	// at the bottom of the dip.
	float pulse = 1.0 - pulse_depth * 0.5 * (1.0 - cos(TIME * pulse_speed * TAU));
	float amount = glow_intensity * pulse * bloom_strength;

	// Per channel, and only from emission_knee upward. A channel already at full scale is
	// driven past 1.0 where the bloom pass can see it while the display clamps it back to
	// where it was; a channel below the knee is left exactly where the artist put it.
	// Driving whole pixels instead is what flattens a blue-white plume or an orange flame
	// into a white blob -- the channels that were not at full scale clip along with the
	// ones that were, taking the hue and the falloff with them.
	//
	// COLOR arrives as the texture already multiplied by the node's modulate chain, so a
	// flame tinted orange per-instance emits orange without being told.
	vec3 emissive_ramp = smoothstep(vec3(emission_knee), vec3(1.0), COLOR.rgb)
		* emission_energy * amount;
	COLOR.rgb += COLOR.rgb * emissive_ramp * glow_color;
}
