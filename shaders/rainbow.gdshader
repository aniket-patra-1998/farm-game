shader_type canvas_item;
render_mode blend_add, unshaded;
// A soft rainbow after rain (WeatherLayer): one arc of light, its centre below the screen, drawn on one
// full-screen rect only while it shows. Light added, never painted: pale bands that lift the farm under them, red
// outside and violet in, fading out toward its feet and at both edges of the band. The owner wants it light and
// gentle ("too deep and saturated" before), so the colours are washed toward white by `saturation`.

uniform float strength = 0.0;      // 0 none .. 1 (WeatherLayer.rainbow_strength times the look's strength)
uniform float saturation = 0.5;    // 0 white light .. 1 the full spectrum
uniform float aspect = 2.22;       // the screen's width over its height
uniform float centre_y = 1.3;      // the arc's centre, in screen heights from the top (below the screen)
uniform float radius = 1.0;        // in screen heights
uniform float width = 0.1;         // the band's width, in screen heights
uniform float centre_x = 0.62;     // across the screen, 0 left .. 1 right

vec3 hue(float h) {
	vec3 k = clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return k * k * (3.0 - 2.0 * k);
}

void fragment() {
	vec2 p = vec2((UV.x - centre_x) * aspect, UV.y - centre_y);
	float d = length(p);
	float t = (d - radius) / width;              // -0.5 inside edge .. 0.5 outside edge
	float band = smoothstep(0.55, 0.2, abs(t));
	// red outside (hue 0), violet inside (0.78)
	vec3 col = mix(vec3(1.0), hue(mix(0.78, 0.0, t + 0.5)), saturation);
	float up = clamp(-p.y / max(d, 1e-4), 0.0, 1.0);   // 1 at the top of the arc, 0 at its feet
	float feet = smoothstep(0.25, 0.75, up);
	COLOR = vec4(col * band * feet * strength, 1.0);
}
