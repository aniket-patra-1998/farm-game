shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;
// The glint over a ripe plot that holds a find (Glints3D): a four-pointed star that twinkles on and off, in the
// colour of how rare the find is (the instance's colour), so luck is seen in the field before the harvest.
// It faces the camera, drifts a little, and each one twinkles on its own beat (the instance's custom red). Added
// to what is behind it, so it glows; hidden behind what stands in front (a tree, a barn), like the crop is.

uniform float rate = 2.6;        // how fast it twinkles
uniform float drift = 0.035;     // tiles it rises and falls
varying float glow;              // 0..1: how bright this twinkle is now

void vertex() {
	float t = TIME * rate + INSTANCE_CUSTOM.r * 6.2831;
	// Mostly dim, with a bright flash each beat and a smaller one between: a glint, not a lamp.
	glow = 0.28 + 0.72 * pow(max(sin(t), 0.0), 5.0) + 0.3 * pow(max(sin(t * 2.0 + 1.3), 0.0), 9.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= 0.6 + 0.55 * glow;
	VERTEX.y += sin(t * 0.5) * drift;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// A four-pointed star: bright along the two axes, falling off fast away from them and with distance.
	float arms = 1.0 / (1.0 + 90.0 * abs(p.x * p.y));
	float reach = clamp(1.0 - length(p), 0.0, 1.0);
	float star = arms * reach * reach;
	float core = pow(clamp(1.0 - length(p) * 2.6, 0.0, 1.0), 2.0);
	float halo = reach * reach * 0.22;
	float a = clamp(star + core + halo, 0.0, 1.0) * glow;
	ALBEDO = mix(COLOR.rgb, vec3(1.0), core * 0.8) * a;
	ALPHA = a;
}
