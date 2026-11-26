shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// The soft light round a building's gold star (CrownStars): a disc that always faces the camera, faint by day
// and warm after dark, rising and falling with its star (the same beat: the instance's custom red channel) and
// breathing slowly. One MultiMesh: one draw for every halo on the farm.

uniform vec3 tint : source_color = vec3(1.0, 0.8, 0.42);
uniform float by_day = 0.1;        // how strong it is at noon..
uniform float by_night = 0.5;      // ..and in full night
uniform float bob = 0.14;          // (as the star's: crown_star3d)
uniform float bob_rate = 1.3;

global uniform float dark;         // 0..1: how far into the night it is

varying float phase;

void vertex() {
	phase = INSTANCE_CUSTOM.x * TAU;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 centre = MODEL_MATRIX[3].xyz + vec3(0.0, sin(TIME * bob_rate + phase) * bob * size, 0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size,
		INV_VIEW_MATRIX[2] * size, vec4(centre, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float d = clamp(length(UV - vec2(0.5)) * 2.0, 0.0, 1.0);
	float a = pow(1.0 - d, 2.4) * mix(by_day, by_night, dark) * (0.85 + 0.15 * sin(TIME * 1.7 + phase));
	ALBEDO = tint * a;
	ALPHA = a;
}
