// Emissive glow for any CanvasItem. It works on three fronts, each independently
// dialled, so one shader covers both solid art (a thruster plume, a flame) and
// nearly-transparent art (an indicator lens that only reads as lit once it fills in):
//
//   emission_energy   drives the node's own pixels past full brightness, per channel.
//   emission_opacity  floods the node's emissive area with glow_color, for art too
//                     faint to have anything worth driving.
//   halo_radius       spills a soft halo into the transparent margin around the node.
//
// At glow_intensity 0 the node draws exactly as it would with no material at all, so
// a script can tween the whole effect on and off (or pulse it) without the node ever
// looking "shaded" while idle.
//
// The halo is a dilation of the texture's own alpha, so it can only reach into padding
// that already exists inside the texture -- or, for an AnimatedSprite2D, inside the
// atlas frame. Art drawn edge to edge has nowhere to put one: leave halo_radius at 0
// there and let the emission carry the glow.
shader_type canvas_item;

// Directions sampled per ring, and rings sampled out to halo_radius, when building
// the halo. Eight taps over three rings is smooth enough for the small radii this is
// used at without turning into a full blur.
const int HALO_TAPS = 8;
const int HALO_RINGS = 3;

// Master switch for every glow material at once, driven by the Bloom video option
// (AppRoot.set_bloom_enabled). 0 takes the node back to drawing exactly as it would
// with no material at all.
global uniform float bloom_strength;
// Per-material strength. Tween this to flash, fade, or switch the glow off entirely.
uniform float glow_intensity : hint_range(0.0, 1.0) = 1.0;
// Color of the light this node gives off, driving the emission flood and the halo.
// The node's own pixels emit in their own colors, not this one.
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// How much light the node's own pixels give off. 0 leaves them untouched; 1 doubles
// their brightness; past ~2 they blow out toward white.
uniform float emission_energy : hint_range(0.0, 4.0) = 1.0;
// Brightness a channel must already carry before it emits at all. High (~0.9) keeps
// the sprite looking exactly as drawn and only drives channels that were at full
// scale anyway; low turns emission into a deliberate blow-out flash.
uniform float emission_knee : hint_range(0.0, 1.0) = 0.9;
// Opacity the glow lends the node's emissive area -- every pixel carrying color, as
// opposed to the black linework and the transparent surround, both of which stay put.
// Art that is barely there when unlit needs this to read as lit; solid art leaves it at 0.
uniform float emission_opacity : hint_range(0.0, 1.0) = 0.0;
// Reach of the halo around the silhouette, in texture pixels. 0 = no halo.
uniform float halo_radius : hint_range(0.0, 32.0) = 0.0;
// Opacity of the halo where it meets the silhouette.
uniform float halo_energy : hint_range(0.0, 4.0) = 1.0;
// How sharply the halo fades over halo_radius. 1 = linear, higher = tighter.
uniform float halo_falloff : hint_range(0.5, 8.0) = 2.0;
// Set this on a node that tiles its texture (a Line2D beam): halo taps wrap at the
// texture edges rather than stopping there, so the glow follows the whole tiled run.
// The node itself must have texture repeat enabled or the taps clamp instead.
uniform bool halo_tiles = false;
// Breathing rate in cycles per second. 0 = a steady glow.
uniform float pulse_speed : hint_range(0.0, 10.0) = 0.0;
// How far the pulse dips below full strength (0.5 = down to half and back).
uniform float pulse_depth : hint_range(0.0, 1.0) = 0.0;

// The node's modulate chain, which fragment's COLOR already folds in but which the
// glow layer needs separately so it fades with the node.
varying vec4 modulation;

void vertex() {
	modulation = COLOR;
}

void fragment() {
	// cos-based so pulse_speed 0 parks the pulse at full strength rather than holding
	// it at the bottom of the dip.
	float pulse = 1.0 - pulse_depth * 0.5 * (1.0 - cos(TIME * pulse_speed * TAU));
	float amount = glow_intensity * pulse * bloom_strength;
	vec4 tex = texture(TEXTURE, UV);
	vec4 base = tex * modulation;

	// Per channel, and only from emission_knee upward. A channel already at full scale
	// is driven past 1.0 where the bloom pass can see it while the display clamps it
	// back to where it was; a channel below the knee is left exactly where the artist
	// put it. Driving whole pixels instead is what flattens a blue-white plume or an
	// orange flame into a white blob -- the channels that were not at full scale clip
	// along with the ones that were, taking the hue and the falloff with them.
	vec3 emissive_ramp = smoothstep(vec3(emission_knee), vec3(1.0), base.rgb)
		* emission_energy * amount;
	vec3 lit = base.rgb * (1.0 + emissive_ramp);

	// Emissive area = pixels that carry color once alpha is divided back out, which
	// picks out a lens (colored, whatever its opacity) from the linework around it
	// (black) and the surround (empty) under either alpha convention.
	vec3 unpremultiplied = tex.rgb / max(tex.a, 0.001);
	float emissive_mask = clamp(max(max(unpremultiplied.r, unpremultiplied.g), unpremultiplied.b), 0.0, 1.0)
		* step(0.003, tex.a);
	float flood_alpha = emission_opacity * emissive_mask;
	float halo_alpha = 0.0;

	// Distance-weighted dilation of the silhouette: each ring of taps counts for less
	// the further out it sits, which fades the halo over halo_radius. The (1 - alpha)
	// factor keeps it outside the sprite instead of washing the sprite out.
	if (halo_radius > 0.0 && halo_energy > 0.0) {
		float halo = 0.0;
		for (int ring = 0; ring < HALO_RINGS; ring++) {
			float distance_ratio = (float(ring) + 0.5) / float(HALO_RINGS);
			vec2 offset = TEXTURE_PIXEL_SIZE * halo_radius * distance_ratio;
			float reach = 0.0;
			for (int tap = 0; tap < HALO_TAPS; tap++) {
				float angle = TAU * (float(tap) + distance_ratio) / float(HALO_TAPS);
				vec2 tap_uv = UV + vec2(cos(angle), sin(angle)) * offset;
				// Off a non-tiling node, anything outside the drawn rect counts as empty,
				// so the halo never smears the edge row -- or a neighbouring atlas frame
				// -- outward.
				bool off_sprite = !halo_tiles
					&& any(notEqual(clamp(tap_uv, vec2(0.0), vec2(1.0)), tap_uv));
				reach = max(reach, off_sprite ? 0.0 : texture(TEXTURE, tap_uv).a);
			}
			halo = max(halo, reach * pow(1.0 - distance_ratio, halo_falloff));
		}
		halo_alpha = halo * (1.0 - tex.a) * halo_energy;
	}
	float glow_alpha = clamp(max(flood_alpha, halo_alpha) * amount * glow_color.a * modulation.a,
		0.0, 1.0);

	// The emitted light is a straight-alpha layer of glow_color lying under the node:
	// it fills in wherever the node itself is thin or absent and leaves solid pixels
	// (linework, opaque art) to the emission above.
	//
	// Only the flood carries the overdrive, so a lit indicator lens crosses the bloom
	// threshold instead of parking exactly on it. The halo deliberately does not: it is
	// atmosphere, and driving it past 1.0 turns a soft falloff into a hard clipped rim.
	float flood_share = flood_alpha / max(flood_alpha + halo_alpha, 0.0001);
	vec3 emitted = glow_color.rgb * mix(1.0, 1.0 + emission_energy * amount, flood_share);
	float glow_share = (1.0 - base.a) * glow_alpha;
	float out_alpha = base.a + glow_share;
	COLOR = vec4(mix(lit, emitted, glow_share / max(out_alpha, 0.0001)), out_alpha);
}
