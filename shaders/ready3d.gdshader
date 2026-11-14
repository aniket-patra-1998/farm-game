shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
// The one "ready" sign for everything with something to collect (buildings, animals, trees, blooms), as
// FarmVille drew it: a soft, light pink triangle pointing down, its corners rounded, hovering over the thing
// and bobbing gently up and down. Always facing the camera and drawn over what stands in front. One quad per
// ready thing in one MultiMesh (ReadyMarks); the instance's custom red channel is its phase, so they don't
// bob in step. `zoom` grows it as the camera pulls back, so it stays the same size on screen.

uniform float zoom = 1.0;
uniform vec3 face : source_color = vec3(1.0, 0.72, 0.84);
uniform vec3 light : source_color = vec3(1.0, 0.88, 0.94);
uniform vec3 rim : source_color = vec3(0.89, 0.47, 0.66);
uniform float bob = 0.07;      // tiles it rises and falls
uniform float rate = 2.4;      // how fast

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
	float d = tri(p, 0.62) - 0.16;                        // rounded corners
	float edge = fwidth(d) * 1.5;
	float a = 1.0 - smoothstep(-edge, edge, d);
	float inner = smoothstep(-0.16, -0.05, d);            // a deeper pink round the rim
	vec3 col = mix(light, face, clamp(UV.y * 1.3, 0.0, 1.0));
	col = mix(col, rim, inner);
	float gloss = 1.0 - smoothstep(0.0, 0.22, length((p - vec2(-0.22, -0.32)) * vec2(1.0, 1.8)));
	col = mix(col, vec3(1.0), gloss * 0.55);
	ALBEDO = col;
	ALPHA = a;
}
