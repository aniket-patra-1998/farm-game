shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;
// Marks left on the ground (Trails): a footprint is a pair of soft ovals (heel and toe), a wheel track a
// strip with tread bars across it. They are quads lying flat; INSTANCE_CUSTOM carries (kind, age 0..1):
// kind 0 a footprint, 1 a tread. They press in dark at first and fade out as they age.

uniform vec3 mark : source_color = vec3(0.17, 0.12, 0.07);
uniform float strength = 0.65;

varying vec2 info;

void vertex() {
	info = INSTANCE_CUSTOM.xy;
}

void fragment() {
	vec2 uv = UV;
	float shape;
	if (info.x < 0.5) {
		// Heel (round, behind) and the ball of the foot (wider, in front); uv.y runs toe to heel.
		float heel = 1.0 - smoothstep(0.0, 1.0, length((uv - vec2(0.5, 0.78)) / vec2(0.3, 0.17)));
		float ball = 1.0 - smoothstep(0.0, 1.0, length((uv - vec2(0.5, 0.35)) / vec2(0.4, 0.3)));
		shape = max(heel, ball);
	} else {
		// A strip with a soft edge, and a bar every so often across it (the tread; its length is in the uv).
		float edge = smoothstep(0.0, 0.22, uv.x) * smoothstep(1.0, 0.78, uv.x);
		float bars = 0.7 + 0.3 * step(0.5, fract(uv.y * 40.0));
		shape = edge * bars * smoothstep(0.0, 0.03, uv.y) * smoothstep(1.0, 0.97, uv.y);
	}
	ALBEDO = mark;
	ALPHA = shape * strength * (1.0 - info.y) * (1.0 - info.y);
	ROUGHNESS = 1.0;
}
