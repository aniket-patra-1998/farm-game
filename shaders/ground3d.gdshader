shader_type spatial;
render_mode cull_disabled;
// Grass seen from above: patches of lighter and darker green at a few scales, a soft tile checker on the
// farm (FarmVille's grid you could read without lines), and a sunlit warmth. All procedural, in world
// space, so it never stretches or repeats visibly.

uniform vec3 grass_light : source_color = vec3(0.33, 0.44, 0.22);
uniform vec3 grass_dark : source_color = vec3(0.22, 0.33, 0.14);
uniform vec3 dry : source_color = vec3(0.74, 0.74, 0.38);
uniform float checker = 0.035;  // how much alternate tiles differ; 0 for the meadow
uniform float dryness = 0.18;   // how much straw-coloured grass shows through
// The farm lawn (farm_n > 0, in tiles): mown in bands, with a lip of bare earth along its edge, so the farm
// reads as a place cut out of the countryside.
uniform float farm_n = 0.0;
uniform vec3 verge : source_color = vec3(0.50, 0.37, 0.22);
uniform float mow = 0.09;       // how much alternate bands differ
uniform float patchy = 0.0;     // the meadow: how strongly patches of lush and thin grass differ
uniform float bare_amount = 0.0; // the meadow: how much bare earth shows in worn patches (0 on the farm lawn)
uniform vec3 bare : source_color = vec3(0.47, 0.37, 0.22);
uniform vec3 cool : source_color = vec3(0.22, 0.45, 0.28); // damp hollows lean blue-green
// What stands on the farm (Ground3D): R darkens the grass round things that block the sky, G wears it to
// trodden straw and earth. shade_rect is the map's corner and size in tiles.
uniform sampler2D shade_map : filter_linear, repeat_disable;
uniform vec4 shade_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 worn : source_color = vec3(0.62, 0.58, 0.36);
uniform float shade_strength = 0.42;

// The meadow's own: the woods (Ground3D paints where the trees are into forest_map, in tiles from forest_rect's
// corner) get a forest floor, and the ground just outside the farm's raised edge is shaded where it meets it.
uniform float forest_amount = 0.0;
uniform sampler2D forest_map : filter_linear, repeat_disable;
uniform vec4 forest_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 forest_dark : source_color = vec3(0.13, 0.23, 0.10);
uniform vec3 forest_moss : source_color = vec3(0.22, 0.36, 0.14);
uniform vec3 litter : source_color = vec3(0.42, 0.28, 0.13);
uniform float edge_n = 0.0;     // the meadow: the farm's size in tiles (0: none), for the contact shade at its edge

global uniform float wetness;     // 0..1: how wet everything is (SurfaceWeather): darker, glossier
global uniform float snow_cover;  // 0..1: how much snow lies on what faces up (SurfaceWeather)

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float broad = fbm(p * 0.18);
	float fine = noise(p * 3.1) * 0.5 + noise(p * 7.3) * 0.5;
	vec3 col = mix(grass_dark, grass_light, smoothstep(0.25, 0.75, broad));
	// Hollows: cooler, deeper green, so the lawn isn't one hue with lighter and darker patches.
	col = mix(col, cool * (0.75 + 0.5 * broad), 0.4 * smoothstep(0.45, 0.8, fbm(p * 0.13 + 50.0)));
	col = mix(col, dry, dryness * smoothstep(0.55, 0.85, fbm(p * 0.37 + 11.0)));
	// A mottle in between the broad patches and the grain, so a stretch of lawn has a texture to it.
	col *= 0.94 + 0.12 * fbm(p * 1.1 + 70.0);
	// Bare earth where the meadow is trodden thin: ragged-edged patches, rare.
	float earth = smoothstep(0.66, 0.74, fbm(p * 0.5 + 7.0) + (fine - 0.5) * 0.12);
	col = mix(col, bare * (0.85 + 0.3 * fine), earth * bare_amount);
	col *= 0.92 + 0.16 * fine;
	col *= 1.0 + patchy * (fbm(p * 0.09 + 31.0) - 0.5);
	if (farm_n > 0.0) {
		col *= 1.0 + mow * (step(0.5, fract((p.x + p.y) * 0.25)) - 0.5);
		float d = min(min(p.x, p.y), min(farm_n - p.x, farm_n - p.y));
		float ragged = (fine - 0.5) * 0.2 + (noise(p * 1.7) - 0.5) * 0.12;
		// A mown border a tile wide just in from the edge (lighter, cut short), a lip of bare earth along the
		// very edge with a ragged inner side, and a dark line where the two meet.
		float border = smoothstep(0.25, 0.4, d + ragged) * smoothstep(1.15, 0.9, d + ragged);
		col = mix(col, col * vec3(1.1, 1.1, 0.95) + vec3(0.02, 0.03, 0.0), border * 0.8);
		float lip = smoothstep(0.38, 0.22, d + ragged);
		col = mix(col, verge * (0.88 + 0.24 * fine), lip * 0.95);
		col *= 1.0 - 0.22 * smoothstep(0.1, 0.0, abs(d + ragged - 0.3));
	}
	if (edge_n > 0.0) {
		// Outside the raised farm: the foot of its wall, in shadow and bare where the grass can't grow.
		float out_d = max(max(-p.x, p.x - edge_n), max(-p.y, p.y - edge_n));
		if (out_d > 0.0) {
			float foot = smoothstep(1.6, 0.0, out_d + (fine - 0.5) * 0.5);
			col = mix(col, bare * 0.8, foot * 0.35 * smoothstep(0.9, 0.1, out_d));
			col *= 1.0 - 0.3 * foot;
		}
	}
	if (forest_amount > 0.0) {
		vec2 fuv = (p - forest_rect.xy) / forest_rect.zw;
		if (fuv.x > 0.0 && fuv.y > 0.0 && fuv.x < 1.0 && fuv.y < 1.0) {
			// The woods' edge is ragged, not a circle round each tree.
			float f = smoothstep(0.3, 0.6, texture(forest_map, fuv).r + (fbm(p * 1.3 + 90.0) - 0.5) * 0.4);
			vec3 floor_col = mix(forest_dark, forest_moss, smoothstep(0.35, 0.7, fbm(p * 0.9 + 17.0)));
			// Fallen leaves: big dim drifts, and the odd single leaf.
			floor_col = mix(floor_col, litter, 0.55 * smoothstep(0.55, 0.75, fbm(p * 2.2 + 5.0)));
			floor_col = mix(floor_col, litter * 1.25, step(0.9, noise(p * 11.0)) * 0.6);
			col = mix(col, floor_col * (0.9 + 0.2 * fine), f * forest_amount);
		}
	}
	float tile = mod(floor(p.x) + floor(p.y), 2.0);
	col *= 1.0 + checker * (tile - 0.5);
	vec2 suv = (p - shade_rect.xy) / shade_rect.zw;
	if (suv.x > 0.0 && suv.y > 0.0 && suv.x < 1.0 && suv.y < 1.0) {
		vec2 sw = texture(shade_map, suv).rg;
		// Wear comes in ragged, so it reads as trodden ground and not a painted stain.
		float ragged = smoothstep(0.2, 0.8, sw.g * (0.6 + 0.8 * fbm(p * 1.7 + 3.0)));
		col = mix(col, worn * (0.9 + 0.2 * fine), ragged * 0.75);
		col *= 1.0 - shade_strength * sw.r;
	}
	// Rain darkens the ground and leaves puddles in the hollows; snow settles in patches first, then everywhere.
	float puddle = smoothstep(0.55, 0.7, fbm(p * 0.8 + 41.0)) * wetness;
	col *= 1.0 - 0.25 * wetness - 0.2 * puddle;
	float snowy = smoothstep(0.0, 0.2, snow_cover * 1.25 - (1.0 - fbm(p * 0.5 + 23.0)) * 0.4);
	col = mix(col, vec3(0.92, 0.94, 1.0) * (0.95 + 0.05 * fine), snowy);
	ALBEDO = col;
	ROUGHNESS = mix(0.95 - 0.35 * wetness - 0.5 * puddle, 0.85, snowy);
	SPECULAR = 0.15 + 0.3 * puddle;
}
