shader_type spatial;
render_mode cull_disabled;
// Foliage cards: a crown's leafy outline is made of many small cards, each a sprig of leaves cut out by a
// texture (see ModelKit.leaf_texture), so the crown has a ragged, leafy silhouette with sky and branches
// showing through, like FarmVille's painted trees, not a smooth ball. A card's colour is in its vertices (its
// light, its tone), its normal points out from the crown so the cards shade together as one rounded mass.

uniform sampler2D sprig : filter_linear_mipmap, repeat_disable;
uniform float cutoff = 0.5;
uniform float roughness = 1.0;
uniform float specular = 0.1;
uniform float ground_ao = 0.32;
uniform float ao_reach = 0.22;
uniform float rim = 0.1;
uniform float sway = 0.0;
uniform float flutter = 0.012;     // how far a sprig's tip trembles, in tiles
global uniform float wind;

varying float height;
varying vec3 tint;

void vertex() {
	tint = COLOR.rgb;
	float loose = 1.0 - UV.y;      // the tip of a sprig moves most, its stem hardly at all
	vec3 root = MODEL_MATRIX[3].xyz;
	if (sway > 0.0) {
		float beat = TIME * 1.4 + root.x * 1.7 + root.z * 1.1;
		float bend = max(VERTEX.y, 0.0) * max(VERTEX.y, 0.0) * sway * (0.4 + wind);
		VERTEX.x += sin(beat) * bend;
		VERTEX.z += cos(beat * 0.8) * bend * 0.6;
	}
	float shiver = sin(TIME * 2.6 + VERTEX.x * 23.0 + VERTEX.z * 19.0 + root.x * 3.0) * (0.5 + wind);
	VERTEX += NORMAL * shiver * flutter * loose;
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec4 s = texture(sprig, UV);
	ALPHA = s.r;
	ALPHA_SCISSOR_THRESHOLD = cutoff;
	float ao = mix(1.0 - ground_ao, 1.0, smoothstep(0.0, ao_reach, height));
	ALBEDO = tint * mix(0.5, 0.78, s.g) * ao;
	// The normal runs out from the crown on both faces of the card, so the two sides shade alike.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = roughness;
	SPECULAR = specular;
	RIM = rim;
	RIM_TINT = 0.9;
}
