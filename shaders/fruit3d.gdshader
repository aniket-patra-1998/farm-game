shader_type spatial;
// A tree's fruit, ripening on the tree (our own touch: it used to be one of two pictures, a bare tree or a full
// one, swapped at the moment it came ready). Every fruit is always in the tree's model; this shader shows each
// one growing: it appears at its own turn in the tree's cycle, small and as green as the leaves, swells, and
// takes its colour, so fruit comes one piece at a time and a tree is never suddenly full.
// Each fruit's vertices carry where its middle is (UV: x and y; UV2.x: z, in the model's space) and its turn
// (UV2.y, 0..1), put there when the model is merged (ModelKit.bake). The tree says when its cycle began and how
// long it lasts (`ripe_from`, `ripe_len`, seconds on the farm's clock); a tree that says nothing shows all its
// fruit ripe (pictures, the shop).
// A fruit rides its tree's bend in the wind (paint3d's own sway, at the height of its middle, so it moves whole
// with its branch) and swings a little after it on its own beat: without that the crown leant away in a gust
// and left its fruit standing in the air.

uniform vec3 albedo : source_color = vec3(1.0);
uniform vec3 unripe : source_color = vec3(0.36, 0.58, 0.22);   // a fruit just come: leaf green
uniform float roughness = 0.76;
uniform float specular = 0.26;
uniform float edge = 0.4;          // how dark the silhouette edge goes (as painted parts do)
uniform float span = 0.4;          // the part of the cycle one fruit takes to grow from nothing to full
uniform float small = 0.3;         // the size a fruit appears at, of its full size
global uniform float crop_clock;   // seconds on the farm's clock (Crops3D), the same for everything that grows
global uniform float wetness;      // 0..1: how wet everything is (SurfaceWeather)
global uniform float wind;         // the weather's wind, set once for everything (Farm3D)
uniform float sway = 0.0;          // how far its tree bends, by height above its foot (as paint3d's); 0: still
uniform float swing = 0.17;        // its own swing after the branch, of the tree's bend a unit up
uniform float swing_pace = 2.6;    // ..and how fast (radians a second)
uniform float ripe_from = -1000000.0;
uniform float ripe_len = 1.0;

varying vec3 tint;     // the fruit's own colour (its shade of the kind's)
varying float mine;    // 0..1: how far this fruit has grown

#include "res://shaders/finish.gdshaderinc"

void vertex() {
	tint = COLOR.rgb;
	vec3 middle = vec3(UV.x, UV.y, UV2.x);
	float ripeness = clamp((crop_clock - ripe_from) / max(ripe_len, 0.001), 0.0, 1.0);
	mine = clamp((ripeness - UV2.y * (1.0 - span)) / span, 0.0, 1.0);
	float size = mine <= 0.0 ? 0.0 : mix(small, 1.0, smoothstep(0.0, 1.0, mine));
	VERTEX = middle + (VERTEX - middle) * size;
	if (sway > 0.0) {
		vec3 root = MODEL_MATRIX[3].xyz;
		float beat = TIME * 1.4 + root.x * 1.7 + root.z * 1.1;
		float bend = max(middle.y, 0.0) * max(middle.y, 0.0) * sway * (0.4 + wind);
		float own = sin(TIME * swing_pace + middle.x * 9.0 + middle.z * 7.0) * swing * sway * (0.4 + wind);
		VERTEX.x += sin(beat) * bend + own;
		VERTEX.y -= abs(own) * 0.4;
		VERTEX.z += cos(beat * 0.8) * bend * 0.6 + own * 0.6;
	}
}

void fragment() {
	ALBEDO = mix(unripe, albedo * tint, smoothstep(0.3, 1.0, mine));
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO *= mix(1.0 - edge, 1.0, smoothstep(0.0, 0.5, facing));
	ALBEDO *= 1.0 - 0.22 * wetness;
	ROUGHNESS = roughness * (1.0 - 0.45 * wetness);
	SPECULAR = specular;
	AO = FINISH_AMBIENT;
}
