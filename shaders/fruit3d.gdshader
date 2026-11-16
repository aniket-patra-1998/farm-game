shader_type spatial;
// A tree's fruit, ripening on the tree (our own touch: it used to be one of two pictures, a bare tree or a full
// one, swapped at the moment it came ready). Every fruit is always in the tree's model; this shader shows each
// one growing: it appears at its own turn in the tree's cycle, small and as green as the leaves, swells, and
// takes its colour, so fruit comes one piece at a time and a tree is never suddenly full.
// Each fruit's vertices carry where its middle is (UV: x and y; UV2.x: z, in the model's space) and its turn
// (UV2.y, 0..1), put there when the model is merged (ModelKit.bake). The tree says when its cycle began and how
// long it lasts (`ripe_from`, `ripe_len`, seconds on the farm's clock); a tree that says nothing shows all its
// fruit ripe (pictures, the shop).

uniform vec3 albedo : source_color = vec3(1.0);
uniform vec3 unripe : source_color = vec3(0.36, 0.58, 0.22);   // a fruit just come: leaf green
uniform float roughness = 0.76;
uniform float specular = 0.26;
uniform float edge = 0.4;          // how dark the silhouette edge goes (as painted parts do)
uniform float span = 0.4;          // the part of the cycle one fruit takes to grow from nothing to full
uniform float small = 0.3;         // the size a fruit appears at, of its full size
global uniform float crop_clock;   // seconds on the farm's clock (Crops3D), the same for everything that grows
global uniform float wetness;      // 0..1: how wet everything is (SurfaceWeather)
uniform float ripe_from = -1000000.0;
uniform float ripe_len = 1.0;

varying vec3 tint;     // the fruit's own colour (its shade of the kind's)
varying float mine;    // 0..1: how far this fruit has grown

void vertex() {
	tint = COLOR.rgb;
	vec3 middle = vec3(UV.x, UV.y, UV2.x);
	float ripeness = clamp((crop_clock - ripe_from) / max(ripe_len, 0.001), 0.0, 1.0);
	mine = clamp((ripeness - UV2.y * (1.0 - span)) / span, 0.0, 1.0);
	float size = mine <= 0.0 ? 0.0 : mix(small, 1.0, smoothstep(0.0, 1.0, mine));
	VERTEX = middle + (VERTEX - middle) * size;
}

void fragment() {
	ALBEDO = mix(unripe, albedo * tint, smoothstep(0.3, 1.0, mine));
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO *= mix(1.0 - edge, 1.0, smoothstep(0.0, 0.5, facing));
	ALBEDO *= 1.0 - 0.22 * wetness;
	ROUGHNESS = roughness * (1.0 - 0.45 * wetness);
	SPECULAR = specular;
	RIM = 0.1;
	RIM_TINT = 0.9;
}
