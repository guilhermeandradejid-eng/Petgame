// Muralha de Treva no horizonte: parede de hachuras horizontais que sobe e desce, sem cor.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, shadows_disabled, blend_mix, depth_draw_never;
#include "res://shaders/comum.gdshaderinc"
uniform float altura_k = 1.0;
varying vec3 vw;
void vertex() { VERTEX.y -= drop_curva(VERTEX); vw = VERTEX; }
void fragment() {
	float sd = floor(ferve);
	float top = 0.55 + 0.3 * vnoise(vec2(UV.x * 14.0, sd * 0.2)) * altura_k + 0.15 * vnoise(vec2(UV.x * 40.0, 3.0));
	if (UV.y > top) discard;
	float k = UV.y / top;
	float c = UV.y * 90.0 + (vnoise(vec2(UV.x * 30.0 + sd, sd)) - 0.5) * 0.7;
	float l = linha(c, mix(0.55, 0.12, k));
	vec3 col = mix(vec3(0.02, 0.025, 0.05), vec3(0.2, 0.24, 0.34), l);
	ALBEDO = col;
	ALPHA = mix(1.0, 0.0, smoothstep(0.75, 1.0, k)) * 0.95;
	ALBEDO = saida(ALBEDO);
}
