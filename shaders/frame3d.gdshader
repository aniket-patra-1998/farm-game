shader_type spatial;
render_mode cull_disabled;
// What a building does not have yet (BuildingModel's plan: the shapes its next size adds), drawn as a timber
// frame in place of the solid shape: beams along a grid on every face and nothing between them, so the
// building it will become is seen through and round the one that stands. The shape is drawn a little inside
// itself, so where it shares a wall with what is built the built wall hides it. Every such part of every
// building shares this one material (ModelKit.frame_material).

uniform vec3 timber : source_color = vec3(0.86, 0.66, 0.38);
uniform float beams = 2.6;      // beams to a tile
uniform float thick = 0.2;      // a beam's width, as a share of the gap from one to the next
uniform float inset = 0.012;    // how far inside the shape it is drawn, in tiles
uniform float ground = 0.07;    // nothing is drawn this near the ground: a yard still to come is not a frame
varying vec3 at;
varying vec3 facing;

void vertex() {
	VERTEX -= NORMAL * inset;
	at = VERTEX;
	facing = NORMAL;
}

void fragment() {
	vec3 beam = step(vec3(0.5 - thick * 0.5), abs(fract(at * beams) - 0.5));
	vec3 across = step(abs(normalize(facing)), vec3(0.85));   // (not the beams a face lies flat in)
	if (at.y < ground || max(max(beam.x * across.x, beam.y * across.y), beam.z * across.z) < 0.5) {
		discard;
	}
	ALBEDO = timber * (0.8 + 0.2 * abs(facing.y));
	ROUGHNESS = 1.0;
}
