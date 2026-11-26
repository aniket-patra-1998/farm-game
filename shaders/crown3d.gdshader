shader_type spatial;
// A tree's crown painted in leaf sprays (TreeModel._sprayed): the tones are in the vertex colours, so the sun
// lights the whole crown nearly alike and nothing shades it a second time (no shadows fall on it, its own least
// of all: a spray's shadow on the next one was a black mess). Bends in the wind and wears a limited tree's touch
// as the other leaf shaders do.
render_mode shadows_disabled, cull_disabled;

uniform vec3 albedo : source_color = vec3(1.0);
uniform float roughness = 1.0;
uniform float specular = 0.1;
uniform float ground_ao = 0.32;
uniform float ao_reach = 0.22;
uniform float sway = 0.0;
uniform float curve = 2.2;        // the painted tones are screen colours: this brings them to the light's own scale
uniform float depth = 0.56;       // ..and this much of that is the leaf's colour in full sun
uniform float flat_light = 0.75;  // how far every leaf's facing is turned towards the sky: painted, not modelled
global uniform float wetness;     // 0..1: how wet everything is (SurfaceWeather): darker, glossier
global uniform float snow_cover;  // 0..1: how much snow lies on what faces up (SurfaceWeather)
global uniform float wind;

varying float height;
varying vec3 tint;

#include "res://shaders/leaf_touch.gdshaderinc"
#include "res://shaders/finish.gdshaderinc"
varying float its_own;       // a number of this thing's own (finish_own): two of a kind differ a little
uniform int touch = 0;   // a limited tree's touch on its leaves (leaf_touch.gdshaderinc); 0: none

void vertex() {
	tint = COLOR.rgb;
	if (touch != 0) {
		tint = leaf_touch(touch, tint, (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - MODEL_MATRIX[3].xyz, TIME);
	}
	tint = pow(max(tint, vec3(0.0)), vec3(curve)) * depth;
	if (sway > 0.0) {
		vec3 root = MODEL_MATRIX[3].xyz;   // this instance's own foot: a MultiMesh's pieces each sway on their own beat
		float beat = TIME * 1.4 + root.x * 1.7 + root.z * 1.1;
		float bend = max(VERTEX.y, 0.0) * max(VERTEX.y, 0.0) * sway * (0.4 + wind);
		VERTEX.x += sin(beat) * bend;
		VERTEX.z += cos(beat * 0.8) * bend * 0.6;
	}
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	its_own = finish_own(MODEL_MATRIX[3].xyz);
}

void fragment() {
	float ao = mix(1.0 - ground_ao, 1.0, smoothstep(0.0, ao_reach, height));
	ALBEDO = finish_lean(albedo * tint, its_own) * ao;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(-0.3, 0.9, 0.3, 0.0)).xyz, flat_light));
	float snow_amt = snow_cover * smoothstep(0.5, 0.85, up);
	ALBEDO = mix(ALBEDO * (1.0 - 0.22 * wetness), vec3(0.93, 0.95, 1.0), snow_amt);
	ROUGHNESS = mix(ROUGHNESS * (1.0 - 0.45 * wetness), 0.9, snow_amt);
	AO = FINISH_AMBIENT;
}
