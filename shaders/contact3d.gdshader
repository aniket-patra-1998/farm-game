shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// The soft dark patch right under an animal or a standing thing, where its body blocks the sky (ambient
// occlusion): what gives it weight on the ground. It is all but black, so it darkens whatever lies under it by
// the same share (wet earth and night grass as much as sunlit lawn), most right under the body (`CORE`) and
// fading out at its rim; `strength` drops as an animal leaves the ground. By night, with no cast shadow to hold
// a thing down, it is drawn stronger (`NIGHT_MORE`).

uniform float strength = 0.38;

global uniform float dark;         // 0..1: how far into the night it is

const vec3 SHADE = vec3(0.012, 0.02, 0.01);
const float CORE = 0.5;            // of the patch's reach, the part right under the body..
const float CORE_SHARE = 0.4;      // ..and its share of the darkness
const float NIGHT_MORE = 0.9;      // how much stronger the shade is drawn in full night
const float MOST = 0.85;           // it never blots the ground out

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float soft = 1.0 - smoothstep(0.15, 1.0, r);
	float core = 1.0 - smoothstep(0.0, CORE, r);
	ALBEDO = SHADE;
	ALPHA = min(strength * COLOR.a * mix(soft, core, CORE_SHARE) * (1.0 + NIGHT_MORE * dark), MOST);
}
