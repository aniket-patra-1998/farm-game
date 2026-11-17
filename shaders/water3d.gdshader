shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// Still water (ponds, troughs, wells, birdbaths, basins, pools): calm and deep. Its depth is its colour (pale
// and clear over a pond's shallows, deep blue in its middle), a web of light moves slowly over its bed, a thin
// line of foam laps at a pond's bank, and glints blink where the light catches. The weather shows on it:
// rain fills it with small rings, wind hurries it, snow freezes it over; at night it glitters under the moon.
// All from time, position and the farm's global moods, so it moves without any script, and every water on
// the farm is this one material (DecorMotion.water, pond_water).

global uniform float wind;         // the weather's wind
global uniform float rain;         // 0..1: how hard it rains now (SurfaceWeather)
global uniform float snow_cover;   // 0..1: how much snow lies (SurfaceWeather): the water freezes over
global uniform float dark;         // 0..1: how far into the night it is
uniform float ripple = 1.0;        // how lively it is (0: glassy)
// A pond (PondModel): UV.x runs from its middle (0) to its shore (1). 0 for water with no shore (troughs,
// basins): that is one depth all over.
uniform float shore_fade = 0.0;
uniform vec3 pale : source_color = vec3(0.60, 0.90, 0.88);     // over the shallows
uniform vec3 mid : source_color = vec3(0.16, 0.60, 0.84);
uniform vec3 depths : source_color = vec3(0.05, 0.27, 0.56);   // the middle of a pond
uniform vec3 ice : source_color = vec3(0.80, 0.90, 0.96);
uniform vec3 moon : source_color = vec3(0.86, 0.92, 1.0);
uniform float basin_depth = 0.55;  // how deep water with no shore reads (0 pale .. 1 the depths)

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Rings spreading from raindrops that fall here and there, each fading as it widens.
float rings(vec2 p, float t) {
	float sum = 0.0;
	vec2 cell = floor(p);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cell + vec2(float(i), float(j));
			float h = hash(c);
			float age = fract(t * 0.9 + h);
			float d = length(p - c - vec2(hash(c + 3.1), hash(c + 7.7)));
			sum += smoothstep(0.09, 0.0, abs(d - age * 0.7)) * (1.0 - age);
		}
	}
	return sum;
}

// Glints that blink where the light catches: a few by day, a glitter of them under the moon.
float glints(vec2 p, float t, float share) {
	vec2 c = floor(p * 5.0);
	vec2 f = fract(p * 5.0) - 0.5;
	float h = hash(c);
	float on = smoothstep(0.75, 1.0, sin(t * 2.0 + h * 40.0)) * step(1.0 - share, h);
	return on * smoothstep(0.16, 0.0, abs(f.x) + abs(f.y));
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float frozen = smoothstep(0.35, 0.7, snow_cover);
	float lively = ripple * (0.6 + 0.6 * wind) * (1.0 - frozen);
	float t = TIME * (0.7 + 0.5 * wind);
	// How deep it is here: 1 in the middle of a pond, 0 at its shore.
	float d = shore_fade > 0.0 ? 1.0 - UV.x : basin_depth;
	vec3 body = mix(mix(pale, mid, smoothstep(0.0, 0.38, d)), depths, smoothstep(0.35, 0.9, d));
	// The web of light on the bed: bright where it is shallow, lost in the depths.
	vec2 q = p * 7.0;
	q += vec2(sin(q.y * 0.9 + t * 0.7), cos(q.x * 0.8 - t * 0.6)) * 0.9;
	float web = pow(0.5 + 0.5 * sin(q.x + sin(q.y * 1.3 + t * 0.5)) * sin(q.y + sin(q.x * 1.2 - t * 0.4)), 4.0);
	body += vec3(0.75, 0.95, 1.0) * web * 0.35 * (1.0 - d * 0.6) * (1.0 - dark * 0.7) * (1.0 - frozen);
	// Rain: small rings all over it.
	if (rain > 0.01 && frozen < 0.99) {   // (the rings cost nine looks a pixel: only while it rains)
		body = mix(body, vec3(1.0), clamp(rings(p * 5.0, TIME), 0.0, 1.0) * 0.55 * rain * (1.0 - frozen));
	}
	// The bank of a pond: a thin line of foam lapping in and out.
	float foam = 0.0;
	if (shore_fade > 0.0) {
		float lap = 0.96 + 0.02 * sin(t * 1.3 + (p.x - p.y) * 7.0) * lively;
		foam = smoothstep(lap - 0.04, lap - 0.01, UV.x) * 0.7;
	}
	// Frozen over: pale ice, clouded in patches, a crack or two across it.
	float cloud = 0.5 + 0.5 * sin(p.x * 3.1 + sin(p.y * 2.3) * 1.7) * sin(p.y * 2.7 + sin(p.x * 1.9));
	float crack = smoothstep(0.03, 0.0, abs(sin(p.x * 2.1 + p.y * 3.3 + sin(p.y * 4.0) * 0.6))) * step(0.5, hash(floor(p * 1.3)));
	vec3 sheet = mix(ice * (0.9 + 0.1 * cloud), vec3(1.0), crack * 0.6);
	body = mix(mix(body, vec3(1.0), foam), sheet, frozen);
	// What catches the light: glints by day, the moon's glitter by night.
	float spark = glints(p, t, 0.14 + 0.3 * dark) * lively;
	vec2 slope = vec2(cos(p.x * 9.0 + p.y * 3.6 + t * 2.1), cos(p.y * 11.7 - p.x * 4.5 + t * 1.7)) * 0.5;
	vec3 n = normalize(vec3(-slope.x * 0.04 * lively, 1.0, -slope.y * 0.04 * lively));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	ALBEDO = body + mix(vec3(0.9), moon * 1.4, dark) * spark;
	ALPHA = mix(mix(mix(0.72, 0.97, smoothstep(0.0, 0.4, d)), 1.0, foam), 1.0, frozen);
	ROUGHNESS = mix(0.06, 0.5, frozen);
	SPECULAR = mix(0.9, 0.4, frozen);
}
