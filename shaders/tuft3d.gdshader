shader_type spatial;
render_mode cull_disabled;
// Grass tufts: blades coloured dark at the root to light at the tip (vertex colour), swaying in the wind
// with the tips moving most, each tuft on its own beat.

uniform float wind = 0.6;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float beat = TIME * 1.7 + world.x * 0.9 + world.z * 0.7;
	float bend = VERTEX.y * VERTEX.y * 2.5 * wind;
	VERTEX.x += sin(beat) * 0.06 * bend;
	VERTEX.z += cos(beat * 0.8) * 0.04 * bend;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
	// Light passing through blades keeps them from going black on their shaded side.
	BACKLIGHT = vec3(0.25, 0.35, 0.1);
}
