shader_type spatial;
// Walls and roofs of the farm's buildings, in local object space so patterns stay put as buildings move:
// 0 boards (clapboard with shadowed laps), 1 logs, 2 stone, 3 plaster, 4 shingles (roofs), 5 corrugated
// metal, 6 planks (a barn's upright boards and battens). Every surface also darkens toward the ground (ambient occlusion), which is what makes a building
// look like it sits on the earth rather than floating over it.

uniform vec3 base_color : source_color = vec3(0.8, 0.3, 0.2);
uniform int style = 0;
uniform float scale = 1.0;      // pattern size: 1 is a board about a twelfth of a tile high
uniform float ground_ao = 0.45; // how dark the foot of the wall gets
uniform bool packed_in_alpha = false;  // each part's style and ground shade ride in its vertex alpha (ModelKit.wall_pack)

global uniform float wetness;     // 0..1: how wet everything is (SurfaceWeather): darker, glossier
global uniform float snow_cover;  // 0..1: how much snow lies on what faces up (SurfaceWeather)

varying vec3 local_pos;
varying vec3 local_normal;
varying float height;

#include "res://shaders/surface_patterns.gdshaderinc"

varying vec3 tint;  // the part's colour when baked into a merged mesh (white if none)
varying float pack; // and its style and ground shade, when they ride in the vertex alpha

void vertex() {
	tint = COLOR.rgb;
	pack = COLOR.a;
	local_pos = VERTEX;
	local_normal = NORMAL;
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 col = base_color * tint;
	int style_k = style;
	float ao_k = ground_ao;
	if (packed_in_alpha) {
		int k = int(round(pack * 255.0));
		style_k = k / 32;
		ao_k = float(k % 32) * 0.02;
	}
	col = surface_pattern(col, style_k, local_pos, local_normal, scale);
	// Lighter towards the top, as the sky lights it: a wall is never one flat colour.
	col *= mix(0.9, 1.06, smoothstep(0.0, 1.3, height));
	col *= mix(1.0 - ao_k, 1.0, smoothstep(0.0, 0.35, height));
	ALBEDO = col;
	ROUGHNESS = style_k == 5 ? 0.45 : 0.9;
	// Weather on the surface: wet things are darker and glossier; snow lies on what faces up.
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	float snow_amt = snow_cover * smoothstep(0.5, 0.85, up);
	ALBEDO = mix(ALBEDO * (1.0 - 0.22 * wetness), vec3(0.93, 0.95, 1.0), snow_amt);
	ROUGHNESS = mix(ROUGHNESS * (1.0 - 0.45 * wetness), 0.9, snow_amt);

	METALLIC = style_k == 5 ? 0.3 : 0.0;
	SPECULAR = style_k == 5 ? 0.35 : 0.08;
}
