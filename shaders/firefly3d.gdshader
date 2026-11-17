shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;
// Fireflies over a pond at night (PondLife): small warm lights that drift and blink, each on its own beat,
// and are not there by day. One quad per firefly in one MultiMesh; the instance's custom red channel is its
// beat (0..1). It moves and blinks from the time alone.

global uniform float dark;      // 0..1: how far into the night it is
uniform vec3 glow : source_color = vec3(1.0, 0.92, 0.45);
uniform float drift = 0.12;     // tiles it wanders either way
varying float beat;

void vertex() {
	beat = INSTANCE_CUSTOM.r;
	float t = TIME * 0.5 + beat * 37.0;
	vec3 wander = vec3(sin(t * 1.3 + beat * 9.0), sin(t * 0.9) * 0.5, cos(t * 1.1 + beat * 5.0)) * drift;
	mat4 at = MODEL_MATRIX;
	at[3].xyz += wander;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], at[3]);
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float blink = smoothstep(0.2, 0.9, sin(TIME * 1.7 + beat * 40.0));
	ALBEDO = glow;
	ALPHA = (1.0 - smoothstep(0.1, 1.0, d)) * blink * smoothstep(0.35, 0.8, dark);
}
