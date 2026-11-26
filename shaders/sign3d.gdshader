shader_type spatial;
// An animal home's signboard (GateSign): a wooden board in a pale frame, hanging from its top edge and swaying
// in the shared wind, with the animal's Market picture on its front. It wears the finish every solid thing does.

uniform sampler2D picture : source_color, filter_linear_mipmap;
uniform vec3 wood : source_color = vec3(0.78, 0.64, 0.42);
uniform vec3 frame : source_color = vec3(0.95, 0.93, 0.89);
uniform float frame_wide = 0.06;   // the frame, as a share of the board's width
uniform float fills = 1.3;         // how big the picture is drawn against the board (a picture has a margin of its own)
uniform float sway = 0.1;          // radians it swings either way in a stiff wind
uniform float pace = 1.7;          // swings a second (x tau)
global uniform float wind;

varying float shows;   // 1 on the face that carries the picture
varying float height;
varying float its_own;

#include "res://shaders/finish.gdshaderinc"

void vertex() {
	shows = COLOR.r;
	// It hangs from its top edge (y = 0): the further down, the further it swings out.
	vec3 root = MODEL_MATRIX[3].xyz;
	float a = sin(TIME * pace + root.x * 1.7 + root.z * 1.1) * sway * (0.3 + 0.7 * wind);
	float ca = cos(a);
	float sa = sin(a);
	VERTEX = vec3(VERTEX.x, VERTEX.y * ca - VERTEX.z * sa, VERTEX.y * sa + VERTEX.z * ca);
	NORMAL = vec3(NORMAL.x, NORMAL.y * ca - NORMAL.z * sa, NORMAL.y * sa + NORMAL.z * ca);
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	its_own = finish_own(root);
}

void fragment() {
	vec3 col = wood;
	if (shows > 0.5) {
		vec2 edge = min(UV, 1.0 - UV);
		col = min(edge.x, edge.y) < frame_wide ? frame : wood;
		vec2 at = (UV - 0.5) / fills + 0.5;
		if (at.x > 0.0 && at.x < 1.0 && at.y > 0.0 && at.y < 1.0) {
			vec4 drawn = texture(picture, at);
			col = mix(col, drawn.rgb, drawn.a);
		}
	}
	ALBEDO = finish_lean(col, its_own);
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
	AO = FINISH_AMBIENT;
}
