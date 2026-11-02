// Plateia em MultiMesh: cada torcedor tem cores próprias (UV.x = região),
// pula, acena, vira o corpo seguindo a bola e faz a "ola".
shader_type spatial;
render_mode unshaded;

uniform float excitement = 0.0;
uniform vec3 ball_pos = vec3(0.0, 1.0, 0.0);
uniform float ola_t = -10.0;
uniform float mute = 0.3;   // torcida menos saturada que os jogadores
uniform float ola_speed = 14.0;

const vec3 SKINS[5] = vec3[](vec3(0.95, 0.73, 0.54), vec3(0.83, 0.6, 0.42), vec3(0.55, 0.35, 0.23),
	vec3(0.37, 0.23, 0.15), vec3(1.0, 0.84, 0.69));
const vec3 HAIRS[6] = vec3[](vec3(0.15, 0.1, 0.08), vec3(0.35, 0.2, 0.1), vec3(1.0, 0.82, 0.25),
	vec3(1.0, 0.3, 0.25), vec3(0.2, 0.55, 1.0), vec3(1.0, 1.0, 1.0));
const vec3 PROPS[4] = vec3[](vec3(1.0, 1.0, 1.0), vec3(1.0, 0.85, 0.25), vec3(0.2, 0.8, 1.0), vec3(1.0, 0.35, 0.6));
const vec3 PANTS[4] = vec3[](vec3(0.18, 0.25, 0.45), vec3(0.95, 0.95, 0.95), vec3(0.2, 0.2, 0.25), vec3(0.95, 0.6, 0.2));

varying vec3 tint;
varying float shade;

void vertex() {
	float seed = INSTANCE_CUSTOM.x;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 fwd = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 to_ball = ball_pos - origin;
	float ang = atan(fwd.x * to_ball.z - fwd.z * to_ball.x, dot(fwd.xz, to_ball.xz));
	ang = clamp(-ang, -0.8, 0.8) * 0.85;
	float c = cos(ang);
	float s = sin(ang);
	VERTEX.xz = mat2(vec2(c, -s), vec2(s, c)) * VERTEX.xz;
	// ola: uma onda que corre pela arquibancada
	float along = origin.x + origin.z;
	float od = (ola_t * ola_speed - (along + 30.0)) * 0.35;
	float ola = exp(-od * od);
	float hop = abs(sin(TIME * (4.0 + seed * 5.0) + seed * 31.0)) * (0.03 + excitement * 0.4);
	VERTEX.y += hop + ola * 0.45;
	VERTEX.x += sin(TIME * 6.0 + seed * 10.0) * 0.14 * UV.y * (0.25 + excitement);
	VERTEX.y += UV.y * ola * 0.25;
	float region = UV.x;
	vec3 col = COLOR.rgb;
	int skin_i = int(INSTANCE_CUSTOM.y * 4.99);
	int hair_i = int(INSTANCE_CUSTOM.z * 5.99);
	int prop_i = int(INSTANCE_CUSTOM.w * 3.99);
	if (region > 0.2 && region < 0.4) col = SKINS[skin_i];
	else if (region > 0.4 && region < 0.6) col = HAIRS[hair_i];
	else if (region > 0.6 && region < 0.8) col = PROPS[prop_i];
	else if (region > 0.8) col = PANTS[prop_i];
	tint = col;
	shade = clamp(dot(NORMAL, normalize(vec3(-0.45, 0.72, 0.53))) * 2.0 + 0.6, 0.0, 1.0);
}

void fragment() {
	vec3 col = tint * mix(0.72, 1.0, step(0.5, shade));
	float l = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(l) * vec3(1.0, 0.94, 1.0), mute) * 0.94;
	col = mix(col, vec3(1.0, 0.84, 0.72), smoothstep(45.0, 300.0, length(VERTEX)) * 0.7);
	ALBEDO = col;
}
