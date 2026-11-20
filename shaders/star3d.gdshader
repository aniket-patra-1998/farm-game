shader_type spatial;
render_mode unshaded;
// A star on a Galaxy tree's crown (docs/LIMITED.md): a small pale light that blinks on its own beat, and nothing
// else on the tree does. Each is marked as a fruit is (ModelKit.mark_fruit: its middle in UV and UV2.x, its own
// number in UV2.y), so the merged crown's stars are one draw and each swells and shrinks about its own middle.
// It rides its tree's bend in the wind, as its fruit does.

uniform vec3 albedo : source_color = vec3(1.0, 0.95, 0.77);
uniform float pace = 2.0;      // how fast a star blinks (radians a second), a little different for each
uniform float dim = 0.25;      // its size at its dimmest, of its full size
uniform float sway = 0.0;      // how far its tree bends, by height above its foot (as paint3d's); 0: still
global uniform float wind;     // the weather's wind, set once for everything (Farm3D)

varying vec3 tint;

void vertex() {
	tint = COLOR.rgb;
	vec3 middle = vec3(UV.x, UV.y, UV2.x);
	float blink = pow(abs(sin(TIME * pace * (0.8 + 0.6 * UV2.y) + UV2.y * 40.0)), 3.0);
	VERTEX = middle + (VERTEX - middle) * mix(dim, 1.2, blink);
	if (sway > 0.0) {
		vec3 root = MODEL_MATRIX[3].xyz;
		float beat = TIME * 1.4 + root.x * 1.7 + root.z * 1.1;
		float bend = max(middle.y, 0.0) * max(middle.y, 0.0) * sway * (0.4 + wind);
		VERTEX.x += sin(beat) * bend;
		VERTEX.z += cos(beat * 0.8) * bend * 0.6;
	}
}

void fragment() {
	ALBEDO = albedo * tint;
}
