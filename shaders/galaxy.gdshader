shader_type canvas_item;

uniform float speed : hint_range(0.0, 2.0) = 0.08;
uniform float seed = 0.0;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.65;
uniform float dim : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Fractal Brownian motion: stack octaves of noise at shrinking scale/strength
// so it reads as organic cloud detail instead of one smooth blob.
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

// A handful of round, soft-edged points per grid cell (most cells empty),
// jittered off the grid so they don't look tiled, varying in size/brightness
// and twinkling over time.
float star_layer(vec2 uv, float scale, float density, float twinkle_speed, float t) {
	vec2 grid_uv = uv * scale;
	vec2 cell = floor(grid_uv);
	vec2 local = fract(grid_uv) - 0.5;
	float is_star = step(1.0 - density, hash(cell));
	vec2 jitter = vec2(hash(cell + 1.1), hash(cell + 2.2)) - 0.5;
	float d = length(local - jitter * 0.7);
	float brightness = hash(cell + 3.7);
	float twinkle = 0.6 + 0.4 * sin(t * twinkle_speed + hash(cell) * 6.28);
	float radius = mix(0.06, 0.22, brightness);
	float dot = smoothstep(radius, 0.0, d);
	return is_star * dot * brightness * twinkle;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	// Large per-pad offset so each pad samples a distinct patch of the noise
	// field instead of all pads showing the same swirl.
	vec2 p = uv * 1.6 + seed * 37.0;

	// Domain-warped fbm: feed noise back into itself as a coordinate offset,
	// which is what turns flat noise into folding, swirling cloud shapes.
	vec2 q = vec2(fbm(p + t), fbm(p + vec2(5.2, 1.3) - t * 0.7));
	vec2 r = vec2(fbm(p + 2.5 * q + vec2(1.7, 9.2) + t * 0.6), fbm(p + 2.5 * q + vec2(8.3, 2.8) - t * 0.5));
	float n1 = fbm(p + 2.0 * r);
	float n2 = fbm(p * 1.3 - seed * 11.0 + 1.5 * q - t * 0.4);

	// Deep, mostly-empty space as the base - color only builds up where the
	// warped noise is actually strong, so most of the pad stays dark.
	vec3 color = vec3(0.015, 0.01, 0.04);
	float wisp1 = smoothstep(0.5, 0.95, n1);
	float wisp2 = smoothstep(0.55, 0.95, n2);
	color += vec3(0.55, 0.2, 0.65) * wisp1 * 0.9;
	color += vec3(0.15, 0.35, 0.7) * wisp2 * 0.7;
	color += vec3(0.8, 0.35, 0.6) * pow(wisp1 * wisp2, 1.5) * 0.6;

	color += vec3(1.0, 0.97, 0.9) * star_layer(uv + seed * 5.0, 9.0, 0.10, 2.4, TIME);
	color += vec3(0.75, 0.85, 1.0) * star_layer(uv - seed * 3.0, 16.0, 0.06, 3.6, TIME) * 0.85;

	// Bright rim near the pad's silhouette so it stays readable against a
	// busy or similarly-dark background. Backgrounds using this same shader
	// (e.g. the Cosmic theme's backdrop) set rim_strength to 0 to disable it.
	float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float rim = 1.0 - smoothstep(0.0, 0.05, edge_dist);
	color = mix(color, vec3(0.9, 0.9, 1.0), rim * rim_strength);

	color += vec3(0.7, 0.5, 1.0) * glow * 0.7;
	// Backdrop use (e.g. the Cosmic theme's background) dims this well below
	// pad intensity so a matching pad skin still reads as distinct foreground
	// against it, instead of blending into an equally-bright twin.
	color *= dim;
	COLOR = vec4(color, COLOR.a);
}
