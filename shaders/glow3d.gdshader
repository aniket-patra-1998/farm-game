shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// Warm light spilling from a lit window or door onto the ground: a soft pool that fades out toward its edge.
// One shared material; `strength` is set once a frame from the time of day (0 by day, 1 at night), so every
// lit building glows with no per-building script.

uniform float strength = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.72, 0.3);

void fragment() {
	float d = clamp(length(UV - vec2(0.5)) * 2.0, 0.0, 1.0);
	float a = pow(1.0 - d, 2.2) * strength;
	ALBEDO = tint * a;
	ALPHA = a;
}
