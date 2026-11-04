// Animação da torcida (compartilhada pelo shader da cor e pelo do contorno).
// Cada torcedor tem um "jeito" sorteado pela semente: balança (40%), bate palma
// (30%), pula (20%) ou acena (10%). Todos viram o corpo seguindo a bola, ficam
// mais agitados com a emoção do jogo e entram na "ola".
uniform float excitement = 0.0;
uniform vec3 ball_pos = vec3(0.0, 1.0, 0.0);
uniform float ola_t = -10.0;
uniform float ola_speed = 14.0;

vec3 crowd_anim(vec3 v, vec2 uv, vec4 custom, mat4 model, float t) {
	float seed = custom.x;
	vec3 origin = (model * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 fwd = normalize((model * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 to_ball = ball_pos - origin;
	float ang = atan(fwd.x * to_ball.z - fwd.z * to_ball.x, dot(fwd.xz, to_ball.xz));
	ang = clamp(-ang, -0.8, 0.8) * 0.7;
	float c = cos(ang);
	float s = sin(ang);
	v.xz = mat2(vec2(c, -s), vec2(s, c)) * v.xz;
	float along = origin.x + origin.z;
	float od = (ola_t * ola_speed - (along + 30.0)) * 0.35;
	float ola = exp(-od * od);
	float arm = uv.y;
	float ph = seed * 31.0;
	float ex = 0.25 + excitement;
	if (seed < 0.4) {
		// balança de um lado para o outro (1,2 Hz), mais no alto do corpo
		v.x += sin(t * 7.54 + ph) * 0.045 * v.y * ex;
	} else if (seed < 0.7) {
		// palmas: as mãos vão e voltam para o meio (3,5 Hz)
		v.x -= sign(v.x) * max(0.0, sin(t * 22.0 + ph)) * 0.07 * arm;
		v.y += abs(sin(t * 11.0 + ph)) * 0.012;
	} else if (seed < 0.9) {
		v.y += abs(sin(t * (5.0 + seed * 3.0) + ph)) * (0.03 + excitement * 0.35);
	} else {
		v.x += sin(t * 6.0 + ph) * 0.16 * arm * ex;
	}
	v.y += excitement * abs(sin(t * 6.5 + ph)) * 0.08;
	v.y += ola * 0.45 + arm * ola * 0.25;
	return v;
}
