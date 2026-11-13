shader_type spatial;
render_mode cull_disabled;
// Crop plants, drawn for a whole field at once through MultiMeshes. Leaves carry their own green in the
// vertex colour; produce (vertex alpha 0) takes its crop's colour from the material (one per crop colour),
// shaded by the vertex colour. Plants sway from the root, tips most, harder in wind, each on its own beat.
// Growth is done here, continuously: INSTANCE_CUSTOM is (when the growing stage began and how long it lasts, in
// minutes on the farm clock, fertilised 0 or 1), and the plant's size is worked out each frame from the clock,
// so it swells smoothly instead of stepping. (Kept small on purpose: the compatibility renderer stores per-
// instance data as 16-bit floats, which overflow to infinity past 65,504 and are coarse past 2,048.)

global uniform float wind;        // the weather's wind, set once for everything (Farm3D)
global uniform float crop_clock;  // seconds on the farm's clock (Crops3D), the same for every plant
uniform float size_from = 0.55;   // the size a growing stage starts at, of full size
uniform float rich_size = 1.18;   // a fertilised plant's size, of an ordinary one's
uniform vec3 produce_colour : source_color = vec3(0.89, 0.27, 0.24);   // this crop's fruit, grain or flower

varying vec4 produce;
varying float up;   // how far up the plant this point is, 0 at the soil

void vertex() {
	float rich_flag = INSTANCE_CUSTOM.z;
	produce = vec4(produce_colour, 1.0 - rich_flag);
	up = clamp(VERTEX.y / 0.35, 0.0, 1.0);
	float stage_length = INSTANCE_CUSTOM.y;
	float grown = stage_length > 0.0 ? clamp((crop_clock / 60.0 - INSTANCE_CUSTOM.x) / stage_length, 0.0, 1.0) : 1.0;
	float grow_scale = stage_length > 0.0 ? mix(size_from, 1.0, grown) : 1.0;
	VERTEX *= grow_scale * mix(1.0, rich_size, rich_flag);
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float beat = TIME * 1.9 + root.x * 1.3 + root.z * 0.9;
	float bend = VERTEX.y * VERTEX.y * 3.0 * (0.4 + wind);
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
	ALBEDO = mix(leaf, fruit, is_produce) * lit * (1.0 + 0.1 * rich);
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO *= mix(0.7, 1.0, smoothstep(0.0, 0.5, facing));
	RIM = 0.1;
	RIM_TINT = 0.9;
	ROUGHNESS = mix(0.85, 0.45, is_produce);
	SPECULAR = mix(0.1, 0.35, is_produce) + 0.2 * rich * (1.0 - is_produce);
	BACKLIGHT = vec3(0.2, 0.3, 0.08) * (1.0 - is_produce);
}
