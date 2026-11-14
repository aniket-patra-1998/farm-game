shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
// FarmVille's "ready" sign: a golden sparkle over a building that has something to collect, bobbing gently and
// twinkling, always facing the camera and drawn over whatever stands in front, so it is seen across the farm.
// One quad per ready building in one MultiMesh (ReadyMarks); the instance's custom red channel is its phase.
// `zoom` grows it as the camera pulls back, so it stays the same size on screen until the far zoom.

uniform float zoom = 1.0;
uniform vec3 gold : source_color = vec3(1.0, 0.82, 0.25);

varying float glint;

void vertex() {
	float phase = INSTANCE_CUSTOM.r * 6.2831;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	glint = 0.5 + 0.5 * sin(TIME * 4.5 + phase);
	VERTEX *= zoom * (0.9 + 0.2 * glint);
	VERTEX.y += sin(TIME * 2.2 + phase) * 0.09 * zoom;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float core = 1.0 - smoothstep(0.08, 0.32, length(p));
	float rays = (1.0 - smoothstep(0.02, 0.1, abs(p.y))) * (1.0 - abs(p.x));
	rays += (1.0 - smoothstep(0.02, 0.1, abs(p.x))) * (1.0 - abs(p.y));
	vec2 q = vec2(p.x + p.y, p.x - p.y) * 0.7071;
	rays += 0.6 * (1.0 - smoothstep(0.01, 0.06, abs(q.y))) * max(1.0 - abs(q.x) * 1.6, 0.0);
	rays += 0.6 * (1.0 - smoothstep(0.01, 0.06, abs(q.x))) * max(1.0 - abs(q.y) * 1.6, 0.0);
	float halo = 0.45 * (1.0 - smoothstep(0.0, 0.85, length(p)));
	float a = clamp(core + rays + halo, 0.0, 1.0);
	ALBEDO = mix(gold, vec3(1.0, 0.98, 0.85), core * (0.4 + 0.3 * glint));
	ALPHA = a;
}
