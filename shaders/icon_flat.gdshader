shader_type canvas_item;
render_mode unshaded, blend_disabled;   // (written as is: straight alpha, the picture kept)
// The pictures' flat sticker look (IconStyle, our own look): a rendered item (straight alpha, cut out by IconDevelop)
// drawn flat. Its colours become two tones (hue kept, a touch richer), a darker line runs where tones meet, and
// round the whole shape a dark outline and a white edge outside it, so it reads alike on paper and on the farm.
// Widths are shares of the picture's side, so every size of picture looks the same.

uniform vec4 line_colour : source_color = vec4(0.231, 0.141, 0.078, 1.0);
uniform vec4 rim_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float line_share = 0.022;   // the dark outline's width, of the side
uniform float rim_share = 0.02;     // the white edge's width outside it
uniform float light = 1.0;          // the lit tone of a colour, of its brightest..
uniform float shade = 0.74;         // ..and its shaded tone (two tones, toon-style, each colour's own hue)
uniform float split = 0.52;         // a point darker than this (of its colour's brightest) takes the shade
uniform float dark = 0.2;           // a colour this dark is dark in itself (spots, a face) and keeps its own
uniform float richer = 1.15;        // saturation kept and a little more
uniform float crease = 0.22;        // a tone change this big draws a line inside the shape (busy leaves don't)
uniform float crease_ink = 0.32;    // how dark that inside line is, toward the outline's colour

const int DIRS = 24;
const int STEPS = 12;

// Two tones of each colour's own hue: lit points take `light`, shaded ones `shade`, never mud. The colour's
// brightest is what it would be in full light (the render's brightest of that hue is taken as 1).
vec3 flat_of(vec4 c) {
	vec3 rgb = c.rgb;
	float v = max(rgb.r, max(rgb.g, rgb.b));
	if (v < dark) {
		return rgb;
	}
	vec3 hue = rgb / v;
	vec3 grey = vec3(dot(hue, vec3(0.3333)));
	hue = clamp(grey + (hue - grey) * richer, 0.0, 1.0);
	float base = min(1.0, v / 0.85);   // (a lit face renders at about 0.85 of full)
	return hue * (base >= split ? light : shade) * clamp(0.6 + 0.5 * v, 0.0, 1.0);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	float side = 1.0 / px.x;
	if (c.a >= 0.5) {
		vec3 f = flat_of(c);
		float step_px = max(1.0, side / 160.0);
		vec4 r = texture(TEXTURE, UV + vec2(px.x, 0.0) * step_px);
		vec4 d = texture(TEXTURE, UV + vec2(0.0, px.y) * step_px);
		float l = dot(f, vec3(0.3333));
		float lr = r.a >= 0.5 ? dot(flat_of(r), vec3(0.3333)) : l;
		float ld = d.a >= 0.5 ? dot(flat_of(d), vec3(0.3333)) : l;
		if (abs(l - lr) > crease || abs(l - ld) > crease) {
			f = mix(f, line_colour.rgb, crease_ink);
		}
		COLOR = vec4(f, 1.0);
	} else {
		// how far the shape is, in pixels: the first ring out that touches it
		float line_px = line_share * side;
		float rim_px = (line_share + rim_share) * side;
		float near = 1e6;
		for (int s = 1; s <= STEPS; s++) {
			float dist = rim_px * float(s) / float(STEPS);
			for (int k = 0; k < DIRS; k++) {
				float a = 6.2831853 * float(k) / float(DIRS);
				if (texture(TEXTURE, UV + vec2(cos(a), sin(a)) * dist * px).a >= 0.5) {
					near = min(near, dist);
				}
			}
			if (near < 1e5) {
				break;
			}
		}
		if (near <= line_px) {
			COLOR = line_colour;
		} else if (near <= rim_px) {
			float edge = clamp(rim_px - near + 0.5, 0.0, 1.0);   // (a soft last pixel)
			COLOR = vec4(rim_colour.rgb, edge);
		} else {
			COLOR = vec4(0.0);
		}
	}
}
