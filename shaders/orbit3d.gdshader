shader_type spatial;
render_mode cull_back;
// A small part going round, bobbing or swinging by itself (a bird circling, ducks paddling, a bucket, a
// weathervane), moved here from the time: no script and one draw. The part is baked with its colours in
// its vertices (ModelKit.tint_arrays), built facing -z at the origin; it travels round a circle `radius`
// wide (facing along it), or with `swing` > 0 turns back and forth that far instead of round.

global uniform float wind;
uniform float speed = 1.0;      // radians a second round the circle (or the swing's pace)
uniform float radius = 0.0;
uniform float swing = 0.0;      // > 0: swings this many radians either way instead of going round
uniform float bob = 0.0;        // up and down by this much
uniform float bob_rate = 2.0;   // bobs a second (x tau)
uniform float phase = 0.0;
uniform float flap = 0.0;       // > 0: a flier's wings (whatever lies further out than `shoulder` either side) beat
uniform float flap_rate = 10.0; // this many radians up and down, at this pace, in bursts with glides between
uniform float shoulder = 0.03;
uniform float dip = 0.0;        // > 0: a swimmer that dabbles: now and then it tips forward this far (radians), head under

void vertex() {
	vec3 root = NODE_POSITION_WORLD;
	float t = TIME + phase + root.x * 0.37 + root.z * 0.23;
	float a = swing > 0.0 ? sin(t * speed) * swing * (0.5 + wind * 0.5) : t * speed;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	if (flap > 0.0 && abs(v.x) > shoulder) {
		// Both wings turn about their shoulders together, up then down; between bursts it glides, wings level.
		float side = sign(v.x);
		float a0 = sin(t * flap_rate) * flap * smoothstep(-0.2, 0.4, sin(t * 0.9));
		float ca = cos(a0);
		float sa = sin(a0);
		float out_x = abs(v.x) - shoulder;
		v.x = side * (shoulder + out_x * ca - v.y * sa);
		v.y = out_x * sa + v.y * ca;
		float n_out = n.x * side;
		n = vec3(side * (n_out * ca - n.y * sa), n_out * sa + n.y * ca, n.z);
	}
	if (dip > 0.0) {
		// It faces -z: tipping forward turns it about its own middle, so its head goes down and its tail up.
		float tip = dip * smoothstep(0.8, 0.95, sin(t * 0.7 + phase * 1.9));
		float ct = cos(tip);
		float st = sin(tip);
		v = vec3(v.x, v.y * ct + v.z * st, v.z * ct - v.y * st);
		n = vec3(n.x, n.y * ct + n.z * st, n.z * ct - n.y * st);
	}
	vec3 p = v + vec3(radius, 0.0, 0.0);
	float c = cos(a);
	float s = sin(a);
	VERTEX = vec3(p.x * c + p.z * s, p.y + sin(t * bob_rate * 6.2832) * bob, -p.x * s + p.z * c);
	NORMAL = vec3(n.x * c + n.z * s, n.y, -n.x * s + n.z * c);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
}
