shader_type spatial;
// A plain painted surface (posts, trim, wheels, animals' coats...), matte unless `shine`. Like the walls
// (wall3d), it darkens toward the ground, so every part of every model meets the earth with contact shade
// instead of full brightness: what makes a thing look stood on the farm rather than pasted over it.

uniform vec3 albedo : source_color = vec3(0.8);
uniform float roughness = 1.0;
uniform float specular = 0.1;
uniform float ground_ao = 0.32;   // how dark a part gets where it touches the ground
uniform float ao_reach = 0.22;    // and how far up the shade fades out (world units)
uniform float sway = 0.0;         // bends in the wind by height above its foot (trees, scarecrows); 0: still
global uniform float wind;        // the weather's wind, set once for everything (Farm3D)

varying float height;

varying vec3 tint;  // the part's colour when baked into a merged mesh (white if none)

void vertex() {
	tint = COLOR.rgb;
	if (sway > 0.0) {
		// Bends from the foot: the higher, the more; each thing on its own beat (from where it stands).
		vec3 root = NODE_POSITION_WORLD;
		float beat = TIME * 1.4 + root.x * 1.7 + root.z * 1.1;
		float bend = max(VERTEX.y, 0.0) * max(VERTEX.y, 0.0) * sway * (0.4 + wind);
		VERTEX.x += sin(beat) * bend;
		VERTEX.z += cos(beat * 0.8) * bend * 0.6;
	}
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float ao = mix(1.0 - ground_ao, 1.0, smoothstep(0.0, ao_reach, height));
	ALBEDO = albedo * tint * ao;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
