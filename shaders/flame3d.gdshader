shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
// A flame: bright at its foot, licking up and flickering, each tongue on its own beat (from where its
// vertices are), all in the vertex shader. Opaque: cheaper on phones than blending, and never painted over.
// It answers the weather as every fire does (docs/WORLD.md): rain beats it down to a low red glow over its
// coals, unless it burns under a roof (`sheltered`), and the wind leans it.

uniform vec3 colour : source_color = vec3(1.0, 0.55, 0.15);
uniform vec3 tip : source_color = vec3(1.0, 0.85, 0.35);
uniform float height = 0.25;       // the flame's height, for shading foot to tip
uniform float sheltered = 0.0;     // 1: under a roof, where the rain does not reach it

global uniform float rain;         // 0..1: how hard it rains now (SurfaceWeather)
global uniform float wind;         // the weather's wind, set once for everything (Farm3D)

const float QUENCH_FROM = 0.15;    // the rain at which a fire starts to sink..
const float QUENCH_FULL = 0.6;     // ..and at which it is out
const float LEFT = 0.16;           // of its height, what is left of a flame the rain has put out
const float LEAN = 0.05;           // how far a flame's tip leans downwind, in units for each unit of wind
const vec3 COALS = vec3(0.62, 0.13, 0.04);

varying float up;
varying float out_share;

void vertex() {
	vec3 root = NODE_POSITION_WORLD;
	float beat = TIME * 9.0 + root.x * 7.0 + root.z * 5.0;
	out_share = smoothstep(QUENCH_FROM, QUENCH_FULL, rain) * (1.0 - sheltered);
	up = clamp(VERTEX.y / height, 0.0, 1.0);
	float lick = up * up;
	VERTEX.y *= (1.0 + 0.22 * sin(beat) + 0.12 * sin(beat * 2.7 + 1.3)) * mix(1.0, LEFT, out_share);
	VERTEX.x += sin(beat * 0.8 + VERTEX.y * 18.0) * 0.03 * lick + wind * LEAN * lick * (1.0 - sheltered);
	VERTEX.z += cos(beat * 0.9 + VERTEX.y * 15.0) * 0.03 * lick;
	VERTEX.xz *= 1.0 - 0.35 * lick;
}

void fragment() {
	ALBEDO = mix(mix(colour, tip, up) * 1.6, COALS * (0.8 + 0.2 * sin(TIME * 3.0 + up * 9.0)), out_share);
}
