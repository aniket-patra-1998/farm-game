// The finish every solid thing on the farm shares (docs/WORLD.md "One finish"; the owner's pick of 26 Nov, sheet
// option C): animals, buildings, decorations, fences and trees are lit and painted by the same rule, so they sit
// in one world.
//   Sun and shade (`light`): the sun's side is warm, the side turned from it is filled with cool sky light, and
//     there is less flat all-round light (`FINISH_AMBIENT`, set as AO by each shader), so a thing has a lit side
//     and a shaded one. Other lights (a lamp, a fire) light it plainly.
//   Painted (`finish_painted`): broad brushy patches of lighter and darker, each thing leaning a little warm or
//     cool of its own (two of a kind are never the same colour), darker towards its foot.
// A shader that includes this gets `light()` and calls `finish_painted` (or `finish_lean`, for leaves, which have
// a pattern of their own) on its colour, and sets `AO = FINISH_AMBIENT`.

global uniform float finish_grain;   // 0: no brushy patches (Quality `finish_grain`: they are worked out per pixel)

const float FINISH_AMBIENT = 0.62;                    // how much of the all-round light is left
const vec3 FINISH_SUN = vec3(1.254, 1.122, 0.924);    // the sun's light, warmed (and a tenth stronger)
const vec3 FINISH_SKY = vec3(0.044, 0.064, 0.156);    // the sky's cool light on a side turned from the sun
const vec3 FINISH_EDGE = vec3(0.6, 0.528, 0.396);     // a warm light edge on the sun's side (the rim it replaces)
const float FINISH_EDGE_SHARP = 3.0;
const float FINISH_GLINT_WIDE = 8.0;                  // how wide the sun's shine is on a dull surface
const float FINISH_GLINT = 120.0;                     // ..and how much tighter on the glossiest
const vec3 PATCH_BROAD = vec3(2.2, 1.1, 2.2);         // a patch is about half a tile across, taller than wide
const float PATCH_FINE = 6.5;                         // ..with a finer grain in it
const float PATCH_BROAD_SHARE = 0.65;
const float PATCH_DARK = 0.86;
const float PATCH_LIGHT = 1.12;
const vec3 LEAN_WARM = vec3(1.035, 1.0, 0.95);        // what a thing's own number leans its colour between
const vec3 LEAN_COOL = vec3(0.96, 1.0, 1.045);
const float FOOT_DARK = 0.8;                          // how dark a thing is where it stands
const float FOOT_LIGHT = 1.05;                        // ..and how light above `reach`
const float FOOT_REACH = 0.55;                        // how far up the dark of its foot fades (tiles)
const float FOOT_REACH_WALL = 1.1;                    // ..on a wall or a roof, which stands taller
const float FOOT_REACH_LOW = 0.18;                    // ..on a thing built low (a fence, a decoration), which would
                                                      // else be dark all the way up

// A number of a thing's own, 0 to 1, from where it stands (`foot`: MODEL_MATRIX[3].xyz).
float finish_own(vec3 foot) {
	return fract(sin(dot(foot.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

float finish_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float finish_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float near = mix(mix(finish_hash(i), finish_hash(i + vec3(1.0, 0.0, 0.0)), f.x),
		mix(finish_hash(i + vec3(0.0, 1.0, 0.0)), finish_hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float far = mix(mix(finish_hash(i + vec3(0.0, 0.0, 1.0)), finish_hash(i + vec3(1.0, 0.0, 1.0)), f.x),
		mix(finish_hash(i + vec3(0.0, 1.0, 1.0)), finish_hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(near, far, f.z);
}

// `col` leaning warm or cool by the thing's own number.
vec3 finish_lean(vec3 col, float number) {
	return col * mix(LEAN_WARM, LEAN_COOL, number);
}

// `col` as painted: at world place `at`, `above` the ground, on a thing whose own number is `number`.
vec3 finish_painted(vec3 col, vec3 at, float number, float above, float reach) {
	if (finish_grain > 0.0) {
		float patch = finish_noise(at * PATCH_BROAD) * PATCH_BROAD_SHARE
			+ finish_noise(at * PATCH_FINE) * (1.0 - PATCH_BROAD_SHARE);
		col *= mix(PATCH_DARK, PATCH_LIGHT, patch);
	}
	return finish_lean(col, number) * mix(FOOT_DARK, FOOT_LIGHT, smoothstep(0.0, reach, above));
}

void light() {
	float facing = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = facing * ATTENUATION;
		float edge_light = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), FINISH_EDGE_SHARP) * lit;
		DIFFUSE_LIGHT += LIGHT_COLOR * (FINISH_SUN * lit + FINISH_SKY * (1.0 - lit) + FINISH_EDGE * edge_light) / PI;
	} else {
		DIFFUSE_LIGHT += facing * ATTENUATION * LIGHT_COLOR / PI;
	}
	// (the shine a wet or polished surface had from the engine's own lighting, which this replaces: none on a
	// rough one, a tight glint on a glossy one)
	float gloss = (1.0 - ROUGHNESS) * (1.0 - ROUGHNESS);
	float glint = pow(clamp(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0, 1.0), FINISH_GLINT_WIDE + FINISH_GLINT * gloss);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * glint * gloss * SPECULAR_AMOUNT;
}
