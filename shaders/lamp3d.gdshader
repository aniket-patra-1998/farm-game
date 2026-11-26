shader_type spatial;
render_mode cull_back, shadows_disabled;
// Something that gives light of its own, answering the world as every light does (docs/WORLD.md): a lamp is
// lit as night falls and plain glass by day; a fire's bed of coals (`fire`) glows day and night, and the rain
// dulls it. One material a colour and kind, shared by every lamp alike (DecorModel).

uniform vec3 colour : source_color = vec3(1.0, 0.8, 0.45);
uniform float fire = 0.0;          // 1: a fire's coals; 0: a lamp

global uniform float dark;         // 0..1: how far into the night it is
global uniform float rain;         // 0..1: how hard it rains now (SurfaceWeather)

const float LIT_FROM = 0.2;        // how dark it is when a lamp comes on..
const float LIT_FULL = 0.55;       // ..and when it is fully lit
const float UNLIT = 0.6;           // a lamp's colour by day, against its lit colour (frosted glass)
const float COALS_LEFT = 0.35;     // of their glow, what a fire's coals keep in full rain
const float WET_FROM = 0.15;       // (as a flame: flame3d)
const float WET_FULL = 0.6;
const float GLOW = 2.0;

void fragment() {
	float coals = mix(1.0, COALS_LEFT, smoothstep(WET_FROM, WET_FULL, rain));
	float on = fire > 0.5 ? coals : smoothstep(LIT_FROM, LIT_FULL, dark);
	ALBEDO = colour * mix(UNLIT, 1.0, on);
	EMISSION = colour * GLOW * on;
	ROUGHNESS = 0.4;
}
