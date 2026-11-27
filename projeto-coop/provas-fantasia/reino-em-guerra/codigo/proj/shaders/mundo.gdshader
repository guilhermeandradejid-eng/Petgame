// Pedras, ponte, moinho, casas e marcos do horizonte: buril triplanar (linhas alinhadas às faces, como tábuas e
// pedras gravadas), aguada plana por material. 'distante' tira a curvatura e afina e clareia a gravura (perspectiva
// atmosférica de gravura: linha mais fina e mais clara ao longe).
shader_type spatial;
render_mode world_vertex_coords, specular_disabled, cull_back;
#include "res://shaders/grav.gdshaderinc"
uniform vec3 aguada : source_color = vec3(1.000, 1.000, 1.000);
uniform float aguada_a = 0.0;
uniform float distante = 0.0;
uniform float extra = 0.0;
uniform float esc = 1.0;
uniform float clarao = 0.0;
varying vec3 v_wn;
varying vec4 v_col;
void vertex() {
	if (distante < 0.5) { VERTEX.y -= curva(VERTEX); }
	v_wn = NORMAL;
	v_col = COLOR;
}
void fragment() {
	ALBEDO = vec3(1.0);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 an = abs(v_wn);
	vec2 q = an.y > max(an.x, an.z) ? wp.xz : (an.x > an.z ? wp.zy : wp.xy);
	q /= esc;
	vec4 ag = vec4(cor_u(aguada), aguada_a);
	if (v_col.a > 0.01 && v_col.a < 0.99) { ag = vec4(v_col.rgb, 1.0); }
	GRAV_SET(wp, q, vec4(ag.rgb, ag.a), 5.3 + float(int(wp.x * 0.3)), extra + escuro_mundo * (1.0 - distante) * 0.7);
	if (distante > 0.5) { g_luz.w = distante; g_px *= 1.0; }
}
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		GF g = GRAV_GET;
		if (distante > 0.5) {
			// marco distante: só 2 camadas no máximo, linha clara, névoa por cima
			g.nev = 0.0;
		}
		vec3 c = grav_cor(NORMAL, LIGHT, VIEW, ATTENUATION, g);
		if (distante > 0.5) {
			vec3 pn = mix(papel_frio.rgb, papel_quente.rgb, nevoa.w);
			c = fract(g.grao * 5.17) < (distante - 0.5) * 1.4 ? pn : c;
		}
		c = mix(c, PAPEL_DIA * 1.4, clarao);
		DIFFUSE_LIGHT += c;
	}
}
