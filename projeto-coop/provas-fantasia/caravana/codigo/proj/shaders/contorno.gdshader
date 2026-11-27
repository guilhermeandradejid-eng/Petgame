// Casca invertida (alfa da cor de vértice = peso). Espessura constante em tela: 2 px na luz (couro escurecido),
// 3,5 px na Treva (tinta-noite), 3 px nos heróis (cor escura do jogador). Mesma curvatura do mundo.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, world_vertex_coords;
#include "res://shaders/comum.gdshaderinc"
uniform float heroi = 0.0;
uniform vec3 cor_heroi : source_color = vec3(0.2, 0.1, 0.1);
uniform float px_luz = 2.0;
uniform float px_treva = 3.5;
uniform float px_heroi = 3.0;
uniform float px_ref = 1080.0;
uniform float forca_pavio = 1.0;
uniform vec4 forcar = vec4(0.0);
uniform float vento_k = 0.0;
varying float vm;
void vertex() {
	if (vento_k > 0.0) {
		float h = max(VERTEX.y - NODE_POSITION_WORLD.y, 0.0);
		float ph = dot(VERTEX.xz, vec2(0.37, 0.21));
		float g = sin(vento.w * 2.1 + ph) * 0.6 + sin(vento.w * 3.7 + ph * 1.7) * 0.4;
		VERTEX.xz += vento.xy * (vento.z * 0.35 + g * 0.18) * h * h * vento_k;
	}
	VERTEX.y -= drop_curva(VERTEX);
	float m, mol, q; vec3 dl;
	pavio(VERTEX, 0.5, m, mol, dl, q);
	m = clamp(m * forca_pavio + forcar.x - forcar.y, 0.0, 1.0);
	vm = m;
	vec4 vp = VIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 nv = normalize((VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
	float span = abs(ortho ? 2.0 / PROJECTION_MATRIX[1][1] : (-vp.z) * 2.0 / PROJECTION_MATRIX[1][1]);
	float px = heroi > 0.5 ? px_heroi : mix(px_treva, px_luz, m);
	float press = 0.8 + 0.4 * h31(floor(VERTEX * 25.0));
	vp.xyz += nv * (px / px_ref * span * COLOR.a * press);
	POSITION = PROJECTION_MATRIX * vp;
}
void fragment() {
	vec3 cor_heroi_l = entrada(cor_heroi);
	vec3 luz = vec3(0.045, 0.022, 0.014);
	ALBEDO = heroi > 0.5 ? cor_heroi_l : mix(C_NOITE * 0.9, luz, vm);
	ALBEDO = saida(ALBEDO);
}
