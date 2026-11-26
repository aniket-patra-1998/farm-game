shader_type spatial;
// A crop painted as a flat picture (PaintedCrops): a card facing the camera, which never turns, so the card is the
// plant. The picture's tones are its shading: the sun lights the whole card alike (as crown3d does a tree's crown),
// so it still dims at night and darkens in rain. It bends in the wind from its foot, and a withered crop is the
// ripe picture gone dry and sunk.
render_mode cull_disabled, shadows_disabled;

uniform sampler2D picture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 card = vec2(1.3, 1.0);   // the card's size, in tiles
uniform float cutoff = 0.5;
uniform float depth = 0.6;        // how much of the picture's colour shows in full sun (crown3d's `depth`)
uniform vec3 dry : source_color = vec3(0.60, 0.48, 0.26);   // a withered plant (CropModels.DRY)
uniform float droop = 0.16;       // how much lower a withered plot stands
uniform float rich_size = 1.08;   // a fertilised plot's size, of an ordinary one's
uniform float sway = 0.018;       // how far the top of a card leans in the wind, in tiles
global uniform float wind;
global uniform float wetness;

#include "res://shaders/finish.gdshaderinc"

varying float withered;   // 0 a living plot .. 1 a withered one
varying float gold;       // 0..1: how far this crop is mastered: a golden cast

void vertex() {
	withered = INSTANCE_CUSTOM.r;
	gold = INSTANCE_CUSTOM.b;
	float foot = -0.5 * card.y;
	float up = (VERTEX.y - foot) / card.y;   // 0 at the card's foot .. 1 at its top
	float size = mix(1.0, rich_size, INSTANCE_CUSTOM.g);
	VERTEX.x *= size;
	VERTEX.y = foot + (VERTEX.y - foot) * size * (1.0 - droop * withered);
	vec3 root = MODEL_MATRIX[3].xyz;   // this plot's own place: every plot sways on its own beat
	VERTEX.x += sin(TIME * 1.9 + root.x * 1.3 + root.z * 0.9) * up * up * sway * (0.4 + wind) * (1.0 - 0.6 * withered);
}

void fragment() {
	vec4 paint = texture(picture, UV);
	ALPHA = paint.a;
	ALPHA_SCISSOR_THRESHOLD = cutoff;
	vec3 col = paint.rgb;
	col = mix(col, dry * (0.45 + 0.9 * dot(col, vec3(0.3, 0.55, 0.15))), withered);
	col = mix(col, col * vec3(1.14, 1.05, 0.78), 0.5 * gold);
	ALBEDO = col * depth * (1.0 - 0.2 * wetness);
	NORMAL = normalize((VIEW_MATRIX * vec4(-0.3, 0.9, 0.3, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	AO = FINISH_AMBIENT;
}
