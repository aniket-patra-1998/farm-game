shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// The soft dark patch right under an animal, where its body blocks the sky (ambient occlusion). It sits on
// the grass and fades out at its rim; `strength` drops as the animal leaves the ground.

uniform float strength = 0.38;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.05, 0.08, 0.03);
	ALPHA = strength * (1.0 - smoothstep(0.15, 1.0, r)) * COLOR.a;
}
