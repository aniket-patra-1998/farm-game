shader_type spatial;
render_mode cull_disabled;
// A palm's frond or a banana tree's leaf: a thin painted sheet, seen from both sides, its colour in its vertices
// (white albedo), so a tree's fronds are one draw. It bends with its tree in the wind (paint3d's sway) and, on
// top of that, each frond bobs from its base on its own beat, its tip moving most, with a quick shiver in a
// wind: a gust ripples through the crown where it used to stand like wire. UV.x: how far along its frond a
// point is (0 at the base, 1 at the tip); UV.y: the frond's own beat (0..1). FrondMesh writes both.

uniform vec3 albedo : source_color = vec3(1.0);
uniform float roughness = 0.9;
uniform float specular = 0.15;
uniform float ground_ao = 0.32;   // how dark it gets where it nears the ground (as every painted part)
uniform float ao_reach = 0.22;
uniform float sway = 0.0;         // how far its tree bends, by height above its foot; 0: still
uniform float bob = 0.9;          // how far a frond's tip bobs, of the tree's bend a unit up
uniform float bob_pace = 2.2;     // ..and how fast (radians a second)
uniform float shiver = 0.25;      // a quicker shake on top, by the wind's strength
global uniform float wetness;     // 0..1: how wet everything is (SurfaceWeather)
global uniform float snow_cover;  // 0..1: how much snow lies on what faces up (SurfaceWeather)
global uniform float wind;        // the weather's wind, set once for everything (Farm3D)

varying float height;
varying vec3 tint;

#include "res://shaders/leaf_touch.gdshaderinc"
uniform int touch = 0;   // a limited tree's touch on its leaves (leaf_touch.gdshaderinc); 0: none

void vertex() {
	tint = COLOR.rgb;
	if (touch != 0) {
		tint = leaf_touch(touch, tint, (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - MODEL_MATRIX[3].xyz, TIME);
	}
	if (sway > 0.0) {
		vec3 root = MODEL_MATRIX[3].xyz;
		float beat = TIME * 1.4 + root.x * 1.7 + root.z * 1.1;
		float bend = max(VERTEX.y, 0.0) * max(VERTEX.y, 0.0) * sway * (0.4 + wind);
		VERTEX.x += sin(beat) * bend;
		VERTEX.z += cos(beat * 0.8) * bend * 0.6;
		float own = sin(TIME * bob_pace + UV.y * 6.2832) * bob + sin(TIME * bob_pace * 4.1 + UV.y * 12.0) * shiver * wind;
		VERTEX.y += own * sway * (0.4 + wind) * UV.x * UV.x;
	}
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float ao = mix(1.0 - ground_ao, 1.0, smoothstep(0.0, ao_reach, height));
	ALBEDO = albedo * tint * ao;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	float snow_amt = snow_cover * smoothstep(0.5, 0.85, up);
	ALBEDO = mix(ALBEDO * (1.0 - 0.22 * wetness), vec3(0.93, 0.95, 1.0), snow_amt);
	ROUGHNESS = mix(ROUGHNESS * (1.0 - 0.45 * wetness), 0.9, snow_amt);
}
