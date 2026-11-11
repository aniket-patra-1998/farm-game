shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// Still water (ponds, troughs, wells, birdbaths, fountain basins): small ripples crossing it and glints
// where they catch the sun, all from time and position, so it moves without any script.

uniform vec3 colour : source_color = vec3(0.32, 0.6, 0.78);
uniform float clarity = 0.92;      // alpha
uniform float ripple = 1.0;        // how strongly it ripples (0: glassy)

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
	float glint = smoothstep(0.9, 0.98, slope.x * slope.y + 0.5) * ripple;
	ALBEDO = colour * (0.92 + 0.08 * slope.x) + vec3(glint * 0.18);
	ALPHA = clarity;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
}
