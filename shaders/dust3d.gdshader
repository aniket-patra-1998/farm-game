shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded, cull_disabled, shadows_disabled;
// Soft puffs of dust and smoke (DustPuffs): camera-facing quads with a round soft edge. Each instance's colour is
// the puff's colour (alpha: how thick it starts) and INSTANCE_CUSTOM.x is its age from 0 (new) to 1 (gone): it
// swells a little and thins out as it ages.

varying vec4 puff;
varying float age;

void vertex() {
	puff = vec4(COLOR.rgb, COLOR.a);
	// Face the camera, keeping the instance's own size and place.
	mat4 face = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	face[0] *= s;
	face[1] *= s;
	face[2] *= s;
	MODELVIEW_MATRIX = VIEW_MATRIX * face;
	age = INSTANCE_CUSTOM.x;
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float soft = 1.0 - smoothstep(0.35, 1.0, r);
	ALBEDO = puff.rgb;
	ALPHA = soft * puff.a * (1.0 - age) * (1.0 - age);
}
