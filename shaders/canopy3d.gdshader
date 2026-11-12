shader_type spatial;
// A leafy canopy: the painted look of paint3d (ground shade, dark silhouette edge, wind sway) plus a leaf pattern:
// small clusters of leaves, each a little lighter on top and darker in a crescent underneath, like FarmVille's
// painted foliage. The colour of each part is in its vertices (white albedo), so canopies merge into one draw.

uniform vec3 albedo : source_color = vec3(1.0);
uniform float roughness = 1.0;
uniform float specular = 0.1;
uniform float ground_ao = 0.32;
uniform float ao_reach = 0.22;
uniform float edge = 0.42;         // the dark inked edge: stronger than a plain part's, so a crown reads against the sky and grass
uniform float rim = 0.1;
uniform float sway = 0.0;
uniform float leaf_scale = 10.0;   // clusters per world unit
uniform float leaf_dark = 0.3;     // how dark the crescent under each cluster goes
uniform float leaf_light = 0.14;   // and how much lighter its top
global uniform float wetness;     // 0..1: how wet everything is (SurfaceWeather): darker, glossier
global uniform float snow_cover;  // 0..1: how much snow lies on what faces up (SurfaceWeather)
global uniform float wind;

varying float height;
varying vec3 tint;
varying vec3 local;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	tint = COLOR.rgb;
	local = VERTEX;
	if (sway > 0.0) {
		vec3 root = MODEL_MATRIX[3].xyz;   // this instance's own foot: a MultiMesh's pieces each sway on their own beat
		float beat = TIME * 1.4 + root.x * 1.7 + root.z * 1.1;
		float bend = max(VERTEX.y, 0.0) * max(VERTEX.y, 0.0) * sway * (0.4 + wind);
		VERTEX.x += sin(beat) * bend;
		VERTEX.z += cos(beat * 0.8) * bend * 0.6;
	}
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float ao = mix(1.0 - ground_ao, 1.0, smoothstep(0.0, ao_reach, height));
	// Leaf clusters: a jittered grid in the tree's own space; inside each cell a round cluster, shaded by where
	// the point lies on it (up: light, below its centre: the crescent of shadow).
	vec3 q = local * leaf_scale;
	vec3 cell = floor(q);
	vec3 f = fract(q) - 0.5;
	f += (vec3(hash(cell), hash(cell + 7.1), hash(cell + 13.7)) - 0.5) * 0.35;
	float d = length(f);
	float cluster = smoothstep(0.6, 0.2, d);
	float under = smoothstep(0.0, 0.45, -f.y) * cluster;
	float over = smoothstep(0.05, 0.4, f.y) * cluster;
	float pattern = 1.08 - leaf_dark * under + leaf_light * over;
	ALBEDO = albedo * tint * ao * pattern;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO *= mix(1.0 - edge, 1.0, smoothstep(0.0, 0.5, facing));
	// Weather on the surface: wet things are darker and glossier; snow lies on what faces up.
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	float snow_amt = snow_cover * smoothstep(0.5, 0.85, up);
	ALBEDO = mix(ALBEDO * (1.0 - 0.22 * wetness), vec3(0.93, 0.95, 1.0), snow_amt);
	ROUGHNESS = mix(ROUGHNESS * (1.0 - 0.45 * wetness), 0.9, snow_amt);
	RIM = rim;
	RIM_TINT = 0.9;
}
