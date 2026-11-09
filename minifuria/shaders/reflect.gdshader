shader_type spatial;
// Passada extra (somada por cima) que dá "verniz" à pintura, reflexo ao vidro e brilho ao metal.
// O renderizador leve (web/celular) não tem reflexo de ambiente de verdade nas peças pequenas:
// aqui o reflexo é montado com o céu do tema (horizonte -> topo), o chão, o brilho do sol e,
// no vidro, faixas de luz presas ao mundo que deslizam pelo para-brisa quando o carro anda.
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 sky_top : source_color = vec3(0.45, 0.65, 0.95);
uniform vec3 sky_hor : source_color = vec3(0.86, 0.91, 0.97);
uniform vec3 ground_col : source_color = vec3(0.18, 0.2, 0.16);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 sun_dir = vec3(0.4, 0.75, 0.5);   // direção PARA o sol (mundo)
uniform float strength = 0.35;   // reflexo do ambiente
uniform float f0 = 0.04;         // reflexo de frente (0,04 verniz/vidro; ~0,6 metal)
uniform float glint = 1.0;       // brilho do sol
uniform float streaks = 0.0;     // faixas de luz (vidro: finas e fortes; pintura: largas e suaves)
uniform float streak_freq = 0.55;
uniform float streak_w = 0.13;
uniform float tint_amt = 0.0;    // metal: o reflexo pega a cor do próprio material
uniform vec3 tint : source_color = vec3(1.0);
uniform float night = 0.0;

void fragment() {
	vec3 N = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 V = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 R = reflect(-V, N);
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	float fres = f0 + (1.0 - f0) * pow(1.0 - ndv, 5.0);
	// ambiente: chão escuro abaixo do horizonte, horizonte claro, topo do céu
	float h = R.y;
	vec3 sky = mix(sky_hor, sky_top, smoothstep(0.05, 0.75, h));
	vec3 env = mix(ground_col, sky, smoothstep(-0.12, 0.04, h));
	// linha do horizonte bem marcada (o "risco" de luz típico de carro envernizado)
	env += sky_hor * smoothstep(0.1, 0.0, abs(h - 0.02)) * 0.35;
	env = mix(env, env * tint, tint_amt);
	vec3 L = normalize(sun_dir);
	float sd = max(dot(R, L), 0.0);
	// brilho do sol mais largo e menos estourado: em carro pequeno e facetado, um ponto finíssimo e 7x mais
	// forte acendia e apagava de um quadro para o outro (cintilação)
	float sun = pow(sd, 150.0) * 2.6 + pow(sd, 28.0) * 0.18;
	vec3 col = env * fres * strength + sun_col * sun * glint * (1.0 - night * 0.7);
	if (streaks > 0.0) {
		vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float u = dot(wp, vec3(0.21, 0.13, 0.17)) + dot(N, vec3(0.3, 0.0, 0.2));
		float b = fract(u * streak_freq * 0.8);
		float s1 = smoothstep(0.0, streak_w * 0.25, b) * smoothstep(streak_w, streak_w * 0.55, b);
		float s2 = smoothstep(streak_w * 1.55, streak_w * 1.7, b) * smoothstep(streak_w * 2.1, streak_w * 1.85, b);
		// só nas faces viradas para cima/para a câmera (onde um reflexo de céu faria sentido)
		s1 *= smoothstep(-0.2, 0.5, N.y);
		s2 *= smoothstep(-0.2, 0.5, N.y);
		col += mix(sky_hor, vec3(1.0), 0.5) * (s1 * 0.55 + s2 * 0.35) * streaks * (0.35 + fres) * (1.0 - night * 0.6);
	}
	ALBEDO = col;
}
