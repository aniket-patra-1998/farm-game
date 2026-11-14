shader_type spatial;
render_mode cull_disabled;
// Grass seen from above: patches of lighter and darker green at a few scales, a soft tile checker on the
// farm (FarmVille's grid you could read without lines), and a sunlit warmth. All procedural, in world
// space, so it never stretches or repeats visibly. The parts that never change (ground_common.gdshaderinc) are
// painted once into `baked`; per pixel the ground then reads that, adds a grain, the shade and wear of what
// stands on it, and rain or snow only when there is any.

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

// The still look painted once into a texture (Ground3D.bake), its colour; bake_rect is the
// texture's corner and size in tiles. Off (and the look worked out live) until the bake is ready.
uniform bool use_bake = false;
uniform sampler2D baked : source_color, filter_linear, repeat_disable;
uniform vec4 bake_rect = vec4(0.0, 0.0, 1.0, 1.0);
const float GRAIN = 0.1;   // the live grain over the baked look

varying vec3 world_pos;

#include "res://shaders/ground_common.gdshaderinc"

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 col;
	float fine;
	vec2 buv = (p - bake_rect.xy) / bake_rect.zw;
	if (use_bake && buv.x > 0.0 && buv.y > 0.0 && buv.x < 1.0 && buv.y < 1.0) {
		// The still look, painted once (Ground3D's bake), with a crisp grain on top that the texture is too
		// coarse to hold up close.
		col = texture(baked, buv).rgb;
		fine = noise(p * 7.3);
		col *= 1.0 + GRAIN * (fine - 0.5);
	} else {
		col = ground_static(p, fine);
	}
	vec2 suv = (p - shade_rect.xy) / shade_rect.zw;
	if (suv.x > 0.0 && suv.y > 0.0 && suv.x < 1.0 && suv.y < 1.0) {
		vec2 sw = texture(shade_map, suv).rg;
		if (sw.g > 0.004) {
			// Wear comes in ragged, so it reads as trodden ground and not a painted stain.
			float ragged = smoothstep(0.2, 0.8, sw.g * (0.6 + 0.8 * fbm(p * 1.7 + 3.0)));
			col = mix(col, worn * (0.9 + 0.2 * fine), ragged * 0.75);
		}
		col *= 1.0 - shade_strength * sw.r;
	}
	// Rain darkens the ground and leaves puddles in the hollows; snow settles in patches first, then everywhere.
	// (Worked out only when it is wet or snowy: on a dry day the ground costs no noise for them.)
	float puddle = 0.0;
	float snowy = 0.0;
	if (wetness > 0.001) {
		puddle = smoothstep(0.55, 0.7, fbm(p * 0.8 + 41.0)) * wetness;
		col *= 1.0 - 0.25 * wetness - 0.2 * puddle;
	}
	if (snow_cover > 0.001) {
		snowy = smoothstep(0.0, 0.2, snow_cover * 1.25 - (1.0 - fbm(p * 0.5 + 23.0)) * 0.4);
		col = mix(col, vec3(0.92, 0.94, 1.0) * (0.95 + 0.05 * fine), snowy);
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.95 - 0.35 * wetness - 0.5 * puddle, 0.85, snowy);
	SPECULAR = 0.15 + 0.3 * puddle;
}
