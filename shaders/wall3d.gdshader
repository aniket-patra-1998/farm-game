shader_type spatial;
// Walls and roofs of the farm's buildings, in local object space so patterns stay put as buildings move:
// 0 boards (clapboard with shadowed laps), 1 logs, 2 stone, 3 plaster, 4 shingles (roofs), 5 corrugated
// metal, 6 planks (a barn's upright boards and battens). Every surface also darkens toward the ground (ambient occlusion), which is what makes a building
// look like it sits on the earth rather than floating over it.

uniform vec3 base_color : source_color = vec3(0.8, 0.3, 0.2);
uniform int style = 0;
uniform float scale = 1.0;      // pattern size: 1 is a board about a twelfth of a tile high
uniform float ground_ao = 0.45; // how dark the foot of the wall gets
uniform bool packed_in_alpha = false;  // each part's style and ground shade ride in its vertex alpha (ModelKit.wall_pack)

global uniform float wetness;     // 0..1: how wet everything is (SurfaceWeather): darker, glossier
global uniform float snow_cover;  // 0..1: how much snow lies on what faces up (SurfaceWeather)

varying vec3 local_pos;
varying vec3 local_normal;
varying float height;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

varying vec3 tint;  // the part's colour when baked into a merged mesh (white if none)
varying float pack; // and its style and ground shade, when they ride in the vertex alpha

void vertex() {
	tint = COLOR.rgb;
	pack = COLOR.a;
	local_pos = VERTEX;
	local_normal = NORMAL;
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 col = base_color * tint;
	int style_k = style;
	float ao_k = ground_ao;
	if (packed_in_alpha) {
		int k = int(round(pack * 255.0));
		style_k = k / 32;
		ao_k = float(k % 32) * 0.02;
	}
	float along = abs(local_normal.x) > 0.5 ? local_pos.z : local_pos.x;
	float y = local_pos.y / scale;
	if (style_k == 0) {
		// Clapboard: broad boards, each lapping the one below with a soft shadow under its lip and a lighter
		// worn top edge; boards differ a little in tone, and are cut into lengths.
		float lap = fract(y * 8.0);
		col *= 0.72 + 0.28 * smoothstep(0.0, 0.3, lap);
		col *= 1.0 + 0.07 * smoothstep(0.82, 1.0, lap);
		float row = floor(y * 8.0);
		float piece = floor(along * 1.6 / scale + hash(vec2(row, 3.0)));
		col *= 0.9 + 0.2 * hash(vec2(row, piece));
		float cut = fract(along * 1.6 / scale + hash(vec2(row, 3.0)));
		col *= mix(0.78, 1.0, smoothstep(0.0, 0.015, min(cut, 1.0 - cut)));
	} else if (style_k == 1) {
		float log_y = fract(y * 6.0);
		col *= 0.62 + 0.38 * sin(log_y * 3.14159);
		col *= 0.92 + 0.14 * hash(vec2(floor(y * 6.0), 1.0));
	} else if (style_k == 2) {
		// Fieldstone: big rounded stones of their own tones (some warmer, some cooler) in dark mortar.
		vec2 cell = vec2(along * 4.2 / scale + floor(y * 5.5) * 0.5, y * 5.5);
		vec2 f = fract(cell);
		vec2 q = abs(f - 0.5) * 2.0;
		float stone = 1.0 - smoothstep(0.62, 0.95, max(q.x, q.y) * 0.75 + length(q) * 0.3);
		float tone = hash(floor(cell));
		vec3 own = col * (0.82 + 0.34 * tone) * mix(vec3(1.06, 1.0, 0.92), vec3(0.94, 0.99, 1.07), hash(floor(cell) + 7.0));
		col = mix(col * 0.52, own * (0.9 + 0.14 * (1.0 - length(q))), stone);
	} else if (style_k == 3) {
		// Plaster: soft blotches, a little grime gathering low on the wall.
		col *= 0.94 + 0.08 * hash(floor(local_pos.xz * 9.0) + floor(y * 9.0));
		col *= 0.97 + 0.05 * sin(along * 5.0 + y * 3.0);
	} else if (style_k == 4) {
		// Rows of big rounded tabs, each row shifted half a tab: the tab's rounded bottom edge shades the row below
		// it, and every tab has its own tone, so a roof reads as laid shingles and not as stripes.
		vec2 tile = vec2(along * 5.0 / scale + floor(y * 6.5) * 0.5, y * 6.5);
		vec2 f = fract(tile);
		float round_edge = 0.34 * pow(abs(2.0 * f.x - 1.0), 2.0);
		col *= 0.6 + 0.4 * smoothstep(round_edge, round_edge + 0.34, f.y);
		col *= 1.0 + 0.08 * smoothstep(0.75, 1.0, f.y);
		float own = hash(floor(tile));
		col *= 0.84 + 0.3 * own;
		col = mix(col, col * vec3(1.08, 1.0, 0.9), step(0.8, hash(floor(tile) + 5.0)) * 0.6);
		col *= mix(0.74, 1.0, smoothstep(0.0, 0.1, min(f.x, 1.0 - f.x)));
	} else if (style_k == 5) {
		col *= 0.85 + 0.15 * sin(along * 60.0 / scale);
	} else if (style_k == 6) {
		// Barn planks: broad upright boards with a batten over each joint, each board its own tone, the paint
		// worn a little where the weather gets at it.
		float across = along * 7.0 / scale;
		float board = floor(across);
		float f = fract(across);
		col *= 0.88 + 0.2 * hash(vec2(board, 11.0));
		col *= mix(1.0, 1.09, step(f, 0.16));   // (the batten stands proud and catches the light)
		col *= mix(0.68, 1.0, smoothstep(0.0, 0.035, min(abs(f - 0.16), min(f, 1.0 - f))));
		col *= 0.96 + 0.06 * hash(vec2(board, floor(y * 3.0)));
	}
	// Lighter towards the top, as the sky lights it: a wall is never one flat colour.
	col *= mix(0.9, 1.06, smoothstep(0.0, 1.3, height));
	col *= mix(1.0 - ao_k, 1.0, smoothstep(0.0, 0.35, height));
	ALBEDO = col;
	ROUGHNESS = style_k == 5 ? 0.45 : 0.9;
	// Weather on the surface: wet things are darker and glossier; snow lies on what faces up.
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	float snow_amt = snow_cover * smoothstep(0.5, 0.85, up);
	ALBEDO = mix(ALBEDO * (1.0 - 0.22 * wetness), vec3(0.93, 0.95, 1.0), snow_amt);
	ROUGHNESS = mix(ROUGHNESS * (1.0 - 0.45 * wetness), 0.9, snow_amt);

	METALLIC = style_k == 5 ? 0.3 : 0.0;
	SPECULAR = style_k == 5 ? 0.35 : 0.08;
}
