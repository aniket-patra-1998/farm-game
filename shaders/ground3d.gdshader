shader_type spatial;
render_mode cull_disabled;
// Grass seen from above: patches of lighter and darker green at a few scales, a soft tile checker on the
// farm (FarmVille's grid you could read without lines), and a sunlit warmth. All procedural, in world
// space, so it never stretches or repeats visibly.

uniform vec3 grass_light : source_color = vec3(0.50, 0.70, 0.27);
uniform vec3 grass_dark : source_color = vec3(0.28, 0.49, 0.18);
uniform vec3 dry : source_color = vec3(0.74, 0.74, 0.38);
uniform float checker = 0.035;  // how much alternate tiles differ; 0 for the meadow
uniform float dryness = 0.18;   // how much straw-coloured grass shows through
// The farm lawn (farm_n > 0, in tiles): mown in bands, with a lip of bare earth along its edge, so the farm
// reads as a place cut out of the countryside.
uniform float farm_n = 0.0;
uniform vec3 verge : source_color = vec3(0.50, 0.37, 0.22);
uniform float mow = 0.09;       // how much alternate bands differ
uniform float patchy = 0.0;     // the meadow: how strongly patches of lush and thin grass differ
// What stands on the farm (Ground3D): R darkens the grass round things that block the sky, G wears it to
// trodden straw and earth. shade_rect is the map's corner and size in tiles.
uniform sampler2D shade_map : filter_linear, repeat_disable;
uniform vec4 shade_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 worn : source_color = vec3(0.62, 0.58, 0.36);
uniform float shade_strength = 0.42;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float broad = fbm(p * 0.18);
	float fine = noise(p * 3.1) * 0.5 + noise(p * 7.3) * 0.5;
	vec3 col = mix(grass_dark, grass_light, smoothstep(0.25, 0.75, broad));
	col = mix(col, dry, dryness * smoothstep(0.55, 0.85, fbm(p * 0.37 + 11.0)));
	col *= 0.92 + 0.16 * fine;
	col *= 1.0 + patchy * (fbm(p * 0.09 + 31.0) - 0.5);
	if (farm_n > 0.0) {
		col *= 1.0 + mow * (step(0.5, fract((p.x + p.y) * 0.25)) - 0.5);
		float d = min(min(p.x, p.y), min(farm_n - p.x, farm_n - p.y));
		float lip = smoothstep(0.55, 0.2, d + (fine - 0.5) * 0.14);
		col = mix(col, verge * (0.88 + 0.24 * fine), lip * 0.9);
	}
	float tile = mod(floor(p.x) + floor(p.y), 2.0);
	col *= 1.0 + checker * (tile - 0.5);
	vec2 suv = (p - shade_rect.xy) / shade_rect.zw;
	if (suv.x > 0.0 && suv.y > 0.0 && suv.x < 1.0 && suv.y < 1.0) {
		vec2 sw = texture(shade_map, suv).rg;
		// Wear comes in ragged, so it reads as trodden ground and not a painted stain.
		float ragged = smoothstep(0.2, 0.8, sw.g * (0.6 + 0.8 * fbm(p * 1.7 + 3.0)));
		col = mix(col, worn * (0.9 + 0.2 * fine), ragged * 0.75);
		col *= 1.0 - shade_strength * sw.r;
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
