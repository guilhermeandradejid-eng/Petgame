// Base redonda de miniatura projetada no chão: sombra de contato + anel do jogador (borda na cor dele, com sinal
// de forma, emissão baixa de 0,6). Inimigos: borda escura e sem emissão; o tamanho da base é o perigo.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never, cull_disabled;
#include "res://shaders/comum.gdshaderinc"
uniform vec3 cor : source_color = vec3(1.0);
uniform float jogador = 1.0;
uniform int sinal = 0;            // 0 círculo, 1 quadrado, 2 triângulo, 3 losango
uniform float emissao = 0.6;
uniform float sombra = 0.55;
uniform float oval = 1.0;
uniform float altura = 0.0;       // no pulo a base fica no chão e encolhe
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float sdf_sinal(vec2 p, int s) {
	if (s == 0) return length(p) - 0.16;
	if (s == 1) return max(abs(p.x), abs(p.y)) - 0.13;
	if (s == 2) { p.y -= 0.03; return max(abs(p.x) * 0.866 + p.y * 0.5, -p.y) - 0.09; }
	return abs(p.x) + abs(p.y) - 0.18;
}
void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * vec2(1.0, oval);
	float k = 1.0 - clamp(altura * 0.35, 0.0, 0.6);
	p /= k;
	float d = length(p);
	float sh = smoothstep(1.0, 0.55, d) * sombra * k;
	vec3 c = vec3(0.02, 0.02, 0.03);
	float a = sh;
	if (jogador > 0.5) {
		float ring = smoothstep(0.035, 0.0, abs(d - 0.86)) ;
		float inner = smoothstep(0.02, 0.0, abs(d - 0.74)) * 0.6;
		// sinal de forma na frente da base (lado da câmera)
		float sg = smoothstep(0.015, -0.015, sdf_sinal(p - vec2(0.0, 0.62), sinal));
		float m = max(max(ring, inner), sg);
		c = mix(c, cor * (1.0 + emissao), m);
		a = max(a, m * 0.95);
	} else {
		float ring = smoothstep(0.05, 0.0, abs(d - 0.88));
		c = mix(c, vec3(0.06, 0.06, 0.08), ring);
		a = max(a, ring * 0.7);
	}
	if (d > 1.0) discard;
	vec4 f = atmos_k(wp, CAMERA_POSITION_WORLD);
	ALBEDO = saida(mix(c, f.rgb, f.a));
	ALPHA = a;
}
