shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
// The rust sign over a rusty vehicle (docs/RUST.md; our own touch): a round bubble with a broken gear in it,
// a small point under it, and a pip for each level of rust below that. Amber, then orange, then red all
// through when the vehicle will not work. Always facing the camera and drawn over what stands in front. One
// quad per sign in one MultiMesh (RustMarks); the instance's custom red channel is its rust as a share of the
// most there is. `zoom` grows it as the camera pulls back, so it stays the same size on screen.

uniform float zoom = 1.0;
uniform float levels = 5.0;    // the most rust there is: how many pips
uniform vec3 mild : source_color = vec3(0.95, 0.66, 0.11);
uniform vec3 worse : source_color = vec3(0.93, 0.45, 0.13);
uniform vec3 seized : source_color = vec3(0.86, 0.18, 0.18);
uniform vec3 paper : source_color = vec3(1.0, 0.98, 0.94);
uniform vec3 ink : source_color = vec3(0.17, 0.18, 0.21);
uniform vec3 unlit : source_color = vec3(0.85, 0.87, 0.89);
varying float share;

// A gear about the origin, less than 0 inside: eight teeth round a ring with a hole.
float gear(vec2 p) {
	float tooth = smoothstep(-0.3, 0.3, cos(atan(p.y, p.x) * 8.0));
	float r = length(p);
	return max(r - mix(0.29, 0.41, tooth), 0.12 - r);
}

void vertex() {
	share = INSTANCE_CUSTOM.r;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= zoom;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;                              // y down
	float stopped = step(0.9, share);
	vec3 col = mix(mix(mild, worse, step(0.5, share)), seized, stopped);
	float aa = fwidth(p.x) * 1.5;
	// The bubble, and the point under it.
	vec2 b = p - vec2(0.0, -0.24);
	float disc = length(b) - 0.6;
	float point = max(abs(p.x) * 1.7 + p.y - 0.6, 0.2 - p.y);
	float body = min(disc, point);
	vec3 c = ink;
	c = mix(c, col, 1.0 - smoothstep(-aa, aa, disc + 0.05));
	c = mix(c, mix(paper, col, stopped), 1.0 - smoothstep(-aa, aa, disc + 0.13));
	// The gear, cracked through from top to bottom, its right piece knocked loose.
	float crack = b.x - 0.07 * (abs(fract(b.y * 2.6 + 0.25) - 0.5) * 4.0 - 1.0);
	vec2 q = b - step(0.0, crack) * vec2(0.05, 0.035);
	float cog = max(gear(q), 0.03 - abs(crack));
	c = mix(c, mix(col, paper, stopped), 1.0 - smoothstep(-aa, aa, cog));
	// A pip for each level, lit for each it has.
	float k = clamp(round(p.x / 0.21), -2.0, 2.0);
	float pip = length(p - vec2(k * 0.21, 0.86)) - 0.09;
	float lit = step(k + 2.5, share * levels + 0.01);
	c = mix(c, mix(unlit, col, lit), (1.0 - smoothstep(-aa, aa, pip + 0.032)) * step(0.7, p.y));
	ALBEDO = c;
	ALPHA = 1.0 - smoothstep(-aa, aa, min(body, pip));
}
