// Lâmina de névoa (cartão horizontal ou em pé) na LINGUAGEM CEL da v2: volumes recortados em 2 tons, sem borrão
// gaussiano. O ruído vira degraus (corpo e miolo) com borda dura e uma linha mais clara na beirada de cima,
// como os personagens. 'vertical' usa x e y do mundo (névoa que sobe do abismo pela beira do penhasco).
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never, world_vertex_coords;
#include "res://shaders/comum.gdshaderinc"
uniform float densidade = 0.5;
uniform float escala = 0.02;
uniform vec2 deriva = vec2(0.3, 0.1);
uniform vec3 cor : source_color = vec3(0.22, 0.27, 0.34);
uniform float quente = 0.0;
uniform vec3 cor_quente : source_color = vec3(0.9, 0.75, 0.45);
uniform vec2 borda_uv = vec2(0.12, 0.12);
uniform float subir = 0.0;           // a lâmina sobe na Expira
uniform float vertical = 0.0;
varying vec3 wp;
void vertex() { VERTEX.y += subir; wp = VERTEX; }
void fragment() {
	vec2 base = vertical > 0.5 ? vec2(wp.x, wp.y * 1.6) : wp.xz;
	vec2 p = base * escala + deriva * vento.w * 0.02;
	float n = vnoise(p) * 0.55 + vnoise(p * 2.3 + 4.0) * 0.3 + vnoise(p * 5.1 - 2.0) * 0.15;
	vec2 e = min(UV, 1.0 - UV) / borda_uv;
	float m = clamp(min(e.x, e.y), 0.0, 1.0);
	if (vertical > 0.5) m *= smoothstep(0.0, 0.35, UV.y) ;
	float v = n * (0.55 + 0.45 * m) + (m - 1.0) * 0.6;
	float aw = fwidth(v) * 1.2 + 0.002;
	float corpo = smoothstep(0.5 - aw, 0.5 + aw, v);
	float miolo = smoothstep(0.62 - aw, 0.62 + aw, v);
	float beira = corpo - smoothstep(0.535 - aw, 0.535 + aw, v);
	float a = (corpo * 0.55 + miolo * 0.45) * densidade;
	vec3 c = mix(cor * 0.92, cor * 1.12, miolo);
	c = mix(c, cor * 1.45 + 0.02, beira * 0.8);
	c = mix(c, cor_quente, quente * miolo);
	if (a < 0.01) discard;
	ALBEDO = saida(c);
	ALPHA = clamp(a, 0.0, 1.0);
}
