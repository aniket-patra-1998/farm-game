shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// Still water (ponds, troughs, wells, birdbaths, fountain basins): small ripples crossing it and glints
// where they catch the sun, all from time and position, so it moves without any script.

uniform vec3 colour : source_color = vec3(0.32, 0.6, 0.78);
uniform float clarity = 0.92;      // alpha
uniform float ripple = 1.0;        // how strongly it ripples (0: glassy)
uniform vec3 sky : source_color = vec3(0.72, 0.86, 0.98);   // what grazing angles reflect
uniform vec3 deep : source_color = vec3(0.1, 0.32, 0.46);   // where it reads deeper

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz * 9.0;
	float t = TIME;
	// Three wave trains at angles to each other: their sum never visibly repeats.
	vec2 slope = vec2(cos(p.x * 1.0 + p.y * 0.4 + t * 2.1), cos(p.y * 1.3 - p.x * 0.5 + t * 1.7)) * 0.5
		+ vec2(cos(p.x * 2.3 - p.y * 1.1 - t * 2.9), cos(p.y * 2.1 + p.x * 0.9 + t * 2.3)) * 0.25;
	vec3 n = normalize(vec3(-slope.x * 0.08 * ripple, 1.0, -slope.y * 0.08 * ripple));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	// Sparkles: glints that blink on and off as the waves pass, not a steady shine.
	float twinkle = 0.5 + 0.5 * sin(t * 3.0 + p.x * 3.1 + p.y * 2.3);
	float glint = smoothstep(0.9, 0.98, slope.x * slope.y + 0.5) * ripple * (0.4 + 0.6 * twinkle);
	// Slow bands of light and dark drifting across: the look of depth and light bending through the water.
	float band = 0.5 + 0.5 * sin(p.x * 0.7 + p.y * 0.5 + t * 0.5 + slope.x * 1.5);
	vec3 body = mix(deep, colour, 0.55 + 0.45 * band);
	// Fresnel: seen from a low angle the surface mirrors the sky, from above it shows the water below.
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = mix(body * (0.92 + 0.08 * slope.x), sky, fres * 0.55) + vec3(glint * 0.3);
	ALPHA = mix(clarity, 1.0, fres);
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
}
