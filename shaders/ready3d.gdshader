shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
// The one "ready" sign for everything with something to collect (buildings, animals, trees, blooms), as
// FarmVille drew it, in our own softer shape (the owner's pick, 17 Nov): a plump bubblegum-pink pin pointing
// down (a round head flowing into a soft point), with a glossy highlight and a crisp white edge, hovering over
// the thing and bobbing gently up and down. Always facing the camera and drawn over what stands in front. One quad per
// ready thing in one MultiMesh (ReadyMarks); the instance's custom red channel is its phase, so they don't
// bob in step. `zoom` grows it as the camera pulls back, so it stays the same size on screen.

uniform float zoom = 1.0;
// Pulled back over a big farm, the signs over small things (animals, trees, blooms: the instance's custom green
// is 1) fade by this much, so the buildings' signs stay and the farm doesn't read as a field of triangles.
uniform float minor_fade = 0.0;
varying float fade;
uniform vec3 face : source_color = vec3(1.0, 0.48, 0.72);
uniform vec3 light : source_color = vec3(1.0, 0.84, 0.92);
uniform vec3 rim : source_color = vec3(0.82, 0.29, 0.55);
uniform float outline = 0.06;  // the white edge round it, so it reads on any ground (of the quad's half-width)
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

// Signed distance to the pin: a circle on top joined smoothly to a downward triangle (y down).
float pin(vec2 p) {
	float head = length(p + vec2(0.0, 0.15)) - 0.42;
	float point = tri(vec2(p.x * 1.05, p.y - 0.05), 0.42) - 0.12;
	const float k = 0.18;
	float h = clamp(0.5 + 0.5 * (point - head) / k, 0.0, 1.0);
	return mix(point, head, h) - k * h * (1.0 - h);
}

void vertex() {
	float phase = INSTANCE_CUSTOM.r * 6.2831;
	fade = 1.0 - minor_fade * INSTANCE_CUSTOM.g;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= zoom;
	VERTEX.y += sin(TIME * rate + phase) * bob * zoom;
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, UV.y * 2.0 - 1.0);   // y down: the pin points down
	float d = pin(p);
	float edge = fwidth(d) * 1.2;
	float body = 1.0 - smoothstep(-edge, edge, d);
	float ring = 1.0 - smoothstep(outline - edge, outline + edge, d);   // the white edge round it
	float inner = smoothstep(-0.09, -0.02, d);            // a thin deeper pink line round the rim
	vec3 col = mix(light, face, clamp(UV.y * 1.2, 0.0, 1.0));
	col = mix(col, rim, inner * 0.9);
	float gloss = 1.0 - smoothstep(0.0, 0.2, length((p - vec2(-0.2, -0.3)) * vec2(1.0, 1.9)));
	col = mix(col, vec3(1.0), gloss * 0.75);
	ALBEDO = mix(vec3(1.0), col, body);
	ALPHA = max(body * 0.97, ring) * fade;
}
