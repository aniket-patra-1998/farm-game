shader_type spatial;
render_mode cull_disabled;
// Crop plants, drawn for a whole field at once through MultiMeshes. Leaves carry their own green in the
// vertex colour; produce (vertex alpha 0) takes its crop's colour from the instance (INSTANCE_CUSTOM),
// shaded by the vertex colour. Plants sway from the root, tips most, harder in wind, each on its own beat.

global uniform float wind;  // the weather's wind, set once for everything (Farm3D)

varying vec4 produce;
varying float up;   // how far up the plant this point is, 0 at the soil

void vertex() {
	produce = INSTANCE_CUSTOM;
	up = clamp(VERTEX.y / 0.35, 0.0, 1.0);
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float beat = TIME * 1.9 + root.x * 1.3 + root.z * 0.9;
	float bend = VERTEX.y * VERTEX.y * 3.0 * (0.4 + wind);
	VERTEX.x += sin(beat) * 0.05 * bend;
	VERTEX.z += cos(beat * 0.7) * 0.035 * bend;
}

void fragment() {
	vec3 leaf = COLOR.rgb;
	vec3 fruit = produce.rgb * (0.55 + 0.6 * COLOR.r);
	float is_produce = 1.0 - step(0.5, COLOR.a);
	// Darker at the soil, sunlit at the tips: depth and form on a plant that is a few triangles.
	float lit = mix(0.72, 1.12, up);
	ALBEDO = mix(leaf, fruit, is_produce) * lit;
	RIM = 0.1;
	RIM_TINT = 0.9;
	ROUGHNESS = mix(0.85, 0.45, is_produce);
	SPECULAR = mix(0.1, 0.35, is_produce);
	BACKLIGHT = vec3(0.2, 0.3, 0.08) * (1.0 - is_produce);
}
