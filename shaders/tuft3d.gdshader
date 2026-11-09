shader_type spatial;
render_mode cull_disabled;
// Grass tufts and wild flowers: blades coloured dark at the root to light at the tip (vertex colour),
// tinted per clump (the instance's custom colour), swaying in the wind with the tips moving most, each on
// its own beat. With flower_heads, vertices of alpha 0 are petals and take the instance's colour instead.

uniform float wind = 0.6;
uniform bool flower_heads = false;

varying vec4 tint;

void vertex() {
	tint = INSTANCE_CUSTOM;
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float beat = TIME * 1.7 + world.x * 0.9 + world.z * 0.7;
	float bend = VERTEX.y * VERTEX.y * 2.5 * wind;
	VERTEX.x += sin(beat) * 0.06 * bend;
	VERTEX.z += cos(beat * 0.8) * 0.04 * bend;
}

void fragment() {
	if (flower_heads) {
		ALBEDO = COLOR.a < 0.5 ? tint.rgb : COLOR.rgb;
	} else {
		ALBEDO = COLOR.rgb * tint.rgb;
	}
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
	// Light passing through blades keeps them from going black on their shaded side.
	BACKLIGHT = vec3(0.25, 0.35, 0.1);
}
