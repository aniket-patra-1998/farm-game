shader_type spatial;
// Walls and roofs of the farm's buildings, in local object space so patterns stay put as buildings move:
// 0 boards (clapboard with shadowed laps), 1 logs, 2 stone, 3 plaster, 4 shingles (roofs), 5 corrugated
// metal. Every surface also darkens toward the ground (ambient occlusion), which is what makes a building
// look like it sits on the earth rather than floating over it.

uniform vec3 base_color : source_color = vec3(0.8, 0.3, 0.2);
uniform int style = 0;
uniform float scale = 1.0;      // pattern size: 1 is a board about a twelfth of a tile high
uniform float ground_ao = 0.45; // how dark the foot of the wall gets

varying vec3 local_pos;
varying vec3 local_normal;
varying float height;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 col = base_color;
	float along = abs(local_normal.x) > 0.5 ? local_pos.z : local_pos.x;
	float y = local_pos.y / scale;
	if (style == 0) {
		float lap = fract(y * 12.0);
		col *= 0.82 + 0.18 * smoothstep(0.0, 0.25, lap);
		col *= 0.95 + 0.1 * hash(vec2(floor(y * 12.0), floor(along * 3.0 / scale)));
	} else if (style == 1) {
		float log_y = fract(y * 7.0);
		col *= 0.7 + 0.3 * sin(log_y * 3.14159);
	} else if (style == 2) {
		vec2 cell = vec2(along * 6.0 / scale + floor(y * 8.0) * 0.5, y * 8.0);
		vec2 f = fract(cell);
		float mortar = step(0.1, f.x) * step(0.12, f.y);
		col *= mix(0.65, 0.9 + 0.2 * hash(floor(cell)), mortar);
	} else if (style == 3) {
		col *= 0.95 + 0.06 * hash(floor(local_pos.xz * 20.0) + floor(y * 20.0));
	} else if (style == 4) {
		vec2 tile = vec2(along * 7.0 / scale + floor(y * 9.0) * 0.5, y * 9.0);
		vec2 f = fract(tile);
		col *= 0.78 + 0.22 * smoothstep(0.0, 0.35, f.y);
		col *= 0.9 + 0.2 * hash(floor(tile));
		col *= mix(0.85, 1.0, step(0.06, f.x));
	} else if (style == 5) {
		col *= 0.85 + 0.15 * sin(along * 60.0 / scale);
	}
	col *= mix(1.0 - ground_ao, 1.0, smoothstep(0.0, 0.35, height));
	ALBEDO = col;
	ROUGHNESS = style == 5 ? 0.45 : 0.9;
	METALLIC = style == 5 ? 0.3 : 0.0;
	SPECULAR = style == 5 ? 0.35 : 0.08;
}
