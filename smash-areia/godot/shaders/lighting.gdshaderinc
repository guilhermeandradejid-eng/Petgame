// Iluminação dinâmica compartilhada por todos os materiais "gibi" (unshaded):
//  - sombras de nuvem suaves que atravessam a praia com o vento (de dia);
//  - luz quente e rápida das batidas (a bola ilumina areia, rede e jogadores);
//  - o sol esquenta aos poucos durante a partida (hora dourada);
//  - arena NOITE: círculo dos refletores, luar azul fora dele e a fogueira tremulando.
// Parâmetros globais (project.godot > shader_globals), atualizados pelo jogo.
global uniform float arena_night;
global uniform vec4 hit_light;          // xyz = posição, w = intensidade (0..1)
global uniform vec4 hit_light_color;
global uniform float sun_warmth;        // 0 = tarde, 1 = pôr do sol

float sl_hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743); }
float sl_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(sl_hash(i), sl_hash(i + vec2(1, 0)), f.x), mix(sl_hash(i + vec2(0, 1)), sl_hash(i + vec2(1, 1)), f.x), f.y);
}

vec3 scene_light(vec3 col, vec3 wp) {
	float day = 1.0 - arena_night;
	// sombra de nuvem: manchas grandes e macias andando devagar
	if (day > 0.001) {
		vec2 q = wp.xz * 0.022 + vec2(TIME * 0.012, TIME * 0.005);
		float n = sl_noise(q) * 0.7 + sl_noise(q * 2.3 + 5.0) * 0.3;
		float cs = smoothstep(0.5, 0.78, n) * day * (1.0 - smoothstep(8.0, 30.0, wp.y));
		col *= mix(vec3(1.0), vec3(0.9, 0.86, 0.94), cs * 0.45);   // sombra de nuvem quente: a areia não esverdeia
		// hora dourada: luz mais quente e um pouco mais baixa
		col *= mix(vec3(1.0), vec3(1.04, 0.98, 0.9), sun_warmth * 0.3 * day);
	}
	// noite: refletores e luar
	if (arena_night > 0.001) {
		float d = length(wp.xz * vec2(0.85, 0.6));
		float pool = 1.0 - smoothstep(9.0, 16.0, d);   // elipse clara e nítida em volta da quadra
		pool *= 1.0 - smoothstep(9.0, 22.0, wp.y);
		pool *= 0.97 + 0.03 * sin(TIME * 0.7);
		vec3 moon = col * vec3(0.32, 0.36, 0.6) + vec3(0.012, 0.018, 0.06);
		vec3 lit = col * vec3(0.84, 0.85, 0.93);   // refletor: branco frio, sem estourar
		vec3 n = mix(moon, lit, pool);
		// fogueira de luau tremulando
		float fd = length(wp - vec3(-19.0, 0.6, -17.0));
		float flick = 0.8 + 0.12 * sin(TIME * 13.0) + 0.08 * sin(TIME * 7.3 + 1.0);
		n += col * vec3(1.0, 0.5, 0.18) * (1.0 - smoothstep(0.5, 7.0, fd)) * 0.7 * flick;
		col = mix(col, n, arena_night);
	}
	// luz da batida (some rápido; mais forte no smash e no especial)
	if (hit_light.w > 0.001) {
		float hd = length(wp - hit_light.xyz);
		float fall = 1.0 - smoothstep(0.0, 3.8, hd);
		col += hit_light_color.rgb * fall * fall * hit_light.w * mix(0.22, 0.5, arena_night);
	}
	return col;
}

// linha da praia curva (enseada): usada pela areia e pelo mar para casarem
float shore_off(float x) {
	return 3.0 * sin(x * 0.035) + 1.4 * sin(x * 0.09 + 1.0);
}

// compatibilidade com os nomes antigos
vec3 night_grade(vec3 col, vec3 wp) {
	return scene_light(col, wp);
}

vec3 night_haze(vec3 day_haze) {
	return mix(day_haze * mix(vec3(1.0), vec3(1.02, 0.94, 0.86), sun_warmth * 0.5), vec3(0.05, 0.07, 0.18), arena_night);
}
