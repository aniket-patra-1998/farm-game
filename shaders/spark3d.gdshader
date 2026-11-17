shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
// A firework's spark (Fireworks3D: over a building that has just grown): a bright dot with a white heart and
// a soft glow in its colour, fading as it dies. Always facing the camera and drawn over what stands in front.
// One quad per spark in one MultiMesh; the instance's colour is the spark's, its custom red channel how much
// of its life it has lived (0..1) and its custom green channel its size in tiles.

varying float age;

void vertex() {
	age = INSTANCE_CUSTOM.r;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= INSTANCE_CUSTOM.g;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float heart = 1.0 - smoothstep(0.22, 0.42, d);
	float glow = 1.0 - smoothstep(0.3, 1.0, d);
	ALBEDO = mix(COLOR.rgb, vec3(1.0), heart * 0.85);
	ALPHA = max(heart, glow * 0.7) * (1.0 - age * age);
}
