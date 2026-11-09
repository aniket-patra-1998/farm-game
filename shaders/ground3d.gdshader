shader_type spatial;
render_mode cull_disabled;
// Grass seen from above: patches of lighter and darker green at a few scales, a soft tile checker on the
// farm (FarmVille's grid you could read without lines), and a sunlit warmth. All procedural, in world
// space, so it never stretches or repeats visibly.

uniform vec3 grass_light : source_color = vec3(0.56, 0.78, 0.30);
uniform vec3 grass_dark : source_color = vec3(0.33, 0.58, 0.20);
uniform vec3 dry : source_color = vec3(0.74, 0.74, 0.38);
uniform float checker = 0.035;  // how much alternate tiles differ; 0 for the meadow
uniform float dryness = 0.18;   // how much straw-coloured grass shows through

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
	float tile = mod(floor(p.x) + floor(p.y), 2.0);
	col *= 1.0 + checker * (tile - 0.5);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
