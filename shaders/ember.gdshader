shader_type canvas_item;

uniform float speed : hint_range(0.0, 2.0) = 0.5;
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

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

// A handful of small bright points that drift upward and fade, like embers
// lifting off a fire - jittered off-grid so they don't look tiled.
float ember_layer(vec2 uv, float scale, float density, float t) {
	vec2 rise_uv = uv + vec2(0.0, t * 0.35);
	vec2 grid_uv = rise_uv * scale;
	vec2 cell = floor(grid_uv);
	vec2 local = fract(grid_uv) - 0.5;
	float is_ember = step(1.0 - density, hash(cell));
	vec2 jitter = vec2(hash(cell + 1.1), hash(cell + 2.2)) - 0.5;
	// Drift sideways with a slow sine sway instead of a straight line.
	jitter.x += sin(t * 1.5 + hash(cell) * 6.28) * 0.25;
	float d = length(local - jitter * 0.8);
	float brightness = hash(cell + 3.7);
	float radius = mix(0.05, 0.14, brightness);
	float dot = smoothstep(radius, 0.0, d);
	// Fade out near the top of each rise cycle so embers look like they burn
	// out rather than looping visibly.
	float cycle = fract(rise_uv.y * scale / 1.0);
	float fade = smoothstep(1.0, 0.55, cycle);
	return is_ember * dot * brightness * fade;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed + seed * 19.0;

	// Flame turbulence rises (negative y over time) and warps as it goes, the
	// same domain-warped fbm trick as the galaxy/aurora skins but biased
	// vertically so it reads as licking flame instead of drifting cloud.
	vec2 p = uv * vec2(2.2, 1.4) + seed * 41.0;
	vec2 rise = vec2(0.0, -t * 0.6);
	vec2 q = vec2(fbm(p + rise), fbm(p + vec2(3.1, 1.7) + rise * 0.8));
	float flame = fbm(p + rise * 1.3 + 2.2 * q);

	// Heat gradient: near-black base, through deep red, to orange/gold at the
	// hottest (highest-noise) points - hotter also biased toward the pad's
	// base (uv.y near 1) like a real flame's roots.
	float heat = smoothstep(0.15, 0.85, flame) * mix(1.0, 0.4, uv.y);
	vec3 color = vec3(0.03, 0.005, 0.0);
	color = mix(color, vec3(0.55, 0.05, 0.02), smoothstep(0.0, 0.5, heat));
	color = mix(color, vec3(0.95, 0.35, 0.05), smoothstep(0.4, 0.85, heat));
	color = mix(color, vec3(1.0, 0.85, 0.35), smoothstep(0.8, 1.0, heat));

	color += vec3(1.0, 0.7, 0.3) * ember_layer(uv + seed * 3.0, 7.0, 0.12, TIME * speed);
	color += vec3(1.0, 0.5, 0.15) * ember_layer(uv - seed * 2.0, 11.0, 0.08, TIME * speed * 1.3) * 0.8;

	float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float rim = 1.0 - smoothstep(0.0, 0.05, edge_dist);
	color = mix(color, vec3(1.0, 0.85, 0.6), rim * rim_strength);

	color += vec3(1.0, 0.6, 0.2) * glow * 0.8;
	color *= dim;
	COLOR = vec4(color, COLOR.a);
}
