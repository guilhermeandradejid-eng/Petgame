// Anel do jogador SEMPRE por cima dos efeitos (sem teste de profundidade, prioridade alta): borda na cor do
// jogador com beirada escura e o sinal de forma (círculo, quadrado, triângulo, losango). Também a seta sobre a
// cabeça (modo 1), recortada em 2 tons.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, shadows_disabled, cull_disabled;
#include "res://shaders/comum.gdshaderinc"
uniform vec3 cor : source_color = vec3(1.0);
uniform int sinal = 0;
uniform int modo = 0;            // 0 anel no chão; 1 seta sobre a cabeça (billboard)
uniform float altura = 0.0;
float sdf_sinal(vec2 p, int s) {
	if (s == 0) return length(p) - 0.16;
	if (s == 1) return max(abs(p.x), abs(p.y)) - 0.13;
	if (s == 2) { p.y -= 0.03; return max(abs(p.x) * 0.866 + p.y * 0.5, -p.y) - 0.09; }
	return abs(p.x) + abs(p.y) - 0.18;
}
void vertex() {
	if (modo == 1) {
		vec3 c = MODEL_MATRIX[3].xyz;
		float s = length(MODEL_MATRIX[0].xyz);
		vec3 v = c + INV_VIEW_MATRIX[0].xyz * VERTEX.x * s + INV_VIEW_MATRIX[1].xyz * VERTEX.y * s;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v, 1.0);
	} else {
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec3 c; float a;
	if (modo == 0) {
		float k = 1.0 - clamp(altura * 0.35, 0.0, 0.6);
		p /= k;
		float d = length(p);
		float ring = step(abs(d - 0.84), 0.09);
		float edge = step(abs(d - 0.84), 0.15) * (1.0 - ring);
		float sg = step(sdf_sinal((p - vec2(0.0, 0.5)) * 0.8, sinal), 0.0);
		float sge = step(sdf_sinal((p - vec2(0.0, 0.5)) * 0.8, sinal), 0.04) * (1.0 - sg);
		c = mix(vec3(0.03, 0.03, 0.05), cor * 1.25, max(ring, sg));
		a = max(max(ring, sg), max(edge, sge) * 0.85);
	} else {
		// seta para baixo: triângulo com beirada escura e o sinal de forma no meio, em branco
		vec2 q = vec2(p.x, -p.y);
		float tri = max(abs(q.x) * 0.866 + q.y * 0.5, -q.y - 0.55) - 0.32;
		float body = step(tri, 0.0);
		float edge = step(tri, 0.12) * (1.0 - body);
		c = mix(vec3(0.03, 0.03, 0.05), cor * 1.2, body);
		a = max(body, edge * 0.9);
	}
	if (a < 0.01) discard;
	ALBEDO = saida(c);
	ALPHA = a;
}
