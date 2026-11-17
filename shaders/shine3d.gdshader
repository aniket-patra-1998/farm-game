shader_type spatial;
render_mode cull_back;
// Polished metal and enamel that glimmers (the Barn's VIP badge while VIP is active, docs/VIP.md). Each part's
// colour is its vertex colour; it is lit a little from inside, breathing slowly, and a band of light crosses
// it on the slant every few seconds. One shared material (ModelKit.shine_material): the whole badge is one
// draw, with no script.

uniform float sweep_every = 2.6;   // seconds from one band of light to the next
uniform float sweep_width = 0.1;   // half the band's width, in the piece's own units
uniform float span = 0.55;         // how far from the piece's middle the band crosses, each way
uniform float glow = 0.42;         // the share of its colour it shines with by itself
uniform float breathe = 0.16;      // ..and how far that rises and falls

varying float along;   // where this point lies on the slant the band travels

void vertex() {
	along = (VERTEX.x + VERTEX.y) * 0.7071;
}

void fragment() {
	vec3 base = COLOR.rgb;
	// The band is on the piece for part of each turn and off it for the rest: a glint, then a pause.
	float at = mix(-span * 1.5, span * 3.5, fract(TIME / sweep_every));
	float band = 1.0 - smoothstep(0.0, sweep_width, abs(along - at));
	ALBEDO = base;
	ROUGHNESS = 0.28;
	SPECULAR = 0.65;
	EMISSION = base * (glow + breathe * sin(TIME * 2.2)) + vec3(1.0, 0.96, 0.82) * band * 0.9;
}
