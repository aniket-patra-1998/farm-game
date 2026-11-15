shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
// Butterflies by day and birds crossing high over the farm: each a pair of wings that flap, moved along its own
// wandering path from the time, so a whole flock is one mesh, one draw and no script. Per vertex: UV = (the
// creature's phase, how far out along a bird's wing: 0 at the body, 1 at the tip), UV2 = (where it lives, x and
// z), COLOR = its colour (alpha: where in its wingbeat a bird is). They fade out at night (global dark).
// A butterfly's wings beat as flat plates. A bird's bend: the tip follows the shoulder a moment late and swings
// further, and between bursts of beating the bird glides on wings held a little raised.

global uniform float dark;
uniform float kind = 0.0;        // 0 butterflies (wander round their home), 1 birds (cross the farm now and then)
uniform float span = 24.0;       // birds: how far across they fly (tiles)
uniform float period = 80.0;     // birds: seconds between crossings

void vertex() {
	float phase = UV.x;
	vec3 centre;
	float yaw;
	float flap_rate;
	float shown = 1.0;
	if (kind < 0.5) {
		float t = TIME * (0.55 + phase * 0.3) + phase * 40.0;
		centre = vec3(UV2.x + sin(t * 0.7) * 1.3 + sin(t * 1.9) * 0.25, 0.32 + 0.22 * sin(t * 0.9 + phase * 6.0),
			UV2.y + cos(t * 0.55) * 1.3 + cos(t * 1.7) * 0.25);
		vec2 d = vec2(cos(t * 0.7) * 0.7 * 1.3, -sin(t * 0.55) * 0.55 * 1.3);
		yaw = atan(d.x, d.y);
		flap_rate = 16.0;
	} else {
		float cycle = mod(TIME + phase * period, period);
		float travel = cycle / (period * 0.35);          // 0..1 while crossing, then gone for the rest
		shown = step(travel, 1.0);
		float lane = phase * 3.0;                        // the flock's birds a little apart
		centre = vec3(UV2.x - 4.0 + travel * span, 3.6 + sin(TIME * 0.8 + lane) * 0.12, UV2.y + lane * 0.5);
		yaw = 1.5708;
		flap_rate = 9.0;
	}
	float beat = TIME * flap_rate + phase * 30.0 + COLOR.a * 6.2832;
	vec3 p = VERTEX;
	if (kind < 0.5) {
		float flap = sin(beat) * 0.85;
		p = vec3(p.x * cos(flap), abs(p.x) * sin(flap), p.z);
	} else {
		float along = UV.y;
		float beating = smoothstep(-0.35, 0.45, sin(TIME * 0.7 + COLOR.a * 40.0));
		float swing = sin(beat - along * 0.9) * mix(0.1, 0.75, beating) + 0.14;
		float bend = swing * smoothstep(0.0, 0.2, along) * mix(0.7, 1.25, along);
		p = vec3(p.x * cos(bend), p.y + abs(p.x) * sin(bend), p.z);
	}
	float c = cos(yaw);
	float s = sin(yaw);
	p = vec3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c);
	VERTEX = (centre + p) * shown + vec3(0.0, -50.0, 0.0) * (1.0 - shown);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = clamp(1.0 - dark * 1.4, 0.0, 1.0);
}
