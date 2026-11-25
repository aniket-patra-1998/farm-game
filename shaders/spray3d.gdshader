shader_type spatial;
render_mode cull_back, shadows_disabled;
// Drops thrown into the air and falling back (a fountain's jet and cascade, a fire's embers), moved wholly
// here: every drop is built at the spout and this places it along its arc from the time and its own data,
// so a whole fountain is one draw with no script. Per drop: UV = (phase 0..1, angle 0..1), UV2 = (reach
// 0..1, size 0..1). Opaque (cheaper than blending on phones, and nothing transparent can paint over it):
// a drop fades out by shrinking away at the end of its flight.

uniform vec3 colour : source_color = vec3(0.88, 0.96, 1.0);
uniform float glow = 0.0;          // emission (embers)
uniform float life = 1.2;          // seconds a drop flies
uniform float rise = 1.6;          // its upward speed at the spout (units/s; negative throws it down)
uniform float gravity = 3.2;       // (negative: it floats up, like an ember)
uniform float reach = 0.3;         // how far out it travels in its life
uniform float start_radius = 0.0;  // drops leave from a ring this wide (a basin's rim) instead of a point
uniform float size = 1.0;
uniform float end_size = 0.5;      // a drop's size at the end of its flight, relative (smoke grows: > 1)
uniform float grow_in = 0.0;       // the share of its flight a drop takes to grow from nothing (0: full at once)
uniform float weather = 0.0;       // how it answers the weather (docs/WORLD.md): 0 not at all (a fountain, a pour),
                                   // 1 smoke (rain thins it and beats it down, the wind carries it), 2 embers
                                   // (none in rain), 3 the steam off a fire the rain is putting out (only then)
uniform float sheen = 0.35;       // self-lit share, so water reads white even in shade

global uniform float rain;         // 0..1: how hard it rains now (SurfaceWeather)
global uniform float wind;         // the weather's wind, set once for everything (Farm3D)

const float WET_FROM = 0.15;       // the rain at which smoke and fire start to answer it..
const float WET_FULL = 0.6;        // ..and at which they have answered in full (as a flame: flame3d)
const float SMOKE_LEFT = 0.55;     // of its size, the smoke left in full rain..
const float SMOKE_RISE = 0.5;      // ..and of its rise
const float DRIFT = 0.07;          // how far the wind carries smoke a second, for each unit of wind

void vertex() {
	float u = fract(TIME / life + UV.x);
	float t = u * life;
	float a = UV.y * TAU;
	float wet = smoothstep(WET_FROM, WET_FULL, rain);
	float shown = 1.0;
	float lift = 1.0;
	float carried = 0.0;
	if (weather > 2.5) {
		shown = wet;
		carried = wind * DRIFT * t;
	} else if (weather > 1.5) {
		shown = 1.0 - wet;
	} else if (weather > 0.5) {
		shown = mix(1.0, SMOKE_LEFT, wet);
		lift = mix(1.0, SMOKE_RISE, wet);
		carried = wind * DRIFT * t;
	}
	vec3 out_dir = vec3(cos(a), 0.0, sin(a));
	vec3 centre = out_dir * (start_radius + reach * (0.55 + 0.45 * UV2.x) * u)
		+ vec3(carried, (rise * t - 0.5 * gravity * t * t) * lift, 0.0);
	float s = size * (0.6 + 0.4 * UV2.y) * mix(1.0, end_size, u) * (1.0 - smoothstep(0.8, 1.0, u))
		* (grow_in > 0.0 ? smoothstep(0.0, grow_in, u) : 1.0) * shown;
	VERTEX = VERTEX * s + centre;
}

void fragment() {
	ALBEDO = colour;
	EMISSION = colour * (glow + sheen);
	ROUGHNESS = 0.1;
	SPECULAR = 0.8;
}
