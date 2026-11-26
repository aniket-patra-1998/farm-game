shader_type spatial;
render_mode cull_back;
// The gold star floating over a building at its biggest size (CrownStars; owner, 25 Nov): it turns slowly and
// rises and falls a little, each on its own beat (the instance's custom red channel), its gold lit from inside
// (more as night falls, so it glows in the dark) with a band of light crossing it every few seconds. All in the
// vertex shader and one MultiMesh: one draw for every star on the farm, with no script and no node a star.

uniform vec3 gold : source_color = vec3(0.95, 0.76, 0.31);
uniform float turn = 0.9;          // radians a second it turns
uniform float bob = 0.14;          // how far it rises and falls each way, in its own radii
uniform float bob_rate = 1.3;      // ..and how fast
uniform float glow = 0.5;          // the share of its colour it shines with by day..
uniform float night = 0.75;        // ..and how much more in full night
uniform float sweep_every = 2.6;   // seconds from one band of light to the next
uniform float sweep_width = 0.2;   // half the band's width, in the star's radii

global uniform float dark;         // 0..1: how far into the night it is

varying float along;               // where this point lies on the slant the band travels

void vertex() {
	float phase = INSTANCE_CUSTOM.x * TAU;
	float a = TIME * turn + phase;
	float c = cos(a);
	float s = sin(a);
	along = (VERTEX.x + VERTEX.y) * 0.7071;
	float lift = sin(TIME * bob_rate + phase) * bob;
	VERTEX = vec3(VERTEX.x * c + VERTEX.z * s, VERTEX.y + lift, -VERTEX.x * s + VERTEX.z * c);
	NORMAL = vec3(NORMAL.x * c + NORMAL.z * s, NORMAL.y, -NORMAL.x * s + NORMAL.z * c);
}

void fragment() {
	float at = mix(-1.6, 3.6, fract(TIME / sweep_every));
	float band = 1.0 - smoothstep(0.0, sweep_width, abs(along - at));
	ALBEDO = gold;
	ROUGHNESS = 0.3;
	SPECULAR = 0.65;
	EMISSION = gold * (glow + night * dark) + vec3(1.0, 0.96, 0.82) * band * 0.8;
}
