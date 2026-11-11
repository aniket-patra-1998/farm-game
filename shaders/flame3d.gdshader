shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
// A flame: bright at its foot, licking up and flickering, each tongue on its own beat (from where its
// vertices are), all in the vertex shader. Opaque: cheaper on phones than blending, and never painted over.

uniform vec3 colour : source_color = vec3(1.0, 0.55, 0.15);
uniform vec3 tip : source_color = vec3(1.0, 0.85, 0.35);
uniform float height = 0.25;       // the flame's height, for shading foot to tip

varying float up;

void vertex() {
	vec3 root = NODE_POSITION_WORLD;
	float beat = TIME * 9.0 + root.x * 7.0 + root.z * 5.0;
	up = clamp(VERTEX.y / height, 0.0, 1.0);
	float lick = up * up;
	VERTEX.y *= 1.0 + 0.22 * sin(beat) + 0.12 * sin(beat * 2.7 + 1.3);
	VERTEX.x += sin(beat * 0.8 + VERTEX.y * 18.0) * 0.03 * lick;
	VERTEX.z += cos(beat * 0.9 + VERTEX.y * 15.0) * 0.03 * lick;
	VERTEX.xz *= 1.0 - 0.35 * lick;
}

void fragment() {
	ALBEDO = mix(colour, tip, up) * 1.6;
}
