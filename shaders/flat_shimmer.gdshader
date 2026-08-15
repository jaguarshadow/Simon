shader_type canvas_item;

// Shared shimmer treatment for all 8 flat color palettes - ambient when idle,
// intensifying on top of the existing base/lit glow feedback when the pad is
// lit during sequence playback or pressed by the player.
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 lit_color : source_color = vec4(1.0);
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.6 + seed * 13.0;

	// Same glow-driven base/lit mix the pads already used - this shimmer
	// layers on top of it rather than replacing it.
	vec3 color = mix(base_color.rgb, lit_color.rgb, glow);

	// Idle: a slow, soft diagonal band of light drifting across the pad so it
	// feels quietly alive even at rest. Kept subtle (low peak, narrow pow()
	// falloff) so it never washes out the palette's own color on bright/
	// saturated pads - "quietly alive," not a glare sweep.
	float band = sin((uv.x + uv.y) * 2.4 - t) * 0.5 + 0.5;
	float idle_shimmer = pow(band, 5.0) * 0.12;

	// Lit / press: a brighter, faster sparkle layered on top while glowing,
	// restrained enough to read as texture on top of the existing base/lit
	// glow feedback rather than competing with it for attention.
	float sparkle = sin((uv.x - uv.y) * 10.0 + TIME * 5.0 + seed * 7.0) * 0.5 + 0.5;
	float active_shimmer = pow(sparkle, 3.0) * 0.22 * glow;

	color += vec3(idle_shimmer + active_shimmer);
	// Preserve the stylebox's own per-pixel alpha (COLOR.a) rather than the
	// uniform's flat alpha, so the tongue's rounded-corner shape stays intact.
	COLOR = vec4(color, COLOR.a);
}
