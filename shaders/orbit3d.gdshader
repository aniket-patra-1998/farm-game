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

void vertex() {
	vec3 root = NODE_POSITION_WORLD;
	float t = TIME + phase + root.x * 0.37 + root.z * 0.23;
	float a = swing > 0.0 ? sin(t * speed) * swing * (0.5 + wind * 0.5) : t * speed;
	vec3 p = VERTEX + vec3(radius, 0.0, 0.0);
	float c = cos(a);
	float s = sin(a);
	VERTEX = vec3(p.x * c + p.z * s, p.y + sin(t * bob_rate * 6.2832) * bob, -p.x * s + p.z * c);
	NORMAL = vec3(NORMAL.x * c + NORMAL.z * s, NORMAL.y, -NORMAL.x * s + NORMAL.z * c);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
}
