shader_type spatial;
render_mode cull_disabled;
// Plowed soil: dark furrows and lighter ridges running along each bed, crumbs and clods, damp where
// fertilized (the instance colour's alpha). The bed's sides (facing sideways) are a darker earth.

uniform vec3 earth : source_color = vec3(0.45, 0.30, 0.18);
uniform vec3 ridge : source_color = vec3(0.60, 0.43, 0.27);
uniform float furrows = 3.0;   // ridges per bed

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 tint;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tint = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 p = world_pos.xz;
	float across = fract(p.x) * furrows;
	float ridge_shape = 0.5 + 0.5 * cos(across * 6.2831853);
	float crumbs = noise(p * 26.0) * 0.6 + noise(p * 61.0) * 0.4;
	vec3 col = mix(earth * 0.72, ridge, ridge_shape * 0.85);
	col *= 0.85 + 0.3 * crumbs;
	float side = 1.0 - smoothstep(0.55, 0.85, world_normal.y);
	col = mix(col, earth * 0.62, side);
	float wet = tint.a;
	col = mix(col, col * vec3(0.72, 0.68, 0.7), wet);
	ALBEDO = col;
	ROUGHNESS = mix(1.0, 0.6, wet);
	SPECULAR = 0.2;
}
