shader_type spatial;
render_mode cull_disabled;
// Crop plants, drawn for a whole field at once through MultiMeshes. Leaves carry their own green in the
// vertex colour; produce (vertex alpha 0) takes its crop's colour from the material (one per crop colour),
// shaded by the vertex colour. Plants sway from the root, tips most, harder in wind, each on its own beat.
// Growth is done here, continuously, from the farm's clock every frame, so a crop's whole life is one smooth
// change and nothing snaps: each stage starts at the size the stage before it ended at and swells to full; the
// ripe plant is drawn from before it is ripe, its fruit as green as its leaves and taking its colour as it
// ripens; and a ripe crop left too long yellows, browns and droops little by little before it withers.
// INSTANCE_CUSTOM is (x: when this stretch began, in minutes on the farm clock; y: how long it lasts, positive
// for growing, negative for wilting, 0 for neither; z: fertilised (1) plus the size it grows from (under 1);
// w: ripening (1) plus how far the crop is mastered (under 1)). (Kept small on purpose: the compatibility renderer stores per-
// instance data as 16-bit floats, which overflow to infinity past 65,504 and are coarse past 2,048.)

global uniform float wind;        // the weather's wind, set once for everything (Farm3D)
global uniform float crop_clock;  // seconds on the farm's clock (Crops3D), the same for every plant
uniform vec3 dry : source_color = vec3(0.60, 0.48, 0.26);   // a withered plant's leaves (CropModels.DRY)
uniform vec3 unripe : source_color = vec3(0.40, 0.62, 0.22);   // fruit that has only just set: leaf green
uniform float droop = 0.5;        // how much lower a fully wilted plant stands
uniform float master_size = 0.1;  // how much bigger a fully mastered crop's plants are
uniform float rich_size = 1.18;   // a fertilised plant's size, of an ordinary one's
uniform vec3 produce_colour : source_color = vec3(0.89, 0.27, 0.24);   // this crop's fruit, grain or flower

varying vec4 produce;
varying float gold;   // 0..1: how far this crop is mastered (its stars): fuller, with a golden cast
varying float ripen;  // 0..1: how far its fruit has taken its colour (1 for anything not ripening)
varying float wilt;   // 0..1: how far a ripe plant has wilted towards withering
varying float up;   // how far up the plant this point is, 0 at the soil
varying vec2 cloud_xz;   // where the plant stands, for the cloud shadows

#include "res://shaders/cloud_shade.gdshaderinc"

void vertex() {
	float rich_flag = step(1.0, INSTANCE_CUSTOM.z);
	float size_from = fract(INSTANCE_CUSTOM.z);
	produce = vec4(produce_colour, 1.0 - rich_flag);
	up = clamp(VERTEX.y / 0.35, 0.0, 1.0);
	float stretch = INSTANCE_CUSTOM.y;
	float along = stretch != 0.0 ? clamp((crop_clock / 60.0 - INSTANCE_CUSTOM.x) / abs(stretch), 0.0, 1.0) : 1.0;
	float grown = stretch > 0.0 ? along : 1.0;
	wilt = stretch < 0.0 ? along : 0.0;
	ripen = mix(1.0, grown, step(1.0, INSTANCE_CUSTOM.w));
	gold = fract(INSTANCE_CUSTOM.w) / 0.9;
	float grow_scale = stretch > 0.0 ? mix(size_from, 1.0, grown) : 1.0;
	VERTEX *= grow_scale * mix(1.0, rich_size, rich_flag) * (1.0 + master_size * gold);
	// Wilting: it sinks and sprawls a little, the way a thirsty plant does.
	VERTEX.y *= 1.0 - droop * wilt * wilt;
	VERTEX.xz *= 1.0 + 0.12 * wilt;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	cloud_xz = root.xz;
	float beat = TIME * 1.9 + root.x * 1.3 + root.z * 0.9;
	float bend = VERTEX.y * VERTEX.y * 3.0 * (0.4 + wind) * (1.0 - 0.6 * wilt);   // (a dry plant barely sways)
	VERTEX.x += sin(beat) * 0.05 * bend;
	VERTEX.z += cos(beat * 0.7) * 0.035 * bend;
}

void fragment() {
	vec3 leaf = COLOR.rgb;
	vec3 fruit = produce.rgb * (0.55 + 0.6 * COLOR.r);
	float is_produce = 1.0 - step(0.5, COLOR.a);
	// Darker at the soil, sunlit at the tips: depth and form on a plant that is a few triangles.
	float lit = mix(0.72, 1.12, up);
	float rich = 1.0 - produce.a;     // fertilised: lusher, deeper colour, a gloss on the leaves
	leaf = mix(leaf, leaf * vec3(0.88, 1.18, 0.82) + vec3(0.0, 0.04, 0.0), rich);
	// Mastered (our own touch: progress shown in the field, not only in a book): a warm golden cast, brighter fruit.
	leaf = mix(leaf, leaf * vec3(1.12, 1.06, 0.72) + vec3(0.035, 0.025, 0.0), gold * 0.8);
	fruit = mix(fruit, fruit * 1.12 + vec3(0.05, 0.035, 0.0), gold);
	// Ripening: the fruit starts as green as the leaves and takes its colour as the crop comes ripe.
	fruit = mix(unripe * (0.55 + 0.6 * COLOR.r), fruit, smoothstep(0.1, 1.0, ripen));
	// Wilting: the leaves yellow, then dry to the brown of a withered crop; the fruit dulls and darkens.
	leaf = mix(leaf, mix(leaf * vec3(1.25, 1.1, 0.55), dry, smoothstep(0.35, 1.0, wilt)), smoothstep(0.0, 0.5, wilt));
	fruit = mix(fruit, fruit * 0.5 + dry * 0.22, smoothstep(0.2, 1.0, wilt));
	ALBEDO = mix(leaf, fruit, is_produce) * lit * (1.0 + 0.1 * rich);
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO *= mix(0.7, 1.0, smoothstep(0.0, 0.5, facing)) * cloud_light(cloud_xz, TIME);
	RIM = 0.1;
	RIM_TINT = 0.9;
	ROUGHNESS = mix(0.85, 0.45, is_produce);
	SPECULAR = mix(0.1, 0.35, is_produce) + 0.2 * rich * (1.0 - is_produce);
	BACKLIGHT = vec3(0.2, 0.3, 0.08) * (1.0 - is_produce);
}
