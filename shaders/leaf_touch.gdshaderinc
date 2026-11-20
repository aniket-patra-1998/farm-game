// A limited tree's touch on its leaves (docs/LIMITED.md; the animals' are coat_touch.gdshaderinc): its colours
// turning slowly round (rainbow), swaying warm and back (sunset), or a glint sweeping across the crown now and
// then (glint). Run in the vertex stage on the leaf's own colour, so it costs the picture nothing. A tree's
// stars blink in their own shader (star3d), and one that shakes is shaken by TreeLife.
const int LEAF_RAINBOW = 2;
const int LEAF_SUNSET = 3;
const int LEAF_GLINT = 4;
const float RAINBOW_PACE = 0.11;   // turns of the colour wheel a second
const float SUNSET_SWAY = 0.045;   // how far the colours sway, of the wheel..
const float SUNSET_PACE = 1.3;     // ..and how fast (radians a second)
const float GLINT_EVERY = 2.6;     // seconds from one glint to the next..
const float GLINT_TIME = 1.1;      // ..and how long one takes to cross
const float GLINT_SHARP = 16.0;    // how narrow its band is
const float GLINT_LIGHT = 0.6;     // how bright

vec3 leaf_turn(vec3 c, float turns) {
	float a = turns * 6.28318;
	vec3 k = vec3(0.57735);
	return clamp(c * cos(a) + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - cos(a)), 0.0, 1.0);
}

// `col`: the leaf's colour; `at`: where it is, from its tree's foot (world space); `time`: seconds.
vec3 leaf_touch(int which, vec3 col, vec3 at, float time) {
	if (which == LEAF_RAINBOW) {
		return leaf_turn(col, time * RAINBOW_PACE);
	}
	if (which == LEAF_SUNSET) {
		return leaf_turn(col, SUNSET_SWAY * sin(time * SUNSET_PACE));
	}
	if (which == LEAF_GLINT) {
		float through = mod(time, GLINT_EVERY) / GLINT_TIME;
		if (through <= 1.0) {
			float across = (at.x - at.z) * 0.7071 + at.y * 0.6;   // (across the screen, leaning with height)
			float band = exp(-pow(across - mix(-1.1, 1.9, through), 2.0) * GLINT_SHARP);
			return col + vec3(1.0, 0.95, 0.7) * band * GLINT_LIGHT;
		}
	}
	return col;
}
