shader_type canvas_item;

uniform float speed : hint_range(0.0, 2.0) = 1.0;
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

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed + seed * 29.0;

	// Phosphor base color cycles slowly through the classic arcade trio -
	// green, cyan, amber - per pad (offset by seed) so a row of pads doesn't
	// all pulse in lockstep.
	float hue_cycle = fract(t * 0.05 + seed * 0.37);
	vec3 phosphor_green = vec3(0.2, 1.0, 0.3);
	vec3 phosphor_cyan = vec3(0.2, 0.9, 1.0);
	vec3 phosphor_amber = vec3(1.0, 0.7, 0.15);
	vec3 phosphor = mix(phosphor_green, phosphor_cyan, smoothstep(0.0, 0.33, hue_cycle) * (1.0 - smoothstep(0.33, 0.66, hue_cycle)));
	phosphor = mix(phosphor, phosphor_amber, smoothstep(0.66, 1.0, hue_cycle));
	phosphor = mix(phosphor, phosphor_green, step(hue_cycle, 0.001));

	// Faint vertical scroll of blocky "pixel" noise, like a CRT signal that
	// never quite sits still.
	vec2 block_uv = floor(uv * vec2(8.0, 24.0) + vec2(0.0, t * 6.0));
	float pixel_noise = hash(block_uv + seed * 13.0);
	float static_amount = 0.05 + 0.05 * sin(t * 3.0 + seed * 5.0);

	vec3 color = vec3(0.01, 0.02, 0.015);
	color += phosphor * (0.35 + pixel_noise * static_amount);

	// Horizontal scanlines - dark bands cut into the phosphor glow, scrolling
	// slowly downward like an interlaced display.
	float scan = sin((uv.y * 60.0) - t * 4.0) * 0.5 + 0.5;
	float scanline = mix(0.55, 1.0, pow(scan, 3.0));
	color *= scanline;

	// Occasional bright horizontal glitch tear.
	float glitch_row = step(0.985, hash(vec2(floor(t * 9.0), seed + 7.0)));
	float glitch_band = step(0.92, fract(uv.y * 3.0 + hash(vec2(floor(t * 9.0), seed)) * 5.0));
	color += phosphor * glitch_row * glitch_band * 0.6;

	// Soft vignette so the edges read as a curved tube rather than a flat
	// rectangle of static.
	vec2 centered = uv - 0.5;
	float vignette = 1.0 - dot(centered, centered) * 0.9;
	color *= vignette;

	float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float rim = 1.0 - smoothstep(0.0, 0.05, edge_dist);
	color = mix(color, phosphor, rim * rim_strength);

	color += phosphor * glow * 0.9;
	color *= dim;
	COLOR = vec4(color, COLOR.a);
}
