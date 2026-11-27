// Terreno: o buril corre em coordenadas de mundo dobradas pela altura (as linhas sobem e descem com o relevo, como
// curvas de nível). Cor de vértice = aguada da terra retomada (margem sul); UV2.x = escuridão a mais da terra descorada.
shader_type spatial;
render_mode world_vertex_coords, specular_disabled, cull_back;
#include "res://shaders/grav.gdshaderinc"
varying vec4 v_col;
varying float v_ex;
varying float v_rd;
void vertex() {
	VERTEX.y -= curva(VERTEX);
	v_col = COLOR;
	v_ex = UV2.x;
	v_rd = UV2.y;
}
void fragment() {
	ALBEDO = vec3(1.0);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// a dobra usa a altura ANTES da curvatura (guardada em UV.y)
	vec2 q = vec2(wp.x + 0.35 * sin(wp.z * 0.7), wp.z + UV.y * 1.4);
	// estrada: barro pisado (menos linha) com dois sulcos de roda (faixas de hachura densa) e poças
	float est = smoothstep(1.15, 0.85, v_rd);
	float sulco = (1.0 - smoothstep(0.05, 0.11, abs(v_rd - 0.42))) * est;
	float ex = v_ex - est * 0.55 + sulco * 2.2 + escuro_mundo;
	GRAV_SET(wp, q, v_col, -0.065, ex);
	g_luz.z = reserva(wp);
}
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += grav_cor(NORMAL, LIGHT, VIEW, ATTENUATION, GRAV_GET);
	}
}
