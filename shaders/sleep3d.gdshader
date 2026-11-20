shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
// The little "z z z" over a sleeping animal's nose (owner, 20 Nov): three small z's leave the nose one after
// another, rise up and across, sway, grow and fade. Always facing the camera, white with a dark edge so it reads
// at night, and hidden by what stands in front (a sleeper behind a barn has none showing through). One quad per
// sleeper in one MultiMesh (SleepMarks): the quad's bottom left corner is the nose, and the instance's custom red
// channel is its phase, so a farm's sleepers don't breathe their z's in step.

uniform vec3 face : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 edge : source_color = vec3(0.16, 0.2, 0.36);
uniform float rate = 0.4;        // journeys a second: each z takes 1 / rate seconds from the nose to gone
uniform float small = 0.06;      // a z's half-size as it leaves the nose, of the quad's side..
uniform float big = 0.15;        // ..and as it fades
uniform float sway = 0.06;       // how far it drifts from side to side on its way
varying float phase;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// How far `p` is from the strokes of a letter z about the origin, one unit tall and wide each way.
float zed(vec2 p) {
	return min(seg(p, vec2(-0.7, 0.8), vec2(0.7, 0.8)), min(seg(p, vec2(0.7, 0.8), vec2(-0.7, -0.8)),
		seg(p, vec2(-0.7, -0.8), vec2(0.7, -0.8))));
}

void vertex() {
	phase = INSTANCE_CUSTOM.r;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = vec2(UV.x, 1.0 - UV.y);                        // y up; the nose is at the bottom left
	float aa = fwidth(p.x) * 1.2;
	float ink = 0.0;
	float rim = 0.0;
	for (int i = 0; i < 3; i++) {
		float t = fract(TIME * rate + phase + float(i) / 3.0);
		vec2 at = vec2(0.14 + 0.56 * t + sway * sin(t * 9.0), 0.1 + 0.72 * t);
		float size = mix(small, big, t);
		float d = zed((p - at) / size) * size;
		float shown = smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.68, 1.0, t));
		float stroke = size * 0.2;
		ink = max(ink, shown * (1.0 - smoothstep(stroke - aa, stroke + aa, d)));
		rim = max(rim, shown * (1.0 - smoothstep(stroke * 2.1 - aa, stroke * 2.1 + aa, d)));
	}
	ALBEDO = mix(edge, face, ink);
	ALPHA = max(ink, rim);
}
