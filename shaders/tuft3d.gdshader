shader_type spatial;
render_mode cull_disabled;
// Grass tufts and wild flowers: blades coloured dark at the root to light at the tip (vertex colour), each
// tuft tinted by its clump (the MultiMesh's instance colour, which the engine multiplies into COLOR),
// swaying in the wind with the tips moving most, each on its own beat. With flower_heads, vertices of
// alpha 0 are petals and take the flower's colour (the instance's custom data) instead.

uniform float wind = 0.6;
uniform bool flower_heads = false;

varying vec4 petal;

void vertex() {
	petal = flower_heads ? INSTANCE_CUSTOM : vec4(1.0);
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float beat = TIME * 1.7 + world.x * 0.9 + world.z * 0.7;
	float bend = VERTEX.y * VERTEX.y * 2.5 * wind;
	VERTEX.x += sin(beat) * 0.06 * bend;
	VERTEX.z += cos(beat * 0.8) * 0.04 * bend;
}

void fragment() {
	ALBEDO = (flower_heads && COLOR.a < 0.5) ? petal.rgb : COLOR.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
	// Light passing through blades keeps them from going black on their shaded side.
	BACKLIGHT = vec3(0.25, 0.35, 0.1);
}
