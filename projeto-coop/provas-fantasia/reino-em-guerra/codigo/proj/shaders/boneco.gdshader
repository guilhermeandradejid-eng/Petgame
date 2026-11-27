// Bonecos e adereços: hachura em UV (metros, segue a forma), aguada da cor de vértice, curvatura de mundo.
shader_type spatial;
render_mode world_vertex_coords, specular_disabled, cull_back;
#include "res://shaders/grav.gdshaderinc"
uniform float extra = 0.0;          // escuridão a mais (descorados)
uniform float clarao = 0.0;         // raio/golpe: vira papel
uniform float achata = 0.0;         // tinta prensada: 0..1 vira mancha de tinta
uniform float isolado = 0.0;        // unção: contorno de cera (no shader de contorno) e brilho de cera no corpo
uniform float aguada_k = 1.0;
uniform float reserva_on = 0.0;
uniform float negativo = 0.0;       // mortos: gravura em negativo (tinta cheia, luz em linha de papel)
uniform float rim = 1.0;
varying vec4 v_col;
varying vec2 v_uv2;
void vertex() {
	VERTEX.y -= curva(VERTEX);
	v_col = COLOR;
	v_uv2 = UV2;
}
void fragment() {
	ALBEDO = vec3(1.0);
	vec4 ag = vec4(v_col.rgb, v_col.a * aguada_k);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	GRAV_SET(wp, UV, ag, v_uv2.y * 97.0, extra);
	if (reserva_on > 0.5) { g_luz.z = reserva(wp); }
	EMISSION = vec3(0.0);
}
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 c = negativo > 0.5 ? grav_neg(NORMAL, LIGHT, VIEW, ATTENUATION, GRAV_GET, rim) : grav_cor(NORMAL, LIGHT, VIEW, ATTENUATION, GRAV_GET);
		c = mix(c, PAPEL_DIA * 1.6, clarao);
		c = mix(c, TINTA, achata);
		c = mix(c, CERA, isolado * 0.25 * step(0.6, 1.0 - dot(NORMAL, VIEW)));
		DIFFUSE_LIGHT += c;
	}
}
