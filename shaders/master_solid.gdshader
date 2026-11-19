shader_type spatial;
// The master material every asset made as a file draws with (docs/ASSETS.md §3, docs/ART_BIBLE.md "Light"):
// its colour from its vertex colours (painted light baked in by the builder) times an optional palette or
// texture; live light from the sun and sky on top; a darker silhouette edge and a warm rim; contact shade near
// the ground; and the weather and night every surface shares (the global values).

uniform vec3 albedo : source_color = vec3(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform float roughness = 0.9;
uniform float specular = 0.15;
uniform float ground_ao = 0.28;   // how dark it gets where it meets the ground
uniform float ao_reach = 0.22;    // and how far up that shade fades (world units)
uniform float edge = 0.35;        // how dark the silhouette edge goes
uniform float rim = 0.25;         // the warm light edge
uniform float rim_tint = 0.75;    // how far the rim takes the light's colour (warm: the sun's in the day)
uniform float sway = 0.0;         // bends in the wind by height (foliage parts); 0: still
// What each part's vertex alpha carries, for a model merged into one surface of mixed finishes:
// 0 nothing; 1 its shine (ModelKit.paint); 2 its surface pattern and ground shade (ModelKit.wall_pack).
uniform int alpha_holds = 0;
global uniform float wetness;
global uniform float snow_cover;
global uniform float wind;

#include "res://shaders/surface_patterns.gdshaderinc"
// A limited animal's coat touch (CoatTouch): 0 for everything else, which then pays nothing for it.
uniform int touch = 0;
uniform vec3 touch_colour = vec3(0.0);   // the coat's own colour (what a star fades into), as the file's colours are
#include "res://shaders/coat_touch.gdshaderinc"

varying float height;
varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	if (touch != 0) {
		COLOR.rgb = coat_touch(touch, touch_colour, COLOR.rgb, UV, UV2, TIME);
	}
	if (sway > 0.0) {
		vec3 root = MODEL_MATRIX[3].xyz;
		float beat = TIME * 1.4 + root.x * 1.7 + root.z * 1.1;
		float bend = max(VERTEX.y, 0.0) * max(VERTEX.y, 0.0) * sway * (0.4 + wind);
		VERTEX.x += sin(beat) * bend;
		VERTEX.z += cos(beat * 0.8) * bend * 0.6;
	}
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	float snow_amt = snow_cover * smoothstep(0.5, 0.85, up);
	if (alpha_holds == 2) {
		// A patterned surface (walls, roofs, stone): the pattern and the shade at its foot ride in the alpha.
		int k = int(round(COLOR.a * 255.0));
		int style_k = k / 32;
		vec3 col = surface_pattern(albedo * COLOR.rgb, style_k, local_pos, local_normal, 1.0);
		col *= mix(0.9, 1.06, smoothstep(0.0, 1.3, height));   // (lighter towards the top, as the sky lights it)
		col *= mix(1.0 - float(k % 32) * 0.02, 1.0, smoothstep(0.0, 0.35, height));
		ALBEDO = mix(col * (1.0 - 0.22 * wetness), vec3(0.93, 0.95, 1.0), snow_amt);
		ROUGHNESS = mix((style_k == 5 ? 0.45 : 0.9) * (1.0 - 0.45 * wetness), 0.9, snow_amt);
		METALLIC = style_k == 5 ? 0.3 : 0.0;
		SPECULAR = style_k == 5 ? 0.35 : 0.08;
	} else {
		vec3 base = albedo * COLOR.rgb;
		if (use_texture) {
			base *= texture(albedo_texture, UV).rgb;
		}
		float ao = mix(1.0 - ground_ao, 1.0, smoothstep(0.0, ao_reach, height));
		float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		ALBEDO = base * ao * mix(1.0 - edge, 1.0, smoothstep(0.0, 0.5, facing));
		ALBEDO = mix(ALBEDO * (1.0 - 0.22 * wetness), vec3(0.93, 0.95, 1.0), snow_amt);
		// (a part's own shine: the same curve as ModelKit.paint's)
		float rough = alpha_holds == 1 ? 1.0 - COLOR.a * 0.6 : roughness;
		ROUGHNESS = mix(rough * (1.0 - 0.45 * wetness), 0.9, snow_amt);
		SPECULAR = alpha_holds == 1 ? 0.1 + COLOR.a * 0.4 : specular;
		RIM = rim;
		RIM_TINT = rim_tint;
	}
}
