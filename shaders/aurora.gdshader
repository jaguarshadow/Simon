shader_type canvas_item;

uniform float speed : hint_range(0.0, 2.0) = 0.12;
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

float star_layer(vec2 uv, float scale, float density, float twinkle_speed, float t) {
	vec2 grid_uv = uv * scale;
	vec2 cell = floor(grid_uv);
	vec2 local = fract(grid_uv) - 0.5;
	float is_star = step(1.0 - density, hash(cell));
	vec2 jitter = vec2(hash(cell + 1.1), hash(cell + 2.2)) - 0.5;
	float d = length(local - jitter * 0.7);
	float brightness = hash(cell + 3.7);
	float twinkle = 0.6 + 0.4 * sin(t * twinkle_speed + hash(cell) * 6.28);
	float radius = mix(0.05, 0.16, brightness);
	float dot = smoothstep(radius, 0.0, d);
	return is_star * dot * brightness * twinkle;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed + seed * 23.0;

	vec3 color = vec3(0.008, 0.012, 0.03);
	color += vec3(0.85, 0.92, 1.0) * star_layer(uv + seed * 4.0, 13.0, 0.05, 2.0, TIME);

	// Domain-warped coordinate so the curtain folds organically instead of
	// tracing a clean sine wave - the same trick the galaxy shader uses for
	// swirling clouds, applied here to bend where the rays sit horizontally.
	float warp = fbm(vec2(uv.x * 3.0, uv.y * 1.2 + t) * 1.4) - 0.5;
	float ray_x = uv.x + warp * 0.6;

	// Fine vertical striation: many thin curtain folds instead of one solid
	// band, with turbulence along y for the shimmering drift.
	float striation = fbm(vec2(ray_x * 9.0, uv.y * 2.2 - t * 1.6));
	float rays = pow(striation, 2.3);

	// Secondary, fainter ray layer offset in time/space for parallax depth.
	float striation2 = fbm(vec2((ray_x + 0.17) * 6.5 - t * 0.35, uv.y * 1.8 + t * 0.6));
	float rays2 = pow(striation2, 2.6);

	// Curtains fade in/out toward the tongue's ends rather than filling it
	// edge-to-edge, so they feel like they drift through frame.
	float edge_fade = smoothstep(0.0, 0.2, uv.y) * smoothstep(1.0, 0.65, uv.y);

	// Real aurora shifts color along its height: green low, teal/violet high.
	vec3 green = vec3(0.15, 0.95, 0.5);
	vec3 teal = vec3(0.1, 0.8, 0.75);
	vec3 pink = vec3(0.75, 0.35, 0.85);
	vec3 aurora_color = mix(green, teal, smoothstep(0.0, 0.6, uv.y));
	aurora_color = mix(aurora_color, pink, smoothstep(0.6, 1.0, uv.y));

	color += aurora_color * rays * edge_fade * 1.3;
	color += teal * rays2 * edge_fade * 0.55;

	// Bright rim near the pad's silhouette so it stays readable against a
	// busy or similarly-dark background. Backgrounds using this same shader
	// set rim_strength to 0 to disable it.
	float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float rim = 1.0 - smoothstep(0.0, 0.05, edge_dist);
	color = mix(color, vec3(0.9, 0.95, 1.0), rim * rim_strength);

	color += vec3(0.6, 0.9, 0.8) * glow * 0.6;
	// Backdrop use dims this well below pad intensity so a matching pad skin
	// still reads as distinct foreground against it.
	color *= dim;
	COLOR = vec4(color, COLOR.a);
}
