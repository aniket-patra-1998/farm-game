shader_type spatial;
render_mode cull_disabled;
// Plowed soil, FarmVille's way: a clean, low, warm red-brown bed with a handful of thin furrows drawn along it,
// a darker rim, and corners a little rounded. The furrows are lit (the surface's normal tilts into each one),
// so they read as worked earth and not as painted stripes, and stop short of the rim. A fine crumb keeps the
// bed from being flat colour. Damp where fertilized (the instance colour's alpha).

uniform vec3 soil : source_color = vec3(0.47, 0.295, 0.19);    // the bed
uniform vec3 furrow : source_color = vec3(0.31, 0.175, 0.10);  // down in a furrow, and the rim
uniform float row_gap = 0.15;     // between furrows: five to a bed
uniform float relief = 0.55;      // how steeply a furrow's sides are lit
uniform float half_width = 0.45;  // the bed's foot from its middle, in tiles (Plots3D.BED / 2)..
uniform float top_half = 0.40;    // ..and where its flat top ends (less Plots3D.BEVEL)
uniform float corner = 0.06;      // how round the bed's corners are

global uniform float snow_cover;  // 0..1 (SurfaceWeather): snow settles on the ridges first, the furrows last
varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 local;
varying vec4 tint;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	local = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tint = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 p = world_pos.xz;
	// How far out from the bed's middle, measured round its rounded corners.
	vec2 q = max(abs(local.xz) - vec2(half_width - corner), vec2(0.0));
	if (length(q) > corner) {
		discard;   // the corners are rounded off
	}
	vec2 q_top = max(abs(local.xz) - vec2(top_half - corner), vec2(0.0));
	float out_d = length(q_top) + top_half - corner;
	float rim = smoothstep(top_half - 0.045, top_half - 0.005, out_d);
	// Furrows along the bed, stopping short of its rim.
	float inside = smoothstep(top_half - 0.04, top_half - 0.1, abs(local.z))
		* smoothstep(top_half - 0.02, top_half - 0.07, abs(local.x));
	float turn = (local.x / row_gap) * 6.2831853 + 3.1415927;
	float trough = smoothstep(0.55, 0.97, 0.5 - 0.5 * cos(turn)) * inside;
	float crumb = noise(p * 26.0) * 0.6 + noise(p * 61.0) * 0.4;
	// (the short slope round the bed is lit nearly as its top is: a side in the sun's shade would be a black edge)
	vec3 lit = normalize(mix(world_normal, vec3(0.0, 1.0, 0.0), 0.65) + vec3(-sin(turn) * relief * inside, 0.0, 0.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(lit, 0.0)).xyz);
	vec3 col = soil * (0.93 + 0.14 * crumb);
	col *= 1.0 - 0.12 * smoothstep(0.22, 0.1, noise(p * 90.0));   // the odd dark speck
	col = mix(col, furrow, trough * 0.85);
	col = mix(col, furrow * 1.15, rim * 0.6);
	float wet = tint.a;
	col = mix(col, col * vec3(0.7, 0.66, 0.68), wet);
	if (snow_cover > 0.001) {
		float drift = noise(p * 3.1);
		float snowy = smoothstep(0.0, 0.35, snow_cover * 1.3 - trough * 0.55 - drift * 0.3);
		col = mix(col, vec3(0.9, 0.93, 0.98) * (0.94 + 0.08 * crumb), snowy);
	}
	ALBEDO = col;
	ROUGHNESS = mix(1.0, 0.55, wet);
	SPECULAR = 0.15;
}
