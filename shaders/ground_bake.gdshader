shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
// Paints the ground's still look (ground_common.gdshaderinc) once, seen straight down by an orthographic camera
// in an off-screen viewport (Ground3D.bake). Unshaded, with the same uniforms as the ground (source_color and
// all), so the renderer treats its colours exactly as it treats the ground's own; the ground reads the picture
// back with source_color, which undoes the screen's encoding on any renderer.

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


varying vec3 world_pos;

#include "res://shaders/ground_common.gdshaderinc"

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fine;
	ALBEDO = ground_static(world_pos.xz, fine);
}
