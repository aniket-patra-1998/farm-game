shader_type spatial;
render_mode cull_disabled;
// A Bloom, whole: its stems, leaves and flower heads are one surface, and its whole life is drawn here from the
// farm's clock, so nothing about it changes picture. Each flower head starts as a small closed green bud and, at
// its turn in the plant's cycle, swells, opens and takes its colour (a Full Bloom's heads open one after
// another); a Single Bloom left ready too long yellows, browns and bends over little by little until it is
// withered. Every vertex carries the middle of the head it belongs to (UV: x and y; UV2.x: z, in the model's
// space) and the head's turn (UV2.y, 0..1); stems and leaves carry a turn below 0 and are not opened. The plant
// says when its cycle began and how long it is (`ripe_from`, `ripe_len`), and when its wilting starts and how
// long that takes (`wilt_from`, `wilt_len`), in seconds on the farm's clock; one that says nothing is in full
// bloom and never wilts (pictures, the shop, a bloom in a Bloom Garden).

uniform vec3 albedo : source_color = vec3(1.0);
uniform vec3 bud : source_color = vec3(0.42, 0.62, 0.26);     // a closed bud: sepal green
uniform vec3 dead : source_color = vec3(0.54, 0.43, 0.23);    // a withered bloom
uniform float span = 0.4;          // the part of the cycle one head takes to open
uniform float bud_wide = 0.26;     // a closed bud's width, of the open flower's..
uniform float bud_tall = 0.5;      // ..and its height
uniform float sway = 0.035;        // how far the top of the plant sways, per tile of height squared
uniform float roughness = 0.72;
global uniform float crop_clock;   // seconds on the farm's clock (Crops3D)
global uniform float wetness;      // 0..1: how wet everything is (SurfaceWeather)
instance uniform float ripe_from = -1000000.0;
instance uniform float ripe_len = 1.0;
instance uniform float wilt_from = 1000000000.0;
instance uniform float wilt_len = 1.0;

varying vec3 tint;     // the part's own colour
varying float open;    // 0..1: how far this head has opened (1 for a stem or a leaf)
varying float head;    // 1 for a vertex of a flower head, 0 for a stem or a leaf
varying float wilt;    // 0..1: how far the plant has wilted

void vertex() {
	tint = COLOR.rgb;
	head = step(0.0, UV2.y);
	float ripeness = clamp((crop_clock - ripe_from) / max(ripe_len, 0.001), 0.0, 1.0);
	open = mix(1.0, clamp((ripeness - UV2.y * (1.0 - span)) / span, 0.0, 1.0), head);
	wilt = clamp((crop_clock - wilt_from) / max(wilt_len, 0.001), 0.0, 1.0);
	// A head opens about its own middle: from a narrow closed bud to the open flower. Wilting, it closes again.
	vec3 middle = vec3(UV.x, UV.y, UV2.x);
	float e = smoothstep(0.0, 1.0, open) * (1.0 - 0.45 * wilt);
	vec3 from_middle = (VERTEX - middle) * vec3(mix(bud_wide, 1.0, e), mix(bud_tall, 1.0, e), mix(bud_wide, 1.0, e));
	VERTEX = mix(VERTEX, middle + from_middle, head);
	// The wind, and the wilt: the higher up, the further it leans; wilted, it hangs over and sinks.
	float up = max(VERTEX.y, 0.0);
	float lean = sin(TIME * 1.7 + NODE_POSITION_WORLD.x * 3.1 + NODE_POSITION_WORLD.z * 2.3) * sway * (1.0 - 0.8 * wilt);
	VERTEX.x += up * up * (lean + 0.9 * wilt * wilt);
	VERTEX.y *= 1.0 - 0.38 * wilt * wilt;
}

void fragment() {
	vec3 col = albedo * tint;
	col = mix(col, mix(bud, col, smoothstep(0.2, 0.85, open)), head);
	col = mix(col, mix(col * vec3(1.15, 1.05, 0.6), dead, smoothstep(0.35, 1.0, wilt)), smoothstep(0.0, 0.5, wilt));
	ALBEDO = col * (1.0 - 0.2 * wetness);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = roughness * (1.0 - 0.4 * wetness);
	SPECULAR = 0.2;
	RIM = 0.25 * head;
	RIM_TINT = 0.7;
}
