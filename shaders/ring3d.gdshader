shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
// A ring spreading on water (WaterRings: a swimmer's wake, a splash where the water is tapped, a fish's leap):
// a thin white circle lying on the surface that fades as it widens. One quad per ring in one MultiMesh; the
// quad's size is the ring's, and the instance's custom red channel how much of its life it has lived (0..1).

varying float age;

void vertex() {
	age = INSTANCE_CUSTOM.r;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float edge = fwidth(d) * 1.5;
	float ring = smoothstep(0.78 - edge, 0.84, d) * (1.0 - smoothstep(0.94, 0.98 + edge, d));
	ALBEDO = vec3(1.0);
	ALPHA = ring * 0.75 * (1.0 - age) * step(0.0, age);
}
