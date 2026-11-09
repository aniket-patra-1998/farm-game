shader_type canvas_item;
// Colour grade over the farm and sky (the HUD sits above it): saturation and contrast for the
// painterly art, cool lifted shadows at night, a warm wash from the sun at golden hour,
// fog haze that thickens toward the far (top) side, and a soft vignette.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform vec3 lift = vec3(0.0);
uniform vec4 warm = vec4(1.0, 0.62, 0.32, 0.0); // rgb = colour, a = strength
uniform vec2 warm_from = vec2(0.0, 0.3);        // screen position of the sun side
uniform vec4 haze = vec4(0.86, 0.88, 0.9, 0.0); // rgb = fog colour, a = strength
uniform float vignette = 0.2;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c += lift * (1.0 - l);
	float w = warm.a * (1.0 - clamp(distance(SCREEN_UV, warm_from) * 0.85, 0.0, 1.0));
	c = mix(c, c * warm.rgb * 1.5, w);
	c = mix(c, haze.rgb, haze.a * (1.0 - 0.55 * SCREEN_UV.y));
	float d = distance(SCREEN_UV, vec2(0.5));
	c *= 1.0 - vignette * smoothstep(0.38, 0.9, d);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
