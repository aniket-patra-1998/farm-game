shader_type canvas_item;
// A shine that sweeps across a picture now and then (our own look: a polished, collectible feel), only where the
// picture is solid. One material for every picture: each starts its sweep at its own time, from where it sits.

uniform float period = 5.0;      // seconds between sweeps
uniform float width = 0.14;      // the band's width, as a share of the picture
uniform float strength = 0.5;    // how bright the band is at its middle

varying float phase;

void vertex() {
	phase = fract(sin(dot(MODEL_MATRIX[3].xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = COLOR;
	float t = fract(TIME / period + phase) * 2.6 - 0.8;   // most of the period the band is off the picture
	float along = (UV.x + UV.y) * 0.5;
	float band = 1.0 - smoothstep(0.0, width, abs(along - t));
	c.rgb += band * strength * c.a;
	COLOR = c;
}
