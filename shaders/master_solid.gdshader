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
uniform float sway = 0.0;         // bends in the wind by height (foliage parts); 0: still
global uniform float wetness;
global uniform float snow_cover;
global uniform float wind;

varying float height;

void vertex() {
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
	vec3 base = albedo * COLOR.rgb;
	if (use_texture) {
		base *= texture(albedo_texture, UV).rgb;
	}
	float ao = mix(1.0 - ground_ao, 1.0, smoothstep(0.0, ao_reach, height));
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = base * ao * mix(1.0 - edge, 1.0, smoothstep(0.0, 0.5, facing));
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	float snow_amt = snow_cover * smoothstep(0.5, 0.85, up);
	ALBEDO = mix(ALBEDO * (1.0 - 0.22 * wetness), vec3(0.93, 0.95, 1.0), snow_amt);
	ROUGHNESS = mix(roughness * (1.0 - 0.45 * wetness), 0.9, snow_amt);
	SPECULAR = specular;
	RIM = rim;
	RIM_TINT = 0.75;   // (warm: tinted toward the light's colour, the sun's in the day)
}
