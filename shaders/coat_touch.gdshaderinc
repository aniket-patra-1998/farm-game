// A limited animal's coat touch (CoatTouch, docs/LIMITED.md), worked out for each point in the vertex stage: it
// costs the pixels nothing, and nothing at all for a material whose `touch` is 0. The file says of each point
// (tools/animal_art export.py, _touch_points): UV.x how far along the animal it is (0 at the nose, 1 at the tail)
// and UV.y whether the touch moves it; UV2.y a number of the point's own (a star's place in the twinkling; how
// high up the animal it is, for embers).

const int TOUCH_STARS = 1;      // a starry coat: each star fades into the coat and back at its own pace
const int TOUCH_RAINBOW = 2;    // a rainbow coat: its colours turn round the colour wheel, slowly
const int TOUCH_SUNSET = 3;     // a sunset coat: its colours sway a little, to and fro
const int TOUCH_GLINT = 4;      // a golden coat: a glint runs over it from nose to tail now and then
const int TOUCH_EMBERS = 5;     // a flame coat: warm light climbs it

const float STAR_PACE = 1.6;        // a star's slowest twinkle (radians a second)..
const float STAR_PACES = 3.2;       // ..and how much quicker the quickest is
const float STAR_BRIGHT = 1.15;     // a star at its brightest, against its painted colour
const float RAINBOW_TURN = 0.5;     // radians of the colour wheel a rainbow turns a second (a full turn in 12 s)
const float SUNSET_PACE = 0.9;      // how fast a sunset sways (radians a second)
const float SUNSET_SWAY = 0.35;     // and how far (radians of the colour wheel, each way)
const float GLINT_EVERY = 4.0;      // seconds from one glint to the next
const float GLINT_SHARE = 0.18;     // of that, the glint is crossing the coat
const float GLINT_WIDE = 0.12;      // how wide the glint is, of the animal's length
const float GLINT_BRIGHT = 0.7;     // how much light it adds at its middle
const float EMBER_PACE = 5.0;       // how fast the light climbs (radians a second)
const float EMBER_WAVES = 7.0;      // how many waves of it stand up the animal
const vec3 EMBER_LIGHT = vec3(0.3, 0.2, 0.02);

// `col` turned `turn` radians round the colour wheel (about the grey axis: its lightness stays).
vec3 hue_turn(vec3 col, float turn) {
	vec3 grey = vec3(0.57735);
	return col * cos(turn) + cross(grey, col) * sin(turn) + grey * dot(grey, col) * (1.0 - cos(turn));
}

// The colour of a point of a touched coat at `time`: `col` its painted colour, `dim` the coat's own colour (what a
// star fades into), `at` its UV and `own` its UV2.
vec3 coat_touch(int which, vec3 dim, vec3 col, vec2 at, vec2 own, float time) {
	if (at.y < 0.5) {
		return col;
	}
	if (which == TOUCH_STARS) {
		float lit = clamp(0.5 + 0.75 * sin(time * (STAR_PACE + STAR_PACES * fract(own.y * 7.0)) + own.y * 40.0), 0.0, 1.0);
		return mix(dim, col * STAR_BRIGHT, lit);
	}
	if (which == TOUCH_RAINBOW) {
		return hue_turn(col, time * RAINBOW_TURN);
	}
	if (which == TOUCH_SUNSET) {
		return hue_turn(col, sin(time * SUNSET_PACE) * SUNSET_SWAY);
	}
	if (which == TOUCH_GLINT) {
		float through = fract(time / GLINT_EVERY) / GLINT_SHARE;   // 0..1 while it crosses; past 1 it waits
		float off = (at.x - (through * 1.4 - 0.2)) / GLINT_WIDE;
		return col + vec3(GLINT_BRIGHT) * exp(-off * off) * step(through, 1.0);
	}
	return col + EMBER_LIGHT * max(0.0, sin(time * EMBER_PACE - own.y * EMBER_WAVES + sin(at.x * 9.0)));
}
