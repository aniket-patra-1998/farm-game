shader_type spatial;
render_mode cull_back, shadows_disabled;
// Drops thrown into the air and falling back (a fountain's jet and cascade, a fire's embers), moved wholly
// here: every drop is built at the spout and this places it along its arc from the time and its own data,
// so a whole fountain is one draw with no script. Per drop: UV = (phase 0..1, angle 0..1), UV2 = (reach
// 0..1, size 0..1). Opaque (cheaper than blending on phones, and nothing transparent can paint over it):
// a drop fades out by shrinking away at the end of its flight.

uniform vec3 colour : source_color = vec3(0.88, 0.96, 1.0);
uniform float glow = 0.0;          // emission (embers)
uniform float life = 1.2;          // seconds a drop flies
uniform float rise = 1.6;          // its upward speed at the spout (units/s; negative throws it down)
uniform float gravity = 3.2;       // (negative: it floats up, like an ember)
uniform float reach = 0.3;         // how far out it travels in its life
uniform float start_radius = 0.0;  // drops leave from a ring this wide (a basin's rim) instead of a point
uniform float size = 1.0;
uniform float sheen = 0.35;       // self-lit share, so water reads white even in shade

void vertex() {
	float u = fract(TIME / life + UV.x);
	float t = u * life;
	float a = UV.y * TAU;
	vec3 out_dir = vec3(cos(a), 0.0, sin(a));
	vec3 centre = out_dir * (start_radius + reach * (0.55 + 0.45 * UV2.x) * u)
		+ vec3(0.0, rise * t - 0.5 * gravity * t * t, 0.0);
	float s = size * (0.6 + 0.4 * UV2.y) * (1.0 - 0.5 * u) * (1.0 - smoothstep(0.8, 1.0, u));
	VERTEX = VERTEX * s + centre;
}

void fragment() {
	ALBEDO = colour;
	EMISSION = colour * (glow + sheen);
	ROUGHNESS = 0.1;
	SPECULAR = 0.8;
}
