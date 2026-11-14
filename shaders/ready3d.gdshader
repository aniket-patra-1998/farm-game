shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
// The one "ready" sign for everything with something to collect (buildings, animals, trees, blooms), as
// FarmVille drew it: a soft, light pink triangle pointing down, its corners rounded, hovering over the thing
// and bobbing gently up and down. Always facing the camera and drawn over what stands in front. One quad per
// ready thing in one MultiMesh (ReadyMarks); the instance's custom red channel is its phase, so they don't
// bob in step. `zoom` grows it as the camera pulls back, so it stays the same size on screen.

uniform float zoom = 1.0;
uniform vec3 face : source_color = vec3(1.0, 0.75, 0.86);
uniform vec3 light : source_color = vec3(1.0, 0.91, 0.95);
uniform vec3 rim : source_color = vec3(0.95, 0.58, 0.74);
uniform float bob = 0.04;      // tiles it rises and falls
uniform float rate = 2.2;      // how fast

// Signed distance to an equilateral triangle of circumradius-ish size r pointing up (Inigo Quilez's).
float tri(vec2 p, float r) {
	const float k = 1.7320508;
	p.x = abs(p.x) - r;
	p.y = p.y + r / k;
	if (p.x + k * p.y > 0.0) {
		p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
	}
	p.x -= clamp(p.x, -2.0 * r, 0.0);
	return -length(p) * sign(p.y);
}

void vertex() {
	float phase = INSTANCE_CUSTOM.r * 6.2831;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= zoom;
	VERTEX.y += sin(TIME * rate + phase) * bob * zoom;
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, UV.y * 2.0 - 1.0);   // y down: the triangle points down
	p.y -= 0.12;                                          // (its weight sits a little high in the quad)
	float d = tri(p, 0.5) - 0.22;                         // well-rounded corners: soft, not sharp
	float edge = fwidth(d) * 1.2;
	float body = 1.0 - smoothstep(-edge, edge, d);
	float halo = (1.0 - smoothstep(0.0, 0.16, d)) * 0.28;  // a faint white glow, so it reads on dark ground
	float inner = smoothstep(-0.1, -0.02, d);             // a thin deeper pink line round the rim
	vec3 col = mix(light, face, clamp(UV.y * 1.2, 0.0, 1.0));
	col = mix(col, rim, inner * 0.8);
	float gloss = 1.0 - smoothstep(0.0, 0.16, length((p - vec2(-0.18, -0.28)) * vec2(1.0, 1.9)));
	col = mix(col, vec3(1.0), gloss * 0.6);
	ALBEDO = mix(vec3(1.0), col, body);
	ALPHA = max(body * 0.95, halo);
}
