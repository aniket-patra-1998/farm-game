shader_type spatial;
render_mode cull_disabled;
// A building's yard floor (the owner's pick, 17 Nov): the farm's own lawn carried inside the fence, worked out
// in world space from the same look (ground_common.gdshaderinc), so a yard's grass runs on from the lawn round it
// and changes with the seasons with it (Ground3D sets this material's colours from the lawn's). Not mown in
// stripes: a yard is grazed, not cut. The trodden earth path from the gate to the door is geometry
// (BuildingModel._yard). One shared material for every yard (ModelKit.yard_material; files name it LIVE_YARD).

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
uniform float mow_width = 4.0;  // tiles across one mown band (the farm's lawn: diagonal stripes)
uniform float hue_drift = 0.0;  // how far big patches lean sunlit yellow-green or cool blue-green
uniform float blades = 0.0;     // how much the tiny light blade tips and dark gaps show
uniform float patchy = 0.0;     // the meadow: how strongly patches of lush and thin grass differ
uniform float bare_amount = 0.0; // the meadow: how much bare earth shows in worn patches (0 on the farm lawn)
uniform vec3 bare : source_color = vec3(0.47, 0.37, 0.22);
uniform vec3 cool : source_color = vec3(0.22, 0.45, 0.28); // damp hollows lean blue-green
uniform float hollows = 0.4;    // how much the damp hollows darken the grass (less on the farm's kept lawn)

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

#include "res://shaders/ground_common.gdshaderinc"

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fine;
	vec3 col = ground_static(world_pos.xz, fine);
	col *= 1.0 - 0.25 * wetness;
	float snowy = smoothstep(0.0, 0.2, snow_cover * 1.25 - (1.0 - fbm(world_pos.xz * 0.5 + 23.0)) * 0.4);
	col = mix(col, vec3(0.92, 0.94, 1.0), snowy);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
}
