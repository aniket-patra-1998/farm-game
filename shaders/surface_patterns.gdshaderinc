// The patterns a building's surfaces are drawn with (ModelKit.WALL_STYLES): one place, shared by the builders'
// own wall shader (wall3d) and the master every file draws with (master_solid).

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// `col` as pattern `style_k` tones it at `at` (in the model's own space) on a surface that faces `facing`;
// `size` is the pattern's.
vec3 surface_pattern(vec3 col, int style_k, vec3 at, vec3 facing, float size) {
	float along = abs(facing.x) > 0.5 ? at.z : at.x;
	float y = at.y / size;
	if (style_k == 0) {
		// Clapboard: broad boards, each lapping the one below with a soft shadow under its lip and a lighter
		// worn top edge; boards differ a little in tone, and are cut into lengths.
		float lap = fract(y * 8.0);
		col *= 0.72 + 0.28 * smoothstep(0.0, 0.3, lap);
		col *= 1.0 + 0.07 * smoothstep(0.82, 1.0, lap);
		float row = floor(y * 8.0);
		float piece = floor(along * 1.6 / size + hash(vec2(row, 3.0)));
		col *= 0.9 + 0.2 * hash(vec2(row, piece));
		float cut = fract(along * 1.6 / size + hash(vec2(row, 3.0)));
		col *= mix(0.78, 1.0, smoothstep(0.0, 0.015, min(cut, 1.0 - cut)));
	} else if (style_k == 1) {
		float log_y = fract(y * 6.0);
		col *= 0.62 + 0.38 * sin(log_y * 3.14159);
		col *= 0.92 + 0.14 * hash(vec2(floor(y * 6.0), 1.0));
	} else if (style_k == 2) {
		// Fieldstone: big rounded stones of their own tones (some warmer, some cooler) in dark mortar.
		vec2 cell = vec2(along * 4.2 / size + floor(y * 5.5) * 0.5, y * 5.5);
		vec2 f = fract(cell);
		vec2 q = abs(f - 0.5) * 2.0;
		float stone = 1.0 - smoothstep(0.62, 0.95, max(q.x, q.y) * 0.75 + length(q) * 0.3);
		float tone = hash(floor(cell));
		vec3 own = col * (0.82 + 0.34 * tone) * mix(vec3(1.06, 1.0, 0.92), vec3(0.94, 0.99, 1.07), hash(floor(cell) + 7.0));
		col = mix(col * 0.52, own * (0.9 + 0.14 * (1.0 - length(q))), stone);
	} else if (style_k == 3) {
		// Plaster: soft blotches, a little grime gathering low on the wall.
		col *= 0.94 + 0.08 * hash(floor(at.xz * 9.0) + floor(y * 9.0));
		col *= 0.97 + 0.05 * sin(along * 5.0 + y * 3.0);
	} else if (style_k == 4) {
		// Rows of big rounded tabs, each row shifted half a tab: the tab's rounded bottom edge shades the row below
		// it, and every tab has its own tone, so a roof reads as laid shingles and not as stripes.
		vec2 tile = vec2(along * 5.0 / size + floor(y * 6.5) * 0.5, y * 6.5);
		vec2 f = fract(tile);
		float round_edge = 0.34 * pow(abs(2.0 * f.x - 1.0), 2.0);
		col *= 0.6 + 0.4 * smoothstep(round_edge, round_edge + 0.34, f.y);
		col *= 1.0 + 0.08 * smoothstep(0.75, 1.0, f.y);
		float own = hash(floor(tile));
		col *= 0.84 + 0.3 * own;
		col = mix(col, col * vec3(1.08, 1.0, 0.9), step(0.8, hash(floor(tile) + 5.0)) * 0.6);
		col *= mix(0.74, 1.0, smoothstep(0.0, 0.1, min(f.x, 1.0 - f.x)));
	} else if (style_k == 5) {
		col *= 0.85 + 0.15 * sin(along * 60.0 / size);
	} else if (style_k == 6) {
		// Barn planks: broad upright boards with a batten over each joint, each board its own tone, the paint
		// worn a little where the weather gets at it.
		float across = along * 7.0 / size;
		float board = floor(across);
		float f = fract(across);
		col *= 0.88 + 0.2 * hash(vec2(board, 11.0));
		col *= mix(1.0, 1.09, step(f, 0.16));   // (the batten stands proud and catches the light)
		col *= mix(0.68, 1.0, smoothstep(0.0, 0.035, min(abs(f - 0.16), min(f, 1.0 - f))));
		col *= 0.96 + 0.06 * hash(vec2(board, floor(y * 3.0)));
	}
	return col;
}
