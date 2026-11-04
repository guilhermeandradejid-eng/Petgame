// Plateia em MultiMesh: cada torcedor tem cores próprias (UV.x = região),
// tem um jeito de torcer (crowd_anim.gdshaderinc), segue a bola e faz a "ola".
shader_type spatial;
render_mode unshaded;
#include "res://shaders/lighting.gdshaderinc"
#include "res://shaders/crowd_anim.gdshaderinc"

uniform float mute = 0.15;   // torcida um pouco menos saturada que os jogadores

const vec3 SKINS[5] = vec3[](vec3(0.95, 0.73, 0.54), vec3(0.83, 0.6, 0.42), vec3(0.55, 0.35, 0.23),
	vec3(0.37, 0.23, 0.15), vec3(1.0, 0.84, 0.69));
// cabelos naturais (sem cores berrantes: a plateia não disputa atenção com a quadra)
const vec3 HAIRS[6] = vec3[](vec3(0.15, 0.1, 0.08), vec3(0.35, 0.2, 0.1), vec3(0.95, 0.78, 0.35),
	vec3(0.55, 0.28, 0.14), vec3(0.22, 0.15, 0.12), vec3(0.1, 0.08, 0.08));
const vec3 PROPS[4] = vec3[](vec3(1.0, 1.0, 1.0), vec3(1.0, 0.85, 0.25), vec3(0.2, 0.8, 1.0), vec3(1.0, 0.35, 0.6));
const vec3 PANTS[4] = vec3[](vec3(0.18, 0.25, 0.45), vec3(0.95, 0.95, 0.95), vec3(0.2, 0.2, 0.25), vec3(0.95, 0.6, 0.2));

varying vec3 tint;
varying float shade;

void vertex() {
	VERTEX = crowd_anim(VERTEX, UV, INSTANCE_CUSTOM, MODEL_MATRIX, TIME);
	float region = UV.x;
	vec3 col = COLOR.rgb;
	int skin_i = int(INSTANCE_CUSTOM.y * 4.99);
	int hair_i = int(INSTANCE_CUSTOM.z * 5.99);
	int prop_i = int(INSTANCE_CUSTOM.w * 3.99);
	if (region < 0.05) col = vec3(0.165, 0.122, 0.2);   // olhinhos
	else if (region > 0.2 && region < 0.4) col = SKINS[skin_i];
	else if (region > 0.4 && region < 0.6) col = HAIRS[hair_i];
	// placas e mãozonas na cor da torcida (ou branco), nada de arco-íris
	else if (region > 0.6 && region < 0.8) col = (prop_i % 2 == 0) ? vec3(1.0, 0.98, 0.95) : min(COLOR.rgb * 1.15 + 0.08, vec3(1.0));
	else if (region > 0.8) col = PANTS[prop_i];
	tint = col;
	shade = clamp(dot(NORMAL, normalize(vec3(-0.45, 0.72, 0.53))) * 1.2 + 0.55, 0.0, 1.0);
}

void fragment() {
	vec3 col = tint * mix(0.8, 1.0, smoothstep(0.35, 0.6, shade));
	float l = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(l) * vec3(1.0, 0.97, 1.0), mute) * 0.97;
	col = mix(col, vec3(0.8, 0.9, 1.0), smoothstep(45.0, 300.0, length(VERTEX)) * 0.6);
	ALBEDO = night_grade(col, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}
