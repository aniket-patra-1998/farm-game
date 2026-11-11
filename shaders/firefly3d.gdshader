shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// Fireflies at night: tiny glowing points drifting low over the grass, each blinking on its own beat, moved from
// the time (one mesh, one draw, no script). Per vertex: UV = (phase, 0), UV2 = (home x, home z). Dark by day.

global uniform float dark;

void vertex() {
	float phase = UV.x;
	float t = TIME * (0.25 + phase * 0.2) + phase * 50.0;
	vec3 centre = vec3(UV2.x + sin(t * 0.8) * 0.9 + sin(t * 2.3) * 0.15, 0.3 + 0.35 * (0.5 + 0.5 * sin(t * 0.6 + phase * 9.0)),
		UV2.y + cos(t * 0.65) * 0.9 + cos(t * 2.1) * 0.15);
	VERTEX = centre + VERTEX;
}

void fragment() {
	float blink = pow(0.5 + 0.5 * sin(TIME * 1.7 + UV.x * 60.0), 3.0);
	float a = blink * smoothstep(0.35, 0.8, dark);
	ALBEDO = vec3(0.85, 1.0, 0.35) * a * 2.2;
	ALPHA = a;
}
