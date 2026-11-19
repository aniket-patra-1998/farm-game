// Soft shadows of passing clouds (docs/WOW_RUN.md item 5): big round patches of shade drifting across
// everything that lies in the sun (the ground, crops and every model), in world space so one cloud shades
// the grass, the crops and the barn alike. A few sines, no texture or noise: cheap on a phone. `cloud_shade`
// is how deep the shade goes (0: none, and the shader does no work for it), set by main from the weather and
// Quality `cloud_shadows`; the time is the shaders' own, so nothing runs per frame for it.

global uniform float cloud_shade;

const vec2 CLOUD_DRIFT = vec2(0.32, 0.12);   // world units a second, with the wind across the farm
const float CLOUD_SCALE = 0.16;              // 1 / a patch's size (world units): about 6 tiles across

// How much light reaches `xz` (1: full sun, down to 1 - cloud_shade under a cloud's middle).
float cloud_light(vec2 xz, float t) {
	if (cloud_shade <= 0.001) {
		return 1.0;
	}
	vec2 q = (xz - CLOUD_DRIFT * t) * CLOUD_SCALE;
	// Two rotated, warped sine fields: round, uneven patches with clear sky between, never a grid.
	float a = sin(q.x + 1.3 * sin(q.y * 0.71 + 0.4)) * sin(q.y * 0.87 + 1.1 * sin(q.x * 0.63 + 1.7));
	vec2 r = vec2(q.x * 0.8 - q.y * 0.6, q.x * 0.6 + q.y * 0.8) * 0.57 + 3.1;
	float b = sin(r.x + 0.9 * sin(r.y * 1.3)) * sin(r.y + 0.8 * sin(r.x * 1.1 + 2.0));
	float c = smoothstep(0.18, 0.62, 0.65 * a + 0.45 * b);
	return 1.0 - cloud_shade * c;
}
